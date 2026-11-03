import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/features/document_imports/data/shared_receipt_inbox_native.dart';
import 'package:personal_finance/features/document_imports/domain/document_import.dart';
import 'package:personal_finance/features/document_imports/domain/shared_receipt.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late StreamController<List<SharedMediaFile>> incoming;
  late NativeSharedReceiptInbox inbox;
  late StreamSubscription<Either<Failure, SharedReceipt?>> sub;
  late List<Either<Failure, SharedReceipt?>> seen;
  late DateTime now;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lumio-share-test-');
    incoming = StreamController<List<SharedMediaFile>>.broadcast();
    ReceiveSharingIntent.setMockValues(initialMedia: [], mediaStream: incoming.stream);
    now = DateTime.utc(2026, 11, 2);
    inbox = NativeSharedReceiptInbox(
      now: () => now,
      directory: () async => Directory('${dir.path}/inbox'),
      normalize: (bytes, {required pdf}) async =>
          DocumentFile(bytes: bytes, contentType: pdf ? 'application/pdf' : 'image/jpeg'),
    );
    seen = [];
    sub = inbox.watch().listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });
  tearDown(() async {
    await sub.cancel();
    await incoming.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });
  Future<void> flush() async {
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (seen.any((e) => e.isLeft() || e.getOrElse((_) => null) != null)) return;
    }
    fail('No inbox result');
  }

  Future<SharedMediaFile> file(String name) async {
    final f = File('${dir.path}/$name');
    await f.writeAsString('%PDF-QA-synthetic');
    return SharedMediaFile(path: f.path, type: SharedMediaType.file, mimeType: 'application/pdf');
  }

  test('copies the original privately before its temporary permission disappears', () async {
    await inbox.setSession('qa', 1);
    final source = await file('source.pdf');
    incoming.add([source]);
    await flush();
    final receipt = seen.last.getOrElse((_) => null)!;
    expect(receipt.ownerId, 'qa');
    await File(source.path).delete();
    expect(await File('${dir.path}/inbox/source').readAsString(), '%PDF-QA-synthetic');
    expect(receipt.file.contentType, 'application/pdf');
  });
  test('duplicate native callback is consumed once and dismissal removes private copies', () async {
    final source = await file('same.pdf');
    incoming.add([source]);
    await flush();
    final receipt = seen.last.getOrElse((_) => null)!;
    incoming.add([source]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen.where((e) => e.getOrElse((_) => null) != null).length, 1);
    expect((await inbox.dismiss(receipt.id)).isRight(), isTrue);
    expect(await Directory('${dir.path}/inbox').exists(), isFalse);
  });
  test('multiple or unsupported shares never create a private draft', () async {
    incoming.add([await file('a.pdf'), await file('b.pdf')]);
    await flush();
    expect(seen.last.getLeft().toNullable()!.message, 'shared-receipt-one-file');
    expect(await Directory('${dir.path}/inbox').exists(), isFalse);
  });
  test('changing user or generation invalidates an owned inbox', () async {
    await inbox.setSession('qa', 1);
    incoming.add([await file('owned.pdf')]);
    await flush();
    await inbox.setSession('other', 1);
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.getOrElse((_) => null), isNull);
    expect(await Directory('${dir.path}/inbox').exists(), isFalse);
  });
  test('an unowned receipt survives sign-in for explicit account confirmation', () async {
    incoming.add([await file('unowned.pdf')]);
    await flush();
    await inbox.setSession('qa', 2);
    expect(seen.last.getOrElse((_) => null)!.ownerId, isNull);
  });
  test('expiry and reset remove temporary files', () async {
    incoming.add([await file('expired.pdf')]);
    await flush();
    now = now.add(const Duration(hours: 24));
    await inbox.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(seen.last.getOrElse((_) => null), isNull);
    expect(await Directory('${dir.path}/inbox').exists(), isFalse);
  });
}
