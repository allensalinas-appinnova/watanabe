import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {executeOperationCommand} from '../lib/operation_commands.js';
import {ensureOperationProjectionVersion} from '../lib/operation_projection_migration.js';
import {operationProjectionDigest} from '../lib/projection_model.js';
import {applyOperationEvent} from '../lib/projection_store.js';
import {app, db, operation, seedUser} from './projection_test_support.mjs';

assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):59180$/,
  'These tests require the local Firestore emulator on port 59180');
assert.equal(process.env.GCLOUD_PROJECT ?? 'demo-clearbudget', 'demo-clearbudget');
after(() => deleteApp(app));

async function seed(uid, opening = 10000) {
  const root = await seedUser(uid);
  await root.update({timeZone: 'America/Bogota', resetStatus: 'ready', dataGeneration: 0});
  await root.collection('accounts').doc('cash').update({
    openingBalanceMinor: opening, currentBalanceMinor: opening, status: 'active',
  });
  const budget = root.collection('budgets').doc('monthly');
  await budget.set({categoryId: 'food', flowType: 'expense', currency: 'COP', monthKey: '2026-10', status: 'active'});
  await budget.collection('items').doc('food-item').set({actualAmountMinor: 0, status: 'active'});
  return root;
}

const create = (requestId, overrides = {}) => ({
  action: 'create', requestId, idempotencyKey: requestId, expectedGeneration: 0,
  type: 'expense', amountMinor: 1200, currency: 'COP', accountId: 'cash', categoryId: 'food',
  budgetId: 'monthly', budgetItemId: 'food-item', monthKey: '2026-10',
  occurredAt: '2026-10-20T15:00:00.000Z', description: 'Groceries', ...overrides,
});

test('create, retry after lost response, correction, cancellation and delayed triggers project exactly once', async () => {
  const uid = `operation-command-${Date.now()}`;
  const root = await seed(uid);
  const command = create('create-operation-command-01');
  const result = await executeOperationCommand(db, uid, command);
  assert.deepEqual(result, {operationId: command.requestId, revision: 0});
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, 8800);
  assert.equal((await root.collection('budgets').doc('monthly').collection('items').doc('food-item').get()).data().actualAmountMinor, 1200);
  assert.equal((await root.collection('monthlySummaries').doc('2026-10_COP').get()).data().expenseMinor, 1200);
  assert.equal((await root.collection('ledgerEntries').get()).size, 1);
  await assert.rejects(executeOperationCommand(db, uid, create('operation-invalid-budget-01', {
    budgetItemId: 'missing-item',
  })), {issue: 'operation-budget-reference-invalid'});
  await assert.rejects(executeOperationCommand(db, uid, create('operation-cop-limit-01', {
    amountMinor: 1000000001, budgetId: undefined, budgetItemId: undefined,
  })), {issue: 'operation-amount-too-large'});

  // Simulate a response lost after the transaction committed.
  assert.deepEqual(await executeOperationCommand(db, uid, command), result);
  await assert.rejects(executeOperationCommand(db, uid, create(command.requestId, {amountMinor: 1300})),
    {issue: 'operation-request-conflict'});

  const operationRef = root.collection('operations').doc(command.requestId);
  const original = (await operationRef.get()).data();
  await applyOperationEvent(db, {userId: uid, operationId: command.requestId, eventId: 'delayed-create-after-command', current: original});
  await applyOperationEvent(db, {userId: uid, operationId: command.requestId, eventId: 'stale-create-after-correction', current: {...original, amountMinor: 999}});
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, 8800);

  const correction = {
    action: 'correct', requestId: 'edit-operation-command-01', expectedGeneration: 0,
    expectedRevision: 0, operationId: command.requestId, amountMinor: 2500,
    currency: 'COP', accountId: 'bank', categoryId: 'food', monthKey: '2026-10',
    occurredAt: '2026-10-21T15:00:00.000Z', description: 'Corrected groceries',
  };
  const corrected = await executeOperationCommand(db, uid, correction);
  assert.deepEqual(corrected, {operationId: command.requestId, revision: 1});
  assert.deepEqual(await executeOperationCommand(db, uid, correction), corrected);
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, 10000);
  assert.equal((await root.collection('accounts').doc('bank').get()).data().currentBalanceMinor, 7500);
  assert.equal((await root.collection('budgets').doc('monthly').collection('items').doc('food-item').get()).data().actualAmountMinor, 2500);
  assert.equal((await root.collection('monthlySummaries').doc('2026-10_COP').get()).data().expenseMinor, 2500);
  await assert.rejects(executeOperationCommand(db, uid, {...correction, requestId: 'try-change-operation-type-01', type: 'income'}),
    {issue: 'operation-edit-invalid-command'});

  const correctionAgain = {...correction, requestId: 'edit-operation-command-02', expectedRevision: 1,
    amountMinor: 2600, description: 'Corrected groceries again'};
  await executeOperationCommand(db, uid, correctionAgain);
  assert.equal((await root.collection('accounts').doc('bank').get()).data().currentBalanceMinor, 7400);
  const ledger = (await root.collection('ledgerEntries').where('operationId', '==', command.requestId).get()).docs;
  assert.equal(ledger.length, 1);
  assert.equal(ledger[0].data().accountId, 'bank');
  assert.equal(ledger[0].data().deltaMinor, -2600);

  const cancel = {action: 'cancel', expectedGeneration: 0, operationId: command.requestId};
  const cancelled = await executeOperationCommand(db, uid, cancel);
  assert.deepEqual(await executeOperationCommand(db, uid, cancel), cancelled);
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, 10000);
  assert.equal((await root.collection('accounts').doc('bank').get()).data().currentBalanceMinor, 10000);
  assert.equal((await root.collection('budgets').doc('monthly').collection('items').doc('food-item').get()).data().actualAmountMinor, 0);
  assert.equal((await root.collection('monthlySummaries').doc('2026-10_COP').get()).data().expenseMinor, 0);
  assert.equal((await root.collection('ledgerEntries').get()).size, 0, 'cancelled source operation remains auditable without active ledger rows');
});

