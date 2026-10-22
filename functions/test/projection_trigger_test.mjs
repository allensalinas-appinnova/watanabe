import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {setTimeout as delay} from 'node:timers/promises';
import {deleteApp} from 'firebase-admin/app';
import {app, operation, seedUser} from './projection_test_support.mjs';

after(() => deleteApp(app));
async function waitFor(check) {
  const deadline = Date.now() + 30000;
  while (Date.now() < deadline) {
    if (await check()) return;
    await delay(200);
  }
  assert.fail('processOperation did not produce the expected projections within 30 seconds');
}

test('real Firestore write triggers Functions, updates all projections, then reverses rejection', {timeout: 90000}, async () => {
  const root = await seedUser('trigger-user');
  const ref = root.collection('operations').doc('linked');
  const account = root.collection('accounts').doc('cash');
  const item = root.collection('budgets').doc('budget').collection('items').doc('item');
  const summary = root.collection('monthlySummaries').doc('2026-10_COP');
  await ref.set(operation({budgetId: 'budget', budgetItemId: 'item'}));
  await waitFor(async () => {
    const [a, i, s] = await Promise.all([account.get(), item.get(), summary.get()]);
    return a.data()?.currentBalanceMinor === 3800 && i.data()?.actualAmountMinor === 1200 &&
      s.data()?.expenseMinor === 1200 && s.data()?.monthKey === '2026-10' && s.data()?.currency === 'COP';
  });
  assert.equal((await root.collection('processedOperations').get()).size, 1);
  await ref.update({status: 'rejected'});
  await waitFor(async () => {
    const [a, i, s] = await Promise.all([account.get(), item.get(), summary.get()]);
    return a.data()?.currentBalanceMinor === 5000 && i.data()?.actualAmountMinor === 0 && s.data()?.expenseMinor === 0;
  });
  assert.equal((await root.collection('processedOperations').get()).size, 2);
});
