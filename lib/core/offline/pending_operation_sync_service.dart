import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'pending_operation_queue.dart';
import 'sync_state.dart';

typedef PendingOperationSender =
    Future<void> Function(
      String operationType,
      Map<String, dynamic> payload,
    );

class PendingOperationSyncService {
  const PendingOperationSyncService(this._database, this._connectivity);

  final PendingOperationDatabase _database;
  final Connectivity _connectivity;

  Stream<SyncStatusSnapshot> watchStatus() => _database.watchRecent().map((rows) {
    int count(SyncState state) => rows.where((row) => row.status == state.name).length;
    return SyncStatusSnapshot(
      pending: count(SyncState.pending),
      syncing: count(SyncState.syncing),
      confirmed: count(SyncState.confirmed),
      rejected: count(SyncState.rejected),
    );
  });

  StreamSubscription<List<ConnectivityResult>> listenForReconnect(
    PendingOperationSender sender,
  ) => _connectivity.onConnectivityChanged.listen((results) {
    if (results.any((result) => result != ConnectivityResult.none)) {
      drain(sender);
    }
  });

  Future<bool> hasConnection() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }

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
    if (!await hasConnection()) return;
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
