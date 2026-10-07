import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'pending_operation_queue.dart';
import 'sync_state.dart';

typedef PendingOperationSender =
    Future<SyncAttemptResult> Function(
      String operationType,
      Map<String, dynamic> payload,
    );
typedef ConnectivityProbe = Future<bool> Function();

class SyncAttemptResult {
  const SyncAttemptResult._(this.succeeded, this.retryable, this.issueCode);

  const SyncAttemptResult.success() : this._(true, false, null);
  const SyncAttemptResult.retryable(SyncIssueCode code) : this._(false, true, code);
  const SyncAttemptResult.rejected(SyncIssueCode code) : this._(false, false, code);

  final bool succeeded;
  final bool retryable;
  final SyncIssueCode? issueCode;
}

class PendingOperationSyncService {
  PendingOperationSyncService(
    this._database,
    this._connectivity, {
    ConnectivityProbe? connectivityProbe,
  }) : _connectivityProbe = connectivityProbe;

  final PendingOperationDatabase _database;
  final Connectivity _connectivity;
  final ConnectivityProbe? _connectivityProbe;
  Future<void>? _drainInFlight;

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
    final probe = _connectivityProbe;
    if (probe != null) return probe();
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

  Future<void> drain(PendingOperationSender sender, {bool retryRejected = false}) {
    final inFlight = _drainInFlight;
    if (inFlight != null) return inFlight;
    final operation = _drain(sender, retryRejected: retryRejected);
    _drainInFlight = operation.whenComplete(() => _drainInFlight = null);
    return _drainInFlight!;
  }

  Future<void> _drain(PendingOperationSender sender, {bool retryRejected = false}) async {
    if (!await hasConnection()) return;
    final operations = retryRejected
        ? await _database.pendingOrRejected()
        : await _database.pending();
    for (final operation in operations) {
      if (operation.status == 'rejected') await _database.retry(operation.id);
      await _database.markSyncing(operation.id);
      try {
        final result = await sender(
          operation.operationType,
          jsonDecode(operation.payload) as Map<String, dynamic>,
        );
        if (result.succeeded) {
          await _database.markConfirmed(operation.id);
        } else if (result.retryable) {
          await _database.markPending(operation.id, result.issueCode!);
          break;
        } else {
          await _database.markRejected(operation.id, result.issueCode!);
        }
      } catch (_) {
        await _database.markRejected(operation.id, SyncIssueCode.unexpected);
      }
    }
    await _database.deleteExpiredHistory();
  }
}
