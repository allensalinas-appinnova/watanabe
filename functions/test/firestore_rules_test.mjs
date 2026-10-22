import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test, {after, before, beforeEach} from 'node:test';
import {assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {Timestamp} from 'firebase/firestore';

const rules = readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8');
let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'demo-clearbudget',
    firestore: {host: '127.0.0.1', port: 59180, rules},
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

const userProfile = () => ({
  locale: 'es',
  countryCode: 'CO',
  timeZone: 'America/Bogota',
  defaultCurrency: 'COP',
  onboardingStatus: 'complete',
  categoryCatalogVersion: 1,
  createdAt: Timestamp.now(),
  updatedAt: Timestamp.now(),
});

test('unauthenticated users cannot read user data or the category catalog', async () => {
  const db = environment.unauthenticatedContext().firestore();
  await assertFails(db.collection('categoryCatalog').doc('food').get());
  await assertFails(db.collection('users').doc('alice').get());
});

test('user data is isolated and authenticated catalog reads are allowed', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const bob = environment.authenticatedContext('bob').firestore();
  await assertSucceeds(alice.collection('categoryCatalog').doc('food').get());
  await assertSucceeds(alice.collection('users').doc('alice').set(userProfile()));
  await assertFails(bob.collection('users').doc('alice').get());
});

