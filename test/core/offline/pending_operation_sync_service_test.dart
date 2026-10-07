import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/offline/pending_operation_queue.dart';
import 'package:personal_finance/core/offline/pending_operation_sync_service.dart';
import 'package:personal_finance/core/offline/sync_state.dart';

void main() {
  late PendingOperationDatabase database;
  late PendingOperationSyncService service;

  setUp(() {
    database = PendingOperationDatabase(NativeDatabase.memory());
    service = PendingOperationSyncService(
      database,
      Connectivity(),
      connectivityProbe: () async => true,
    );
  });

  tearDown(() => database.close());

  test('keeps a temporary connectivity failure pending and retries with same key', () async {
    await service.enqueue(
      idempotencyKey: 'stable-operation-key',
      operationType: 'transfer',
      payload: const {'amountMinor': 500, 'sourceAccountId': 'one'},
    );
    await service.drain(
      (_, _) async => const SyncAttemptResult.retryable(SyncIssueCode.networkUnavailable),
    );

    var operation = await database.findByIdempotencyKey('stable-operation-key');
    expect(operation?.status, 'pending');
    expect(operation?.retryCount, 1);
    expect(operation?.lastError, 'networkUnavailable');

    await service.drain((_, payload) async {
      expect(payload['amountMinor'], 500);
      return const SyncAttemptResult.success();
    });
    operation = await database.findByIdempotencyKey('stable-operation-key');
    expect(operation?.status, 'confirmed');
  });

  test('stores permanent rejection as a safe code, not an exception message', () async {
    await service.enqueue(
      idempotencyKey: 'invalid-operation-key',
      operationType: 'operation',
      payload: const {'description': 'private note'},
    );
    await service.drain(
      (_, _) async => const SyncAttemptResult.rejected(SyncIssueCode.invalidOperation),
    );

    final operation = await database.findByIdempotencyKey('invalid-operation-key');
    expect(operation?.status, 'rejected');
    expect(operation?.lastError, 'invalidOperation');
    expect(operation?.lastError, isNot(contains('private note')));
  });

  test('does not attempt delivery while offline', () async {
    service = PendingOperationSyncService(
      database,
      Connectivity(),
      connectivityProbe: () async => false,
    );
    await service.enqueue(
      idempotencyKey: 'offline-operation-key',
      operationType: 'operation',
      payload: const {'amountMinor': 100},
    );
    var sendCount = 0;
    await service.drain((_, _) async {
      sendCount++;
      return const SyncAttemptResult.success();
    });

    expect(sendCount, 0);
    expect((await database.pending()).single.idempotencyKey, 'offline-operation-key');
  });
}
