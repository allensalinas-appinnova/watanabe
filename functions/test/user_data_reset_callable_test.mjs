import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {app, db} from './projection_test_support.mjs';

after(() => deleteApp(app));
assert.equal(process.env.GCLOUD_PROJECT, 'demo-clearbudget');
const endpoint = 'http://127.0.0.1:59192/demo-clearbudget/us-central1/resetUserData';
async function invoke(data, token) {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {'Content-Type': 'application/json', ...(token ? {Authorization: `Bearer ${token}`} : {})},
    body: JSON.stringify({data}), signal: AbortSignal.timeout(30000),
  });
  return {status: response.status, body: await response.json()};
}

test('reset callable authenticates, preserves Auth account, recursively deletes and replays safely', {timeout: 90000}, async () => {
  const unauthenticated = await invoke({requestId: 'callable-reset-1', expectedGeneration: 0, confirmed: true});
  assert.equal(unauthenticated.body.error.status, 'UNAUTHENTICATED');
  const signup = await fetch('http://127.0.0.1:59199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({returnSecureToken: true}),
  });
  assert.equal(signup.status, 200);
  const {idToken, localId} = await signup.json();
  const root = db.doc(`users/${localId}`);
  await root.set({onboardingStatus: 'complete', dataGeneration: 0});
  await root.collection('accounts').doc('bank').collection('nested').doc('row').set({private: true});
  await db.doc('categoryCatalog/global').set({isActive: true});
  const command = {requestId: 'callable-reset-1', expectedGeneration: 0, confirmed: true};
  const result = await invoke(command, idToken);
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal(result.body.result.status, 'complete');
  assert.equal(result.body.result.dataGeneration, 1);
  assert.equal((await root.collection('accounts').get()).size, 0);
  assert.equal((await root.get()).data().onboardingStatus, 'not_started');
  assert.equal((await db.doc('categoryCatalog/global').get()).exists, true);
  const replay = await invoke(command, idToken);
  assert.deepEqual(replay.body, result.body);
  const lookup = await fetch('http://127.0.0.1:59199/identitytoolkit.googleapis.com/v1/accounts:lookup?key=fake-key', {
    method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({idToken}),
  });
  assert.equal(lookup.status, 200);
  assert.equal((await lookup.json()).users[0].localId, localId);
});