test('clients cannot write calculated balances or monthly summaries', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const account = alice.collection('users').doc('alice').collection('accounts').doc('cash');
  await assertSucceeds(alice.collection('users').doc('alice').set(userProfile()));
  await assertSucceeds(account.set({
    name: 'Cash', type: 'cash', currency: 'COP', openingBalanceMinor: 0,
    currentBalanceMinor: 0, includeInDashboard: true, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  await assertFails(account.update({currentBalanceMinor: 100}));
  await assertFails(
    alice.collection('users').doc('alice').collection('monthlySummaries').doc('2026-10_COP')
      .set({monthKey: '2026-10', currency: 'COP'}),
  );
});

test('invalid operation amounts and cross-account transfers are rejected', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  await assertSucceeds(alice.collection('users').doc('alice').set(userProfile()));
  const accounts = alice.collection('users').doc('alice').collection('accounts');
  const accountData = (name) => ({
    name, type: 'cash', currency: 'COP', openingBalanceMinor: 0,
    currentBalanceMinor: 0, includeInDashboard: true, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  await assertSucceeds(accounts.doc('source').set(accountData('Source')));
  await assertFails(alice.collection('users').doc('alice').collection('operations').doc('invalid-op').set({
    type: 'expense', amountMinor: 1.5, currency: 'COP', categoryId: 'food',
    accountId: 'source', monthKey: '2026-10', occurredAt: Timestamp.now(),
    description: 'Invalid', status: 'confirmed', idempotencyKey: 'invalid-op',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  const bob = environment.authenticatedContext('bob').firestore();
  await assertFails(bob.collection('users').doc('bob').collection('operations').doc('cross-user').set({
    type: 'transfer', amountMinor: 100, currency: 'COP', sourceAccountId: 'source',
    destinationAccountId: 'source', monthKey: '2026-10', occurredAt: Timestamp.now(),
    description: 'Invalid', status: 'confirmed', idempotencyKey: 'cross-user',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
});

test('amount cap is enforced for operations, account opening balances and budgets', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const user = alice.collection('users').doc('alice');
  await assertSucceeds(user.set(userProfile()));
  const accounts = user.collection('accounts');
  const accountData = (name, amount) => ({
    name, type: 'cash', currency: 'COP', openingBalanceMinor: amount,
    currentBalanceMinor: amount, includeInDashboard: true, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  await assertSucceeds(accounts.doc('max-cash').set(accountData('Max cash', 1000000000)));
  await assertFails(accounts.doc('too-much-cash').set(accountData('Too much', 1000000001)));
  await assertSucceeds(user.collection('categories').doc('food').set({
    type: 'expense', name: 'Food', icon: 'food', sortOrder: 1,
    isSystem: false, isArchived: false, createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  const operation = (id, amount) => user.collection('operations').doc(id).set({
    type: 'expense', amountMinor: amount, currency: 'COP', categoryId: 'food',
    accountId: 'max-cash', monthKey: '2026-10', occurredAt: Timestamp.now(),
    description: 'Expense', status: 'confirmed', idempotencyKey: id,
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  await assertSucceeds(operation('valid-amount', 1000000000));
  await assertFails(operation('large-amount', 1000000001));

  const budget = user.collection('budgets').doc('max-budget');
  await assertSucceeds(budget.set({
    categoryId: 'food', flowType: 'expense', monthKey: '2026-10', currency: 'COP',
    plannedAmountMinor: 1000000000, itemCount: 1, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  await assertFails(user.collection('budgets').doc('large-budget').set({
    categoryId: 'food', flowType: 'expense', monthKey: '2026-10', currency: 'COP',
    plannedAmountMinor: 1000000001, itemCount: 1, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  await assertSucceeds(budget.collection('items').doc('within-limit').set({
    description: 'Within limit', amountMinor: 1000000000, dayOfMonth: 31,
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  await assertFails(budget.collection('items').doc('over-limit').set({
    description: 'Over limit', amountMinor: 1000000001, dayOfMonth: 31,
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
});

test('itemized budgets can create the parent and items atomically', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const user = alice.collection('users').doc('alice');
  const budget = user.collection('budgets').doc('2026-10_expense_food_COP');
  const category = user.collection('categories').doc('food');
  await assertSucceeds(user.set(userProfile()));
  await assertSucceeds(category.set({
    type: 'expense', name: 'Comida', icon: 'restaurant', sortOrder: 1,
    isSystem: false, isArchived: false,
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));

  const batch = alice.batch();
  batch.set(budget, {
    categoryId: 'food', flowType: 'expense', monthKey: '2026-10', currency: 'COP',
    plannedAmountMinor: 150000, itemCount: 2, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  batch.set(budget.collection('items').doc('item-1'), {
    description: 'Comidas', amountMinor: 100000, dayOfMonth: 15,
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  batch.set(budget.collection('items').doc('item-2'), {
    description: 'Bebidas', amountMinor: 50000, dayOfMonth: 16,
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  await assertSucceeds(batch.commit());

  const archiveItem = alice.batch();
  archiveItem.update(budget, {
    plannedAmountMinor: 100000, itemCount: 1, updatedAt: Timestamp.now(),
  });
  archiveItem.update(budget.collection('items').doc('item-2'), {
    status: 'archived', archivedAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  await assertSucceeds(archiveItem.commit());
  await assertFails(budget.collection('items').doc('item-2').delete());
  const archivedItem = await budget.collection('items').doc('item-2').get();
  assert.equal(archivedItem.data().status, 'archived');
});

test('budget-linked operations require a complete matching item, including archived history', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const user = alice.collection('users').doc('alice');
  const category = user.collection('categories').doc('food');
  const budget = user.collection('budgets').doc('2026-10_expense_food_COP');
  const item = budget.collection('items').doc('item-1');
  const account = user.collection('accounts').doc('cash');
  await assertSucceeds(user.set(userProfile()));
  await assertSucceeds(category.set({
    type: 'expense', name: 'Comida', icon: 'food', sortOrder: 1,
    isSystem: false, isArchived: false, createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  await assertSucceeds(account.set({
    name: 'Cash', type: 'cash', currency: 'COP', openingBalanceMinor: 0,
    currentBalanceMinor: 0, includeInDashboard: true, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  const setup = alice.batch();
  setup.set(budget, {
    categoryId: 'food', flowType: 'expense', monthKey: '2026-10', currency: 'COP',
    plannedAmountMinor: 10000, itemCount: 1, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  setup.set(item, {
    description: 'Comida', amountMinor: 10000, dayOfMonth: 20,
    actualAmountMinor: 0, status: 'active', createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  });
  await assertSucceeds(setup.commit());

  const operation = (id, overrides = {}) => user.collection('operations').doc(id).set({
    type: 'expense', amountMinor: 1000, currency: 'COP', categoryId: 'food', accountId: 'cash',
    budgetId: budget.id, budgetItemId: item.id, monthKey: '2026-10', occurredAt: Timestamp.now(),
    description: 'Lunch', status: 'confirmed', idempotencyKey: id,
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(), ...overrides,
  });
  await assertSucceeds(operation('linked-valid'));
  await assertFails(operation('linked-partial', {budgetItemId: null}));
  await assertFails(operation('linked-wrong-category', {categoryId: 'other'}));
  await assertFails(operation('linked-wrong-type', {type: 'income'}));
  await assertFails(operation('linked-wrong-currency', {currency: 'MXN'}));

  const legacyItem = user.collection('budgets').doc(budget.id).collection('items').doc('legacy-item');
  await assertSucceeds(legacyItem.set({
    description: 'Elemento heredado', amountMinor: 5000, dayOfMonth: 15,
    actualAmountMinor: 0, createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  await assertSucceeds(operation('linked-legacy-item', {budgetItemId: legacyItem.id}));

  await item.update({status: 'archived', archivedAt: Timestamp.now(), updatedAt: Timestamp.now()});
  await assertSucceeds(operation('linked-archived-item'));
  await budget.update({status: 'archived', updatedAt: Timestamp.now()});
  await assertSucceeds(operation('linked-archived-budget', {budgetItemId: legacyItem.id}));
});
