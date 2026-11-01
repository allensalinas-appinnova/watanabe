import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/document_import.dart';

/// Private app storage; no shared Downloads, filenames or credentials in metadata.
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
    if (m['generation'] != generation ||
        DateTime.now().millisecondsSinceEpoch - (m['savedAt'] as num).toInt() > 86400000) {
      await clear(uid);
      return null;
    }
    return DocumentDraft(
      file: DocumentFile(
        bytes: await File(p.join(dir.path, 'source')).readAsBytes(),
        contentType: m['contentType'] as String,
      ),
      importId: m['importId'] as String,
      generation: generation,
      review: Map<String, Object?>.from(m['review'] as Map? ?? {}),
    );
  }

  Future<void> save(String uid, DocumentDraft draft) {
    final next = _pending.catchError((Object _) {}).then((_) => _save(uid, draft));
    _pending = next;
    return next;
  }

  Future<void> _save(String uid, DocumentDraft draft) async {
    if (_cleared.contains('$uid:${draft.importId}')) return;
    final dir = await _directory(uid);
    await dir.create(recursive: true);
    final existing = File(p.join(dir.path, 'draft.json'));
    final sameSource =
        await existing.exists() &&
        (jsonDecode(await existing.readAsString()) as Map)['importId'] == draft.importId &&
        await File(p.join(dir.path, 'source')).exists();
    if (!sameSource) {
      await File(p.join(dir.path, 'source.tmp')).writeAsBytes(draft.file.bytes, flush: true);
      await File(p.join(dir.path, 'source.tmp')).rename(p.join(dir.path, 'source'));
    }
    await File(p.join(dir.path, 'draft.tmp')).writeAsString(
      jsonEncode({
        'generation': draft.generation,
        'contentType': draft.file.contentType,
        'importId': draft.importId,
        'review': draft.review,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      }),
      flush: true,
    );
    await File(p.join(dir.path, 'draft.tmp')).rename(p.join(dir.path, 'draft.json'));
  }

  Future<void> clear(String uid) async {
    await _pending.catchError((Object _) {});
    final dir = await _directory(uid);
    if (await dir.exists()) {
      final meta = File(p.join(dir.path, 'draft.json'));
      if (await meta.exists()) {
        _cleared.add('$uid:${(jsonDecode(await meta.readAsString()) as Map)['importId']}');
      }
      await dir.delete(recursive: true);
    }
  }
}
