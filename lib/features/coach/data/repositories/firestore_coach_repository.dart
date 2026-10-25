import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/firebase_failure_mapper.dart';
import '../../../../core/offline/pending_operation_queue.dart';
import '../../../finance/domain/entities/financial_operation.dart';
import '../../domain/entities/coach_models.dart';
import '../../domain/repositories/coach_repository.dart';

class FirestoreCoachRepository implements CoachRepository {
  FirestoreCoachRepository({
    required FirebaseFirestore firestore,
    PendingOperationDatabase? pendingOperations,
  }) : _firestore = firestore,
       _pendingOperations = pendingOperations;

  final FirebaseFirestore _firestore;
  final PendingOperationDatabase? _pendingOperations;
  final _writeFailures = StreamController<({String uid, CoachWriteFailure failure})>.broadcast();
  final _writeRevisions = <({String uid, String commandKey}), int>{};

  /// Server rejections arriving after a command returned pending.
  @override
  Stream<CoachWriteFailure> watchWriteFailures(String uid) =>
      _writeFailures.stream.where((event) => event.uid == uid).map((event) => event.failure);
  Future<void> dispose() => _writeFailures.close();

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  Future<int> _dataGeneration(String uid) async {
    final profile = (await _user(uid).get()).data();
    if (profile?['resetStatus'] == 'resetting') throw StateError('user-reset-in-progress');
    return (profile?['dataGeneration'] as num? ?? 0).toInt();
  }

  @override
  Stream<CoachCompletion?> watchCompletion(
    String uid, {
    required CoachReviewKind kind,
    required String periodKey,
  }) => _sanitize(
    _user(
      uid,
    ).collection(_collection(kind)).doc(periodKey).snapshots(includeMetadataChanges: true).map((
      doc,
    ) {
      final data = doc.data();
      return data == null ? null : completionFromMap(data, pending: doc.metadata.hasPendingWrites);
    }),
  );

