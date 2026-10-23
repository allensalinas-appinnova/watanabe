import assert from 'node:assert/strict';
import test from 'node:test';

assert.equal(process.env.GCLOUD_PROJECT, 'demo-clearbudget');
assert.match(process.env.FIRESTORE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):59180$/);
const base = 'http://127.0.0.1:59192/demo-clearbudget/us-central1/';
async function invoke(name, data, token) {
  const response = await fetch(base + name, {
    method: 'POST', headers: {'Content-Type': 'application/json',
      ...(token ? {Authorization: `Bearer ${token}`} : {})},
    body: JSON.stringify({data}), signal: AbortSignal.timeout(30000),
  });
  return {status: response.status, body: await response.json()};
}

test('real callable wrappers require authentication and deny users not enrolled in the pilot', {timeout: 90000}, async () => {
  const signup = await fetch('http://127.0.0.1:59199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({returnSecureToken: true}), signal: AbortSignal.timeout(10000),
  });
  assert.equal(signup.status, 200);
  const {idToken} = await signup.json();
  for (const name of ['mutateEmailImport', 'listEmailImports']) {
    const unauthenticated = await invoke(name, {});
    assert.equal(unauthenticated.body.error.status, 'UNAUTHENTICATED');
    const unauthorized = await invoke(name, {uid: 'forged-owner', privateContent: 'DO_NOT_ECHO'}, idToken);
    assert.equal(unauthorized.body.error.status, 'PERMISSION_DENIED');
    assert.equal(unauthorized.body.error.details.issue, 'import-pilot-disabled');
    assert.equal(JSON.stringify(unauthorized.body).includes('DO_NOT_ECHO'), false);
  }
});
