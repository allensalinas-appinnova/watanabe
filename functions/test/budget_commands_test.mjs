import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {executeBudgetCommand} from '../lib/budget_commands.js';
import {executeOperationCommand} from '../lib/operation_commands.js';
import {ensureOperationProjectionVersion} from '../lib/operation_projection_migration.js';
import {app, db, seedUser, userDump} from './projection_test_support.mjs';

after(() => deleteApp(app));
const item = (amountMinor = 100, dayOfMonth = 15) => ({description: 'Planned item', amountMinor, dayOfMonth});
const create = (requestId = 'create-request', overrides = {}) => ({
  action: 'create', requestId, categoryId: 'food', flowType: 'expense',
  monthKey: '2026-10', currency: 'COP', items: [item(), item(200)], ...overrides,
});
const send = (root, data) => executeBudgetCommand(db, root.id, {
  expectedGeneration: 0,
  ...data,
});
const associate = (root, data) => send(root, {
  action: 'setOperationBudgetItem',
  expectedRevision: 0,
  operationId: 'association-operation',
  budgetId: null,
  itemId: null,
  ...data,
});
const refs = (root, budgetId) => root.collection('budgets').doc(budgetId);

test('archiving two items and adding COP 50000 preserves the active aggregate and linked expense', async () => {
  const root = await seedUser('budget-aggregate-regression');
  const budgetId = '2026-10_expense_food_COP';
  const initial = await send(root, create('budget-aggregate-create', {
    monthKey: '2026-10',
    items: [
      {description: 'First archived item', amountMinor: 250000, dayOfMonth: 5},
      {description: 'Second archived item', amountMinor: 200000, dayOfMonth: 10},
      {description: 'Item to keep', amountMinor: 50000, dayOfMonth: 15},
    ],
  }));
  const budget = refs(root, budgetId);
  assert.equal(initial.budget.plannedAmountMinor, 500000);
  assert.equal(initial.budget.itemCount, 3);
  const createReceipt = await root.collection('budgetCommands').doc('budget-aggregate-create').get();
  assert.equal(createReceipt.data().result.budget.plannedAmountMinor, 500000);

  await send(root, {
    action: 'archiveItem', requestId: 'budget-aggregate-archive-1',
    budgetId, itemId: 'budget-aggregate-create_0',
  });
  let snapshot = await budget.get();
  assert.equal(snapshot.data().plannedAmountMinor, 250000);
  assert.equal(snapshot.data().itemCount, 2);

  await send(root, {
    action: 'archiveItem', requestId: 'budget-aggregate-archive-2',
    budgetId, itemId: 'budget-aggregate-create_1',
  });
  snapshot = await budget.get();
  assert.equal(snapshot.data().plannedAmountMinor, 50000);
  assert.equal(snapshot.data().itemCount, 1);
  const archiveReceipt = await root.collection('budgetCommands').doc('budget-aggregate-archive-2').get();
  assert.equal(archiveReceipt.data().result.budget.plannedAmountMinor, 50000);

  const addRequestId = 'budget-aggregate-add-50000';
  const added = await send(root, {
    action: 'addItem', requestId: addRequestId, budgetId,
    item: {description: 'New planned item', amountMinor: 50000, dayOfMonth: 20},
  });
  assert.equal(added.item.amountMinor, 50000);
  assert.equal(added.budget.plannedAmountMinor, 100000);
  assert.equal(added.budget.itemCount, 2);
  const addedItemRef = budget.collection('items').doc(`${addRequestId}_0`);
  assert.equal((await addedItemRef.get()).data().amountMinor, 50000);
  const addReceipt = await root.collection('budgetCommands').doc(addRequestId).get();
  assert.equal(addReceipt.data().result.item.amountMinor, 50000);

  await root.update({timeZone: 'America/Bogota', resetStatus: 'ready', dataGeneration: 0});
  await root.collection('accounts').doc('cash').update({
    openingBalanceMinor: 100000,
    currentBalanceMinor: 100000,
  });
  await ensureOperationProjectionVersion(db, root.id);
  const operationRequestId = 'budget-aggregate-expense-25k';
  await executeOperationCommand(db, root.id, {
    action: 'create', requestId: operationRequestId, idempotencyKey: operationRequestId,
    expectedGeneration: 0, type: 'expense', amountMinor: 25000, currency: 'COP',
    accountId: 'cash', categoryId: 'food', budgetId, budgetItemId: addedItemRef.id,
    occurredAt: '2026-10-20T15:00:00.000Z', monthKey: '2026-10', description: 'Synthetic budget expense',
  });

  snapshot = await budget.get();
  const itemSnapshot = await budget.collection('items').get();
  const activeItems = itemSnapshot.docs.filter((doc) => doc.data().status !== 'archived');
  const archivedItems = itemSnapshot.docs.filter((doc) => doc.data().status === 'archived');
  assert.equal(activeItems.length, 2);
  assert.equal(archivedItems.length, 2);
  assert.equal(activeItems.reduce((sum, doc) => sum + doc.data().amountMinor, 0), 100000);
  assert.equal(snapshot.data().plannedAmountMinor, 100000);
  assert.equal(snapshot.data().itemCount, 2);
  assert.equal((await addedItemRef.get()).data().actualAmountMinor, 25000);
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, 75000);
  assert.equal((await root.collection('monthlySummaries').doc('2026-10_COP').get()).data().expenseMinor, 25000);
  assert.equal(snapshot.data().plannedAmountMinor - 25000, 75000, 'COP 75000 remains planned');
});

