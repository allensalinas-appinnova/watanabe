import assert from 'node:assert/strict';
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
  for(const path of [`resourceUsage/${uid}`,`resourceUsage/${uid}/storageCapacityMeters/synthetic`,`users/${uid}/paymentInstrumentCommands/synthetic`,`users/${uid}/documentSources/synthetic`,`servicePolicies/documentImports`]) {
    await assertFails(owner.doc(path).get());await assertFails(owner.doc(path).set({arbitrary:true}));
  }
});

test('accepted deletion blocks the profile atomically before a cached-token upload',async()=>{
  const uid='deleting-storage-user',id='deletion-import',bytes=Buffer.from('synthetic');
  await env.withSecurityRulesDisabled(async c=>{
    await c.firestore().doc(`users/${uid}`).set({dataGeneration:0,resetStatus:'ready'});
    await c.firestore().doc(`users/${uid}/documentImports/${id}`).set({dataGeneration:0,status:'prepared',size:bytes.length,contentType:'image/png',expiresAt:Timestamp.fromMillis(Date.now()+60000)});
    const batch=c.firestore().batch();
    batch.set(c.firestore().doc(`accountDeletions/${uid}`),{status:'requested'});
    batch.update(c.firestore().doc(`users/${uid}`),{resetStatus:'resetting',dataGeneration:1});
    await batch.commit();
  });
  await assertFails(env.authenticatedContext(uid,{firebase:{sign_in_provider:'password'}}).storage().ref(`users/${uid}/documentImports/0/${id}/source`).put(bytes,{contentType:'image/png'}));
});

test('a deleted profile cannot upload even if its old reservation remains',async()=>{
  const uid='missing-storage-profile',id='old-reservation';
  await env.withSecurityRulesDisabled(async c=>{
    await c.firestore().doc(`accountDeletions/${uid}`).set({status:'working'});
    await c.firestore().doc(`users/${uid}/documentImports/${id}`).set({dataGeneration:0,status:'prepared',size:bytes.length,contentType:'image/png',expiresAt:Timestamp.fromMillis(Date.now()+60000)});
  });
  await assertFails(env.authenticatedContext(uid,{firebase:{sign_in_provider:'password'}}).storage().ref(`users/${uid}/documentImports/0/${id}/source`).put(bytes,{contentType:'image/png'}));
});

test('upload rejects an old generation even when the profile is ready again',async()=>{
  const uid='reset-storage-user',id='old-generation';
  await env.withSecurityRulesDisabled(async c=>{
    await c.firestore().doc(`users/${uid}`).set({dataGeneration:2,resetStatus:'ready'});
    await c.firestore().doc(`users/${uid}/documentImports/${id}`).set({dataGeneration:1,status:'prepared',size:bytes.length,contentType:'image/png',expiresAt:Timestamp.fromMillis(Date.now()+60000)});
  });
  await assertFails(env.authenticatedContext(uid,{firebase:{sign_in_provider:'password'}}).storage().ref(`users/${uid}/documentImports/1/${id}/source`).put(bytes,{contentType:'image/png'}));
});

// Emulator accepts cases above the production cross-service limit. Audit the
// reachable read paths independently so that an extra guard cannot break uploads.
test('each Storage create policy fits the production two-document access limit',()=>{
  const source=readFileSync(new URL('../../storage.rules',import.meta.url),'utf8').replace(/\/\/[^\n]*/g,'');
  const functions=new Map();
  for(const match of source.matchAll(/function\s+(\w+)\([^)]*\)\s*\{/g)){
    let depth=1,end=match.index+match[0].length;
    for(;depth>0&&end<source.length;end++){if(source[end]==='{')depth++;else if(source[end]==='}')depth--;}
    functions.set(match[1],source.slice(match.index+match[0].length,end-1));
  }
  function readPaths(expression,visited=new Set()){
    const paths=new Set();
    for(const match of expression.matchAll(/firestore\.(?:get|exists)\(/g)){
      const start=match.index+match[0].length;let depth=1,end=start;
      for(;depth>0&&end<expression.length;end++){if(expression[end]==='(')depth++;else if(expression[end]===')')depth--;}
      paths.add(expression.slice(start,end-1).replace(/\s/g,''));
    }
    for(const [name,body] of functions){
      if(!visited.has(name)&&new RegExp('\\b'+name+'\\s*\\(').test(expression)){
        visited.add(name);for(const path of readPaths(body,visited))paths.add(path);
      }
    }
    return paths;
  }
  let policies=0;
  for(const match of source.matchAll(/allow\s+([^:]+):\s*if\s*([^;]+);/g)){
    if(!match[1].split(',').map(x=>x.trim()).includes('create'))continue;
    policies++;const paths=readPaths(match[2]);
    assert.ok(paths.size<=2,`Storage create uses ${paths.size} Firestore documents; production allows two`);
  }
  assert.ok(policies>0);
});
