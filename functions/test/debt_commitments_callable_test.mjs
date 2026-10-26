import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {app, db} from './projection_test_support.mjs';

after(() => deleteApp(app));
const endpoint = 'http://127.0.0.1:59192/demo-clearbudget/us-central1/mutateDebtCommitment';
async function invoke(data, token) {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {'Content-Type': 'application/json', ...(token ? {Authorization: `Bearer ${token}`} : {})},
    body: JSON.stringify({data}),
    signal: AbortSignal.timeout(10000),
  });
  return {status: response.status, body: await response.json()};
}

async function createUser() {
  const response = await fetch('http://127.0.0.1:59199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({email: `debt-plan-${Date.now()}@example.test`, password: 'Synthetic-Password-123', returnSecureToken: true}),
  });
  assert.equal(response.status, 200);
  const auth = await response.json();
  const root = db.doc(`users/${auth.localId}`);
  await root.set({onboardingStatus: 'complete', dataGeneration: 0});
  await root.collection('accounts').doc('loan').set({nature: 'debt', type: 'loan', currency: 'COP', status: 'active'});
  await root.collection('accounts').doc('bank').set({nature: 'money', currency: 'COP', status: 'active'});
  return {token: auth.idToken, root};
}

test('commitment callable authenticates, scopes to UID, versions plans, skips occurrences and links one payment idempotently', {timeout: 60000}, async () => {
  const unauthenticated = await invoke({requestId: 'plan-create-unauth', expectedGeneration: 0, action: 'create'});
  assert.equal(unauthenticated.body.error.status, 'UNAUTHENTICATED');

  const {token, root} = await createUser();
  const create = {
    requestId: 'plan-create-0001', expectedGeneration: 0, action: 'create',
    debtAccountId: 'loan', currency: 'COP', amountMinor: 240000000,
    firstDueMonth: '2026-10', dueDay: 31, lastDueMonth: null,
    bankAccountId: 'bank', remindersEnabled: false,
  };
  const created = await invoke(create, token);
  assert.equal(created.status, 200);
  const commitmentId = created.body.result.commitmentId;
  const commitment = root.collection('debtCommitments').doc(commitmentId);
  assert.equal((await commitment.get()).data().amountMinor, 240000000);
  assert.equal((await commitment.collection('versions').doc('1').get()).exists, true);
  assert.deepEqual((await invoke(create, token)).body, created.body);
  assert.equal((await invoke({...create, amountMinor: 1}, token)).body.error.status, 'ALREADY_EXISTS');

  const edit = {requestId: 'plan-edit-00001', expectedGeneration: 0, action: 'edit', commitmentId,
    effectiveFromMonth: '2026-11', amountMinor: 250000000, dueDay: 30};
  assert.equal((await invoke(edit, token)).status, 200);
  assert.equal((await commitment.get()).data().amountMinor, 250000000);
  assert.equal((await commitment.collection('versions').doc('2').get()).data().amountMinor, 250000000);

  const skip = {requestId: 'plan-skip-00001', expectedGeneration: 0, action: 'skip', commitmentId,
    monthKey: '2026-11', skipped: true};
  assert.equal((await invoke(skip, token)).status, 200);
  assert.equal((await commitment.collection('occurrences').doc(`${commitmentId}_2026-11`).get()).data().skipped, true);

  await root.collection('debtPayments').doc('payment-1').set({debtAccountId: 'loan', amountMinor: 100000, currency: 'COP', status: 'unallocated'});
  const link = {requestId: 'plan-link-00001', expectedGeneration: 0, action: 'linkPayment', commitmentId,
    paymentId: 'payment-1', monthKey: '2026-12'};
  assert.equal((await invoke(link, token)).status, 200);
  assert.equal((await root.collection('debtPaymentLinks').doc('payment-1').get()).data().commitmentId, commitmentId);
  assert.equal((await invoke(link, token)).status, 200);
  const collision = await invoke({...link, requestId: 'plan-link-00002', monthKey: '2026-12'}, token);
  assert.equal(collision.body.error.status, 'ALREADY_EXISTS');
  const skipLinked = await invoke({requestId: 'plan-skip-00002', expectedGeneration: 0,
    action: 'skip', commitmentId, monthKey: '2026-12', skipped: true}, token);
  assert.equal(skipLinked.body.error.status, 'FAILED_PRECONDITION');
  const pause = {requestId: 'plan-pause-0001', expectedGeneration: 0, action: 'pause', commitmentId,
    fromMonth: '2026-12', paused: true};
  assert.equal((await invoke(pause, token)).status, 200);
  assert.equal((await commitment.get()).data().pausedFromMonth, '2026-12');
  assert.equal((await db.doc('users/attacker/debtCommitments/forged').get()).exists, false);
});
