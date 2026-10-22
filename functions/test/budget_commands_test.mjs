import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {executeBudgetCommand} from '../lib/budget_commands.js';
import {app, db, seedUser, userDump} from './projection_test_support.mjs';

after(() => deleteApp(app));
const item = (amountMinor = 100, dayOfMonth = 15) => ({description: 'Planned item', amountMinor, dayOfMonth});
const create = (requestId = 'create-request', overrides = {}) => ({
  action: 'create', requestId, categoryId: 'food', flowType: 'expense',
  monthKey: '2026-10', currency: 'COP', items: [item(), item(200)], ...overrides,
});
const send = (root, data) => executeBudgetCommand(db, root.id, data);
const refs = (root, budgetId) => root.collection('budgets').doc(budgetId);

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
