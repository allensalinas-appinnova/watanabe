import 'dart:typed_data';
import 'package:idb_shim/idb_browser.dart';
import '../domain/document_import.dart';

class DocumentDraftStore {
  final Set<String> _cleared = {};
  Future<Database> _db() => getIdbFactory()!.open(
    'lumio_document_drafts',
    version: 1,
    onUpgradeNeeded: (e) {
      e.database.createObjectStore('drafts');
    },
  );
  Future<DocumentDraft?> load(String uid, int generation) async {
    final db = await _db();
    try {
      final tx = db.transaction('drafts', idbModeReadOnly);
      final value = await tx.objectStore('drafts').getObject(uid);
      await tx.completed;
      if (value is! Map) return null;
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
        review: Map<String, Object?>.from(value['review'] as Map),
      );
    } finally {
      db.close();
    }
  }

  Future<void> save(String uid, DocumentDraft d) async {
    if (_cleared.contains('$uid:${d.importId}')) return;
    final db = await _db();
    try {
      final tx = db.transaction('drafts', idbModeReadWrite);
      await tx.objectStore('drafts').put({
        'importId': d.importId,
        'generation': d.generation,
        'contentType': d.file.contentType,
        'bytes': d.file.bytes.toList(),
        'review': d.review,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      }, uid);
      await tx.completed;
    } finally {
      db.close();
    }
  }

  Future<void> clear(String uid) async {
    final db = await _db();
    try {
      final tx = db.transaction('drafts', idbModeReadWrite);
      final store = tx.objectStore('drafts');
      final prior = await store.getObject(uid);
      if (prior is Map) _cleared.add('$uid:${prior['importId']}');
      await store.delete(uid);
      await tx.completed;
    } finally {
      db.close();
    }
  }
}
