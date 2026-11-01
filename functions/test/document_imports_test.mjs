import assert from 'node:assert/strict';
import {randomUUID,createHash} from 'node:crypto';
import test,{after} from 'node:test';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore,Timestamp} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {prepareDocumentImport,analyzeDocumentImport,trackDocumentObject,suggestDocumentAccount} from '../lib/document_imports.js';
import {usageSummary,registeredUid} from '../lib/resource_usage.js';
import {discardDocument,deleteAttachment,readAttachment} from '../lib/document_storage.js';
import {executeOperationCommand} from '../lib/operation_commands.js';
import {executeDebtCommand} from '../lib/debt_commands.js';
import {mutatePaymentInstrument,accountIdentity} from '../lib/account_identity.js';
import {executeUserDataReset} from '../lib/user_data_reset.js';

assert.equal(process.env.GCLOUD_PROJECT,'demo-clearbudget');
assert.match(process.env.FIRESTORE_EMULATOR_HOST??'',/^127\.0\.0\.1:59180$/);
assert.ok(process.env.STORAGE_EMULATOR_HOST || process.env.FIREBASE_STORAGE_EMULATOR_HOST);
const app=initializeApp({projectId:'demo-clearbudget',storageBucket:'demo-clearbudget.appspot.com'});
const db=getFirestore(app),bucket=getStorage(app).bucket();
after(()=>deleteApp(app));
const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII=','base64');
const hash=createHash('sha256').update(png).digest('hex');
const date='2026-10-20T15:00:00.000Z';
async function seed() {
  const uid='document-'+randomUUID(),root=db.doc(`users/${uid}`);
  await root.set({dataGeneration:0,resetStatus:'ready',operationProjectionVersion:1,timeZone:'America/Bogota',locale:'es',onboardingStatus:'complete'});
  await root.collection('accounts').doc('cash').set({name:'Synthetic cash',type:'cash',nature:'money',status:'active',currency:'COP',openingBalanceMinor:500000,currentBalanceMinor:500000,dataGeneration:0});
  await root.collection('accounts').doc('card').set({name:'Synthetic card',type:'creditCard',nature:'debt',status:'active',currency:'COP',openingBalanceMinor:0,currentBalanceMinor:0,principalMinor:0,chargesMinor:0,referenceAt:Timestamp.fromDate(new Date('2020-01-01')),dataGeneration:0});
  await root.collection('categories').doc('food').set({name:'Synthetic category',type:'expense',isArchived:false});
  await db.doc('servicePolicies/documentImports').set({enabled:true});
  return {uid,root};
}
async function source(uid, overrides={}) {
  const input={requestId:randomUUID(),expectedGeneration:0,size:png.length,sha256:hash,contentType:'image/png',...overrides};
  const session=await prepareDocumentImport(db,uid,input);
  if(session.status==='duplicate')return session;
  await bucket.file(session.storagePath).save(png,{metadata:{contentType:'image/png'}});
  return session;
}
let calls=0;
const analyzer=async()=>{calls++;return {extraction:{supported:true,amountMinor:25000,currency:'COP',date:'2026-10-20',description:'Synthetic purchase',categoryId:'food'},usage:{inputTokens:100,outputTokens:20},model:'synthetic'};};
const analyze=(uid,s,a=analyzer)=>analyzeDocumentImport(db,uid,{importId:s.importId,expectedGeneration:0},a);
function purchase(s,card=false) {return {action:card?'purchase':'create',requestId:`doc_${s.importId}`,expectedGeneration:0,accountId:card?'card':'cash',categoryId:'food',amountMinor:25000,
  occurredAt:date,description:'Synthetic purchase',documentImportId:s.importId,documentImportVersion:s.version,confirmedPerformed:true,
  ...(!card?{type:'expense',currency:'COP',monthKey:'2026-10',idempotencyKey:`doc_${s.importId}`}:{})};}

