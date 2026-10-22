import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {app, db} from './projection_test_support.mjs';

after(() => deleteApp(app));
const endpoint = 'http://127.0.0.1:59192/demo-clearbudget/us-central1/adjustAccountBalances';
async function invoke(data, token) {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {'Content-Type': 'application/json', ...(token ? {Authorization: `Bearer ${token}`} : {})},
    body: JSON.stringify({data}),
    signal: AbortSignal.timeout(10000),
  });
  return {status: response.status, body: await response.json()};
}

test('callable requires Auth, scopes mutations to auth UID and rejects reused IDs with changed contents', {timeout: 60000}, async () => {
  const unauthenticated = await invoke({requestId: 'balance-call-1', adjustments: []});
  assert.equal(unauthenticated.body.error.status, 'UNAUTHENTICATED');
  const response = await fetch('http://127.0.0.1:59199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({email: `balance-adjust-${Date.now()}@example.test`, password: 'Synthetic-Password-123', returnSecureToken: true}),
  });
  assert.equal(response.status, 200);
  const {idToken, localId} = await response.json();
  const user = db.doc(`users/${localId}`);
  await user.set({});
  await user.collection('accounts').doc('bank').set({currency: 'COP', currentBalanceMinor: 1200, status: 'active'});
  const command = {requestId: 'balance-call-1', adjustments: [{accountId: 'bank', currency: 'COP', targetBalanceMinor: 0}], userId: 'attacker'};
  const first = await invoke(command, idToken);
  assert.equal(first.status, 200);
  assert.equal(first.body.result.adjustments[0].previousBalanceMinor, 1200);
  assert.equal((await user.collection('accounts').doc('bank').get()).data().currentBalanceMinor, 0);
  assert.equal((await db.doc('users/attacker/accounts/bank').get()).exists, false);
  const replay = await invoke(command, idToken);
  assert.deepEqual(replay.body, first.body);
  const conflict = await invoke({...command, adjustments: [{accountId: 'bank', currency: 'COP', targetBalanceMinor: 100}]}, idToken);
  assert.equal(conflict.body.error.status, 'ALREADY_EXISTS');
});
