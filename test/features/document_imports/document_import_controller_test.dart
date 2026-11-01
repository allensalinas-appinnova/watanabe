import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/features/auth/presentation/providers/auth_providers.dart';
import 'package:personal_finance/features/document_imports/data/document_connection.dart';
import 'package:personal_finance/features/document_imports/data/document_file_picker.dart';
import 'package:personal_finance/features/document_imports/data/document_import_mapper.dart';
import 'package:personal_finance/features/document_imports/domain/document_import.dart';
import 'package:personal_finance/features/document_imports/presentation/document_import_providers.dart';

class Repo extends Mock implements DocumentImportRepository {}

class Picker extends Mock implements DocumentFilePicker {}

class Connection extends Mock implements DocumentConnection {}

void main() {
  final file = DocumentFile(bytes: Uint8List.fromList([1, 2, 3]), contentType: 'image/png');
  final draft = DocumentDraft(file: file, importId: 'synthetic-import', generation: 1);
  setUpAll(() {
    registerFallbackValue(draft);
    registerFallbackValue(DocumentFileSource.gallery);
  });
  late Repo repo;
  late Picker picker;
  late Connection connection;
  late ProviderContainer container;
  setUp(() {
    repo = Repo();
    picker = Picker();
    connection = Connection();
    when(() => repo.loadDraft(any(), any())).thenAnswer((_) async => const Right(null));
    when(() => repo.saveDraft(any(), any())).thenAnswer((_) async => const Right(unit));
    when(() => repo.watch(any(), any())).thenAnswer((_) => const Stream.empty());
    when(() => connection.hasNetwork()).thenAnswer((_) async => false);
    when(() => picker.pick(any())).thenAnswer((_) async => file);
    container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith((ref) => const Stream.empty()),
        documentImportRepositoryProvider.overrideWithValue(repo),
        documentFilePickerProvider.overrideWithValue(picker),
        documentConnectionProvider.overrideWithValue(connection),
      ],
    );
  });
  tearDown(() => container.dispose());
  test('offline selection persists draft and never uploads or reserves quota', () async {
    final c = container.read(documentImportControllerProvider.notifier);
    await c.initialize('owner', 1);
    await c.select(DocumentFileSource.gallery);
    await c.analyze();
    final state = container.read(documentImportControllerProvider);
    expect(state.offline, isTrue);
    expect(state.draft!.file.bytes, [1, 2, 3]);
    verify(() => repo.saveDraft('owner', any())).called(1);
    verifyNever(() => repo.prepare(any()));
  });
  test('draft storage failure prevents uploading and is not presented as network loss', () async {
    when(() => repo.loadDraft('owner', 1)).thenAnswer((_) async => Right(draft));
    when(() => connection.hasNetwork()).thenAnswer((_) async => true);
    when(
      () => repo.saveDraft(any(), any()),
    ).thenAnswer((_) async => const Left(UnknownFailure('document-draft-unavailable')));
    final c = container.read(documentImportControllerProvider.notifier);
    await c.initialize('owner', 1);
    await c.analyze();
    expect(
      container.read(documentImportControllerProvider).error!.message,
      'document-draft-unavailable',
    );
    expect(container.read(documentImportControllerProvider).busy, isFalse);
    verifyNever(() => repo.prepare(any()));
  });
  test('failed upload keeps stable import identity and requires server discard', () async {
    when(() => repo.loadDraft('owner', 1)).thenAnswer((_) async => Right(draft));
    when(() => connection.hasNetwork()).thenAnswer((_) async => true);
    when(
      () => repo.prepare(any()),
    ).thenAnswer((_) async => const Left(NetworkFailure('offline', technicalCode: 'unavailable')));
    when(() => repo.discard(any(), any())).thenAnswer((_) async => const Right(unit));
    final c = container.read(documentImportControllerProvider.notifier);
    await c.initialize('owner', 1);
    await c.analyze();
    await c.analyze();
    final sent = verify(() => repo.prepare(captureAny())).captured.cast<DocumentDraft>();
    expect(sent.map((d) => d.importId).toSet(), {'synthetic-import'});
    expect(sent.every((d) => d.review['serverAttempted'] == true), isTrue);
    await c.discard();
    verify(() => repo.discard('synthetic-import', 1)).called(1);
    expect(container.read(documentImportControllerProvider).draft, isNull);
  });
  test('switching UID or data generation isolates the previous draft', () async {
    when(() => repo.loadDraft('owner', 1)).thenAnswer((_) async => Right(draft));
    final c = container.read(documentImportControllerProvider.notifier);
    await c.initialize('owner', 1);
    expect(container.read(documentImportControllerProvider).draft, isNotNull);
    await c.initialize('another-owner', 1);
    expect(container.read(documentImportControllerProvider).draft, isNull);
    expect(c.belongsTo('owner', 1), isFalse);
  });
  test('mapping does not invent extracted fields and treats unknown status safely', () {
    final s = mapDocumentImport('test', {'dataGeneration': 1, 'status': 'future-status'});
    expect(s.phase, DocumentPhase.failed);
    expect(s.suggestion.amountMinor, isNull);
    expect(s.suggestion.accountId, isNull);
    final u = mapUsage({
      'policy': {'enabled': true},
      'dailyUsed': 2,
      'attachmentBytes': 500,
    });
    expect(u.dailyLimit, 5);
    expect(u.monthlyLimit, 20);
    expect(u.attachmentLimit, 100000000);
    expect(u.enabled, isTrue);
  });
}