test('partial account references distinguish debit cards and account endings without extra balances',async()=>{
  assert.throws(()=>accountIdentity({accountLastFour:'1234567890123456'}));
  const {uid,root}=await seed();
  const command={requestId:randomUUID(),expectedGeneration:0,expectedVersion:0,action:'create',accountId:'cash',name:'Debit',lastFour:'1234'};
  const result=await mutatePaymentInstrument(db,uid,command);
  assert.deepEqual(await mutatePaymentInstrument(db,uid,command),result);
  assert.equal((await root.collection('accounts').doc('cash').get()).get('currentBalanceMinor'),500000);
  await assert.rejects(mutatePaymentInstrument(db,uid,{...command,requestId:randomUUID(),action:'update',instrumentId:result.instrumentId,expectedVersion:0}));
  const accounts=[{id:'cash',nature:'money',status:'active',currency:'COP',institutionName:'Banco',accountLastFour:'9999'}];
  const instruments=[{accountId:'cash',status:'active',lastFour:'1234'}];
  assert.equal(suggestDocumentAccount({currency:'COP',accountHint:{kind:'debitCard',lastFour:'1234',institution:'Banco'}},accounts,instruments),'cash');
  assert.equal(suggestDocumentAccount({currency:'COP',accountHint:{kind:'account',lastFour:'1234'}},accounts,instruments),null);
  assert.throws(()=>registeredUid({uid,token:{firebase:{sign_in_provider:'anonymous'}}}));
});

test('bank expense and card purchase approve one operation and one private attachment on retries',async()=>{
  for(const card of [false,true]) {
    const {uid,root}=await seed(); const prepared=await source(uid); const before=calls;
    const ready=await analyze(uid,prepared); assert.equal(ready.status,'ready');
    await analyze(uid,prepared); assert.equal(calls,before+1);
    const command=purchase(ready,card);
    const run=()=>card?executeDebtCommand(db,uid,command,{enabled:true}):executeOperationCommand(db,uid,command);
    const result=await run(); assert.deepEqual(await run(),result);
    assert.equal((await root.collection('operations').get()).size,1);
    assert.equal((await root.collection('attachments').get()).size,1);
    assert.equal((await root.collection('accounts').doc(card?'card':'cash').get()).get('currentBalanceMinor'),card?-25000:475000);
    let usage=await usageSummary(db,uid);
    assert.equal(usage.dailyUsed,1);assert.equal(usage.monthlyUsed,1);
    assert.equal(usage.attachmentBytes,png.length);assert.equal(usage.temporaryBytes,0);assert.equal(usage.reservedBytes,0);
    const [metadata]=await bucket.file(prepared.storagePath).getMetadata();
    await trackDocumentObject(db,metadata,false);
    assert.equal((await usageSummary(db,uid)).attachmentBytes,png.length);
    const attachment=(await root.collection('attachments').get()).docs[0];
    const contents=await readAttachment(db,uid,{attachmentId:attachment.id});assert.equal(contents.data,png.toString('base64'));
    const duplicate=await prepareDocumentImport(db,uid,{requestId:randomUUID(),expectedGeneration:0,size:png.length,contentType:'image/png',sha256:hash});
    assert.equal(duplicate.status,'duplicate');
    await deleteAttachment(db,uid,{attachmentId:attachment.id,expectedGeneration:0});
    await deleteAttachment(db,uid,{attachmentId:attachment.id,expectedGeneration:0});
    usage=await usageSummary(db,uid);assert.equal(usage.attachmentBytes,0);
    assert.equal((await root.collection('operations').get()).size,1);
    assert.equal((await root.collection('monthlySummaries').doc('2026-10_COP').get()).get('expenseMinor'),25000);
  }
});

