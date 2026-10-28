import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {applyOperationEvent} from '../lib/projection_store.js';
import {operationProjectionDigest} from '../lib/projection_model.js';
import {app, db, operation, seedUser, userDump} from './projection_test_support.mjs';

after(() => deleteApp(app));
const apply = async (root, eventId, previous, current, operationId = eventId) => {
  const operationRef = root.collection('operations').doc(operationId);
  if (current) {
    const existing = await operationRef.get();
    if (!existing.exists || operationProjectionDigest(existing.data()) !== operationProjectionDigest(current)) {
      await operationRef.set({...current, idempotencyKey: current.idempotencyKey ?? operationId});
    }
  } else {
    await operationRef.delete();
  }
  try {
    return await applyOperationEvent(db, {userId: root.id, operationId, eventId, previous, current});
  } catch (error) {
    // Keep these projection transaction tests focused on derived writes; the
    // production source document is written by the callable before its trigger.
    if (current) await operationRef.delete();
    throw error;
  }
};
const balance = async (root, account = 'cash') => (await root.collection('accounts').doc(account).get()).data().currentBalanceMinor;

test('transaction creates complete summaries and reverses linked archived item on edit, rejection and deletion', async () => {
  const root = await seedUser('store-lifecycle');
  const first = operation({budgetId: 'budget', budgetItemId: 'item'});
  await apply(root, 'create', undefined, first, 'lifecycle-operation');
  assert.equal(await balance(root), 3800);
  const summary = (await root.collection('monthlySummaries').doc('2026-10_COP').get()).data();
  assert.equal(summary.monthKey, '2026-10');
  assert.equal(summary.currency, 'COP');
  assert.equal(summary.expenseMinor, 1200);
  assert.equal(summary.byCategory.food, -1200);
  const item = root.collection('budgets').doc('budget').collection('items').doc('item');
  assert.equal((await item.get()).data().actualAmountMinor, 1200);
  const edited = {...first, amountMinor: 1800};
  await apply(root, 'edit', first, edited, 'lifecycle-operation');
  assert.equal(await balance(root), 3200);
  assert.equal((await item.get()).data().actualAmountMinor, 1800);
  const rejected = {...edited, status: 'rejected'};
  await apply(root, 'reject', edited, rejected, 'lifecycle-operation');
  assert.equal(await balance(root), 5000);
  assert.equal((await item.get()).data().actualAmountMinor, 0);
  await apply(root, 'restore', rejected, edited, 'lifecycle-operation');
  await apply(root, 'delete', edited, undefined, 'lifecycle-operation');
  assert.equal(await balance(root), 5000);
  assert.equal((await item.get()).data().actualAmountMinor, 0);
});

test('same event repeated and delivered concurrently commits only once; separate events compose', async () => {
  const root = await seedUser('store-idempotency');
  await apply(root, 'same', undefined, operation(), 'same-operation');
  await Promise.all(Array.from({length: 4}, () => apply(root, 'same', undefined, operation(), 'same-operation')));
  const once = await userDump(root);
  await apply(root, 'same', undefined, operation(), 'same-operation');
  assert.deepEqual(await userDump(root), once);
  await Promise.all(['other-a', 'other-b'].map((id) => apply(root, id, undefined, operation({amountMinor: 100}), `${id}-operation`)));
  assert.equal(await balance(root), 3600);
  assert.equal((await root.collection('processedOperations').get()).size, 3);
});

test('changes move contributions between accounts, months, categories, types and currencies', async () => {
  const root = await seedUser('store-moves');
  const first = operation();
  await apply(root, 'create', undefined, first, 'moving-operation');
  const changed = operation({type: 'income', categoryId: 'salary', accountId: 'mxn', currency: 'MXN', monthKey: '2026-11', amountMinor: 200});
  await apply(root, 'move', first, changed, 'moving-operation');
  assert.equal(await balance(root), 5000);
  assert.equal(await balance(root, 'mxn'), 2200);
  const old = (await root.collection('monthlySummaries').doc('2026-10_COP').get()).data();
  assert.equal(old.expenseMinor, 0);
  assert.equal(old.byCategory.food, 0);
  const next = (await root.collection('monthlySummaries').doc('2026-11_MXN').get()).data();
  assert.equal(next.incomeMinor, 200);
  assert.equal(next.byCategory.salary, 200);
  const brl = {...changed, accountId: 'brl', currency: 'BRL', categoryId: 'salary'};
  await apply(root, 'brl', changed, brl, 'moving-operation');
  assert.equal(await balance(root, 'mxn'), 2000);
  assert.equal(await balance(root, 'brl'), 3200);
  await apply(root, 'expense', brl, operation({categoryId: 'travel', accountId: 'bank'}), 'moving-operation');
  assert.equal(await balance(root, 'brl'), 3000);
  assert.equal(await balance(root, 'bank'), 8800);
});

