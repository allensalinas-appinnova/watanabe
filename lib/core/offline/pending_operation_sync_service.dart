import 'dart:convert';

import 'pending_operation_queue.dart';

typedef PendingOperationSender =
    Future<void> Function(
      String operationType,
      Map<String, dynamic> payload,
    );

class PendingOperationSyncService {
  const PendingOperationSyncService(this._database);

  final PendingOperationDatabase _database;

  Future<void> enqueue({
    required String idempotencyKey,
    required String operationType,
    required Map<String, Object?> payload,
  }) => _database
      .enqueue(
        idempotencyKey: idempotencyKey,
        operationType: operationType,
        payload: payload,
      )
      .then((_) {});

  Future<void> drain(PendingOperationSender sender, {bool retryRejected = false}) async {
    final operations = retryRejected
        ? await _database.pendingOrRejected()
        : await _database.pending();
    for (final operation in operations) {
      if (operation.status == 'rejected') await _database.retry(operation.id);
      await _database.markSyncing(operation.id);
      try {
        await sender(
          operation.operationType,
          jsonDecode(operation.payload) as Map<String, dynamic>,
        );
        await _database.markConfirmed(operation.id);
      } catch (error) {
        await _database.markRejected(operation.id, error.toString());
      }
    }
  }
}
