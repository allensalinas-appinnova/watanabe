import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {executeBalanceAdjustment} from '../lib/balance_adjustments.js';
import {app, db, seedUser, userDump} from './projection_test_support.mjs';

after(() => deleteApp(app));
const invoke = (uid, requestId, adjustments, reason) => executeBalanceAdjustment(db, uid, {requestId, adjustments, reason});

test('authenticated adjustment atomically sets mixed-currency accounts and is idempotent', async () => {
  const root = await seedUser('balance-adjustment-idempotency');
  const command = [{accountId: 'bank', currency: 'COP', targetBalanceMinor: -500}, {accountId: 'mxn', currency: 'MXN', targetBalanceMinor: 0}];
  const first = await invoke(root.id, 'balance-adjustment-1', command, 'Reconciliación');
  assert.deepEqual(first.adjustments.map(({deltaMinor}) => deltaMinor), [-10500, -2000]);
  assert.equal((await root.collection('accounts').doc('bank').get()).data().currentBalanceMinor, -500);
  const replay = await invoke(root.id, 'balance-adjustment-1', command, 'Reconciliación');
  assert.deepEqual(replay.adjustments, first.adjustments);
  assert.equal((await root.collection('balanceAdjustments').get()).size, 1);
  await assert.rejects(invoke(root.id, 'balance-adjustment-1', [{...command[0], targetBalanceMinor: 9}], 'other'), {issue: 'balance-adjustment-request-conflict'});
});

test('rejects unauthenticated, inactive, incompatible and out-of-range commands without partial writes', async () => {
  const root = await seedUser('balance-adjustment-validation');
  await assert.rejects(invoke(undefined, 'balance-adjustment-2', [{accountId: 'bank', currency: 'COP', targetBalanceMinor: 0}]), {status: 'unauthenticated'});
  for (const rows of [
    [{accountId: 'cash', currency: 'COP', targetBalanceMinor: 0}],
    [{accountId: 'bank', currency: 'MXN', targetBalanceMinor: 0}],
    [{accountId: 'bank', currency: 'COP', targetBalanceMinor: 1_000_000_001}],
    [{accountId: 'bank', currency: 'COP', targetBalanceMinor: 0}, {accountId: 'missing', currency: 'COP', targetBalanceMinor: 0}],
  ]) {
    const before = await userDump(root);
    await assert.rejects(invoke(root.id, `balance-adjustment-${Math.random()}`, rows));
    assert.deepEqual(await userDump(root), before);
  }
});

test('same concurrent request commits one adjustment; colliding operation transactions compose', async () => {
  const root = await seedUser('balance-adjustment-concurrency');
  const rows = [{accountId: 'bank', currency: 'COP', targetBalanceMinor: 7000}];
  const results = await Promise.all(Array.from({length: 4}, () => invoke(root.id, 'balance-adjustment-3', rows)));
  assert(results.every((result) => result.adjustments[0].deltaMinor === -3000));
  assert.equal((await root.collection('balanceAdjustments').get()).size, 1);
  assert.equal((await root.collection('accounts').doc('bank').get()).data().currentBalanceMinor, 7000);
});