test('pending has no projection, confirmation applies it; transfers affect both accounts without income/expense', async () => {
  const root = await seedUser('store-status-transfer');
  const pending = operation({status: 'pending'});
  await root.collection('operations').doc('pending-operation').set({...pending, idempotencyKey: 'pending-operation'});
  const untouched = await userDump(root);
  await apply(root, 'pending', undefined, pending, 'pending-operation');
  assert.deepEqual(await userDump(root), untouched);
  await apply(root, 'confirmed', pending, operation(), 'pending-operation');
  const transfer = operation({type: 'transfer', sourceAccountId: 'cash', destinationAccountId: 'bank', amountMinor: 10000});
  await apply(root, 'transfer', undefined, transfer, 'transfer-operation');
  assert.equal(await balance(root), -6200);
  assert.equal(await balance(root, 'bank'), 20000);
  const summary = (await root.collection('monthlySummaries').doc('2026-10_COP').get()).data();
  assert.equal(summary.incomeMinor, 0);
  assert.equal(summary.expenseMinor, 1200);
  assert.equal(summary.transferInMinor, 10000);
  assert.equal(summary.transferOutMinor, 10000);
  assert.deepEqual(summary.byCategory, {food: -1200});
});

test('late validation failure rolls back balances, summary and event marker, then retries recover', async () => {
  const root = await seedUser('store-rollback');
  const linked = operation({budgetId: 'budget', budgetItemId: 'item'});
  const item = root.collection('budgets').doc('budget').collection('items').doc('item');
  await item.update({actualAmountMinor: 'invalid'});
  const before = await userDump(root);
  await assert.rejects(apply(root, 'retry-event', undefined, linked, 'retry-operation'), {code: 'invalid_integer'});
  assert.deepEqual(await userDump(root), before);
  await item.update({actualAmountMinor: 0});
  await apply(root, 'retry-event', undefined, linked, 'retry-operation');
  assert.equal(await balance(root), 3800);
  assert.equal((await item.get()).data().actualAmountMinor, 1200);
  assert.equal((await root.collection('processedOperations').doc('retry-event').get()).exists, true);
});

test('out-of-order removal retries after creation, preserving the final ledger result', async () => {
  const root = await seedUser('store-order');
  const linked = operation({budgetId: 'budget', budgetItemId: 'item'});
  const untouched = await userDump(root);
  await assert.rejects(apply(root, 'remove', linked, undefined, 'removal-operation'), {code: 'negative_item_actual'});
  assert.deepEqual(await userDump(root), untouched);
  await apply(root, 'create', undefined, linked, 'removal-operation');
  await apply(root, 'remove', linked, undefined, 'removal-operation');
  assert.equal(await balance(root), 5000);
  assert.equal((await root.collection('budgets').doc('budget').collection('items').doc('item').get()).data().actualAmountMinor, 0);
});

test('missing or incompatible references fail without partial projections', async () => {
  const root = await seedUser('store-invalid-reference');
  for (const overrides of [
    {accountId: 'missing'}, {accountId: 'mxn'}, {budgetId: 'budget'},
    {budgetId: 'missing', budgetItemId: 'item'},
    {budgetId: 'budget', budgetItemId: 'item', categoryId: 'travel'},
  ]) {
    const before = await userDump(root);
    await assert.rejects(apply(root, 'invalid', undefined, operation(overrides), `invalid-${overrides.accountId ?? overrides.budgetId ?? 'ref'}`));
    assert.deepEqual(await userDump(root), before);
  }
});

test('multiple linked incomes aggregate independently and rejecting one preserves the other', async () => {
  const root = await seedUser('store-income-items');
  const budget = root.collection('budgets').doc('income');
  const item = budget.collection('items').doc('salary');
  await budget.set({categoryId: 'salary', flowType: 'income', currency: 'BRL'});
  await item.set({}); // Legacy item: missing status/actual is active/zero.
  const income = operation({type: 'income', categoryId: 'salary', currency: 'BRL', accountId: 'brl', budgetId: 'income', budgetItemId: 'salary', amountMinor: 250});
  await apply(root, 'income-a', undefined, income, 'income-operation-a');
  await apply(root, 'income-b', undefined, {...income, amountMinor: 450}, 'income-operation-b');
  assert.equal((await item.get()).data().actualAmountMinor, 700);
  assert.equal(await balance(root, 'brl'), 3700);
  await apply(root, 'reject-income-a', income, {...income, status: 'rejected'}, 'income-operation-a');
  assert.equal((await item.get()).data().actualAmountMinor, 450);
  assert.equal(await balance(root, 'brl'), 3450);
});
