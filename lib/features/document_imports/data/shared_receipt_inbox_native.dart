import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../../core/error/failure.dart';
import '../../../core/utils/request_id.dart';
import '../domain/document_import.dart';
import '../domain/shared_receipt.dart';
import 'document_file_picker.dart';

class NativeSharedReceiptInbox implements SharedReceiptInbox {
  NativeSharedReceiptInbox({
    DateTime Function()? now,
    Future<Directory> Function()? directory,
    Future<DocumentFile> Function(Uint8List bytes, {required bool pdf})? normalize,
  }) : _now = now ?? DateTime.now,
       _directory = directory,
       _normalize = normalize ?? DocumentFilePicker.normalize;
  final DateTime Function() _now;
  final Future<Directory> Function()? _directory;
  final Future<DocumentFile> Function(Uint8List bytes, {required bool pdf}) _normalize;
  final _events = StreamController<Either<Failure, SharedReceipt?>>.broadcast();
  StreamSubscription<List<SharedMediaFile>>? _native;
  SharedReceipt? _pending;
  String? _uid;
  int? _generation;
  bool _started = false;
  Timer? _expiry;
  Future<void> _serial = Future.value();
  final Set<String> _seen = {};
  Future<Directory> _folder() async {
    if (_directory != null) return _directory();
    return Directory(p.join((await getApplicationSupportDirectory()).path, 'shared_receipt_inbox'));
  }

  @override
  Stream<Either<Failure, SharedReceipt?>> watch() async* {
    if (!_started) {
      _started = true;
      _native = ReceiveSharingIntent.instance.getMediaStream().listen(
        _enqueue,
        onError: (Object _) => _events.add(const Left(UnknownFailure('document-file-invalid'))),
      );
      await refresh();
      try {
        _enqueue(await ReceiveSharingIntent.instance.getInitialMedia());
      } catch (_) {
        _events.add(const Left(UnknownFailure('document-file-invalid')));
      }
    }
    yield Right(_pending);
    try {
      yield* _events.stream;
    } finally {
      _expiry?.cancel();
      await _native?.cancel();
      _native = null;
      _started = false;
    }
  }

  @override
  Future<void> setSession(String? uid, int? generation, {bool resetting = false}) async {
    _uid = uid;
    _generation = generation;
    final pending = _pending;
    if (pending != null &&
        (resetting || (pending.ownerId != null && !pending.matches(uid ?? '', generation ?? -1)))) {
      await dismiss(pending.id);
    }
  }

  @override
  Future<void> refresh() async {
    try {
      if (Platform.isIOS) {
        await const MethodChannel('lumio/shared_receipts').invokeMethod<void>('purgeExpired');
      }
      final dir = await _folder(), meta = File(p.join((await _folder()).path, 'pending.json'));
      if (!await meta.exists()) return;
      final data = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      final receipt = SharedReceipt(
        id: data['id'] as String,
        file: DocumentFile(
          bytes: await File(p.join(dir.path, 'source')).readAsBytes(),
          contentType: data['mime'] as String,
        ),
        receivedAt: DateTime.parse(data['receivedAt'] as String),
        ownerId: data['uid'] as String?,
        generation: data['generation'] as int?,
      );
      _pending = receipt;
      _armExpiry(receipt);
      if (receipt.isExpired(_now()) ||
          (receipt.ownerId != null && _uid != null && !receipt.matches(_uid!, _generation ?? -1))) {
        await dismiss(receipt.id);
        return;
      }
      _events.add(Right(receipt));
    } catch (_) {
      _events.add(const Left(UnknownFailure('shared-receipt-retry')));
    }
  }

  void _armExpiry(SharedReceipt receipt) {
    _expiry?.cancel();
    final delay = receipt.receivedAt.add(const Duration(hours: 24)).difference(_now());
    _expiry = Timer(delay.isNegative ? Duration.zero : delay, () => unawaited(dismiss(receipt.id)));
  }

