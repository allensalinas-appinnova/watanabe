import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/document_import.dart';

/// Private app storage; metadata is switched only after the new bytes are safe.
class DocumentDraftStore {
  Future<void> _pending = Future.value();
  final Set<String> _cleared = {};

  Future<Directory> _directory(String uid) async {
    final base = await getApplicationSupportDirectory();
    return Directory(
      p.join(base.path, 'document_drafts', sha256.convert(utf8.encode(uid)).toString()),
    );
  }

  Future<DocumentDraft?> load(String uid, int generation) async {
    await _pending.catchError((Object _) {});
    final dir = await _directory(uid), meta = File(p.join(dir.path, 'draft.json'));
    if (!await meta.exists()) return null;
    final m = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
    if (m['active'] == false) return null;
    if (m['generation'] != generation ||
        DateTime.now().millisecondsSinceEpoch - (m['savedAt'] as num).toInt() > 86400000) {
      await clear(uid);
      return null;
    }
    final sourceName = m['sourceKey'] as String? ?? 'source';
    return DocumentDraft(
      file: DocumentFile(
        bytes: await File(p.join(dir.path, sourceName)).readAsBytes(),
        contentType: m['contentType'] as String,
      ),
      importId: m['importId'] as String,
      generation: generation,
      review: Map<String, Object?>.from(m['review'] as Map? ?? {}),
    );
  }

  Future<void> save(String uid, DocumentDraft draft) => _enqueue(() async {
    if (_cleared.contains('$uid:${draft.importId}')) return;
    final dir = await _directory(uid);
    await dir.create(recursive: true);
    final meta = File(p.join(dir.path, 'draft.json'));
    final previous = await _readMeta(meta);
    if (previous?['active'] == true && previous?['importId'] != draft.importId) {
      // A delayed write from an older review must never replace the active draft.
      throw StateError('document-draft-changed');
    }
    final key = await _writeBytes(dir, draft, previous);
    await _writeMeta(meta, {
      ...?previous,
      'active': true,
      'generation': draft.generation,
      'contentType': draft.file.contentType,
      'importId': draft.importId,
      'sourceKey': key,
      'review': draft.review,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
    });
  });

  Future<void> replace(
    String uid,
    String expectedImportId,
    DocumentDraft draft, {
    PendingDocumentCleanup? cleanup,
  }) => _enqueue(() async {
    final dir = await _directory(uid);
    await dir.create(recursive: true);
    final meta = File(p.join(dir.path, 'draft.json'));
    final previous = await _readMeta(meta);
    if (previous?['active'] != true || previous?['importId'] != expectedImportId) {
      throw StateError('document-draft-changed');
    }
    final key = await _writeBytes(dir, draft, null);
    final cleanups = _cleanupMaps(previous);
    if (cleanup != null && !cleanups.any((c) => c['importId'] == cleanup.importId)) {
      cleanups.add({'importId': cleanup.importId, 'generation': cleanup.generation});
    }
    try {
      await _writeMeta(meta, {
        'active': true,
        'generation': draft.generation,
        'contentType': draft.file.contentType,
        'importId': draft.importId,
        'sourceKey': key,
        'review': draft.review,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'pendingCleanup': cleanups,
      });
    } catch (_) {
      final staged = File(p.join(dir.path, key));
      if (await staged.exists()) await staged.delete();
      rethrow;
    }
    await _deleteSourceIfUnused(dir, previous);
  });

  Future<List<PendingDocumentCleanup>> pendingCleanup(String uid) async {
    await _pending.catchError((Object _) {});
    final dir = await _directory(uid), meta = await _readMeta(File(p.join(dir.path, 'draft.json')));
    return _cleanupMaps(meta)
        .map(
          (c) => PendingDocumentCleanup(
            importId: c['importId'] as String,
            generation: (c['generation'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<void> completeCleanup(String uid, String importId) => _enqueue(() async {
    final dir = await _directory(uid), file = File(p.join(dir.path, 'draft.json'));
    final meta = await _readMeta(file);
    if (meta == null) return;
    final cleanups = _cleanupMaps(meta)..removeWhere((c) => c['importId'] == importId);
    await _writeMeta(file, {...meta, 'pendingCleanup': cleanups});
  });

  Future<void> clearIfMatches(String uid, String expectedImportId) => _enqueue(() async {
    final dir = await _directory(uid), file = File(p.join(dir.path, 'draft.json'));
    final meta = await _readMeta(file);
    if (meta?['active'] != true || meta?['importId'] != expectedImportId) return;
    _cleared.add('$uid:$expectedImportId');
    final sourceName = meta?['sourceKey'] as String? ?? 'source';
    final source = File(p.join(dir.path, sourceName));
    if (await source.exists()) await source.delete();
    await _writeMeta(file, {...meta!, 'active': false, 'review': {}});
  });

  Future<void> clear(String uid) => _enqueue(() async {
    final dir = await _directory(uid), file = File(p.join(dir.path, 'draft.json'));
    final meta = await _readMeta(file);
    if (meta == null) return;
    final id = meta['importId'];
    if (id is String) _cleared.add('$uid:$id');
    final source = File(p.join(dir.path, meta['sourceKey'] as String? ?? 'source'));
    if (await source.exists()) await source.delete();
    await _writeMeta(file, {...meta, 'active': false, 'review': {}});
  });

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final next = _pending.catchError((Object _) {}).then((_) => action());
    _pending = next.then<void>((_) {}, onError: (_, _) {});
    return next;
  }

  Future<Map<String, dynamic>?> _readMeta(File file) async {
    if (!await file.exists()) return null;
    return Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map);
  }

  Future<String> _writeBytes(
    Directory dir,
    DocumentDraft draft,
    Map<String, dynamic>? previous,
  ) async {
    final key = previous?['active'] == true && previous?['importId'] == draft.importId
        ? (previous?['sourceKey'] as String? ?? 'source')
        : 'source_${sha256.convert(utf8.encode(draft.importId))}';
    final existing = File(p.join(dir.path, key));
    if (await existing.exists() && previous?['importId'] == draft.importId) return key;
    final staged = File(p.join(dir.path, '$key.tmp'));
    await staged.writeAsBytes(draft.file.bytes, flush: true);
    await staged.rename(existing.path);
    return key;
  }

  Future<void> _writeMeta(File file, Map<String, Object?> value) async {
    final staged = File('${file.path}.tmp');
    await staged.writeAsString(jsonEncode(value), flush: true);
    await staged.rename(file.path);
  }

  List<Map<String, dynamic>> _cleanupMaps(Map<String, dynamic>? meta) =>
      (meta?['pendingCleanup'] as List? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList();

  Future<void> _deleteSourceIfUnused(Directory dir, Map<String, dynamic>? old) async {
    if (old == null) return;
    final oldName = old['sourceKey'] as String? ?? 'source';
    final newMeta = await _readMeta(File(p.join(dir.path, 'draft.json')));
    if (newMeta?['sourceKey'] == oldName) return;
    final file = File(p.join(dir.path, oldName));
    if (await file.exists()) await file.delete();
  }
}
