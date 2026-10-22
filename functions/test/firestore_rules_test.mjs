import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test, {after, before, beforeEach} from 'node:test';
import {assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {Timestamp, deleteField} from 'firebase/firestore';

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

test('home preferences are owner-updatable, typed, bounded, and cannot add profile fields', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const bob = environment.authenticatedContext('bob').firestore();
  const profile = alice.collection('users').doc('alice');
  await assertSucceeds(profile.set(userProfile()));
  const validPreferences = {
    widgets: {
      totalBalance: false,
      incomeSummary: true,
      expenseSummary: true,
      expenseBudgetRatio: true,
      incomeBudgetRatio: true,
      recentActivity: false,
    },
    hiddenBudgetCategoryIds: ['food', 'transport'],
  };
  await assertSucceeds(profile.update({homePreferences: validPreferences}));
  await assertSucceeds(profile.update({homePreferences: deleteField()}));
  await assertFails(profile.update({homePreferences: {...validPreferences, admin: true}}));
  await assertFails(profile.update({homePreferences: {...validPreferences, widgets: {
    ...validPreferences.widgets, unknown: true,
  }}}));
  await assertFails(profile.update({homePreferences: {...validPreferences, widgets: {
    ...validPreferences.widgets, totalBalance: 'false',
  }}}));
  await assertFails(profile.update({homePreferences: {
    ...validPreferences, hiddenBudgetCategoryIds: Array(101).fill('category'),
  }}));
  await assertFails(profile.update({unauthorizedProfileField: true}));
  await assertFails(bob.doc('users/alice').update({homePreferences: validPreferences}));
});

