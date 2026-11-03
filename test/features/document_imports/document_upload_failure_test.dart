import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/features/document_imports/data/document_draft_store.dart';
import 'package:personal_finance/features/document_imports/data/firebase_document_import_repository.dart';
import 'package:personal_finance/features/document_imports/domain/document_import.dart';

class _Firestore extends Mock implements FirebaseFirestore {}

class _Functions extends Mock implements FirebaseFunctions {}

class _Storage extends Mock implements FirebaseStorage {}

class _Auth extends Mock implements FirebaseAuth {}

class _Drafts extends Mock implements DocumentDraftStore {}

class _Callable extends Mock implements HttpsCallable {}

class _Result extends Mock implements HttpsCallableResult<Object?> {}

class _Reference extends Mock implements Reference {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(SettableMetadata());
  });
  test('unauthorized upload fallback preserves the specific missing-upload failure', () async {
    final functions = _Functions(),
        storage = _Storage(),
        callable = _Callable(),
        reference = _Reference(),
        prepared = _Result();
    when(
      () => functions.httpsCallable('mutateDocumentImport', options: any(named: 'options')),
    ).thenReturn(callable);
    when(() => prepared.data).thenReturn({
      'status': 'prepared',
      'version': 1,
      'dataGeneration': 0,
      'storagePath': 'users/synthetic/documentImports/0/import-id/source',
      'storageUploaded': false,
    });
    when(() => callable.call<Object?>(any<Object?>())).thenAnswer((call) async {
      final data = call.positionalArguments.single as Map;
      if (data['action'] == 'prepare') return prepared;
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'document-upload-required',
      );
    });
    when(() => storage.ref(any())).thenReturn(reference);
    when(
      () => reference.putData(any(), any()),
    ).thenThrow(FirebaseException(plugin: 'firebase_storage', code: 'unauthorized'));
    final repo = FirebaseDocumentImportRepository(
      _Firestore(),
      functions,
      storage,
      _Auth(),
      _Drafts(),
    );
    final result = await repo.prepare(
      DocumentDraft(
        file: DocumentFile(bytes: Uint8List.fromList([1, 2, 3]), contentType: 'image/png'),
        importId: 'import-id',
        generation: 0,
      ),
    );
    expect(result.getLeft().toNullable()?.message, 'document-upload-required');
    expect(result.getLeft().toNullable()?.technicalCode, 'failed-precondition');
  });
}
