import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {executeBalanceAdjustment} from '../lib/balance_adjustments.js';
import {executeBudgetCommand} from '../lib/budget_commands.js';
import {executeDebtCommand} from '../lib/debt_commands.js';
import {executeEmailImportCommand} from '../lib/email_imports.js';
import {applyOperationEvent} from '../lib/projection_store.js';
import {app, db, seedUser, userDump} from './projection_test_support.mjs';

after(() => deleteApp(app));

test('stale-generation callables and delayed triggers cannot recreate reset data', async () => {
  const root = await seedUser('generation-stale-writes');
  await root.update({dataGeneration: 2});
  const before = await userDump(root);
  const expectedGeneration = 0;
  const rejected = [
    () => executeBudgetCommand(db, root.id, {
      requestId: 'stale-budget-001', expectedGeneration, action: 'create', categoryId: 'food',
      flowType: 'expense', monthKey: '2026-10', currency: 'COP',
      items: [{description: 'item', amountMinor: 1, dayOfMonth: 1}],
    }),
    () => executeDebtCommand(db, root.id, {
      requestId: 'stale-debt-001', expectedGeneration, action: 'create', name: 'debt',
      product: 'creditCard', currency: 'COP', referenceAt: '2026-10-01T00:00:00Z',
      debtMinor: 0, mode: 'existing',
    }, {enabled: true}),
    () => executeBalanceAdjustment(db, root.id, {
      requestId: 'stale-adjust-001', expectedGeneration,
      adjustments: [{accountId: 'bank', currency: 'COP', targetBalanceMinor: 1}],
    }),
    () => executeEmailImportCommand(db, root.id, {
      requestId: 'stale-import-001', expectedGeneration, candidateId: 'candidate',
      action: 'discard', expectedVersion: 1,
    }, {allowedUids: [root.id]}),
  ];
  for (const operation of rejected) {
    await assert.rejects(operation(), {status: 'failed-precondition'});
    assert.deepEqual(await userDump(root), before);
  }
  await assert.doesNotReject(applyOperationEvent(db, {
    userId: root.id, eventId: 'delayed-generation-zero-trigger',
    current: {
      type: 'expense', amountMinor: 100, currency: 'COP', monthKey: '2026-10',
      accountId: 'deleted-account', categoryId: 'food', status: 'confirmed', dataGeneration: 0,
    },
  }));
  assert.deepEqual(await userDump(root), before);
});
