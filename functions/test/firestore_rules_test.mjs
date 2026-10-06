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