test('category colors accept valid ARGB values and reject malformed values without widening access', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const bob = environment.authenticatedContext('bob').firestore();
  const category = alice.collection('users').doc('alice').collection('categories').doc('food');
  await assertSucceeds(alice.collection('users').doc('alice').set(userProfile()));
  await assertSucceeds(category.set({
    type: 'expense', name: 'Food', icon: 'food', colorValue: 0xFF1C61D1,
    sortOrder: 1, isSystem: false, isArchived: false,
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  await assertSucceeds(category.update({colorValue: 0xFF147D55}));
  await assertSucceeds(category.update({colorValue: deleteField()}));
  await assertFails(category.update({colorValue: 'blue'}));
  await assertFails(category.update({colorValue: -1}));
  await assertFails(category.update({colorValue: 4294967296}));
  const bobCategory = bob.collection('users').doc('alice').collection('categories').doc('food');
  await assertFails(bobCategory.update({colorValue: 0xFFB54708}));
});

test('clients cannot write calculated balances or monthly summaries', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const bob = environment.authenticatedContext('bob').firestore();
  const account = alice.collection('users').doc('alice').collection('accounts').doc('cash');
  await assertSucceeds(alice.collection('users').doc('alice').set(userProfile()));
  await assertSucceeds(account.set({
    name: 'Cash', type: 'cash', currency: 'COP', openingBalanceMinor: 0,
    currentBalanceMinor: 0, includeInDashboard: true, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
  await assertSucceeds(account.update({includeInDashboard: false}));
  await assertSucceeds(account.update({includeInDashboard: true}));
  await assertFails(account.update({includeInDashboard: 'false'}));
  await assertFails(bob.collection('users').doc('alice').collection('accounts').doc('cash')
    .update({includeInDashboard: false}));
  await assertFails(account.update({currentBalanceMinor: 100}));
  await assertFails(
    alice.collection('users').doc('alice').collection('monthlySummaries').doc('2026-10_COP')
      .set({monthKey: '2026-10', currency: 'COP'}),
  );
  const event = alice.collection('users').doc('alice').collection('balanceAdjustments').doc('request-12345678');
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc('users/alice/balanceAdjustments/request-12345678').set({
      adjustedAt: Timestamp.now(), adjustments: [], digest: 'private',
    });
  });
  await assertSucceeds(event.get());
  await assertFails(event.set({adjustments: []}));
  await assertFails(event.update({adjustments: []}));
  await assertFails(event.delete());
  await assertFails(bob.collection('users').doc('alice').collection('balanceAdjustments').doc('request-12345678').get());
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

  await assertFails(user.collection('budgets').doc('max-budget').set({
    categoryId: 'food', flowType: 'expense', monthKey: '2026-10', currency: 'COP',
    plannedAmountMinor: 1000000000, itemCount: 1, status: 'active',
    createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
  }));
});

test('budgets and items are owner-readable but all direct writes are denied', async () => {
  const alice = environment.authenticatedContext('alice').firestore();
  const bob = environment.authenticatedContext('bob').firestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const budget = context.firestore().doc('users/alice/budgets/budget');
    await budget.set({categoryId: 'food', flowType: 'expense', monthKey: '2026-10', currency: 'COP',
      plannedAmountMinor: 1000, itemCount: 1, status: 'active'});
    await budget.collection('items').doc('item').set({description: 'Item', amountMinor: 1000, dayOfMonth: 1, actualAmountMinor: 0});
  });
  const budget = alice.doc('users/alice/budgets/budget');
  const item = budget.collection('items').doc('item');
  await assertSucceeds(budget.get());
  await assertSucceeds(alice.collection('users/alice/budgets').where('monthKey', '==', '2026-10').get());
  await assertSucceeds(budget.collection('items').orderBy('dayOfMonth').get());
  await assertFails(bob.doc('users/alice/budgets/budget').get());
  await assertFails(bob.doc('users/alice/budgets/budget/items/item').get());
  await assertFails(environment.unauthenticatedContext().firestore().collection('users/alice/budgets').get());
  await assertFails(budget.update({plannedAmountMinor: 1001}));
  await assertFails(budget.update({status: 'archived'}));
  await assertFails(budget.delete());
  await assertFails(item.update({amountMinor: 1001}));
  await assertFails(item.update({description: 'x'.repeat(1000000)}));
  await assertFails(item.update({actualAmountMinor: 100}));
  await assertFails(item.delete());
  await assertFails(budget.collection('items').doc('new').set({description: 'Valid', amountMinor: 1, dayOfMonth: 1}));
  const batch = alice.batch();
  batch.update(budget, {plannedAmountMinor: 2000, itemCount: 2});
  batch.set(budget.collection('items').doc('batch-item'), {description: 'Valid', amountMinor: 1000, dayOfMonth: 1});
  await assertFails(batch.commit());
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
  await environment.withSecurityRulesDisabled(async (context) => {
    const adminBudget = context.firestore().doc(budget.path);
    await adminBudget.set({categoryId: 'food', flowType: 'expense', monthKey: '2026-10',
      currency: 'COP', plannedAmountMinor: 10000, itemCount: 1, status: 'active'});
    await adminBudget.collection('items').doc(item.id).set({description: 'Comida',
      amountMinor: 10000, dayOfMonth: 20, actualAmountMinor: 0, status: 'active'});
  });

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
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(legacyItem.path).set({
      description: 'Elemento heredado', amountMinor: 5000, dayOfMonth: 15, actualAmountMinor: 0,
    });
  });
  await assertSucceeds(operation('linked-legacy-item', {budgetItemId: legacyItem.id}));

  await environment.withSecurityRulesDisabled(async (context) => context.firestore().doc(item.path).update({status: 'archived'}));
  await assertSucceeds(operation('linked-archived-item'));
  await environment.withSecurityRulesDisabled(async (context) => context.firestore().doc(budget.path).update({status: 'archived'}));
  await assertSucceeds(operation('linked-archived-budget', {budgetItemId: legacyItem.id}));
});

test('command receipts cannot be read or changed by any client', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc('users/alice/budgetCommands/request-1').set({digest: 'server-only', result: {}});
  });
  for (const context of [environment.authenticatedContext('alice'), environment.authenticatedContext('bob'), environment.unauthenticatedContext()]) {
    const receipt = context.firestore().doc('users/alice/budgetCommands/request-1');
    await assertFails(receipt.get());
    await assertFails(receipt.set({digest: 'forged', result: {}}));
    await assertFails(receipt.update({digest: 'forged'}));
    await assertFails(receipt.delete());
  }
});