test('concurrent distinct operations serialize on the shared account balance', async () => {
  const uid = `operation-race-${Date.now()}`;
  const root = await seed(uid, 20000);
  await ensureOperationProjectionVersion(db, uid);
  const commands = [
    create('parallel-operation-command-01', {amountMinor: 2000, budgetId: undefined, budgetItemId: undefined}),
    create('parallel-operation-command-02', {amountMinor: 3000, budgetId: undefined, budgetItemId: undefined}),
    {
      action: 'create', requestId: 'parallel-transfer-command-01', idempotencyKey: 'parallel-transfer-command-01',
      expectedGeneration: 0, type: 'transfer', amountMinor: 2500, currency: 'COP',
      sourceAccountId: 'cash', destinationAccountId: 'bank',
      monthKey: '2026-10', occurredAt: '2026-10-20T15:00:00.000Z', description: 'Move savings',
    },
  ];
  await Promise.all(commands.map((command) => executeOperationCommand(db, uid, command)));
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, 12500);
  assert.equal((await root.collection('accounts').doc('bank').get()).data().currentBalanceMinor, 12500);
  assert.equal((await root.collection('operations').get()).size, 3);
  assert.equal((await root.collection('ledgerEntries').get()).size, 4);
  const summary = (await root.collection('monthlySummaries').doc('2026-10_COP').get()).data();
  assert.equal(summary.expenseMinor, 5000);
  assert.equal(summary.transferInMinor, 2500);
  assert.equal(summary.transferOutMinor, 2500);
});

test('account archival requires zero balance and archived accounts cannot receive new operations', async () => {
  const uid = `operation-archive-${Date.now()}`;
  const root = await seed(uid);
  await ensureOperationProjectionVersion(db, uid);
  const archive = {action: 'archiveAccount', accountId: 'cash', expectedGeneration: 0};
  await assert.rejects(executeOperationCommand(db, uid, archive), {issue: 'account-balance-must-be-zero-before-archive'});
  await root.collection('accounts').doc('empty').set({
    currency: 'COP', nature: 'money', status: 'active', openingBalanceMinor: 0,
    currentBalanceMinor: 0,
  });
  const emptyArchive = {...archive, accountId: 'empty'};
  assert.deepEqual(await executeOperationCommand(db, uid, emptyArchive), {accountId: 'empty', status: 'archived'});
  await assert.rejects(executeOperationCommand(db, uid, create('archived-account-operation-01', {
    accountId: 'empty', budgetId: undefined, budgetItemId: undefined,
  })), {issue: 'account_inactive', status: 'failed-precondition'});
  assert.equal((await root.collection('accounts').doc('empty').get()).data().currentBalanceMinor, 0);
  assert.equal((await root.collection('operations').get()).size, 0);
});