test('failed analysis refunds commercial quota but preserves technical attempt consumption',async()=>{
  const {uid}=await seed(),s=await source(uid);
  await assert.rejects(analyze(uid,s,async()=>{throw new Error('synthetic');}));
  let u=await usageSummary(db,uid);assert.equal(u.dailyUsed,0);assert.equal(u.monthlyUsed,0);
  assert.equal(u.monthly.ai_attempts,1);assert.equal(u.monthly.ai_failures,1);
  await analyze(uid,s);u=await usageSummary(db,uid);assert.equal(u.dailyUsed,1);assert.equal(u.monthly.ai_attempts,2);
});

test('concurrent analysis reserves one daily unit, generation and per-user isolation remain enforced',async()=>{
  const {uid}=await seed();await db.doc('servicePolicies/documentImports').set({enabled:true,dailyAnalyses:1});
  const [a,b]=await Promise.all([source(uid),source(uid)]);
  const results=await Promise.allSettled([analyze(uid,a),analyze(uid,b)]);
  assert.equal(results.filter(x=>x.status==='fulfilled').length,1);
  assert.equal((await usageSummary(db,uid)).dailyUsed,1);
  await assert.rejects(analyzeDocumentImport(db,'different-user',{importId:a.importId,expectedGeneration:0},analyzer));
  await assert.rejects(prepareDocumentImport(db,uid,{requestId:randomUUID(),expectedGeneration:1,size:png.length,sha256:hash,contentType:'image/png'}));
});

test('storage events may repeat or arrive out of order without restoring deleted bytes',async()=>{
  const {uid}=await seed();
  const p={requestId:randomUUID(),expectedGeneration:0,size:png.length,sha256:hash,contentType:'image/png'};
  const s=await prepareDocumentImport(db,uid,p);
  const m={name:s.storagePath,generation:'123456789',size:png.length};
  await trackDocumentObject(db,m,true);await trackDocumentObject(db,m,false);await trackDocumentObject(db,m,true);
  const u=await usageSummary(db,uid);assert.equal(u.temporaryBytes,0);assert.equal(u.attachmentBytes,0);
  await discardDocument(db,uid,s.importId,0);await discardDocument(db,uid,s.importId,0);
  assert.equal((await usageSummary(db,uid)).reservedBytes,0);
});

test('reset removes source and attachments while preserving quota and cost records',async()=>{
  const {uid,root}=await seed(),s=await source(uid),ready=await analyze(uid,s);
  await executeOperationCommand(db,uid,purchase(ready));
  await executeUserDataReset(db,uid,{requestId:randomUUID(),expectedGeneration:0,confirmed:true});
  assert.equal((await root.get()).get('dataGeneration'),1);
  assert.equal((await root.collection('attachments').get()).size,0);
  assert.equal((await bucket.file(s.storagePath).exists())[0],false);
  const u=await usageSummary(db,uid);assert.equal(u.dailyUsed,1);assert.equal(u.attachmentBytes,0);
});

