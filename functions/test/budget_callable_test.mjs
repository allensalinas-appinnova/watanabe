import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {app, db} from './projection_test_support.mjs';

after(() => deleteApp(app));
const endpoint = 'http://127.0.0.1:59192/demo-clearbudget/us-central1/mutateBudget';
const command = {action: 'create', requestId: 'callable-create', categoryId: 'food',
  flowType: 'expense', monthKey: '2026-10', currency: 'COP',
  items: [{description: 'Synthetic budget', amountMinor: 250, dayOfMonth: 1}]};
async function invoke(data, token) {
  const response = await fetch(endpoint, {
    method: 'POST', headers: {'Content-Type': 'application/json', ...(token ? {Authorization: `Bearer ${token}`} : {})},
    body: JSON.stringify({data}), signal: AbortSignal.timeout(10000),
  });
  return {status: response.status, body: await response.json()};
}

test('real callable authenticates emulator tokens, scopes data and replays safely', {timeout: 60000}, async () => {
  assert.equal((await invoke(command)).body.error.status, 'UNAUTHENTICATED');
  const response = await fetch('http://127.0.0.1:59199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({email: `budget-callable-${Date.now()}@example.test`, password: 'Synthetic-Password-123', returnSecureToken: true}),
  });
  assert.equal(response.status, 200);
  const {idToken, localId} = await response.json();
  const user = db.doc(`users/${localId}`);
  await user.set({onboardingStatus: 'complete'});
  await user.collection('categories').doc('food').set({type: 'expense', isArchived: false});
  const first = await invoke(command, idToken);
  assert.equal(first.status, 200);
  assert.equal(first.body.result.budget.plannedAmountMinor, 250);
  assert.equal(first.body.result.budget.itemCount, 1);
  const replay = await invoke(command, idToken);
  assert.deepEqual(replay.body, first.body);
  assert.equal((await user.collection('budgetCommands').get()).size, 1);
  assert.equal((await user.collection('budgets').doc(first.body.result.budget.id).collection('items').get()).size, 1);
  assert.equal((await invoke({...command, userId: 'other'}, idToken)).body.error.status, 'INVALID_ARGUMENT');
});