  Query<Map<String, dynamic>> _reportQuery(String uid, DateTime startAt, DateTime endAtExclusive) =>
      _user(uid)
          .collection('operations')
          .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startAt))
          .where('occurredAt', isLessThan: Timestamp.fromDate(endAtExclusive))
          .orderBy('occurredAt', descending: true)
          .orderBy(FieldPath.documentId, descending: true);

  @override
  Stream<void> watchReportChanges(
    String uid, {
    required DateTime startAt,
    required DateTime endAtExclusive,
  }) => Stream.multi((controller) {
    final subscriptions = <StreamSubscription<dynamic>>[];
    void error(Object error, StackTrace stack) => controller.addError(
      error is Failure ? error : FirebaseFailureMapper.fromException(error),
      stack,
    );
    subscriptions.add(
      _reportQuery(uid, startAt, endAtExclusive)
          .snapshots(includeMetadataChanges: true)
          .skip(1)
          .listen((_) => controller.add(null), onError: error),
    );
    final database = _pendingOperations;
    if (database != null) {
      subscriptions.add(
        database
            .watchActive()
            .map((rows) {
              final matching = <String>[];
              for (final row in rows) {
                if (!const {
                  'operation',
                  'income',
                  'expense',
                  'transfer',
                }.contains(row.operationType)) {
                  continue;
                }
                final payload = jsonDecode(row.payload) as Map<String, dynamic>;
                if (payload['ownerUserId'] != uid) continue;
                final date = _date(payload['occurredAt']);
                if (date == null) throw const FormatException('invalid-operation-date');
                if (date.isBefore(startAt) || !date.isBefore(endAtExclusive)) continue;
                matching.add(
                  jsonEncode([row.idempotencyKey, row.operationType, row.status, row.payload]),
                );
              }
              matching.sort();
              return jsonEncode(matching);
            })
            .distinct()
            .skip(1)
            .listen((_) => controller.add(null), onError: error),
      );
    }
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  });

  static Stream<T> _sanitize<T>(Stream<T> source) => source.transform(
    StreamTransformer.fromHandlers(
      handleError: (Object error, StackTrace stack, EventSink<T> sink) {
        sink.addError(error is Failure ? error : FirebaseFailureMapper.fromException(error), stack);
      },
    ),
  );

  @override
  Stream<CoachPreferences> watchPreferences(String uid) => _user(uid)
      .snapshots(includeMetadataChanges: true)
      .map(
        (doc) => CoachPreferences.fromMap(
          doc.data()?['coachPreferences'],
          hasPendingWrites: doc.metadata.hasPendingWrites,
        ),
      );

  @override
  Stream<List<CoachCompletion>> watchCompletions(String uid, {required DateTime since}) {
    return Stream.multi((controller) {
      final latest = <CoachReviewKind, List<CoachCompletion>>{};
      final subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
      for (final kind in CoachReviewKind.values) {
        subscriptions.add(
          _user(uid)
              .collection(_collection(kind))
              .where('periodKey', isGreaterThanOrEqualTo: _dateKey(since))
              .orderBy('periodKey')
              .snapshots(includeMetadataChanges: true)
              .listen((snapshot) {
                try {
                  latest[kind] = snapshot.docs
                      .map(
                        (doc) => completionFromMap(
                          doc.data(),
                          pending: doc.metadata.hasPendingWrites,
                        ),
                      )
                      .toList();
                  if (latest.length == CoachReviewKind.values.length) {
                    final all = latest.values.expand((v) => v).toList()
                      ..sort((a, b) {
                        final period = a.periodKey.compareTo(b.periodKey);
                        return period == 0 ? a.kind.index.compareTo(b.kind.index) : period;
                      });
                    controller.add(List.unmodifiable(all));
                  }
                } catch (error, stack) {
                  controller.addError(error, stack);
                }
              }, onError: controller.addError),
        );
      }
      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  @override
  Future<Either<Failure, CoachWriteState>> savePreferences(
    String uid,
    CoachPreferences preferences,
  ) => _write(
    uid,
    'preferences',
    () => _user(uid).set(
      {'coachPreferences': preferences.toMap()},
      SetOptions(mergeFields: ['coachPreferences']),
    ),
  );

  @override
  Future<Either<Failure, CoachWriteState>> complete(
    String uid, {
    required String periodKey,
    required CoachReviewKind kind,
    bool noMovements = false,
  }) => _write(
    uid,
    '${kind.name}:$periodKey',
    () async => _user(uid).collection(_collection(kind)).doc(periodKey).set({
      'periodKey': periodKey,
      'kind': kind.name,
      'noMovements': noMovements,
      'reviewedAt': FieldValue.serverTimestamp(),
      'dataGeneration': await _dataGeneration(uid),
    }),
  );

  Future<Either<Failure, CoachWriteState>> _write(
    String uid,
    String commandKey,
    Future<void> Function() write,
  ) async {
    final key = (uid: uid, commandKey: commandKey);
    final revision = (_writeRevisions[key] ?? 0) + 1;
    _writeRevisions[key] = revision;
    var returnedPending = false;
    try {
      // Attach the error handler before timing out. Firestore retains the write
      // offline; a timeout must neither cancel it nor leak a late rejection.
      final server = write().then<Either<Failure, CoachWriteState>>(
        (_) => const Right(CoachWriteState.confirmed),
        onError: (Object error, StackTrace stack) {
          final failure = FirebaseFailureMapper.fromException(error);
          if (returnedPending && !_writeFailures.isClosed && _writeRevisions[key] == revision) {
            _writeFailures.add((
              uid: uid,
              failure: CoachWriteFailure(failure: failure, commandKey: commandKey),
            ));
          }
          return Left<Failure, CoachWriteState>(failure);
        },
      );
      return await server.timeout(
        const Duration(milliseconds: 1200),
        onTimeout: () {
          returnedPending = true;
          return const Right(CoachWriteState.pending);
        },
      );
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  @override
  Future<Either<Failure, CoachPeriodReport>> loadReport(
    String uid, {
    required DateTime startAt,
    required DateTime endAtExclusive,
  }) async {
    try {
      if (!startAt.isBefore(endAtExclusive)) {
        return const Left(ConflictFailure('invalid-coach-period'));
      }
      final base = _reportQuery(uid, startAt, endAtExclusive).limit(100);
      Query<Map<String, dynamic>> page = base;
      var freshness = CoachFreshness.fresh;
      final operations = <String, FinancialOperation>{};
      while (true) {
        late QuerySnapshot<Map<String, dynamic>> snapshot;
        try {
          snapshot = await page.get().timeout(const Duration(seconds: 8));
        } on TimeoutException {
          // Native cached data can still be useful after a stalled default read.
          freshness = CoachFreshness.cached;
          snapshot = await page
              .get(const GetOptions(source: Source.cache))
              .timeout(const Duration(seconds: 2));
          if (snapshot.docs.isEmpty) {
            throw TimeoutException('coach-report-cache-unavailable');
          }
        }
        if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
          freshness = CoachFreshness.cached;
        }
        for (final doc in snapshot.docs) {
          final operation = operationFromMap(
            doc.id,
            doc.data(),
            pending: doc.metadata.hasPendingWrites,
          );
          if (doc.metadata.isFromCache || doc.metadata.hasPendingWrites) {
            freshness = CoachFreshness.cached;
          }
          operations[operation.idempotencyKey] = operation;
        }
        if (snapshot.docs.length < 100) break;
        final last = snapshot.docs.last;
        page = base.startAfter([last.data()['occurredAt'], last.id]);
      }
      final local = await _pendingOperations?.watchActive().first ?? <PendingOperation>[];
      for (final row in local) {
        if (!const {'operation', 'income', 'expense', 'transfer'}.contains(row.operationType)) {
          continue;
        }
        final payload = jsonDecode(row.payload) as Map<String, dynamic>;
        if (payload['ownerUserId'] != uid || operations.containsKey(row.idempotencyKey)) continue;
        final operation = operationFromMap('local-${row.idempotencyKey}', {
          ...payload,
          'idempotencyKey': row.idempotencyKey,
          // Syncing is an unacknowledged local command, not confirmed money.
          'status': row.status == 'syncing' ? 'pending' : row.status,
          if (row.operationType != 'operation') 'type': row.operationType,
        });
        if (!operation.occurredAt.isBefore(startAt) &&
            operation.occurredAt.isBefore(endAtExclusive)) {
          operations[row.idempotencyKey] = operation;
        }
      }
      final sorted = operations.values.toList()
        ..sort((a, b) {
          final date = b.occurredAt.compareTo(a.occurredAt);
          return date == 0 ? b.id.compareTo(a.id) : date;
        });
      return Right(
        CoachPeriodReport(
          startAt: startAt,
          endAtExclusive: endAtExclusive,
          operations: sorted,
          freshness: freshness,
        ),
      );
    } on TimeoutException {
      return const Left(
        NetworkFailure('coach-report-unavailable', technicalCode: 'deadline-exceeded'),
      );
    } catch (error) {
      return Left(FirebaseFailureMapper.fromException(error));
    }
  }

  static CoachCompletion completionFromMap(Map<String, dynamic> data, {bool pending = false}) =>
      CoachCompletion(
        periodKey: data['periodKey'] as String,
        kind: CoachReviewKind.values.byName(data['kind'] as String),
        noMovements: data['noMovements'] as bool? ?? false,
        reviewedAt: _date(data['reviewedAt']),
        pending: pending,
      );

  /// Strict mapping: corrupt financial data fails the report instead of adding zeroes.
  static FinancialOperation operationFromMap(
    String id,
    Map<String, dynamic> data, {
    bool pending = false,
  }) {
    final date = _date(data['occurredAt']);
    if (date == null) throw const FormatException('invalid-operation-date');
    return FinancialOperation(
      id: id,
      type: OperationType.values.byName(data['type'] as String),
      amountMinor: data['amountMinor'] as int,
      currency: data['currency'] as String,
      monthKey: data['monthKey'] as String? ?? _dateKey(date).substring(0, 7),
      occurredAt: date,
      status: pending
          ? OperationStatus.pending
          : OperationStatus.values.byName(data['status'] as String? ?? 'confirmed'),
      idempotencyKey: data['idempotencyKey'] as String? ?? id,
      categoryId: data['categoryId'] as String?,
      accountId: data['accountId'] as String?,
      sourceAccountId: data['sourceAccountId'] as String?,
      destinationAccountId: data['destinationAccountId'] as String?,
      budgetId: data['budgetId'] as String?,
      budgetItemId: data['budgetItemId'] as String?,
      description: data['description'] as String? ?? '',
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  static DateTime? _date(Object? value) => switch (value) {
    final Timestamp timestamp => timestamp.toDate(),
    final DateTime date => date,
    final String text => DateTime.tryParse(text),
    _ => null,
  };

  static String _collection(CoachReviewKind kind) =>
      kind == CoachReviewKind.daily ? 'coachDailyCheckIns' : 'coachWeeklyReviews';
  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
