import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'pending_operation_queue.g.dart';

class PendingOperations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get idempotencyKey => text().unique()();
  TextColumn get operationType => text()();
  TextColumn get payload => text()();
  TextColumn get status => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DriftDatabase(tables: [PendingOperations])
class PendingOperationDatabase extends _$PendingOperationDatabase {
  PendingOperationDatabase(super.e);

  @override
  int get schemaVersion => 1;

  Future<int> enqueue({
    required String idempotencyKey,
    required String operationType,
    required Map<String, Object?> payload,
  }) => into(pendingOperations).insertOnConflictUpdate(
    PendingOperationsCompanion.insert(
      idempotencyKey: idempotencyKey,
      operationType: operationType,
      payload: jsonEncode(payload),
      status: 'pending',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ),
  );

  Future<List<PendingOperation>> pending() =>
      (select(pendingOperations)
            ..where((row) => row.status.equals('pending'))
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .get();

  Future<List<PendingOperation>> pendingOrRejected() =>
      (select(pendingOperations)
            ..where((row) => row.status.isIn(const ['pending', 'rejected']))
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .get();

  Stream<List<PendingOperation>> watchActive() =>
      (select(pendingOperations)
            ..where((row) => row.status.isIn(const ['pending', 'syncing', 'rejected']))
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .watch();

  Stream<List<PendingOperation>> watchRecent() =>
      (select(pendingOperations)..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])).watch();

  Future<PendingOperation?> findByIdempotencyKey(String key) async {
    return (select(
      pendingOperations,
    )..where((row) => row.idempotencyKey.equals(key))).getSingleOrNull();
  }

  Future<void> clearConfirmed(String key) async {
    await (delete(pendingOperations)..where((row) => row.idempotencyKey.equals(key))).go();
  }

  Future<void> markSyncing(int id) => (update(pendingOperations)..where((row) => row.id.equals(id)))
      .write(const PendingOperationsCompanion(status: Value('syncing')));

  Future<void> markConfirmed(int id) =>
      (update(pendingOperations)..where((row) => row.id.equals(id))).write(
        PendingOperationsCompanion(
          status: const Value('confirmed'),
          lastError: const Value(null),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> markRejected(int id, String error) =>
      (update(pendingOperations)..where((row) => row.id.equals(id))).write(
        PendingOperationsCompanion(
          status: const Value('rejected'),
          lastError: Value(error),
          retryCount: const Value(0),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> retry(int id) =>
      (update(pendingOperations)..where((row) => row.id.equals(id))).write(
        PendingOperationsCompanion(
          status: const Value('pending'),
          lastError: const Value(null),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
}

Future<PendingOperationDatabase> openPendingOperationDatabase() async {
  final directory = await getApplicationSupportDirectory();
  return PendingOperationDatabase(
    NativeDatabase.createInBackground(File(p.join(directory.path, 'clearbudget.sqlite'))),
  );
}
