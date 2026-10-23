import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {app, db} from './projection_test_support.mjs';
after(() => deleteApp(app));
assert.equal(process.env.GCLOUD_PROJECT, 'demo-clearbudget');
const base = 'http://127.0.0.1:59192/demo-clearbudget/us-central1/mutateDebt';
async function invoke(data, token) {
  const response = await fetch(base, {method: 'POST', headers: {'Content-Type': 'application/json', ...(token ? {Authorization: `Bearer ${token}`} : {})}, body: JSON.stringify({data}), signal: AbortSignal.timeout(30000)});
  return {status: response.status, body: await response.json()};
}
test('callable requires Auth and applies a synthetic card purchase once end to end', {timeout: 90000}, async () => {
  assert.equal((await invoke({})).body.error.status, 'UNAUTHENTICATED');
  const signup = await fetch('http://127.0.0.1:59199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({returnSecureToken: true})});
  const {idToken, localId} = await signup.json();
  await db.doc(`users/${localId}`).set({timeZone: 'America/Bogota'});
  await db.doc(`users/${localId}/categories/food`).set({type: 'expense'});
  const created = await invoke({requestId: 'create_card_01', action: 'create', name: 'Synthetic', product: 'creditCard', currency: 'COP', mode: 'existing', debtMinor: 0, referenceAt: '2026-01-01T00:00:00Z'}, idToken);
  assert.equal(created.status, 200, JSON.stringify(created.body));
  const accountId = created.body.result.accountId;
  const purchase = {requestId: 'purchase_card01', action: 'purchase', accountId, occurredAt: '2026-01-02T12:00:00Z', amountMinor: 100, categoryId: 'food'};
  const results = await Promise.all([invoke(purchase, idToken), invoke(purchase, idToken)]);
  assert.deepEqual(results[0].body, results[1].body);
  assert.equal(results[0].status, 200);
  assert.equal((await db.doc(`users/${localId}/accounts/${accountId}`).get()).data().currentBalanceMinor, -100);
  assert.equal((await db.collection(`users/${localId}/operations`).get()).size, 1);
  const other = await invoke({...purchase, requestId: 'foreign_card01', accountId: 'other-user-card'}, idToken);
  assert.equal(other.body.error.details.issue, 'debt-account-not-found');
});
