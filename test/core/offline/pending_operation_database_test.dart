import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/core/offline/pending_operation_queue.dart';

void main() {
  test('owner-scoped selection and reset preserve other users and quarantine', () async {
    final db = PendingOperationDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final owner in ['a', 'b', '']) {
      await db.enqueue(
        idempotencyKey: 'key-$owner',
        operationType: 'operation',
        payload: {
          if (owner.isNotEmpty) 'ownerUserId': owner,
          'dataGeneration': 0,
        },
      );
    }
    expect((await db.activeForUser('a')).map((r) => r.idempotencyKey), ['key-a']);
    expect(await db.findByIdempotencyKey('key-a', userId: 'b'), isNull);
    expect(await db.watchQuarantineCount().first, 1);
    await db.clearUserData('a');
    expect(await db.findByIdempotencyKey('key-a', userId: 'a'), isNull);
    expect(await db.findByIdempotencyKey('key-b', userId: 'b'), isNotNull);
    expect(await db.watchQuarantineCount().first, 1);
    await db.discardQuarantine();
    expect(await db.watchQuarantineCount().first, 0);
  });

  test(
    'reopen recovers expired lease with same request; stale callback cannot overwrite',
    () async {
      final directory = await Directory.systemTemp.createTemp('lumio-outbox-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/queue.sqlite');
      var db = PendingOperationDatabase(NativeDatabase(file));
      final now = DateTime.utc(2026, 11, 2);
      await db.enqueue(
        idempotencyKey: 'stable-key',
        operationType: 'transfer',
        payload: {'ownerUserId': 'a', 'dataGeneration': 1},
      );
      final row = await db.claim('a', 'attempt-1', now);
      await db.close();
      db = PendingOperationDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(await db.claim('b', 'foreign', now.add(const Duration(seconds: 121))), isNull);
      expect(await db.claim('a', 'early', now.add(const Duration(seconds: 119))), isNull);
      final recovered = await db.claim('a', 'attempt-2', now.add(const Duration(seconds: 120)));
      expect(recovered?.id, row?.id);
      expect(recovered?.idempotencyKey, 'stable-key');
      await db.finish(row!.id, 'a', 'attempt-1', 'confirmed');
      expect((await db.findByIdempotencyKey('stable-key', userId: 'a'))?.status, 'syncing');
      await db.finish(row.id, 'b', 'attempt-2', 'confirmed');
      expect((await db.findByIdempotencyKey('stable-key', userId: 'a'))?.status, 'syncing');
      await db.finish(row.id, 'a', 'attempt-2', 'confirmed');
      expect((await db.findByIdempotencyKey('stable-key', userId: 'a'))?.status, 'confirmed');
    },
  );

  test('v1 migration quarantines unknown owners and recovers known interrupted rows', () async {
    final db = PendingOperationDatabase(
      NativeDatabase.memory(
        setup: (sqlite) {
          sqlite
            ..execute(
              'CREATE TABLE pending_operations (id INTEGER PRIMARY KEY AUTOINCREMENT, idempotency_key TEXT NOT NULL UNIQUE, operation_type TEXT NOT NULL, payload TEXT NOT NULL, status TEXT NOT NULL, retry_count INTEGER NOT NULL DEFAULT 0, last_error TEXT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
            )
            ..execute(
              "INSERT INTO pending_operations (idempotency_key,operation_type,payload,status,created_at,updated_at) VALUES ('known','operation','{\"ownerUserId\":\"a\",\"dataGeneration\":1}','syncing',1,1), ('unknown','operation','{}','pending',1,1)",
            )
            ..execute('PRAGMA user_version = 1');
        },
      ),
    );
    addTearDown(db.close);
    expect((await db.pending(userId: 'a')).single.idempotencyKey, 'known');
    expect(await db.watchQuarantineCount().first, 1);
    expect(
      (await db.findByIdempotencyKey('known', userId: 'a'))?.payload,
      contains('"dataGeneration":1'),
    );
  });

  test('idempotency key cannot replace payload or revive a confirmed operation', () async {
    final db = PendingOperationDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final payload = {'ownerUserId': 'a', 'amountMinor': 25000};
    final id = await db.enqueue(
      idempotencyKey: 'key',
      operationType: 'operation',
      payload: payload,
    );
    await db.claim('a', 'attempt', DateTime.now().toUtc());
    await db.finish(id, 'a', 'attempt', 'confirmed');
    await db.enqueue(idempotencyKey: 'key', operationType: 'operation', payload: payload);
    expect((await db.findByIdempotencyKey('key', userId: 'a'))?.status, 'confirmed');
    await expectLater(
      db.enqueue(idempotencyKey: 'key', operationType: 'operation', payload: {'ownerUserId': 'b'}),
      throwsStateError,
    );
  });
}
