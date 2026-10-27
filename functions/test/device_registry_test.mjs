import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {app, db} from './projection_test_support.mjs';
import {executeDeviceRegistryCommand} from '../lib/device_registry.js';

after(() => deleteApp(app));
const installationId = '123e4567-e89b-42d3-a456-426614174000';

test('registration is idempotent and enforces the 24-hour activity refresh', async () => {
  const uid = `device_unit_${Date.now()}`;
  const now = new Date();
  await executeDeviceRegistryCommand(db, uid, {action: 'register', installationId, platform: 'ios'}, now);
  const ref = db.doc(`users/${uid}/devices/${installationId}`);
  const first = (await ref.get()).data();
  assert.equal(first.platform, 'ios');
  assert.equal(first.installationId, installationId);
  assert.equal(first.expiresAt.toMillis(), now.getTime() + 90 * 86400000);
  await executeDeviceRegistryCommand(db, uid, {action: 'register', installationId, platform: 'ios'}, new Date(now.getTime() + 2 * 3600000));
  assert.equal((await ref.get()).data().expiresAt.toMillis(), first.expiresAt.toMillis());
  await executeDeviceRegistryCommand(db, uid, {action: 'register', installationId, platform: 'android'}, new Date(now.getTime() + 25 * 3600000));
  const updated = (await ref.get()).data();
  assert.equal(updated.platform, 'android');
  assert.equal(updated.expiresAt.toMillis(), now.getTime() + 25 * 3600000 + 90 * 86400000);
  assert.equal(updated.createdAt.toMillis(), first.createdAt.toMillis());
  await executeDeviceRegistryCommand(db, uid, {action: 'remove', installationId});
  await executeDeviceRegistryCommand(db, uid, {action: 'remove', installationId});
  assert.equal((await ref.get()).exists, false);
});

test('registry validates authentication, action, installation id and platform', async () => {
  await assert.rejects(executeDeviceRegistryCommand(db, undefined, {action: 'register'}), {issue: 'authentication-required'});
  await assert.rejects(executeDeviceRegistryCommand(db, 'alice', {action: 'register', installationId: 'not-a-uuid', platform: 'ios'}), {issue: 'invalid-installation-id'});
  await assert.rejects(executeDeviceRegistryCommand(db, 'alice', {action: 'register', installationId, platform: 'macOS'}), {issue: 'invalid-platform'});
  await assert.rejects(executeDeviceRegistryCommand(db, 'alice', {action: 'update', installationId}), {issue: 'invalid-action'});
});

test('callable requires auth, rejects anonymous sessions and scopes data to authenticated uid', {timeout: 90000}, async () => {
  const endpoint = 'http://127.0.0.1:59192/demo-clearbudget/us-central1/manageDevice';
  const invoke = async (data, token) => {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {'Content-Type': 'application/json', ...(token ? {Authorization: `Bearer ${token}`} : {})},
      body: JSON.stringify({data}),
      signal: AbortSignal.timeout(30000),
    });
    return {status: response.status, body: await response.json()};
  };
  const denied = await invoke({action: 'register', installationId, platform: 'ios'});
  assert.equal(denied.body.error.status, 'UNAUTHENTICATED');

  const authUrl = 'http://127.0.0.1:59199/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key';
  const anonymous = await fetch(authUrl, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({returnSecureToken: true})});
  const anonymousToken = (await anonymous.json()).idToken;
  const guestResult = await invoke({action: 'register', installationId, platform: 'ios'}, anonymousToken);
  assert.equal(guestResult.body.error.status, 'PERMISSION_DENIED');

  const registered = await fetch(authUrl, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({email: `device-${Date.now()}@example.test`, password: 'test-pass-123', returnSecureToken: true})});
  const {idToken, localId} = await registered.json();
  const result = await invoke({action: 'register', installationId, platform: 'ios', uid: 'attacker-selected-uid'}, idToken);
  assert.equal(result.status, 200, JSON.stringify(result.body));
  assert.equal((await db.doc(`users/${localId}/devices/${installationId}`).get()).exists, true);
  assert.equal((await db.doc(`users/attacker-selected-uid/devices/${installationId}`).get()).exists, false);
  const secondInstall = '123e4567-e89b-42d3-b456-426614174001';
  await invoke({action: 'register', installationId: secondInstall, platform: 'web'}, idToken);
  assert.equal((await db.collection(`users/${localId}/devices`).get()).size, 2);
  await invoke({action: 'remove', installationId}, idToken);
  assert.equal((await db.doc(`users/${localId}/devices/${installationId}`).get()).exists, false);
  await db.recursiveDelete(db.doc(`users/${localId}`));
});
