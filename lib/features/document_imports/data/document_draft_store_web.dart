import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart';

import '../domain/document_import.dart';

/// A single IndexedDB record keeps bytes, active pointer and cleanup queue atomic.
class DocumentDraftStore {
  final Set<String> _cleared = {};

  Future<Database> _db() => getIdbFactory()!.open(
    'lumio_document_drafts',
    version: 1,
    onUpgradeNeeded: (e) {
      if (!e.database.objectStoreNames.contains('drafts')) {
        e.database.createObjectStore('drafts');
      }
    },
  );

  Future<DocumentDraft?> load(String uid, int generation) async {
    final db = await _db();
    try {
      final tx = db.transaction('drafts', idbModeReadOnly);
      final value = await tx.objectStore('drafts').getObject(uid);
      await tx.completed;
      if (value is! Map || value['active'] == false) return null;
      if (value['generation'] != generation ||
          DateTime.now().millisecondsSinceEpoch - (value['savedAt'] as num).toInt() > 86400000) {
        await clear(uid);
        return null;
      }
      return DocumentDraft(
        importId: value['importId'] as String,
        generation: generation,
        file: DocumentFile(
          bytes: Uint8List.fromList((value['bytes'] as List).cast<int>()),
          contentType: value['contentType'] as String,
        ),
        review: Map<String, Object?>.from(value['review'] as Map? ?? {}),
      );
    } finally {
      db.close();
    }
  }

  Future<void> save(String uid, DocumentDraft draft) async {
    if (_cleared.contains('$uid:${draft.importId}')) return;
    final db = await _db();
    try {
      final tx = db.transaction('drafts', idbModeReadWrite), store = tx.objectStore('drafts');
      final previous = await store.getObject(uid);
      if (previous is Map &&
          previous['active'] != false &&
          previous['importId'] != draft.importId) {
        tx.abort();
        try {
          await tx.completed;
        } catch (_) {
          // The abort protects the newer active draft from a stale save.
        }
        throw StateError('document-draft-changed');
      }
      final old = previous is Map ? Map<String, Object?>.from(previous) : <String, Object?>{};
      await store.put(_record(draft, pending: _cleanups(old)), uid);
      await tx.completed;
    } finally {
      db.close();
    }
  }

  Future<void> replace(
    String uid,
    String expectedImportId,
    DocumentDraft draft, {
    PendingDocumentCleanup? cleanup,
  }) async {
    final db = await _db();
    try {
      final tx = db.transaction('drafts', idbModeReadWrite), store = tx.objectStore('drafts');
      final previous = await store.getObject(uid);
      if (previous is! Map ||
          previous['active'] == false ||
          previous['importId'] != expectedImportId) {
        tx.abort();
        try {
          await tx.completed;
        } catch (_) {
          // The abort is expected for a stale replacement request.
        }
        throw StateError('document-draft-changed');
      }
      final pending = _cleanups(Map<String, Object?>.from(previous));
      if (cleanup != null && !pending.any((item) => item['importId'] == cleanup.importId)) {
        pending.add({'importId': cleanup.importId, 'generation': cleanup.generation});
      }
      await store.put(_record(draft, pending: pending), uid);
      await tx.completed;
    } finally {
      db.close();
    }
  }

  Future<List<PendingDocumentCleanup>> pendingCleanup(String uid) async {
    final db = await _db();
    try {
      final tx = db.transaction('drafts', idbModeReadOnly);
      final value = await tx.objectStore('drafts').getObject(uid);
      await tx.completed;
      if (value is! Map) return const [];
      return _cleanups(Map<String, Object?>.from(value))
          .map(
            (item) => PendingDocumentCleanup(
              importId: item['importId'] as String,
              generation: (item['generation'] as num).toInt(),
            ),
          )
          .toList();
    } finally {
      db.close();
    }
  }

  Future<void> completeCleanup(String uid, String importId) async {
    final db = await _db();
    try {
      final tx = db.transaction('drafts', idbModeReadWrite), store = tx.objectStore('drafts');
      final value = await store.getObject(uid);
      if (value is Map) {
        final record = Map<String, Object?>.from(value);
        record['pendingCleanup'] = _cleanups(record)
          ..removeWhere((item) => item['importId'] == importId);
        await store.put(record, uid);
      }
      await tx.completed;
    } finally {
      db.close();
    }
  }

  Future<void> clearIfMatches(String uid, String expectedImportId) async {
    final db = await _db();
    try {
      final tx = db.transaction('drafts', idbModeReadWrite), store = tx.objectStore('drafts');
      final value = await store.getObject(uid);
      if (value is Map && value['active'] != false && value['importId'] == expectedImportId) {
        _cleared.add('$uid:$expectedImportId');
        await store.put({
          ...Map<String, Object?>.from(value),
          'active': false,
          'bytes': <int>[],
        }, uid);
      }
      await tx.completed;
    } finally {
      db.close();
    }
  }

  Future<void> clear(String uid) async {
    final db = await _db();
    try {
      final tx = db.transaction('drafts', idbModeReadWrite), store = tx.objectStore('drafts');
      final value = await store.getObject(uid);
      if (value is Map) {
        if (value['importId'] is String) _cleared.add('$uid:${value['importId']}');
        await store.put({
          ...Map<String, Object?>.from(value),
          'active': false,
          'bytes': <int>[],
        }, uid);
      }
      await tx.completed;
    } finally {
      db.close();
    }
  }

  Map<String, Object?> _record(
    DocumentDraft draft, {
    required List<Map<String, Object?>> pending,
  }) => {
    'active': true,
    'importId': draft.importId,
    'generation': draft.generation,
    'contentType': draft.file.contentType,
    'bytes': draft.file.bytes.toList(),
    'review': draft.review,
    'savedAt': DateTime.now().millisecondsSinceEpoch,
    'pendingCleanup': pending,
  };

  List<Map<String, Object?>> _cleanups(Map<String, Object?> record) =>
      (record['pendingCleanup'] as List? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(Map<String, Object?>.from)
          .toList();
}