test('invalid extraction fields remain reviewable rather than fabricating dates or categories',async()=>{
 const {validateExtraction}=await import('../lib/document_imports.js');
 const x=validateExtraction({supported:true,currency:'COP',amountMinor:25000,date:'2026-99-20',categoryId:'archived',accountId:'invented'},[{id:'archived',type:'expense',isArchived:true}],[],[]);
 assert.equal(x.date,undefined);assert.equal(x.categoryId,undefined);assert.equal(x.accountId,undefined);
 assert.ok(x.warnings.includes('date-review'));
});
test('PDF page limits and forged image payloads do not consume analysis quota',async()=>{
 const {PDFDocument}=await import('pdf-lib');
 const {uid}=await seed();const pdf=await PDFDocument.create();for(let i=0;i<4;i++)pdf.addPage();
 const bytes=Buffer.from(await pdf.save());
 const s=await prepareDocumentImport(db,uid,{requestId:randomUUID(),expectedGeneration:0,size:bytes.length,contentType:'application/pdf',sha256:createHash('sha256').update(bytes).digest('hex')});
 await bucket.file(s.storagePath).save(bytes,{metadata:{contentType:'application/pdf'}});
 await assert.rejects(analyze(uid,s));assert.equal((await usageSummary(db,uid)).dailyUsed,0);
 await discardDocument(db,uid,s.importId,0);
 const invalid=Buffer.from('not an image');
 const bad=await prepareDocumentImport(db,uid,{requestId:randomUUID(),expectedGeneration:0,size:invalid.length,contentType:'image/png',sha256:createHash('sha256').update(invalid).digest('hex')});
 await bucket.file(bad.storagePath).save(invalid,{metadata:{contentType:'image/png'}});
 await assert.rejects(analyze(uid,bad));assert.equal((await usageSummary(db,uid)).dailyUsed,0);
});
test('two temporary reservations and the retained storage cap are enforced across devices',async()=>{
 const {uid}=await seed();
 const reserve=()=>prepareDocumentImport(db,uid,{requestId:randomUUID(),expectedGeneration:0,size:100,contentType:'image/png',sha256:hash});
 const results=await Promise.allSettled([reserve(),reserve(),reserve()]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,2);
 const {uid:full}=await seed();await db.doc(`resourceUsage/${full}`).set({attachmentBytes:99999999});
 await assert.rejects(prepareDocumentImport(db,full,{requestId:randomUUID(),expectedGeneration:0,size:100,contentType:'image/png',sha256:hash}));
});
test('unsupported documents consume one commercial unit; lost responses reuse the same result',async()=>{
 const {uid}=await seed(),s=await source(uid);let attempts=0;
 const unsupported=async()=>{attempts++;return {extraction:{supported:false},usage:{inputTokens:5},model:'synthetic'};};
 const first=await analyze(uid,s,unsupported);assert.equal(first.status,'unsupported');
 assert.deepEqual(await analyze(uid,s,unsupported),first);assert.equal(attempts,1);assert.equal((await usageSummary(db,uid)).dailyUsed,1);
});
test('storage deletion with a lost event releases bytes immediately on confirmed absence',async()=>{
 const {uid,root}=await seed(),s=await source(uid),ready=await analyze(uid,s);
 await executeOperationCommand(db,uid,purchase(ready));await bucket.file(s.storagePath).delete();
 await deleteAttachment(db,uid,{attachmentId:s.importId,expectedGeneration:0});
 assert.equal((await usageSummary(db,uid)).attachmentBytes,0);
 assert.equal((await root.collection('accounts').doc('cash').get()).get('currentBalanceMinor'),475000);
});

test('a crashed analysis lease is refunded once even if financial reset removed its proposal',async()=>{
 const {reserveAnalysis}=await import('../lib/resource_usage.js');
 const {cleanupExpiredDocuments}=await import('../lib/document_storage.js');
 const {uid,root}=await seed();const attempt=randomUUID(),id=randomUUID();
 const old=new Date(Date.now()-200000);
 await db.runTransaction(async tx=>{const r=await reserveAnalysis(tx,db,uid,{dailyAnalyses:5,monthlyAnalyses:20},old,attempt,id);r.write();});
 await cleanupExpiredDocuments(db);await cleanupExpiredDocuments(db);
 assert.equal((await usageSummary(db,uid)).dailyUsed,0);
 assert.equal((await db.doc(`resourceUsage/${uid}/analysisReservations/${attempt}`).get()).get('state'),'released');
 assert.equal((await root.collection('operations').get()).size,0);
});
test('a late deletion event after discard cannot release a reservation twice',async()=>{
 const {uid}=await seed();const s=await prepareDocumentImport(db,uid,{requestId:randomUUID(),expectedGeneration:0,size:png.length,contentType:'image/png',sha256:hash});
 await discardDocument(db,uid,s.importId,0);
 await trackDocumentObject(db,{name:s.storagePath,generation:'late-generation',size:png.length},true);
 const u=await usageSummary(db,uid);assert.equal(u.reservedBytes,0);assert.equal(u.temporaryBytes,0);
});
