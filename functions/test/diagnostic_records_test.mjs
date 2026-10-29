import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {executeDiagnosticCommand, validateDiagnosticRecord} from '../lib/diagnostic_records.js';
import {executeUserDataReset} from '../lib/user_data_reset.js';
import {app, db, seedUser} from './projection_test_support.mjs';

after(() => deleteApp(app));
const runTag = `-${Date.now()}-${process.pid}`;
let serial = 0;
const command = (recordId, kind, values, overrides = {}) => ({requestId: `diagnostic-command-${++serial}`, expectedGeneration: 0, revision: 0, action: 'save', recordId, kind, values, ...overrides});

test('validation rejects invalid shapes, pollution, overflow, impossible dates and dual-purpose reserves', () => {
  for (const [kind, values] of [
    ['context', {dependents: -1}], ['context', {sharedExpensePercent: 101}],
    ['context', {verifiedOn: '2026-02-30'}], ['context', {extra: true}],
    ['context', {incomeStability: 'guaranteed'}], ['context', {completeMonths: '2026-13'}],
    ['account', {accountId: '../alice', excluded: 'yes'}],
    ['account', {accountId: 'cash', excluded: 'yes'}],
    ['goal', {name: 'x'.repeat(501)}], ['reserve', {name: 'Emergency', accountId: 'cash', currency: 'COP', amountMinor: 100, purpose: 'emergency', goalId: 'goal'}],
    ['reserve', {name: 'Goal', accountId: 'cash', currency: 'COP', amountMinor: 100, purpose: 'goal', goalId: 'goal', entryId: 'budget:b:i'}],
    ['debt', {accountId: 'cash', currency: 'COP', referenceDate: '2026-10-29', rateBps: 1.5}],
  ]) assert.throws(() => validateDiagnosticRecord(kind, values));
  assert.throws(() => validateDiagnosticRecord('__proto__', {}));
});

test('records are idempotent, generation scoped and never modify financial balances', async () => {
  const root = await seedUser('diagnostic-records' + runTag);
  const before = (await root.collection('accounts').doc('cash').get()).data();
  const payload = command('context', 'context', {dependents: 2, accountsComplete: 'yes'});
  const first = await executeDiagnosticCommand(db, root.id, payload);
  assert.deepEqual(await executeDiagnosticCommand(db, root.id, payload), first);
  await assert.rejects(executeDiagnosticCommand(db, root.id, {...payload, values: {dependents: 3}}), {code: 'already-exists'});
  await assert.rejects(executeDiagnosticCommand(db, undefined, payload), {code: 'unauthenticated'});
  await assert.rejects(executeDiagnosticCommand(db, root.id, command('context', 'context', {}, {expectedGeneration: 2})), {code: 'failed-precondition'});
  await assert.rejects(executeDiagnosticCommand(db, root.id, command('context', 'context', {dependents: 1})), {code: 'failed-precondition'});
  assert.deepEqual((await root.collection('accounts').doc('cash').get()).data(), before);
  assert.equal((await root.collection('operations').get()).size, 0);
});

test('reserve transactions enforce real owner accounts, currency, available balance and single purpose', async () => {
  const root = await seedUser('diagnostic-reserves' + runTag);
  const reserve = (name, amount) => command(name, 'reserve', {name, accountId: 'cash', currency: 'COP', amountMinor: amount, purpose: 'emergency'});
  await executeDiagnosticCommand(db, root.id, reserve('one', 3000));
  await assert.rejects(executeDiagnosticCommand(db, root.id, reserve('two', 3000)), {code: 'invalid-argument'});
  await assert.rejects(executeDiagnosticCommand(db, root.id, command('missing', 'reserve', {name: 'Missing', accountId: 'not-owned', currency: 'COP', amountMinor: 1, purpose: 'emergency'})), {code: 'invalid-argument'});
  await assert.rejects(executeDiagnosticCommand(db, root.id, command('wrong', 'reserve', {name: 'Wrong', accountId: 'cash', currency: 'USD', amountMinor: 1, purpose: 'emergency'})), {code: 'invalid-argument'});
  await executeDiagnosticCommand(db, root.id, command('goal', 'goal', {name: 'Trip', currency: 'COP', amountMinor: 10000, dueDate: '2027-12-01', kind: 'goal'}));
  await executeDiagnosticCommand(db, root.id, command('trip', 'reserve', {name: 'Trip', accountId: 'cash', currency: 'COP', amountMinor: 1000, purpose: 'goal', goalId: 'goal'}));
  await assert.rejects(executeDiagnosticCommand(db, root.id, command('goal', 'goal', {}, {action: 'delete', revision: 1})), {code: 'invalid-argument'});
  assert.equal((await root.collection('accounts').doc('cash').get()).data().currentBalanceMinor, 5000);
});