test('create, recalculate corrupted aggregates, edit, archive and recreate preserve historical actuals', async () => {
  const root = await seedUser('budget-lifecycle');
  const first = await send(root, create());
  const budget = refs(root, first.budget.id);
  assert.equal(first.budget.plannedAmountMinor, 300);
  assert.equal(first.budget.itemCount, 2);
  await budget.update({plannedAmountMinor: 999999, itemCount: 99});
  const firstItem = budget.collection('items').doc('create-request_0');
  await firstItem.update({actualAmountMinor: 333});
  const edited = await send(root, {action: 'updateItem', requestId: 'edit-request', budgetId: budget.id,
    itemId: firstItem.id, item: item(150)});
  assert.equal(edited.budget.plannedAmountMinor, 350);
  assert.equal(edited.budget.itemCount, 2);
  assert.equal(edited.item.actualAmountMinor, 333);
  await budget.collection('items').doc('legacy').set({...item(50)});
  const added = await send(root, {action: 'addItem', requestId: 'add-request', budgetId: budget.id, item: item(150)});
  assert.equal(added.budget.plannedAmountMinor, 550);
  assert.equal(added.budget.itemCount, 4);
  const removed = await send(root, {action: 'archiveItem', requestId: 'remove-request', budgetId: budget.id, itemId: firstItem.id});
  assert.equal(removed.budget.plannedAmountMinor, 400);
  assert.equal((await firstItem.get()).data().actualAmountMinor, 333);
  await send(root, {action: 'archiveBudget', requestId: 'archive-request', budgetId: budget.id});
  const recreated = await send(root, create('recreate-request', {items: [item(42)]}));
  assert.equal(recreated.budget.id, budget.id);
  assert.equal(recreated.budget.plannedAmountMinor, 42);
  assert.equal(recreated.budget.itemCount, 1);
  const all = await budget.collection('items').get();
  assert.equal(all.size, 5);
  assert.equal(all.docs.filter((doc) => doc.data().status !== 'archived').length, 1);
  assert.equal((await firstItem.get()).data().actualAmountMinor, 333);
});

test('reconciliation repairs only a stale parent aggregate from active items and is a no-op afterward', async () => {
  const root = await seedUser('budget-reconcile-stale-parent');
  const created = await send(root, create('reconcile-budget-create', {
    items: [item(300), item(700)],
  }));
  const budget = refs(root, created.budget.id);
  const firstItem = budget.collection('items').doc('reconcile-budget-create_0');
  await firstItem.update({actualAmountMinor: 125});
  const childrenBefore = (await budget.collection('items').get()).docs.map((doc) => ({
    id: doc.id,
    data: doc.data(),
  }));
  const unrelatedBudget = refs(root, 'budget');
  const unrelatedBefore = (await unrelatedBudget.get()).data();
  await budget.update({plannedAmountMinor: 999999, itemCount: 99});

  const repaired = await send(root, {
    action: 'reconcile', requestId: 'budget-reconcile-first', budgetId: budget.id,
  });
  assert.equal(repaired.budget.plannedAmountMinor, 1000);
  assert.equal(repaired.budget.itemCount, 2);
  let parent = (await budget.get()).data();
  assert.equal(parent.plannedAmountMinor, 1000);
  assert.equal(parent.itemCount, 2);
  assert.equal(parent.status, 'active');
  assert.equal((await firstItem.get()).data().actualAmountMinor, 125);
  assert.deepEqual(
    (await budget.collection('items').get()).docs.map((doc) => ({id: doc.id, data: doc.data()})),
    childrenBefore,
  );
  assert.deepEqual((await unrelatedBudget.get()).data(), unrelatedBefore);

  const updateTimeAfterRepair = (await budget.get()).updateTime.toMillis();
  const repeated = await send(root, {
    action: 'reconcile', requestId: 'budget-reconcile-noop', budgetId: budget.id,
  });
  assert.equal(repeated.budget.plannedAmountMinor, 1000);
  assert.equal((await budget.get()).updateTime.toMillis(), updateTimeAfterRepair);
  parent = (await budget.get()).data();
  assert.equal(parent.plannedAmountMinor, 1000);
  assert.equal(parent.itemCount, 2);
});

