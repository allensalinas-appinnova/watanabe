import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fpdart/fpdart.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/firebase_failure_mapper.dart';
import '../domain/document_import.dart';
import 'document_draft_store.dart';
import 'document_import_mapper.dart';

class _DocumentImportFailure implements Exception {
  const _DocumentImportFailure(this.failure);
  final Failure failure;
}

class FirebaseDocumentImportRepository implements DocumentImportRepository {
  FirebaseDocumentImportRepository(
    this.firestore,
    this.functions,
    this.storage,
    this.auth,
    this.drafts,
  );
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final FirebaseStorage storage;
  final FirebaseAuth auth;
  final DocumentDraftStore drafts;
  String get _uid => auth.currentUser!.uid;
  Future<Either<Failure, T>> _run<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on _DocumentImportFailure catch (error) {
      return Left(error.failure);
    } on TimeoutException {
      return const Left(NetworkFailure('document-network', technicalCode: 'unavailable'));
    } on FirebaseFunctionsException catch (e) {
      return Left(
        NetworkFailure(
          e.code == 'deadline-exceeded'
              ? 'document-response-timeout'
              : e.code == 'unauthenticated'
              ? 'document-app-check'
              : e.details is Map
              ? (e.details as Map)['issue'] as String? ?? e.message ?? e.code
              : e.message ?? e.code,
          technicalCode: e.code,
        ),
      );
    } catch (e) {
      if (e is FirebaseException && e.code == 'retry-limit-exceeded') {
        return const Left(NetworkFailure('document-network', technicalCode: 'unavailable'));
      }
      return Left(FirebaseFailureMapper.fromException(e));
    }
  }

  Future<Map<String, dynamic>> _call(String action, Map<String, Object?> data) async =>
      Map<String, dynamic>.from(
        (await functions
                    .httpsCallable(
                      'mutateDocumentImport',
                      options: HttpsCallableOptions(
                        timeout: Duration(seconds: action == 'analyze' ? 180 : 60),
                      ),
                    )
                    .call<Object?>({
                      'action': action,
                      ...data,
                    }))
                .data
            as Map,
      );
  @override
  Future<Either<Failure, DocumentImport>> prepare(DocumentDraft draft) => _run(() async {
    final data = await _call('prepare', {
      'requestId': draft.importId,
      'expectedGeneration': draft.generation,
      'size': draft.file.bytes.length,
      'contentType': draft.file.contentType,
      'sha256': sha256.convert(draft.file.bytes).toString(),
    });
    final session = mapDocumentImport(draft.importId, data);
    if (session.phase != DocumentPhase.prepared || data['storageUploaded'] == true) return session;
    try {
      final task = storage
          .ref(session.storagePath)
          .putData(draft.file.bytes, SettableMetadata(contentType: draft.file.contentType));
      await task.timeout(
        const Duration(seconds: 45),
        onTimeout: () async {
          await task.cancel();
          throw TimeoutException('document-network');
        },
      );
    } on FirebaseException catch (e) {
      // An immutable object may already exist after a lost upload response.
      if (e.code != 'unauthorized') rethrow;
      // The server validates existence, bytes and hash before reserving analysis quota.
      // Do not depend on the asynchronous Storage trigger after a lost response.
      return (await analyze(
        session,
      )).match((failure) => throw _DocumentImportFailure(failure), (value) => value);
    }
    return session;
  });
  @override
  Future<Either<Failure, DocumentImport>> analyze(DocumentImport source) => _run(
    () async => mapDocumentImport(
      source.id,
      await _call('analyze', {'importId': source.id, 'expectedGeneration': source.generation}),
    ),
  );
  @override
  Stream<DocumentImport?> watch(String uid, String id) => firestore
      .doc('users/$uid/documentImports/$id')
      .snapshots()
      .map((d) => d.exists ? mapDocumentImport(d.id, d.data()!) : null);
  @override
  Future<Either<Failure, String>> approve(DocumentApproval a) => _run(() async {
    final ownerUid = _uid;
    final data = <String, Object?>{
      'requestId': 'doc_${a.source.id}',
      'expectedGeneration': a.source.generation,
      'action': a.creditCard ? 'purchase' : 'create',
      'accountId': a.accountId,
      'categoryId': a.categoryId,
      'amountMinor': a.amountMinor,
      'occurredAt': a.occurredAt.toUtc().toIso8601String(),
      'description': a.description,
      'documentImportId': a.source.id,
      'documentImportVersion': a.source.version,
      'confirmedPerformed': true,
      'duplicatesReviewed': a.duplicatesReviewed,
      if (!a.creditCard) ...{
        'type': 'expense',
        'currency': a.currency,
        'monthKey': a.monthKey,
        'idempotencyKey': 'doc_${a.source.id}',
      },
    };
    final result = Map<String, dynamic>.from(
      (await functions
                  .httpsCallable(a.creditCard ? 'mutateDebt' : 'mutateOperation')
                  .call<Object?>(data))
              .data
          as Map,
    );
    final id = result['operationId'] as String? ?? (result['operationIds'] as List).first as String;
    await drafts.clearIfMatches(ownerUid, a.source.id);
    return id;
  });
  @override
  Future<Either<Failure, Unit>> discard(String importId, int generation) => _run(() async {
    final ownerUid = _uid;
    await _call('discard', {'importId': importId, 'expectedGeneration': generation});
    await drafts.clearIfMatches(ownerUid, importId);
    return unit;
  });
  @override
  Future<Either<Failure, UsageSummary>> usage() => _run(
    () async => mapUsage(
      Map<String, dynamic>.from(
        (await functions.httpsCallable('getResourceUsage').call<Object?>()).data as Map,
      ),
    ),
  );
  @override
  Stream<List<DocumentAttachment>> attachments(
    String uid, {
    String? operationId,
    String? attachmentId,
  }) {
    Query<Map<String, dynamic>> q = firestore
        .collection('users')
        .doc(uid)
        .collection('attachments')
        .where('status', isEqualTo: 'active');
    if (attachmentId != null) q = q.where(FieldPath.documentId, isEqualTo: attachmentId);
    if (operationId != null) q = q.where('operationId', isEqualTo: operationId);
    return q.snapshots().map(
      (s) => s.docs.map((d) {
        final m = d.data();
        return DocumentAttachment(
          id: d.id,
          operationId: m['operationId'] as String,
          size: (m['size'] as num).toInt(),
          contentType: m['contentType'] as String,
          generation: (m['dataGeneration'] as num).toInt(),
        );
      }).toList(),
    );
  }

  @override
  Future<Either<Failure, DocumentFile>> readAttachment(String id) => _run(() async {
    final data = Map<String, dynamic>.from(
      (await functions.httpsCallable('mutateAttachment').call<Object?>({
            'action': 'read',
            'attachmentId': id,
          })).data
          as Map,
    );
    return DocumentFile(
      bytes: base64Decode(data['data'] as String),
      contentType: data['contentType'] as String,
    );
  });
  @override
  Future<Either<Failure, Unit>> deleteAttachment(DocumentAttachment a) => _run(() async {
    await functions.httpsCallable('mutateAttachment').call<Object?>({
      'action': 'delete',
      'attachmentId': a.id,
      'expectedGeneration': a.generation,
    });
    return unit;
  });
  @override
  Future<Either<Failure, DocumentDraft?>> loadDraft(String uid, int generation) =>
      _run(() => drafts.load(uid, generation));
  @override
  Future<Either<Failure, Unit>> saveDraft(String uid, DocumentDraft draft) async {
    try {
      if (auth.currentUser?.uid != uid) return const Left(AuthFailure('session-expired'));
      await drafts.save(uid, draft);
      return const Right(unit);
    } on StateError catch (error) {
      return Left(ConflictFailure(error.message));
    } catch (_) {
      return const Left(UnknownFailure('document-draft-unavailable'));
    }
  }

  @override
  Future<Either<Failure, Unit>> replaceDraft(
    String uid,
    String expectedImportId,
    DocumentDraft draft, {
    required bool cleanupPreviousImport,
    required int previousGeneration,
  }) async {
    try {
      if (auth.currentUser?.uid != uid || draft.generation != previousGeneration) {
        return const Left(ConflictFailure('document-draft-changed'));
      }
      await drafts.replace(
        uid,
        expectedImportId,
        draft,
        cleanup: cleanupPreviousImport
            ? PendingDocumentCleanup(importId: expectedImportId, generation: previousGeneration)
            : null,
      );
      if (cleanupPreviousImport) {
        if (auth.currentUser?.uid != uid) return const Right(unit);
        try {
          await _call('discard', {
            'importId': expectedImportId,
            'expectedGeneration': previousGeneration,
          });
          await drafts.completeCleanup(uid, expectedImportId);
        } catch (_) {
          // The new draft is already active. The old remote proposal remains
          // queued locally for a retry and cannot clear the active draft.
        }
      }
      return const Right(unit);
    } on StateError catch (error) {
      return Left(ConflictFailure(error.message));
    } catch (_) {
      return const Left(UnknownFailure('document-draft-unavailable'));
    }
  }

  @override
  Future<void> retryPendingCleanup(String uid) async {
    if (auth.currentUser?.uid != uid) return;
    try {
      for (final cleanup in await drafts.pendingCleanup(uid)) {
        if (auth.currentUser?.uid != uid) return;
        try {
          await _call('discard', {
            'importId': cleanup.importId,
            'expectedGeneration': cleanup.generation,
          });
          await drafts.completeCleanup(uid, cleanup.importId);
        } catch (_) {
          // Retain the item for the next app start or draft replacement.
        }
      }
    } catch (_) {
      // A local store failure must not prevent opening the active draft.
    }
  }

  @override
  Future<void> clearDraft(String uid) => drafts.clear(uid);
}
