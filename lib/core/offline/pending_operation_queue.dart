import 'dart:convert';

import 'package:drift/drift.dart';

import 'pending_operation_backend_stub.dart'
    if (dart.library.io) 'pending_operation_backend_native.dart'
    if (dart.library.js_interop) 'pending_operation_backend_web.dart'
    as backend;
import 'sync_state.dart';

part 'pending_operation_queue.g.dart';

class PendingOperations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idempotencyKey => text().unique()();
  TextColumn get operationType => text()();
  TextColumn get payload => text()();
  TextColumn get status => text()();
  TextColumn get ownerUserId => text().nullable()();
  TextColumn get syncAttemptId => text().nullable()();
  DateTimeColumn get syncLeaseUntil => dateTime().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DriftDatabase(tables: [PendingOperations])
class PendingOperationDatabase extends _$PendingOperationDatabase {
  PendingOperationDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) => transaction(() async {
      if (from < 2) {
        await m.addColumn(pendingOperations, pendingOperations.ownerUserId);
        await m.addColumn(pendingOperations, pendingOperations.syncAttemptId);
        await m.addColumn(pendingOperations, pendingOperations.syncLeaseUntil);
        final rows = await select(pendingOperations).get();
        for (final row in rows) {
          final owner = _owner(row.payload);
          await (update(pendingOperations)..where((r) => r.id.equals(row.id))).write(
            PendingOperationsCompanion(
              ownerUserId: Value(owner),
              status: Value(
                owner == null
                    ? 'quarantined'
                    : row.status == 'syncing'
                    ? 'pending'
                    : row.status,
              ),
            ),
          );
        }
      }
    }),
    beforeOpen: (_) => customStatement(
      'CREATE INDEX IF NOT EXISTS pending_owner_status ON pending_operations (owner_user_id, status)',
    ),
  );

  String? _owner(String payload) {
    try {
      final value = (jsonDecode(payload) as Map<String, dynamic>)['ownerUserId'];
      return value is String && value.isNotEmpty ? value : null;
    } catch (_) {
      return null;
    }
  }

  Future<int> enqueue({
    required String idempotencyKey,
    required String operationType,
    required Map<String, Object?> payload,
  }) async {
    final encoded = jsonEncode(payload), owner = _owner(jsonEncode(payload));
    return transaction(() async {
      final existing = await (select(
        pendingOperations,
      )..where((r) => r.idempotencyKey.equals(idempotencyKey))).getSingleOrNull();
      if (existing != null) {
        if (existing.ownerUserId != owner ||
            existing.operationType != operationType ||
            existing.payload != encoded) {
          throw StateError('offline-request-content-conflict');
        }
        return existing.id;
      }
      return into(pendingOperations).insert(
        PendingOperationsCompanion.insert(
          idempotencyKey: idempotencyKey,
          operationType: operationType,
          payload: encoded,
          ownerUserId: Value(owner),
          status: owner == null ? 'quarantined' : 'pending',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    });
  }

  Future<List<PendingOperation>> pending({required String userId}) => (select(
    pendingOperations,
  )..where((r) => r.ownerUserId.equals(userId) & r.status.equals('pending'))).get();

  Future<List<PendingOperation>> pendingOrRejected({required String userId}) => (select(
    pendingOperations,
  )..where((r) => r.ownerUserId.equals(userId) & r.status.isIn(['pending', 'rejected']))).get();

  Stream<List<PendingOperation>> watchActive(String userId) =>
      (select(pendingOperations)
            ..where(
              (r) =>
                  r.ownerUserId.equals(userId) & r.status.isIn(['pending', 'syncing', 'rejected']),
            )
            ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
          .watch();

  Stream<List<PendingOperation>> watchRecent(String userId) =>
      (select(pendingOperations)
            ..where((r) => r.ownerUserId.equals(userId))
            ..orderBy([(r) => OrderingTerm.desc(r.updatedAt)]))
          .watch();

  Stream<int> watchQuarantineCount() => (select(
    pendingOperations,
  )..where((r) => r.status.equals('quarantined'))).watch().map((rows) => rows.length);

  Future<void> discardQuarantine() async {
    await (delete(pendingOperations)..where((r) => r.status.equals('quarantined'))).go();
  }

  Future<PendingOperation?> findByIdempotencyKey(String key, {required String userId}) => (select(
    pendingOperations,
  )..where((r) => r.idempotencyKey.equals(key) & r.ownerUserId.equals(userId))).getSingleOrNull();

  Future<List<PendingOperation>> activeForUser(String userId) =>
      (select(pendingOperations)..where(
            (r) => r.ownerUserId.equals(userId) & r.status.isIn(['pending', 'syncing', 'rejected']),
          ))
          .get();

  Future<void> clearUserData(String userId) async {
    await (delete(pendingOperations)..where((r) => r.ownerUserId.equals(userId))).go();
  }

  Future<void> clearConfirmed(String key, String userId) async {
    await (delete(pendingOperations)..where(
          (r) =>
              r.idempotencyKey.equals(key) &
              r.ownerUserId.equals(userId) &
              r.status.equals('confirmed'),
        ))
        .go();
  }

  Future<PendingOperation?> claim(
    String userId,
    String attemptId,
    DateTime now, {
    bool retryRejected = false,
    Set<int> excludedIds = const {},
  }) => transaction(() async {
    final query = select(pendingOperations)
      ..where(
        (r) =>
            r.ownerUserId.equals(userId) &
            r.id.isNotIn(excludedIds) &
            (r.status.equals('pending') |
                (retryRejected ? r.status.equals('rejected') : const Constant(false)) |
                (r.status.equals('syncing') &
                    (r.syncLeaseUntil.isNull() | r.syncLeaseUntil.isSmallerOrEqualValue(now)))),
      )
      ..orderBy([(r) => OrderingTerm.asc(r.createdAt)])
      ..limit(1);
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    await (update(pendingOperations)..where((r) => r.id.equals(row.id))).write(
      PendingOperationsCompanion(
        status: const Value('syncing'),
        syncAttemptId: Value(attemptId),
        syncLeaseUntil: Value(now.add(const Duration(seconds: 120))),
        updatedAt: Value(now),
      ),
    );
    return row;
  });

  Future<void> finish(
    int id,
    String userId,
    String attemptId,
    String status, {
    SyncIssueCode? issue,
    String? technicalCode,
  }) async {
    final row = await (select(pendingOperations)..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (update(pendingOperations)..where(
          (r) =>
              r.id.equals(id) &
              r.ownerUserId.equals(userId) &
              r.syncAttemptId.equals(attemptId) &
              r.status.equals('syncing'),
        ))
        .write(
          PendingOperationsCompanion(
            retryCount: Value(row.retryCount + (issue == null ? 0 : 1)),
            status: Value(status),
            syncAttemptId: const Value(null),
            syncLeaseUntil: const Value(null),
            lastError: Value(
              issue == null
                  ? null
                  : SyncFailureInfo(issue: issue, technicalCode: technicalCode).encode(),
            ),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<int> deleteExpiredHistory(
    String userId, {
    Duration retention = const Duration(days: 30),
  }) =>
      (delete(pendingOperations)..where(
            (r) =>
                r.ownerUserId.equals(userId) &
                r.status.equals('confirmed') &
                r.updatedAt.isSmallerThanValue(DateTime.now().toUtc().subtract(retention)),
          ))
          .go();
}

Future<PendingOperationDatabase> openPendingOperationDatabase() async {
  return PendingOperationDatabase(await backend.openPendingOperationExecutor());
}
