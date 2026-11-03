import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {randomUUID} from 'node:crypto';
import {setTimeout as delay} from 'node:timers/promises';
import {deleteApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {app, db} from './projection_test_support.mjs';
import {acceptAccountDeletion} from '../lib/account_deletion.js';

after(() => deleteApp(app));
test('accepting deletion actually starts the Firestore worker and deletes Auth', {timeout:60000}, async()=>{
  assert.match(process.env.FIREBASE_AUTH_EMULATOR_HOST??'',/^(127\.0\.0\.1|localhost):59199$/);
  const auth=getAuth(app);
  const user=await auth.createUser({email:`trigger-${randomUUID()}@example.test`,password:'Emulator-only-123'});
  await db.doc(`users/${user.uid}`).set({dataGeneration:0});
  await acceptAccountDeletion(db,user.uid,{auth_time:Math.floor(Date.now()/1000),firebase:{sign_in_provider:'password'}},
    {requestId:randomUUID(),expectedOwnerUid:user.uid,expectedGeneration:0,confirmed:true});
  const marker=db.doc(`accountDeletions/${user.uid}`), deadline=Date.now()+40000;
  while(Date.now()<deadline && (await marker.get()).get('status')!=='complete') await delay(200);
  const state=await marker.get();
  assert.equal(state.get('status'),'complete',`worker state=${state.get('status')} stage=${state.get('stage')} attempts=${state.get('attempts')}`);
  await assert.rejects(auth.getUser(user.uid),e=>e.code==='auth/user-not-found');
});

test('authenticated callable acceptance also delivers its background deletion event', {timeout:60000},async()=>{
  assert.match(process.env.FIREBASE_AUTH_EMULATOR_HOST??'',/^(127\.0\.0\.1|localhost):59199$/);
  const auth=getAuth(app), email=`callable-${randomUUID()}@example.test`, password='Emulator-only-123';
  const user=await auth.createUser({email,password});
  await db.doc(`users/${user.uid}`).set({dataGeneration:0});
  const signIn=await fetch('http://127.0.0.1:59199/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator-only',{
    method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password,returnSecureToken:true})});
  const credential=await signIn.json();assert.equal(typeof credential.idToken,'string');
  const response=await fetch('http://127.0.0.1:59192/demo-clearbudget/us-central1/requestAccountDeletion',{
    method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${credential.idToken}`},
    body:JSON.stringify({data:{requestId:randomUUID(),expectedOwnerUid:user.uid,expectedGeneration:0,confirmed:true}})});
  const result=await response.json();assert.equal(result.result?.status,'accepted');
  const marker=db.doc(`accountDeletions/${user.uid}`),deadline=Date.now()+40000;
  while(Date.now()<deadline && (await marker.get()).get('status')!=='complete') await delay(200);
  const state=await marker.get();
  assert.equal(state.get('status'),'complete',`worker state=${state.get('status')} stage=${state.get('stage')} attempts=${state.get('attempts')}`);
  await assert.rejects(auth.getUser(user.uid),e=>e.code==='auth/user-not-found');
});