test('concurrent reserves cannot overallocate an account', async () => {
  const root = await seedUser('diagnostic-concurrent' + runTag);
  const results = await Promise.allSettled(['one', 'two'].map(id => executeDiagnosticCommand(db, root.id, command(id, 'reserve', {name: id, accountId: 'cash', currency: 'COP', amountMinor: 4000, purpose: 'emergency'}))));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal((await root.collection('diagnosticRecords').get()).size, 1);
});

test('asset valuation history is explicit and all supplemental facts are removed by reset', async () => {
  const root = await seedUser('diagnostic-reset' + runTag);
  const values = {name: 'Property', currency: 'COP', amountMinor: 100000, referenceDate: '2026-10-01', ownershipPercent: 50, availability: 'restricted', assetClass: 'property', obligation: 'no'};
  await executeDiagnosticCommand(db, root.id, command('asset', 'asset', values));
  await executeDiagnosticCommand(db, root.id, command('asset', 'asset', {...values, amountMinor: 110000, referenceDate: '2026-10-29'}, {revision: 1}));
  assert.equal((await root.collection('diagnosticRecords').doc('asset').collection('valuations').get()).size, 2);
  await executeUserDataReset(db, root.id, {requestId: 'diagnostic-reset-001', expectedGeneration: 0, confirmed: true});
  assert.equal((await root.collection('diagnosticRecords').get()).size, 0);
  assert.equal((await root.collection('diagnosticCommands').get()).size, 0);
  assert.equal((await root.collection('diagnosticRecords').doc('asset').collection('valuations').get()).size, 0);
});


test('goal resources have one purpose and deleting an asset removes its valuation history', async () => {
  const root = await seedUser('diagnostic-retirement' + runTag);
  await executeDiagnosticCommand(db, root.id, command('retirement', 'goal', {name: 'Retirement', kind: 'retirement', currency: 'COP', amountMinor: 100000, dueDate: '2046-10-29'}));
  const asset = {name: 'Fund', currency: 'COP', amountMinor: 50000, referenceDate: '2026-10-29', ownershipPercent: 100, availability: 'restricted', assetClass: 'fixedIncome', obligation: 'no', goalId: 'retirement'};
  await executeDiagnosticCommand(db, root.id, command('fund', 'asset', asset));
  await assert.rejects(executeDiagnosticCommand(db, root.id, command('retirement', 'goal', {name: 'Retirement', kind: 'retirement', currency: 'USD', amountMinor: 100000, dueDate: '2046-10-29'}, {revision: 1})), {code: 'invalid-argument'});
  await assert.rejects(executeDiagnosticCommand(db, root.id, command('double', 'asset', {...asset, accountId: 'cash'})), {code: 'invalid-argument'});
  await executeDiagnosticCommand(db, root.id, command('fund', 'asset', {}, {action: 'delete', revision: 1}));
  assert.equal((await root.collection('diagnosticRecords').doc('fund').collection('valuations').get()).size, 0);
});


test('payments consume only reserves created before them and free their backing for new reserves', async () => {
  const root = await seedUser('diagnostic-reserve-lifecycle' + runTag);
  const budget = root.collection('budgets').doc('budget');
  await budget.set({currency: 'COP', categoryId: 'food', monthKey: '2026-10', status: 'active'});
  await budget.collection('items').doc('item').set({amountMinor: 1000, actualAmountMinor: 100, status: 'active'});
  await executeDiagnosticCommand(db, root.id, command('reserved', 'reserve', {name: 'Payment', accountId: 'cash', currency: 'COP', amountMinor: 600, purpose: 'obligation', entryId: 'budget:budget:item'}));
  assert.equal((await root.collection('diagnosticRecords').doc('reserved').get()).data().paymentBaselineMinor, 100);
  await budget.collection('items').doc('item').update({actualAmountMinor: 300});
  await root.collection('accounts').doc('cash').update({currentBalanceMinor: 4800});
  await executeDiagnosticCommand(db, root.id, command('emergency', 'reserve', {name: 'Emergency', accountId: 'cash', currency: 'COP', amountMinor: 4400, purpose: 'emergency'}));
  assert.equal((await root.collection('diagnosticRecords').get()).size, 2);
});
