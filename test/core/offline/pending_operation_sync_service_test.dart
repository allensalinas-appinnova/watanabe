import 'dart:async';
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
    )..setSession('user');
  });

  tearDown(() async {
    service.setSession(null);
    await database.close();
  });

  test('keeps a temporary connectivity failure pending and retries with same key', () async {
    await service.enqueue(
      idempotencyKey: 'stable-operation-key',
      operationType: 'transfer',
      payload: const {'ownerUserId': 'user', 'amountMinor': 500, 'sourceAccountId': 'one'},
    );
    await service.drain(
      'user',
      (_, _) async => const SyncAttemptResult.retryable(SyncIssueCode.networkUnavailable),
    );

    var operation = await database.findByIdempotencyKey('stable-operation-key', userId: 'user');
    expect(operation?.status, 'pending');
    expect(operation?.retryCount, 1);
    expect(operation?.lastError, 'networkUnavailable');

    await service.drain('user', (_, payload) async {
      expect(payload['amountMinor'], 500);
      return const SyncAttemptResult.success();
    });
    operation = await database.findByIdempotencyKey('stable-operation-key', userId: 'user');
    expect(operation?.status, 'confirmed');
  });

  test('stores permanent rejection as a safe code, not an exception message', () async {
    await service.enqueue(
      idempotencyKey: 'invalid-operation-key',
      operationType: 'operation',
      payload: const {'ownerUserId': 'user', 'description': 'private note'},
    );
    await service.drain(
      'user',
      (_, _) async => const SyncAttemptResult.rejected(SyncIssueCode.invalidOperation),
    );

    final operation = await database.findByIdempotencyKey('invalid-operation-key', userId: 'user');
    expect(operation?.status, 'rejected');
    expect(operation?.lastError, 'invalidOperation');
    expect(operation?.lastError, isNot(contains('private note')));
  });

  test('persists an allow-listed Firebase code with a rejected operation', () async {
    await service.enqueue(
      idempotencyKey: 'denied-operation-key',
      operationType: 'operation',
      payload: const {'ownerUserId': 'user', 'description': 'private note'},
    );
    await service.drain(
      'user',
      (_, _) async => const SyncAttemptResult.rejected(
        SyncIssueCode.permissionDenied,
        technicalCode: 'permission-denied',
      ),
    );

    final operation = await database.findByIdempotencyKey('denied-operation-key', userId: 'user');
    expect(operation?.lastError, 'permissionDenied:permission-denied');
    expect(operation?.lastError, isNot(contains('private note')));
    expect(
      SyncFailureInfo.parse(operation?.lastError),
      const SyncFailureInfo(
        issue: SyncIssueCode.permissionDenied,
        technicalCode: 'permission-denied',
      ),
    );
  });

  test('drops malformed technical details instead of persisting arbitrary text', () async {
    await service.enqueue(
      idempotencyKey: 'safe-code-operation-key',
      operationType: 'operation',
      payload: const {
        'ownerUserId': 'user',
      },
    );
    await service.drain(
      'user',
      (_, _) async => const SyncAttemptResult.rejected(
        SyncIssueCode.invalidOperation,
        technicalCode: 'permission-denied with private payload',
      ),
    );

    final operation = await database.findByIdempotencyKey(
      'safe-code-operation-key',
      userId: 'user',
    );
    expect(operation?.lastError, 'invalidOperation');
  });

  test('does not attempt delivery while offline', () async {
    service = PendingOperationSyncService(
      database,
      Connectivity(),
      connectivityProbe: () async => false,
    )..setSession('user');
    await service.enqueue(
      idempotencyKey: 'offline-operation-key',
      operationType: 'operation',
      payload: const {'ownerUserId': 'user', 'amountMinor': 100},
    );
    var sendCount = 0;
    await service.drain('user', (_, _) async {
      sendCount++;
      return const SyncAttemptResult.success();
    });

    expect(sendCount, 0);
    expect((await database.pending(userId: 'user')).single.idempotencyKey, 'offline-operation-key');
  });
  test('session change cannot send another owner or accept an obsolete callback', () async {
    var now = DateTime.utc(2026, 11, 2);
    service = PendingOperationSyncService(
      database,
      Connectivity(),
      connectivityProbe: () async => true,
      clock: () => now,
    )..setSession('a');
    for (final owner in ['a', 'b']) {
      await service.enqueue(
        idempotencyKey: 'key-$owner',
        operationType: 'operation',
        payload: {'ownerUserId': owner, 'requestId': 'key-$owner', 'dataGeneration': 1},
      );
    }
    final started = Completer<void>(), response = Completer<SyncAttemptResult>();
    final original = service.drain('a', (_, payload) async {
      expect(payload['ownerUserId'], 'a');
      started.complete();
      return response.future;
    });
    await started.future;
    service.setSession('b');
    await service.drain('b', (_, payload) async {
      expect(payload['ownerUserId'], 'b');
      return const SyncAttemptResult.success();
    });
    response.complete(const SyncAttemptResult.success());
    await original;
    expect((await database.findByIdempotencyKey('key-a', userId: 'a'))?.status, 'syncing');
    expect((await database.findByIdempotencyKey('key-b', userId: 'b'))?.status, 'confirmed');
    now = now.add(const Duration(seconds: 120));
    service.setSession('a');
    await service.drain('a', (_, payload) async {
      expect(payload['requestId'], 'key-a');
      expect(payload['dataGeneration'], 1);
      return const SyncAttemptResult.success();
    });
    expect((await database.findByIdempotencyKey('key-a', userId: 'a'))?.status, 'confirmed');
  });

  test('unowned legacy data never reaches a sender', () async {
    await service.enqueue(
      idempotencyKey: 'unowned',
      operationType: 'operation',
      payload: const {'amountMinor': 99},
    );
    var attempts = 0;
    await service.drain('user', (_, _) async {
      attempts++;
      return const SyncAttemptResult.success();
    }, retryRejected: true);
    expect(attempts, 0);
    expect(await database.watchQuarantineCount().first, 1);
  });
}
