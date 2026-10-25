// Firestore's sealed SDK interfaces are mocked only at the repository boundary.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_finance/core/error/failure.dart';
import 'package:personal_finance/core/offline/pending_operation_queue.dart';
import 'package:personal_finance/core/offline/sync_state.dart';
import 'package:personal_finance/features/coach/data/repositories/firestore_coach_repository.dart';
import 'package:personal_finance/features/coach/domain/entities/coach_models.dart';
import 'package:personal_finance/features/coach/domain/repositories/coach_repository.dart';
import 'package:personal_finance/features/finance/domain/entities/financial_operation.dart';

class MockFirestore extends Mock implements FirebaseFirestore {}

class MockCollection extends Mock implements CollectionReference<Map<String, dynamic>> {}

class MockDocument extends Mock implements DocumentReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockSnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocument extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockMetadata extends Mock implements SnapshotMetadata {}

class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

class MockPendingDatabase extends Mock implements PendingOperationDatabase {}

void main() {
  final date = DateTime.utc(2026, 10, 22);
  Map<String, dynamic> operation(String key) => {
    'type': 'expense',
    'amountMinor': 125,
    'currency': 'COP',
    'occurredAt': Timestamp.fromDate(date),
    'idempotencyKey': key,
    'status': 'confirmed',
    'accountId': 'cash',
    'categoryId': 'food',
  };

  test('strict operation mapping keeps transfer accounts and pending metadata', () {
    final result = FirestoreCoachRepository.operationFromMap('id', {
      ...operation('key'),
      'type': 'transfer',
      'sourceAccountId': 'cash',
      'destinationAccountId': 'bank',
    }, pending: true);
    expect(result.sourceAccountId, 'cash');
    expect(result.destinationAccountId, 'bank');
    expect(result.status, OperationStatus.pending);
    expect(result.monthKey, '2026-10');
    expect(
      () => FirestoreCoachRepository.operationFromMap('id', {
        ...operation('key'),
        'amountMinor': null,
      }),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => FirestoreCoachRepository.operationFromMap('id', {
        ...operation('key'),
        'occurredAt': 'bad',
      }),
      throwsFormatException,
    );
  });

  test('completion mapping permits unresolved server timestamp', () {
    final result = FirestoreCoachRepository.completionFromMap({
      'periodKey': '2026-10-19',
      'kind': 'weekly',
      'noMovements': true,
      'reviewedAt': null,
    }, pending: true);
    expect(result.kind, CoachReviewKind.weekly);
    expect(result.noMovements, true);
    expect(result.pending, true);
    expect(result.reviewedAt, isNull);
    expect(
      FirestoreCoachRepository.completionFromMap({
        'periodKey': '2026-10-22',
        'kind': 'daily',
        'reviewedAt': Timestamp.fromDate(date),
      }).reviewedAt!.toUtc(),
      date,
    );
  });

  late MockFirestore firestore;
  late MockDocument user;
  late MockCollection collection;
  late MockQuery query;
  late MockMetadata metadata;
  late FirestoreCoachRepository repository;
  late PendingOperationDatabase database;

  setUp(() {
    firestore = MockFirestore();
    user = MockDocument();
    final users = MockCollection();
    collection = MockCollection();
    query = MockQuery();
    metadata = MockMetadata();
    final profileSnapshot = MockDocumentSnapshot();
    // Mocktail requires a closure here to capture the zero-argument invocation.
    // ignore: unnecessary_lambdas
    when(() => profileSnapshot.data()).thenReturn({'dataGeneration': 0});
    when(() => user.get()).thenAnswer((_) => Future.value(profileSnapshot));
    database = PendingOperationDatabase(NativeDatabase.memory());
    repository = FirestoreCoachRepository(firestore: firestore, pendingOperations: database);
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('alice')).thenReturn(user);
    when(() => user.collection('operations')).thenReturn(collection);
    when(
      () => collection.where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(date)),
    ).thenReturn(query);
    when(
      () => query.where(
        'occurredAt',
        isLessThan: Timestamp.fromDate(date.add(const Duration(days: 1))),
      ),
    ).thenReturn(query);
    when(() => query.orderBy('occurredAt', descending: true)).thenReturn(query);
    when(() => query.orderBy(FieldPath.documentId, descending: true)).thenReturn(query);
    when(() => query.limit(100)).thenReturn(query);
    when(() => metadata.hasPendingWrites).thenReturn(false);
    when(() => metadata.isFromCache).thenReturn(false);
  });

  tearDown(() async {
    await repository.dispose();
    await database.close();
  });

  MockSnapshot snapshot(int count, {int offset = 0}) {
    final result = MockSnapshot();
    when(() => result.metadata).thenReturn(metadata);
    final docs = List.generate(count, (i) {
      final doc = MockQueryDocument();
      when(() => doc.id).thenReturn('id-${offset + i}');
      when(doc.data).thenReturn(operation('key-${offset + i}'));
      when(() => doc.metadata).thenReturn(metadata);
      return doc;
    });
    when(() => result.docs).thenReturn(docs);
    return result;
  }

  Future<void> enqueue(
    String key,
    String owner, {
    String type = 'operation',
    DateTime? occurredAt,
  }) => database
      .enqueue(
        idempotencyKey: key,
        operationType: type,
        payload: {
          ...operation(key),
          'occurredAt': (occurredAt ?? date).toIso8601String(),
          'ownerUserId': owner,
          'sourceAccountId': 'a',
          'destinationAccountId': 'b',
        },
      )
      .then((_) {});

  test('loads all pages and merges owner scoped pending and rejected with deduplication', () async {
    final first = snapshot(100);
    final second = snapshot(1, offset: 100);
    var reads = 0;
    when(() => query.get()).thenAnswer((_) async => reads++ == 0 ? first : second);
    when(() => query.startAfter([Timestamp.fromDate(date), 'id-99'])).thenReturn(query);
    await enqueue('key-0', 'alice');
    await enqueue('other-owner', 'bob');
    await enqueue('pending-transfer', 'alice', type: 'transfer');
    await enqueue('rejected', 'alice');
    final rejected = await database.findByIdempotencyKey('rejected');
    await database.markRejected(rejected!.id, SyncIssueCode.permissionDenied);
    final result = await repository.loadReport(
      'alice',
      startAt: date,
      endAtExclusive: date.add(const Duration(days: 1)),
    );
    final report = result.getOrElse((failure) => throw StateError(failure.message));
    expect(reads, 2);
    expect(report.operations, hasLength(103));
    expect(report.confirmedCount, 101);
    expect(report.pendingCount, 1);
    expect(report.rejectedCount, 1);
    expect(
      report.operations.singleWhere((v) => v.idempotencyKey == 'pending-transfer').sourceAccountId,
      'a',
    );
    expect(report.totalsByCurrency['COP']!.expenseMinor, 101 * 125);
    expect(report.freshness, CoachFreshness.fresh);
  });

  test('cached empty snapshot is cached, query errors are failures', () async {
    when(() => metadata.isFromCache).thenReturn(true);
    when(() => query.get()).thenAnswer((_) async => snapshot(0));
    final cached = await repository.loadReport(
      'alice',
      startAt: date,
      endAtExclusive: date.add(const Duration(days: 1)),
    );
    expect(cached.getOrElse((_) => throw StateError('failed')).freshness, CoachFreshness.cached);
    when(
      () => query.get(),
    ).thenThrow(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
    final failed = await repository.loadReport(
      'alice',
      startAt: date,
      endAtExclusive: date.add(const Duration(days: 1)),
    );
    expect(failed.isLeft(), true);
  });

  test(
    'active merge includes syncing and explicit types within owner and period boundaries',
    () async {
      when(() => query.get()).thenAnswer((_) async => snapshot(1));
      for (final type in ['operation', 'income', 'expense', 'transfer']) {
        await enqueue('syncing-$type', 'alice', type: type);
        final row = await database.findByIdempotencyKey('syncing-$type');
        await database.markSyncing(row!.id);
      }
      await enqueue('key-0', 'alice');
      final duplicate = await database.findByIdempotencyKey('key-0');
      await database.markSyncing(duplicate!.id);
      await enqueue('foreign', 'bob');
      final foreign = await database.findByIdempotencyKey('foreign');
      await database.markSyncing(foreign!.id);
      await enqueue('before', 'alice', occurredAt: date.subtract(const Duration(microseconds: 1)));
      await enqueue('at-end', 'alice', occurredAt: date.add(const Duration(days: 1)));
      await enqueue('unsupported', 'alice', type: 'balance-adjustment');
      await enqueue('confirmed', 'alice');
      final confirmed = await database.findByIdempotencyKey('confirmed');
      await database.markConfirmed(confirmed!.id);
      final result = await repository.loadReport(
        'alice',
        startAt: date,
        endAtExclusive: date.add(const Duration(days: 1)),
      );
      final report = result.getOrElse((failure) => throw StateError(failure.message));
      expect(report.operations, hasLength(5));
      expect(report.confirmedCount, 1);
      expect(report.pendingCount, 4);
      expect(report.rejectedCount, 0);
      expect(report.totalsByCurrency['COP']!.incomeMinor, 0);
      expect(report.totalsByCurrency['COP']!.expenseMinor, 125);
      expect(
        report.operations.singleWhere((v) => v.idempotencyKey == 'syncing-income').type,
        OperationType.income,
      );
      final transfer = report.operations.singleWhere((v) => v.idempotencyKey == 'syncing-transfer');
      expect(transfer.type, OperationType.transfer);
      expect(transfer.sourceAccountId, 'a');
      expect(transfer.destinationAccountId, 'b');
      expect(
        report.operations.singleWhere((v) => v.idempotencyKey == 'key-0').status,
        OperationStatus.confirmed,
      );
    },
  );

  test('completion writes exact deterministic map and preserves late server errors', () async {
    final completions = MockCollection();
    final document = MockDocument();
    final server = Completer<void>();
    when(() => user.collection('coachDailyCheckIns')).thenReturn(completions);
    when(() => completions.doc('2026-10-22')).thenReturn(document);
    when(() => document.set(any())).thenAnswer((_) => server.future);
    final failures = <CoachWriteFailure>[];
    final CoachRepository contract = repository;
    final subscription = contract.watchWriteFailures('alice').listen(failures.add);
    final otherUserFailures = <CoachWriteFailure>[];
    final otherUserSubscription = contract.watchWriteFailures('bob').listen(otherUserFailures.add);
    final result = await repository.complete(
      'alice',
      periodKey: '2026-10-22',
      kind: CoachReviewKind.daily,
      noMovements: true,
    );
    expect(result.getOrElse((_) => throw StateError('failed')), CoachWriteState.pending);
    final map = verify(() => document.set(captureAny())).captured.single as Map;
    expect(map.keys.toSet(), {
      'periodKey',
      'kind',
      'noMovements',
      'reviewedAt',
      'dataGeneration',
    });
    expect(map['reviewedAt'], isA<FieldValue>());
    expect(map['dataGeneration'], 0);
    server.completeError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
    await Future<void>.delayed(Duration.zero);
    expect(failures.single.failure, isA<AuthFailure>());
    expect(failures.single.commandKey, 'daily:2026-10-22');
    expect(otherUserFailures, isEmpty);
    await subscription.cancel();
    await otherUserSubscription.cancel();
  });

  test('preference write replaces full optional map and reports server failure', () async {
    registerFallbackValue(SetOptions(merge: true));
    when(() => user.set(any(), any())).thenAnswer((_) async {});
    final result = await repository.savePreferences('alice', const CoachPreferences());
    expect(result.getOrElse((_) => throw StateError('failed')), CoachWriteState.confirmed);
    final call = verify(() => user.set(captureAny(), captureAny())).captured;
    expect(call.first, {'coachPreferences': const CoachPreferences().toMap()});
    expect((call.last as SetOptions).mergeFields, [
      FieldPath(['coachPreferences']),
    ]);
    when(
      () => user.set(any(), any()),
    ).thenThrow(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
    final failed = await repository.savePreferences('alice', const CoachPreferences());
    expect(failed.isLeft(), true);
  });

  test('superseded late failures are suppressed only for matching user and command', () async {
    registerFallbackValue(SetOptions(merge: true));
    final daily = MockCollection();
    final weekly = MockCollection();
    final dailyDoc = MockDocument();
    final weeklyDoc = MockDocument();
    when(() => user.collection('coachDailyCheckIns')).thenReturn(daily);
    when(() => user.collection('coachWeeklyReviews')).thenReturn(weekly);
    when(() => daily.doc('2026-10-22')).thenReturn(dailyDoc);
    when(() => weekly.doc('2026-10-19')).thenReturn(weeklyDoc);
    final oldDaily = Completer<void>();
    final newDaily = Completer<void>();
    final weeklyWrite = Completer<void>();
    final preferencesWrite = Completer<void>();
    var writes = 0;
    when(
      () => dailyDoc.set(any()),
    ).thenAnswer((_) => writes++ == 0 ? oldDaily.future : newDaily.future);
    when(() => weeklyDoc.set(any())).thenAnswer((_) => weeklyWrite.future);
    when(() => user.set(any(), any())).thenAnswer((_) => preferencesWrite.future);
    final failures = <CoachWriteFailure>[];
    final subscription = repository.watchWriteFailures('alice').listen(failures.add);
    final pending = [
      repository.complete('alice', periodKey: '2026-10-22', kind: CoachReviewKind.daily),
      repository.complete('alice', periodKey: '2026-10-22', kind: CoachReviewKind.daily),
      repository.complete('alice', periodKey: '2026-10-19', kind: CoachReviewKind.weekly),
      repository.savePreferences('alice', const CoachPreferences()),
    ];
    for (final result in await Future.wait(pending)) {
      expect(result.getOrElse((_) => throw StateError('failed')), CoachWriteState.pending);
    }
    oldDaily.completeError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
    await Future<void>.delayed(Duration.zero);
    expect(failures, isEmpty);
    newDaily.completeError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
    weeklyWrite.completeError(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
    preferencesWrite.completeError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(failures.map((event) => event.commandKey), [
      'daily:2026-10-22',
      'weekly:2026-10-19',
      'preferences',
    ]);
    await subscription.cancel();
  });

  test('individual historical completion watches metadata, absence, and visible errors', () async {
    final ref = MockCollection();
    final docRef = MockDocument();
    final feed = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
    when(() => user.collection('coachWeeklyReviews')).thenReturn(ref);
    when(() => ref.doc('2020-01-06')).thenReturn(docRef);
    when(() => docRef.snapshots(includeMetadataChanges: true)).thenAnswer((_) => feed.stream);
    final values = <CoachCompletion?>[];
    final errors = <Object>[];
    final subscription = repository
        .watchCompletion('alice', kind: CoachReviewKind.weekly, periodKey: '2020-01-06')
        .listen(values.add, onError: errors.add);
    final doc = MockDocumentSnapshot();
    when(doc.data).thenReturn(null);
    when(() => doc.metadata).thenReturn(metadata);
    feed.add(doc);
    await Future<void>.delayed(Duration.zero);
    expect(values, [null]);
    when(doc.data).thenReturn({'periodKey': '2020-01-06', 'kind': 'weekly', 'noMovements': true});
    when(() => metadata.hasPendingWrites).thenReturn(true);
    feed.add(doc);
    await Future<void>.delayed(Duration.zero);
    expect(values.last!.pending, true);
    when(() => metadata.hasPendingWrites).thenReturn(false);
    feed
      ..add(doc)
      ..addError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
    await Future<void>.delayed(Duration.zero);
    expect(values.last!.pending, false);
    expect(values.last!.periodKey, '2020-01-06');
    expect(errors.single, isA<AuthFailure>());
    await subscription.cancel();
    expect(feed.hasListener, false);
    await feed.close();
  });

  test('report changes skip each initial snapshot and ignore unrelated local mutations', () async {
    final remote = StreamController<QuerySnapshot<Map<String, dynamic>>>();
    final local = StreamController<List<PendingOperation>>();
    final mockDatabase = MockPendingDatabase();
    when(() => query.snapshots(includeMetadataChanges: true)).thenAnswer((_) => remote.stream);
    when(mockDatabase.watchActive).thenAnswer((_) => local.stream);
    final watched = FirestoreCoachRepository(firestore: firestore, pendingOperations: mockDatabase);
    var events = 0;
    final errors = <Object>[];
    final subscription = watched
        .watchReportChanges(
          'alice',
          startAt: date,
          endAtExclusive: date.add(const Duration(days: 1)),
        )
        .listen((_) => events++, onError: errors.add);
    await Future<void>.delayed(Duration.zero);
    remote.add(snapshot(0));
    local.add([]);
    await Future<void>.delayed(Duration.zero);
    expect(events, 0);
    await enqueue('foreign', 'bob');
    await enqueue('outside', 'alice', occurredAt: date.add(const Duration(days: 1)));
    local.add(await database.pending());
    await Future<void>.delayed(Duration.zero);
    expect(events, 0);
    await enqueue('selected', 'alice');
    local.add(await database.pending());
    await Future<void>.delayed(Duration.zero);
    expect(events, 1);
    final selected = await database.findByIdempotencyKey('selected');
    await database.markSyncing(selected!.id);
    local.add(await database.watchActive().first);
    await Future<void>.delayed(Duration.zero);
    expect(events, 2);
    remote.add(snapshot(1));
    await Future<void>.delayed(Duration.zero);
    expect(events, 3);
    remote.addError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
    await Future<void>.delayed(Duration.zero);
    expect(errors.single, isA<AuthFailure>());
    await subscription.cancel();
    expect(remote.hasListener, false);
    expect(local.hasListener, false);
    await remote.close();
    await local.close();
    await watched.dispose();
  });

  test('preferences expose pending metadata then clear it on server acknowledgement', () async {
    final feed = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
    when(() => user.snapshots(includeMetadataChanges: true)).thenAnswer((_) => feed.stream);
    final doc = MockDocumentSnapshot();
    when(
      doc.data,
    ).thenReturn({'coachPreferences': const CoachPreferences(dailyEnabled: true).toMap()});
    when(() => doc.metadata).thenReturn(metadata);
    final values = <CoachPreferences>[];
    final subscription = repository.watchPreferences('alice').listen(values.add);
    when(() => metadata.hasPendingWrites).thenReturn(true);
    feed.add(doc);
    await Future<void>.delayed(Duration.zero);
    expect(values.single.hasPendingWrites, true);
    when(() => metadata.hasPendingWrites).thenReturn(false);
    feed.add(doc);
    await Future<void>.delayed(Duration.zero);
    expect(values.last.hasPendingWrites, false);
    expect(values.last.toMap(), values.first.toMap());
    await subscription.cancel();
    await feed.close();
  });

  testWidgets('stalled default read falls back to cache and retains cached freshness', (
    tester,
  ) async {
    final stalled = Completer<QuerySnapshot<Map<String, dynamic>>>();
    when(() => query.get()).thenAnswer((_) => stalled.future);
    when(
      () => query.get(const GetOptions(source: Source.cache)),
    ).thenAnswer((_) async => snapshot(1));
    final cacheOnlyRepository = FirestoreCoachRepository(firestore: firestore);
    final result = cacheOnlyRepository.loadReport(
      'alice',
      startAt: date,
      endAtExclusive: date.add(const Duration(days: 1)),
    );
    await tester.pump(const Duration(seconds: 8));
    final report = (await result).getOrElse((failure) => throw StateError(failure.message));
    expect(report.freshness, CoachFreshness.cached);
    expect(report.totalsByCurrency['COP']!.expenseMinor, 125);
    // A default request completing late must not leak an unhandled exception.
    stalled.completeError(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
    await tester.pump();
    await cacheOnlyRepository.dispose();
  });

  testWidgets('stalled read with empty cache fails instead of reporting zero', (tester) async {
    when(
      () => query.get(),
    ).thenAnswer((_) => Completer<QuerySnapshot<Map<String, dynamic>>>().future);
    when(
      () => query.get(const GetOptions(source: Source.cache)),
    ).thenAnswer((_) async => snapshot(0));
    final result = repository.loadReport(
      'alice',
      startAt: date,
      endAtExclusive: date.add(const Duration(days: 1)),
    );
    await tester.pump(const Duration(seconds: 8));
    expect((await result).match((failure) => failure, (_) => null), isA<NetworkFailure>());
  });

  testWidgets('cache fallback also has a finite timeout', (tester) async {
    when(
      () => query.get(),
    ).thenAnswer((_) => Completer<QuerySnapshot<Map<String, dynamic>>>().future);
    when(
      () => query.get(const GetOptions(source: Source.cache)),
    ).thenAnswer((_) => Completer<QuerySnapshot<Map<String, dynamic>>>().future);
    final result = repository.loadReport(
      'alice',
      startAt: date,
      endAtExclusive: date.add(const Duration(days: 1)),
    );
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 2));
    expect((await result).match((failure) => failure, (_) => null), isA<NetworkFailure>());
  });

  test('completion watches wait for both kinds and emit metadata-only acknowledgements', () async {
    final feeds = <StreamController<QuerySnapshot<Map<String, dynamic>>>>[];
    final completed = <List<CoachCompletion>>[];
    for (final name in ['coachDailyCheckIns', 'coachWeeklyReviews']) {
      final ref = MockCollection();
      final ordered = MockQuery();
      final feed = StreamController<QuerySnapshot<Map<String, dynamic>>>();
      feeds.add(feed);
      when(() => user.collection(name)).thenReturn(ref);
      when(() => ref.where('periodKey', isGreaterThanOrEqualTo: '2026-10-22')).thenReturn(ordered);
      when(() => ordered.orderBy('periodKey')).thenReturn(ordered);
      when(() => ordered.snapshots(includeMetadataChanges: true)).thenAnswer((_) => feed.stream);
    }
    final subscription = repository.watchCompletions('alice', since: date).listen(completed.add);
    await Future<void>.delayed(Duration.zero);
    final doc = MockQueryDocument();
    when(doc.data).thenReturn({
      'periodKey': '2026-10-22',
      'kind': 'daily',
      'noMovements': true,
    });
    when(() => doc.metadata).thenReturn(metadata);
    final daily = MockSnapshot();
    when(() => daily.docs).thenReturn([doc]);
    when(() => metadata.hasPendingWrites).thenReturn(true);
    feeds.first.add(daily);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isEmpty);
    feeds.last.add(snapshot(0));
    await Future<void>.delayed(Duration.zero);
    expect(completed.single.single.pending, true);
    when(() => metadata.hasPendingWrites).thenReturn(false);
    feeds.first.add(daily);
    await Future<void>.delayed(Duration.zero);
    expect(completed.last.single.pending, false);
    await subscription.cancel();
    for (final feed in feeds) {
      expect(feed.hasListener, false);
      await feed.close();
    }
  });
}
