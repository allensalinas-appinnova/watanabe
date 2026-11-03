import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/document_imports/data/document_draft_store_native.dart';
import 'package:personal_finance/features/document_imports/domain/document_import.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  late Directory root;
  late DocumentDraftStore store;

  DocumentDraft makeDraft(String id, List<int> bytes) => DocumentDraft(
    file: DocumentFile(bytes: Uint8List.fromList(bytes), contentType: 'image/jpeg'),
    importId: id,
    generation: 4,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('lumio-drafts-');
    store = DocumentDraftStore();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProvider,
      (call) async => call.method == 'getApplicationSupportDirectory' ? root.path : null,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProvider,
      null,
    );
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'replacement switches the active pointer and retains retryable cleanup separately',
    () async {
      final oldDraft = makeDraft('old-import', [1, 2, 3]);
      final nextDraft = makeDraft('new-import', [8, 9]);
      await store.save('owner', oldDraft);

      await store.replace(
        'owner',
        oldDraft.importId,
        nextDraft,
        cleanup: PendingDocumentCleanup(importId: oldDraft.importId, generation: 4),
      );

      final active = await store.load('owner', 4);
      expect(active?.importId, nextDraft.importId);
      expect(active?.file.bytes, [8, 9]);
      expect(await store.pendingCleanup('owner'), [
        isA<PendingDocumentCleanup>()
            .having((item) => item.importId, 'importId', oldDraft.importId)
            .having((item) => item.generation, 'generation', 4),
      ]);

      await expectLater(store.save('owner', oldDraft), throwsA(isA<StateError>()));
      expect((await store.load('owner', 4))?.file.bytes, [8, 9]);

      await store.clearIfMatches('owner', oldDraft.importId);
      expect((await store.load('owner', 4))?.importId, nextDraft.importId);
      await store.completeCleanup('owner', oldDraft.importId);
      expect(await store.pendingCleanup('owner'), isEmpty);
    },
  );

  test('stale expected import id cannot replace the active receipt', () async {
    final oldDraft = makeDraft('active', [1]);
    await store.save('owner', oldDraft);

    await expectLater(
      store.replace('owner', 'different-id', makeDraft('next', [2])),
      throwsA(isA<StateError>()),
    );
    final active = await store.load('owner', 4);
    expect(active?.importId, oldDraft.importId);
    expect(active?.file.bytes, [1]);
  });
}