test('movement association can be moved and removed without changing financial projections', async () => {
  const root = await seedUser('budget-operation-association');
  const createRequestId = 'association-budget-create';
  const {budget} = await send(root, create(createRequestId, {items: [item(10000), item(20000)]}));
  await root.update({timeZone: 'America/Bogota', resetStatus: 'ready', dataGeneration: 0});
  await root.collection('accounts').doc('cash').update({
    openingBalanceMinor: 5000,
    currentBalanceMinor: 5000,
  });
  await ensureOperationProjectionVersion(db, root.id);
  const operationId = 'association-operation';
  await executeOperationCommand(db, root.id, {
    action: 'create', requestId: operationId, idempotencyKey: operationId,
    expectedGeneration: 0, type: 'expense', amountMinor: 1200, currency: 'COP',
    accountId: 'cash', categoryId: 'food', occurredAt: '2026-10-15T15:00:00.000Z',
    monthKey: '2026-10', description: 'Synthetic association test',
  });

  const item0 = refs(root, budget.id).collection('items').doc(`${createRequestId}_0`);
  const item1 = refs(root, budget.id).collection('items').doc(`${createRequestId}_1`);
  const operationRef = root.collection('operations').doc(operationId);
  const balanceBefore = (await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor;
  const summaryBefore = (await root.collection('monthlySummaries').doc('2026-10_COP').get()).data();
  assert.equal(balanceBefore, 3800);
  assert.equal(summaryBefore.expenseMinor, 1200);

  const firstAssociation = {
    action: 'setOperationBudgetItem', requestId: 'association-link-first',
    expectedRevision: 0, operationId, budgetId: budget.id, itemId: item0.id,
  };
  await associate(root, firstAssociation);
  assert.equal((await item0.get()).data().actualAmountMinor, 1200);
  assert.equal((await item1.get()).data().actualAmountMinor, 0);
  assert.equal((await operationRef.get()).data().budgetItemId, item0.id);

  await associate(root, {
    action: 'setOperationBudgetItem', requestId: 'association-link-unchanged',
    expectedRevision: 1, operationId, budgetId: budget.id, itemId: item0.id,
  });
  assert.equal((await item0.get()).data().actualAmountMinor, 1200);
  assert.equal((await operationRef.get()).data().revision, 1);
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, balanceBefore);
  assert.deepEqual((await root.collection('monthlySummaries').doc('2026-10_COP').get()).data(), summaryBefore);

  const moveRequest = {
    action: 'setOperationBudgetItem', requestId: 'association-link-move',
    expectedRevision: 1, operationId, budgetId: budget.id, itemId: item1.id,
  };
  await associate(root, moveRequest);
  assert.equal((await item0.get()).data().actualAmountMinor, 0);
  assert.equal((await item1.get()).data().actualAmountMinor, 1200);
  assert.equal((await operationRef.get()).data().budgetItemId, item1.id);

  const clearRequest = {
    action: 'setOperationBudgetItem', requestId: 'association-link-clear',
    expectedRevision: 2, operationId, budgetId: null, itemId: null,
  };
  await associate(root, clearRequest);
  assert.equal((await item1.get()).data().actualAmountMinor, 0);
  const clearedOperation = (await operationRef.get()).data();
  assert.equal(clearedOperation.budgetId, undefined);
  assert.equal(clearedOperation.budgetItemId, undefined);
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, balanceBefore);
  assert.deepEqual((await root.collection('monthlySummaries').doc('2026-10_COP').get()).data(), summaryBefore);

  const replayRequest = {
    action: 'setOperationBudgetItem', requestId: 'association-link-replay',
    expectedRevision: 3, operationId, budgetId: budget.id, itemId: item0.id,
  };
  const firstReplay = await associate(root, replayRequest);
  const stateAfterFirst = await userDump(root);
  assert.deepEqual(await associate(root, replayRequest), firstReplay);
  assert.deepEqual(await userDump(root), stateAfterFirst);
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, balanceBefore);
  assert.equal((await root.collection('monthlySummaries').doc('2026-10_COP').get()).data().expenseMinor, 1200);
});

