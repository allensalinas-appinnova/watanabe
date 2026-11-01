import {readFileSync} from 'node:fs';
import test,{before,after} from 'node:test';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {Timestamp} from 'firebase/firestore';
let env;
before(async()=>{env=await initializeTestEnvironment({projectId:'demo-clearbudget',firestore:{host:'127.0.0.1',port:59180,
  rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')},storage:{host:'127.0.0.1',port:59191,
  rules:readFileSync(new URL('../../storage.rules',import.meta.url),'utf8')}});});
after(()=>env.cleanup());
const bytes=Buffer.from('synthetic-file');
test('source uploads require owner, registered session, current generation and server reservation',async()=>{
  const uid='document-rules-user',id='document-rules-001',path=`users/${uid}/documentImports/1/${id}/source`;
  await env.withSecurityRulesDisabled(async c=>{
    await c.firestore().doc(`users/${uid}`).set({dataGeneration:1,resetStatus:'ready'});
    await c.firestore().doc(`users/${uid}/documentImports/${id}`).set({dataGeneration:1,status:'prepared',size:bytes.length,
      contentType:'image/png',expiresAt:Timestamp.fromMillis(Date.now()+3600000)});
  });
  const owner=env.authenticatedContext(uid,{firebase:{sign_in_provider:'password'}});
  const other=env.authenticatedContext('other-document-user',{firebase:{sign_in_provider:'password'}});
  await assertFails(env.unauthenticatedContext().storage().ref(path).put(bytes,{contentType:'image/png'}));
  await assertFails(other.storage().ref(path).put(bytes,{contentType:'image/png'}));
  await assertFails(env.authenticatedContext(uid,{firebase:{sign_in_provider:'anonymous'}}).storage().ref(path).put(bytes,{contentType:'image/png'}));
  await assertFails(owner.storage().ref(path).put(bytes,{contentType:'application/pdf'}));
  await assertFails(owner.storage().ref(path).put(Buffer.from('wrong-size'),{contentType:'image/png'}));
  await assertSucceeds(owner.storage().ref(path).put(bytes,{contentType:'image/png'}));
  await assertFails(owner.storage().ref(path).put(bytes,{contentType:'image/png'}));
  await assertFails(owner.storage().ref(path).getDownloadURL());
  await assertFails(owner.storage().ref(path).delete());
  await assertFails(owner.storage().ref(`users/${uid}/receipts/bypass.png`).put(bytes,{contentType:'image/png'}));
});
test('financial import records are owner-readable, while all mutations and usage records are server-only',async()=>{
  const uid='document-read-user';
  await env.withSecurityRulesDisabled(async c=>{
    for(const collection of ['documentImports','attachments','paymentInstruments','paymentInstrumentCommands','documentSources']) {
      await c.firestore().doc(`users/${uid}/${collection}/synthetic`).set({dataGeneration:0});
    }
    await c.firestore().doc(`resourceUsage/${uid}`).set({attachmentBytes:50});
  });
  const owner=env.authenticatedContext(uid).firestore(),other=env.authenticatedContext('other').firestore();
  for(const collection of ['documentImports','attachments','paymentInstruments']) {
    const path=`users/${uid}/${collection}/synthetic`;
    await assertSucceeds(owner.doc(path).get());await assertFails(other.doc(path).get());
    await assertFails(owner.doc(path).set({dataGeneration:0}));await assertFails(owner.doc(path).delete());
  }
  for(const path of [`resourceUsage/${uid}`,`users/${uid}/paymentInstrumentCommands/synthetic`,`users/${uid}/documentSources/synthetic`,`servicePolicies/documentImports`]) {
    await assertFails(owner.doc(path).get());await assertFails(owner.doc(path).set({arbitrary:true}));
  }
});
