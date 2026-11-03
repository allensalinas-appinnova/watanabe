import assert from 'node:assert/strict';
import test, {after} from 'node:test';
import {randomUUID} from 'node:crypto';
import {deleteApp} from 'firebase-admin/app';
import {acceptAccountDeletion as acceptDeletion, completeAccountDeletion} from '../lib/account_deletion.js';
import {recordUsage} from '../lib/resource_usage.js';
import {trackDocumentObject} from '../lib/document_imports.js';
import {app, db} from './projection_test_support.mjs';

function acceptAccountDeletion(db,uid,token,p,now) {
 return acceptDeletion(db,uid,token,{expectedOwnerUid:uid,...p},now);
}

after(() => deleteApp(app));
const token = {auth_time: Math.floor(Date.now()/1000), firebase: {sign_in_provider:'password'}};
const request = {requestId: 'account-deletion-request', expectedGeneration: 1, confirmed:true};
const fakeAuth = () => ({updateUser: async () => ({}), revokeRefreshTokens: async () => {}, deleteUser: async () => {}});
async function seed() {
 const uid = `deletion-${randomUUID()}`;
 await db.doc(`users/${uid}`).set({dataGeneration:1,onboardingStatus:'complete'});
 await db.doc(`users/${uid}/accounts/bank`).set({currentBalanceMinor:5000});
 await db.doc(`users/${uid}/budgets/budget/items/item`).set({amountMinor:100});
 await db.doc(`resourceUsage/${uid}/events/event`).set({units:{calls:1}});
 return uid;
}

test('deletion requires authentication, confirmation, recent login and matching generation', async () => {
 const uid = await seed();
 await assert.rejects(acceptAccountDeletion(db,undefined,token,request), e => e.code==='unauthenticated');
 await assert.rejects(acceptAccountDeletion(db,uid,token,{...request,expectedOwnerUid:'different-session'}),e=>e.code==='permission-denied');
 await assert.rejects(acceptAccountDeletion(db,uid,token,{...request,uid}), e => e.code==='invalid-argument');
 await assert.rejects(acceptAccountDeletion(db,uid,{...token,auth_time:1},request), e => e.message==='requires-recent-login');
 await assert.rejects(acceptAccountDeletion(db,uid,token,{...request,expectedGeneration:0}), e => e.code==='failed-precondition');
 assert.equal((await db.doc(`users/${uid}/accounts/bank`).get()).get('currentBalanceMinor'),5000);
});

test('accepted deletion is idempotent, resumes a partial failure and isolates another UID', async () => {
 const uid = await seed(), other = await seed();
 const job=db.doc(`maintenanceJobs/deletion-${randomUUID()}`);
 await job.set({cursor:uid,status:'running',runId:'old',worker:'old'});
 const first = await acceptAccountDeletion(db,uid,token,request);
 assert.deepEqual(await acceptAccountDeletion(db,uid,token,request), first);
 await assert.rejects(acceptAccountDeletion(db,uid,token,{...request,requestId:'different-request'}),e=>e.code==='already-exists');
 let fail = true, fileDeletes = 0;
 const dependencies = {auth:fakeAuth(), deleteFiles:async()=>{fileDeletes++;}, afterStage:async stage=>{if(stage==='files' && fail){fail=false;throw Error('synthetic-interruption');}}};
 await assert.rejects(completeAccountDeletion(db,uid,dependencies),/synthetic-interruption/);
 assert.equal((await db.doc(`accountDeletions/${uid}`).get()).get('status'),'failed');
 await completeAccountDeletion(db,uid,dependencies);
 await completeAccountDeletion(db,uid,dependencies);
 assert.equal(fileDeletes,1);
 assert.equal((await job.get()).get('cursor'),null);
 assert.notEqual((await job.get()).get('runId'),'old');
 assert.equal((await db.doc(`users/${uid}`).get()).exists,false);
 assert.equal((await db.collection(`users/${uid}/budgets/budget/items`).get()).empty,true);
 assert.equal((await db.collection(`resourceUsage/${uid}/events`).get()).empty,true);
 assert.equal((await db.doc(`accountDeletions/${uid}`).get()).get('status'),'complete');
 assert.ok((await db.doc(`accountDeletions/${uid}`).get()).get('expiresAt'));
 assert.equal((await db.doc(`users/${other}/accounts/bank`).get()).get('currentBalanceMinor'),5000);
});

test('late usage and Storage events cannot recreate individual measurement after deletion', async () => {
 const uid=await seed(); await acceptAccountDeletion(db,uid,token,request);
 await completeAccountDeletion(db,uid,{auth:fakeAuth(),deleteFiles:async()=>{}});
 await recordUsage(db,uid,'late','functions',{calls:1});
 await trackDocumentObject(db,{name:`users/${uid}/documentImports/1/document-id/source`,generation:'1',size:'200'},false);
 assert.equal((await db.doc(`resourceUsage/${uid}`).get()).exists,false);
 assert.equal((await db.collection(`resourceUsage/${uid}/objects`).get()).empty,true);
});

test('missing Auth identity is successful on retry; arbitrary Auth errors are not hidden',async()=>{
 const uid=await seed();await acceptAccountDeletion(db,uid,token,request);
 const missing=async()=>{throw Object.assign(Error('gone'),{code:'auth/user-not-found'});};
 await completeAccountDeletion(db,uid,{auth:{updateUser:missing,revokeRefreshTokens:missing,deleteUser:missing},deleteFiles:async()=>{}});
 assert.equal((await db.doc(`accountDeletions/${uid}`).get()).get('status'),'complete');
});

test('Auth Emulator identity is actually deleted while another account remains accessible',async()=>{
 assert.match(process.env.FIREBASE_AUTH_EMULATOR_HOST??'',/^(127\.0\.0\.1|localhost):59199$/);
 const {getAuth}=await import('firebase-admin/auth');const auth=getAuth(app);
 assert.match(process.env.FIREBASE_STORAGE_EMULATOR_HOST??'',/^(127\.0\.0\.1|localhost):59191$/);
 const {getStorage}=await import('firebase-admin/storage');
 const bucketName='demo-clearbudget.appspot.com', bucket=getStorage(app).bucket(bucketName);
 const identity=await auth.createUser({email:`delete-${randomUUID()}@example.test`,password:'Synthetic-test-only-123'});
 const other=await auth.createUser({email:`keep-${randomUUID()}@example.test`,password:'Synthetic-test-only-123'});
 await db.doc(`users/${identity.uid}`).set({dataGeneration:1,onboardingStatus:'complete'});
 await db.doc(`users/${identity.uid}/accounts/bank`).set({currentBalanceMinor:100});
 const source=bucket.file(`users/${identity.uid}/documentImports/1/fixture/source`);
 const preserved=bucket.file(`users/${other.uid}/attachments/fixture`);
 await source.save(Buffer.from('synthetic receipt'));await preserved.save(Buffer.from('other synthetic receipt'));
 await acceptAccountDeletion(db,identity.uid,token,request);
 await completeAccountDeletion(db,identity.uid,{auth,bucketName});
 assert.equal((await source.exists())[0],false);assert.equal((await preserved.exists())[0],true);
 await preserved.delete();
 await assert.rejects(auth.getUser(identity.uid),e=>e.code==='auth/user-not-found');
 assert.equal((await auth.getUser(other.uid)).disabled,false);
 assert.equal((await db.doc(`users/${identity.uid}`).get()).exists,false);
 await auth.deleteUser(other.uid);
});
