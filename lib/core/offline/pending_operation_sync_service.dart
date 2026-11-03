import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../utils/request_id.dart';
import 'pending_operation_queue.dart';
import 'sync_state.dart';

typedef PendingOperationSender =
    Future<SyncAttemptResult> Function(
      String operationType,
      Map<String, dynamic> payload,
    );
typedef ConnectivityProbe = Future<bool> Function();

class SyncAttemptResult {
  const SyncAttemptResult._(this.succeeded, this.retryable, this.issueCode, this.technicalCode);

  const SyncAttemptResult.success() : this._(true, false, null, null);
  const SyncAttemptResult.retryable(SyncIssueCode code, {String? technicalCode})
    : this._(false, true, code, technicalCode);
  const SyncAttemptResult.rejected(SyncIssueCode code, {String? technicalCode})
    : this._(false, false, code, technicalCode);

  final bool succeeded;
  final bool retryable;
  final SyncIssueCode? issueCode;
  final String? technicalCode;
}

class PendingOperationSyncService {
  PendingOperationSyncService(
    this._database,
    this._connectivity, {
    ConnectivityProbe? connectivityProbe,
    DateTime Function()? clock,
  }) : _connectivityProbe = connectivityProbe,
       _clock = clock ?? DateTime.now;

  final PendingOperationDatabase _database;
  final Connectivity _connectivity;
  final ConnectivityProbe? _connectivityProbe;
  final DateTime Function() _clock;
  final Map<String, Future<void>> _inFlight = {};
  final Map<String, Timer> _recoveries = {};
  int _sessionEpoch = 0;
  String? _activeUserId;

  void setSession(String? userId) {
    if (_activeUserId == userId) return;
    _activeUserId = userId;
    _sessionEpoch++;
    for (final timer in _recoveries.values) {
      timer.cancel();
    }
    _recoveries.clear();
  }

  Stream<SyncStatusSnapshot> watchStatus(String userId) =>
      _database.watchRecent(userId).map((rows) {
        int count(SyncState state) => rows.where((row) => row.status == state.name).length;
        return SyncStatusSnapshot(
          pending: count(SyncState.pending),
          syncing: count(SyncState.syncing),
          confirmed: count(SyncState.confirmed),
          rejected: count(SyncState.rejected),
        );
      });

  StreamSubscription<List<ConnectivityResult>> listenForReconnect(
    String userId,
    PendingOperationSender sender,
  ) => _connectivity.onConnectivityChanged.listen((results) {
    if (results.any((result) => result != ConnectivityResult.none)) {
      unawaited(drain(userId, sender));
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

  Future<void> drain(String userId, PendingOperationSender sender, {bool retryRejected = false}) {
    if (_activeUserId != userId) return Future.value();
    final epoch = _sessionEpoch;
    final key = '$userId:$epoch';
    return _inFlight.putIfAbsent(
      key,
      () => _drain(userId, epoch, sender, retryRejected: retryRejected).whenComplete(() {
        _inFlight.remove(key);
      }),
    );
  }

  Future<void> _drain(
    String userId,
    int epoch,
    PendingOperationSender sender, {
    required bool retryRejected,
  }) async {
    bool valid() => _activeUserId == userId && _sessionEpoch == epoch;
    if (!await hasConnection() || !valid()) return;
    final visited = <int>{};
    while (valid()) {
      final attemptId = newRequestId();
      final operation = await _database.claim(
        userId,
        attemptId,
        _clock().toUtc(),
        retryRejected: retryRejected,
        excludedIds: visited,
      );
      if (operation == null) break;
      if (!visited.add(operation.id)) {
        await _database.finish(
          operation.id,
          userId,
          attemptId,
          'rejected',
          issue: SyncIssueCode.invalidOperation,
        );
        break;
      }
      if (!valid()) break;
      try {
        final payload = jsonDecode(operation.payload) as Map<String, dynamic>;
        if (payload['ownerUserId'] != userId) {
          await _database.finish(operation.id, userId, attemptId, 'quarantined');
          continue;
        }
        final result = await sender(operation.operationType, payload);
        if (!valid()) break;
        await _database.finish(
          operation.id,
          userId,
          attemptId,
          result.succeeded
              ? 'confirmed'
              : result.retryable
              ? 'pending'
              : 'rejected',
          issue: result.issueCode,
          technicalCode: result.technicalCode,
        );
        if (result.retryable) break;
      } catch (_) {
        if (valid()) {
          await _database.finish(
            operation.id,
            userId,
            attemptId,
            'rejected',
            issue: SyncIssueCode.unexpected,
          );
        }
        break;
      }
    }
    await _database.deleteExpiredHistory(userId);
    // Recover a killed process or a callback belonging to an obsolete session.
    if (valid() && (await _database.activeForUser(userId)).any((r) => r.status == 'syncing')) {
      _recoveries[userId]?.cancel();
      _recoveries[userId] = Timer(const Duration(seconds: 121), () {
        if (valid()) unawaited(drain(userId, sender));
      });
    }
  }
}
