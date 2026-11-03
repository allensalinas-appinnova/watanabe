import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/features/document_imports/domain/document_import.dart';
import 'package:personal_finance/features/document_imports/domain/shared_receipt.dart';

class Repo extends Mock implements DocumentImportRepository {}

void main() {
  final now = DateTime.utc(2026, 11, 2, 12);
  final file = DocumentFile(bytes: Uint8List.fromList([1, 2, 3]), contentType: 'image/jpeg');
  late Repo repo;
  late AdoptSharedReceipt adopt;
  SharedReceipt receipt({String? owner, int? generation, DateTime? at}) => SharedReceipt(
    id: 'shared-id',
    file: file,
    receivedAt: at ?? now,
    ownerId: owner,
    generation: generation,
  );
  setUpAll(() {
    registerFallbackValue(DocumentDraft(file: file, importId: 'fallback', generation: 1));
    registerFallbackValue(
      const DocumentImport(id: 'fallback', generation: 1, version: 1, phase: DocumentPhase.ready),
    );
  });
  setUp(() {
    repo = Repo();
    adopt = AdoptSharedReceipt(repo, now: () => now);
    when(() => repo.loadDraft(any(), any())).thenAnswer((_) async => const Right(null));
    when(() => repo.saveDraft(any(), any())).thenAnswer((_) async => const Right(unit));
  });
  test('receiving adopts stable identity without analysis or financial commands', () async {
    expect(
      (await adopt(receipt(owner: 'qa', generation: 1), uid: 'qa', generation: 1)).isRight(),
      isTrue,
    );
    final saved = verify(() => repo.saveDraft('qa', captureAny())).captured.single as DocumentDraft;
    expect(saved.importId, 'shared-id');
    expect(saved.file.bytes, [1, 2, 3]);
    expect(saved.generation, 1);
    verifyNever(() => repo.prepare(any()));
    verifyNever(() => repo.analyze(any()));
  });
  test('other users, stale generations and expired files cannot be adopted', () async {
    for (final source in [
      receipt(owner: 'other', generation: 1),
      receipt(owner: 'qa', generation: 0),
      receipt(at: now.subtract(const Duration(hours: 24))),
    ]) {
      expect((await adopt(source, uid: 'qa', generation: 1)).isLeft(), isTrue);
    }
    verifyNever(() => repo.saveDraft(any(), any()));
  });
  test('unowned file can be adopted only by explicit orchestration after login', () async {
    expect((await adopt(receipt(), uid: 'qa', generation: 1)).isRight(), isTrue);
  });
  test('conflicting draft remains untouched until replacement is confirmed', () async {
    final old = DocumentDraft(file: file, importId: 'old', generation: 1);
    when(() => repo.loadDraft(any(), any())).thenAnswer((_) async => Right(old));
    expect(
      (await adopt(receipt(), uid: 'qa', generation: 1)).getLeft().toNullable()!.message,
      'shared-receipt-conflict',
    );
    verifyNever(() => repo.saveDraft(any(), any()));
    expect((await adopt(receipt(), uid: 'qa', generation: 1, replace: true)).isRight(), isTrue);
  });
  test('discard failure preserves old draft and does not accept new source', () async {
    when(() => repo.loadDraft(any(), any())).thenAnswer(
      (_) async => Right(
        DocumentDraft(
          file: file,
          importId: 'old',
          generation: 1,
          review: {'serverAttempted': true},
        ),
      ),
    );
    when(() => repo.watch('qa', 'old')).thenAnswer(
      (_) => Stream.value(
        const DocumentImport(id: 'old', generation: 1, version: 1, phase: DocumentPhase.ready),
      ),
    );
    when(
      () => repo.discard('old', 1),
    ).thenAnswer((_) async => const Left(NetworkFailure('offline')));
    expect((await adopt(receipt(), uid: 'qa', generation: 1, replace: true)).isLeft(), isTrue);
    verifyNever(() => repo.saveDraft(any(), any()));
  });
  test('lost adoption acknowledgement reuses existing draft without another save', () async {
    when(() => repo.loadDraft(any(), any())).thenAnswer(
      (_) async => Right(DocumentDraft(file: file, importId: 'shared-id', generation: 1)),
    );
    expect((await adopt(receipt(), uid: 'qa', generation: 1)).isRight(), isTrue);
    verifyNever(() => repo.saveDraft(any(), any()));
  });
}