test('command replay is a no-op and a changed payload cannot reuse a request ID', async () => {
  const root = await seedUser('budget-idempotent');
  const command = create();
  const first = await send(root, command);
  const before = await userDump(root);
  assert.deepEqual(await send(root, command), first);
  assert.deepEqual(await userDump(root), before);
  await assert.rejects(send(root, {...command, items: [item(300)]}), {issue: 'budget-request-conflict'});
  assert.deepEqual(await userDump(root), before);
});

test('concurrent additions and duplicate requests produce coherent totals and one receipt each', async () => {
  const root = await seedUser('budget-concurrent');
  const {budget} = await send(root, create());
  const a = {action: 'addItem', requestId: 'concurrent-a', budgetId: budget.id, item: item(500)};
  await Promise.all([send(root, a), send(root, a), send(root, {...a, requestId: 'concurrent-b', item: item(700)})]);
  const current = (await refs(root, budget.id).get()).data();
  assert.equal(current.plannedAmountMinor, 1500);
  assert.equal(current.itemCount, 4);
  assert.equal((await root.collection('budgetCommands').get()).size, 3);
});

test('concurrent removals cannot remove the last active item', async () => {
  const root = await seedUser('budget-last-item');
  const {budget} = await send(root, create());
  const outcomes = await Promise.allSettled([0, 1].map((index) => send(root, {
    action: 'archiveItem', requestId: `remove-item-${index}`, budgetId: budget.id, itemId: `create-request_${index}`,
  })));
  assert.equal(outcomes.filter((o) => o.status === 'fulfilled').length, 1);
  assert.equal(outcomes.find((o) => o.status === 'rejected').reason.issue, 'budget-last-item');
  assert.equal((await refs(root, budget.id).get()).data().itemCount, 1);
});

test('invalid values, incompatible categories and injected aggregate/actual fields never write', async () => {
  const root = await seedUser('budget-invalid');
  const baseline = await userDump(root);
  const commands = [
    create('invalid-1', {items: [item(0)]}), create('invalid-2', {items: [item(-1)]}),
    create('invalid-3', {items: [item(1000000001)]}),
    create('invalid-4', {items: [item(1000000000), item(1)]}),
    create('invalid-5', {monthKey: '2026-02', items: [item(100, 29)]}),
    create('invalid-6', {categoryId: 'salary'}), create('invalid-7', {categoryId: '../foreign'}),
    create('invalid-8', {plannedAmountMinor: 10}),
    create('invalid-9', {items: [{...item(), actualAmountMinor: 10}]}),
    create('invalid-10', {userId: 'other-user'}),
    create('invalid-11', {items: [{...item(), description: 'x'.repeat(201)}]}),
  ];
  for (const command of commands) {
    await assert.rejects(send(root, command));
    assert.deepEqual(await userDump(root), baseline);
  }
  const leap = await send(root, create('leap-request', {monthKey: '2028-02', items: [item(100, 29)]}));
  assert.equal(leap.budget.plannedAmountMinor, 100);
});

test('maximum amounts respect currency precision; duplicate category/month creation conflicts', async () => {
  const root = await seedUser('budget-currencies');
  for (const [currency, amount] of [['COP', 1000000000], ['MXN', 100000000000], ['BRL', 100000000000]]) {
    const result = await send(root, create(`currency-${currency}`, {currency, items: [item(amount)]}));
    assert.equal(result.budget.plannedAmountMinor, amount);
  }
  await assert.rejects(send(root, create('duplicate-request')), {issue: 'budget-already-exists'});
});

test('authentication and UID scoping cannot be overridden by a caller', async () => {
  const alice = await seedUser('budget-alice');
  const bob = await seedUser('budget-bob');
  const {budget} = await send(alice, create());
  const before = await userDump(alice);
  await assert.rejects(executeBudgetCommand(db, undefined, create()), {status: 'unauthenticated'});
  await assert.rejects(send(bob, {action: 'archiveBudget', requestId: 'foreign-request', budgetId: budget.id}), {issue: 'budget-not-found'});
  await assert.rejects(send(bob, {action: 'archiveBudget', requestId: 'foreign-request', budgetId: `../${alice.id}/${budget.id}`}), {issue: 'budget-invalid-reference'});
  assert.deepEqual(await userDump(alice), before);
});

test('invalid existing active items fail atomically without changing the receipt or parent', async () => {
  const root = await seedUser('budget-rollback');
  const {budget} = await send(root, create());
  await refs(root, budget.id).collection('items').doc('bad-legacy').set(item(1000000001));
  const before = await userDump(root);
  await assert.rejects(send(root, {action: 'addItem', requestId: 'failed-request', budgetId: budget.id, item: item(1)}));
  assert.deepEqual(await userDump(root), before);
});