test('a legacy archived account remains reversible when correcting its old operation', async () => {
  const uid = `operation-legacy-archive-${Date.now()}`;
  const root = await seed(uid, 10000);
  const command = create('legacy-archived-expense-01', {budgetId: undefined, budgetItemId: undefined});
  await executeOperationCommand(db, uid, command);
  await root.collection('accounts').doc('cash').update({status: 'archived'});

  const correction = {
    action: 'correct', requestId: 'legacy-archived-correction-01', expectedGeneration: 0,
    expectedRevision: 0, operationId: command.requestId, amountMinor: 1500,
    currency: 'COP', accountId: 'bank', categoryId: 'food', monthKey: '2026-10',
    occurredAt: '2026-10-21T15:00:00.000Z', description: 'Corrected after archival',
  };
  await executeOperationCommand(db, uid, correction);
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, 10000);
  assert.equal((await root.collection('accounts').doc('bank').get()).data().currentBalanceMinor, 8500);
  await assert.rejects(executeOperationCommand(db, uid, create('legacy-archived-new-expense-01', {
    accountId: 'cash', budgetId: undefined, budgetItemId: undefined,
  })), {issue: 'account_inactive', status: 'failed-precondition'});
});

test('clean legacy projection is marked; drift is diagnosed without changing financial projections', async () => {
  const cleanUid = `operation-migration-clean-${Date.now()}`;
  const clean = await seed(cleanUid);
  const legacy = operation({amountMinor: 1200, budgetId: 'monthly', budgetItemId: 'food-item'});
  const digest = operationProjectionDigest(legacy);
  await clean.collection('operations').doc('legacy-operation').set({...legacy, idempotencyKey: 'legacy-operation'});
  await clean.collection('accounts').doc('cash').update({currentBalanceMinor: 8800});
  await clean.collection('budgets').doc('monthly').collection('items').doc('food-item').update({actualAmountMinor: 1200});
  await clean.collection('monthlySummaries').doc('2026-10_COP').set({monthKey: '2026-10', currency: 'COP',
    incomeMinor: 0, expenseMinor: 1200, transferInMinor: 0, transferOutMinor: 0, byCategory: {food: -1200}});
  await ensureOperationProjectionVersion(db, cleanUid);
  const migrated = (await clean.collection('operations').doc('legacy-operation').get()).data();
  assert.equal(migrated.appliedProjectionDigest, digest);
  assert.equal((await clean.get()).data().operationProjectionVersion, 1);
  await ensureOperationProjectionVersion(db, cleanUid);
  assert.equal((await clean.collection('accounts').doc('cash').get()).data().currentBalanceMinor, 8800);

  const driftUid = `operation-migration-drift-${Date.now()}`;
  const drift = await seed(driftUid);
  await drift.collection('operations').doc('legacy-operation').set({...legacy, idempotencyKey: 'legacy-operation'});
  await drift.collection('accounts').doc('cash').update({currentBalanceMinor: 1234});
  await assert.rejects(ensureOperationProjectionVersion(db, driftUid),
    {issue: 'operation-projection-reconciliation-required'});
  assert.equal((await drift.collection('accounts').doc('cash').get()).data().currentBalanceMinor, 1234);
  assert.equal((await drift.collection('operations').doc('legacy-operation').get()).data().appliedProjectionDigest, undefined);
  const profile = (await drift.get()).data();
  assert.notEqual(profile.operationProjectionVersion, 1);
  assert.equal(profile.operationProjectionMigrationIssue, 'operation-projection-reconciliation-required');
});

test('currency-specific balance bounds reject overflow without a partial operation', async () => {
  const uid = `operation-currency-bound-${Date.now()}`;
  const root = await seed(uid, 999999999);
  await ensureOperationProjectionVersion(db, uid);
  await assert.rejects(executeOperationCommand(db, uid, create('cop-balance-overflow-01', {
    type: 'income', categoryId: 'salary', amountMinor: 2, budgetId: undefined, budgetItemId: undefined,
  })), {issue: 'account_balance_out_of_range', status: 'failed-precondition'});
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, 999999999);
  assert.equal((await root.collection('operations').get()).size, 0);
  assert.equal((await root.collection('ledgerEntries').get()).size, 0);
});
