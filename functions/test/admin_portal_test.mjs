import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {app, db} from './projection_test_support.mjs';
import {bootstrapAdminOperator, requireAdminOperator} from '../lib/admin_portal.js';

after(() => deleteApp(app));

const googleAuth = (uid, email, overrides = {}) => ({
  uid,
  token: {
    email,
    email_verified: true,
    firebase: {sign_in_provider: 'google.com'},
    ...overrides,
  },
});

test('bootstrap grants only the configured, verified Google identity and is idempotent', async () => {
  const uid = `admin_${Date.now()}`;
  const owner = googleAuth(uid, 'owner@example.test');
  assert.deepEqual(await bootstrapAdminOperator(db, owner, 'OWNER@example.test'), {role: 'owner'});
  assert.deepEqual(await bootstrapAdminOperator(db, owner, 'owner@example.test'), {role: 'owner'});
  assert.deepEqual(await requireAdminOperator(db, owner), {
    uid, email: 'owner@example.test', role: 'owner', status: 'active',
  });
  await assert.rejects(bootstrapAdminOperator(db, googleAuth('other', 'other@example.test'), 'owner@example.test'), {issue: 'not-an-authorized-operator'});
  await assert.rejects(bootstrapAdminOperator(db, googleAuth('unverified', 'owner@example.test', {email_verified: false}), 'owner@example.test'), {issue: 'verified-google-account-required'});
  await assert.rejects(bootstrapAdminOperator(db, {uid: 'password', token: {email: 'owner@example.test', email_verified: true, firebase: {sign_in_provider: 'password'}}}, 'owner@example.test'), {issue: 'verified-google-account-required'});
  await db.doc(`adminOperators/${uid}`).delete();
});

test('portal authorization requires a server-provisioned active operator document', async () => {
  const auth = googleAuth(`not_admin_${Date.now()}`, 'owner@example.test');
  await assert.rejects(requireAdminOperator(db, auth), {issue: 'admin-access-required'});
  await assert.rejects(requireAdminOperator(db, undefined), {issue: 'authentication-required'});
});

test('admin callables reject missing and ordinary password authentication before serving data', {timeout: 90000}, async () => {
  const endpoint = 'http://127.0.0.1:59192/demo-clearbudget/us-central1/bootstrapAdmin';
  const invoke = async (token) => {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {'Content-Type': 'application/json', ...(token ? {Authorization: `Bearer ${token}`} : {})},
      body: JSON.stringify({data: {}}),
    });
    return {status: response.status, body: await response.json()};
  };
  const unauthenticated = await invoke(undefined);
  assert.equal(unauthenticated.body.error.status, 'UNAUTHENTICATED');
  const signedUp = await fetch('http://127.0.0.1:59199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key', {
    method: 'POST', headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({email: `ordinary-${Date.now()}@example.test`, password: 'test-pass-123', returnSecureToken: true}),
  });
  const {idToken} = await signedUp.json();
  const ordinaryUser = await invoke(idToken);
  assert.equal(ordinaryUser.body.error.status, 'PERMISSION_DENIED');
});
