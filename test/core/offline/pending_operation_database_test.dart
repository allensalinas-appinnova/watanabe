import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/offline/pending_operation_queue.dart';

void main() {
  test('pending operation survives database reopen and reaches confirmed once', () async {
    final directory = await Directory.systemTemp.createTemp('clearbudget-drift-');
    final path = '${directory.path}/pending.sqlite';
    final first = PendingOperationDatabase(NativeDatabase(File(path)));
    await first.enqueue(
      idempotencyKey: 'offline-operation-1',
      operationType: 'transfer',
      payload: const {
        'amountMinor': 100,
        'sourceAccountId': 'source',
        'destinationAccountId': 'destination',
      },
    );
    await first.close();

    final reopened = PendingOperationDatabase(NativeDatabase(File(path)));
    final pending = await reopened.pending();
    expect(pending, hasLength(1));
    await reopened.markSyncing(pending.single.id);
    await reopened.markConfirmed(pending.single.id);
    final confirmed = await reopened.findByIdempotencyKey('offline-operation-1');
    expect(confirmed?.status, 'confirmed');
    await reopened.enqueue(
      idempotencyKey: 'offline-operation-2',
      operationType: 'operation',
      payload: const {'amountMinor': 50},
    );
    final rejected = await reopened.findByIdempotencyKey('offline-operation-2');
    await reopened.markSyncing(rejected!.id);
    await reopened.markRejected(rejected.id, 'permission-denied');
    expect((await reopened.findByIdempotencyKey('offline-operation-2'))?.status, 'rejected');
    await reopened.retry(rejected.id);
    expect((await reopened.findByIdempotencyKey('offline-operation-2'))?.status, 'pending');
    await reopened.close();
    await directory.delete(recursive: true);
  });
}