  void _enqueue(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final uid = _uid, generation = _generation;
    _serial = _serial.catchError((Object _) {}).then((_) => _receive(files, uid, generation));
  }

  Future<void> _receive(List<SharedMediaFile> files, String? uid, int? generation) async {
    try {
      if (files.length != 1) throw StateError('shared-receipt-one-file');
      final signature = <String>[];
      for (final f in files) {
        final stat = await File(f.path).stat();
        if (stat.type == FileSystemEntityType.notFound &&
            _seen.any((key) => key.contains(':${f.path}:'))) {
          return;
        }
        signature.add(
          '${f.type.name}:${f.path}:${stat.modified.microsecondsSinceEpoch}:${stat.size}',
        );
      }
      final event = signature.join('|');
      if (_seen.contains(event)) return;
      final item = files.single;
      if (item.type != SharedMediaType.image && item.type != SharedMediaType.file) {
        throw StateError('document-file-invalid');
      }
      if (_pending != null) throw StateError('shared-receipt-busy');
      final source = File(item.path);
      final size = await source.length();
      if (size == 0 || size > 20000000) throw StateError('document-file-invalid');
      final bytes = await source.readAsBytes();
      final isPdf =
          bytes.length > 4 && ascii.decode(bytes.sublist(0, 5), allowInvalid: true) == '%PDF-';
      if (item.type == SharedMediaType.file &&
          !isPdf &&
          !DocumentFilePicker.isSupportedImage(bytes) &&
          !(item.mimeType?.startsWith('image/') ?? false)) {
        throw StateError('document-file-invalid');
      }
      final file = await _normalize(bytes, pdf: isPdf);
      if (uid != null && (uid != _uid || generation != _generation)) return;
      final fingerprint = sha256.convert(bytes).toString();
      final dir = await _folder();
      await dir.create(recursive: true);
      final receipt = SharedReceipt(
        id: newRequestId(),
        file: file,
        receivedAt: _now(),
        ownerId: uid,
        generation: generation,
      );
      await File(p.join(dir.path, 'source')).writeAsBytes(file.bytes, flush: true);
      await File(p.join(dir.path, 'pending.json')).writeAsString(
        jsonEncode({
          'id': receipt.id,
          'mime': file.contentType,
          'receivedAt': receipt.receivedAt.toIso8601String(),
          'uid': uid,
          'generation': generation,
          'fingerprint': fingerprint,
        }),
        flush: true,
      );
      _pending = receipt;
      _armExpiry(receipt);
      _seen.add(event);
      if (_seen.length > 32) _seen.remove(_seen.first);
      await ReceiveSharingIntent.instance.reset();
      await _cleanNativeCopy(item.path);
      _events.add(Right(receipt));
    } catch (e) {
      final code = e is StateError && e.message.startsWith('shared-receipt-')
          ? e.message
          : 'document-file-invalid';
      _events.add(Left(UnknownFailure(code)));
      await ReceiveSharingIntent.instance.reset();
      for (final file in files) {
        await _cleanNativeCopy(file.path);
      }
    }
  }

  Future<void> _cleanNativeCopy(String path) async {
    try {
      final roots = [(await getTemporaryDirectory()).path];
      if (Platform.isIOS) {
        final group = await const MethodChannel(
          'lumio/shared_receipts',
        ).invokeMethod<String>('groupPath');
        if (group != null) roots.add(group);
      }
      final source = File(path);
      if (roots.any((r) => p.isWithin(r, source.absolute.path)) && await source.exists()) {
        await source.delete();
      }
    } catch (_) {
      /* Inventory is retried when the app resumes. */
    }
  }

  @override
  Future<Either<Failure, Unit>> dismiss(String id) async {
    if (_pending?.id != id) return const Right(unit);
    try {
      final dir = await _folder();
      if (await dir.exists()) await dir.delete(recursive: true);
      _expiry?.cancel();
      _pending = null;
      _events.add(const Right(null));
      return const Right(unit);
    } catch (_) {
      return const Left(UnknownFailure('shared-receipt-retry'));
    }
  }
}
