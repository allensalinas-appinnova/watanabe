import assert from 'node:assert/strict';
import test,{after} from 'node:test';
import {randomUUID} from 'node:crypto';
import {deleteApp} from 'firebase-admin/app';
import {Timestamp} from 'firebase-admin/firestore';
import {app,db} from './projection_test_support.mjs';
import {capacityDaySegments,observeStorageCapacity,storageCapacityScope} from '../lib/storage_capacity.js';
import {recordStorageTime} from '../lib/resource_usage.js';
import {estimateUserCosts,evaluateUsageEventCost} from '../lib/resource_costs.js';
import {REVIEWED_RESOURCE_TARIFFS} from '../lib/resource_tariffs.js';
import {getStorage} from 'firebase-admin/storage';
import {reconcileStorageObjectAbsence} from '../lib/document_storage.js';
import {trackDocumentObject} from '../lib/document_imports.js';
import {eventId} from '../lib/resource_usage.js';
after(()=>deleteApp(app));
const scope={bucket:'synthetic-bucket',region:'us-central1',storageClass:'STANDARD'};
const hour=3600000,giB=2**30,at=new Date('2026-11-03T10:00:00Z');
async function seed(bytes=giB){
 const uid=`capacity-${randomUUID()}`,root=db.doc(`resourceUsage/${uid}`),id=randomUUID();
 await root.set({attachmentBytes:bytes,temporaryBytes:0,reservedBytes:123,synthetic:true});
 await root.collection('periods').doc('month_2026-11').set({documentAnalyses:4});
 await root.collection('objects').doc(id).set({bytes,deleted:false,retained:true});
 return {uid,root,id};
}
const events=async root=>(await root.collection('events').get()).docs.map(d=>d.data());

test('scope requires verified bucket/location and the actual object class; segments are bounded UTC intervals',()=>{
 const saved={...process.env};
 try{
  process.env.RESOURCE_STORAGE_BUCKET='synthetic-bucket';process.env.RESOURCE_STORAGE_LOCATION='us-central1';
  assert.deepEqual(storageCapacityScope({bucket:'synthetic-bucket',storageClass:'STANDARD'}),scope);
  assert.equal(storageCapacityScope({bucket:'other',storageClass:'STANDARD'}),null);
  assert.equal(storageCapacityScope({bucket:'synthetic-bucket'}),null);
  delete process.env.RESOURCE_STORAGE_LOCATION;assert.equal(storageCapacityScope({bucket:'synthetic-bucket',storageClass:'STANDARD'}),null);
 }finally{for(const key of ['RESOURCE_STORAGE_BUCKET','RESOURCE_STORAGE_LOCATION'])if(saved[key]===undefined)delete process.env[key];else process.env[key]=saved[key];}
 assert.throws(()=>capacityDaySegments(at.getTime(),at.getTime()-1,10),/interval-invalid/);
 assert.throws(()=>capacityDaySegments(0,1,-1),/interval-invalid/);
 assert.equal(capacityDaySegments(0,400*86400000,1).segments.length,31);
});
test('baseline does not backdate; repeated and concurrent observations meter one interval without changing quotas',async()=>{
 const {uid,root,id}=await seed();
 await observeStorageCapacity(db,uid,id,scope,at);assert.equal((await events(root)).length,0);
 const later=new Date(at.getTime()+hour);
 await Promise.all([observeStorageCapacity(db,uid,id,scope,later),observeStorageCapacity(db,uid,id,scope,later)]);
 await observeStorageCapacity(db,uid,id,scope,at);
 const rows=await events(root);assert.equal(rows.length,1);assert.equal(rows[0].units.byteHours,giB);
 assert.equal(evaluateUsageEventCost(rows[0],REVIEWED_RESOURCE_TARIFFS).knownSubtotalUsd,0.000027397);
 assert.equal((await root.get()).get('attachmentBytes'),giB);assert.equal((await root.get()).get('reservedBytes'),123);
 assert.equal((await root.collection('periods').doc('month_2026-11').get()).get('documentAnalyses'),4);
 assert.equal((await root.collection('periods').doc('month_2026-11').get()).get('storage_classifiedByteHours'),giB);
});
test('month and UTC-day boundaries preserve the actual period instead of putting the whole interval in the report day',async()=>{
 const {uid,root,id}=await seed();
 await observeStorageCapacity(db,uid,id,scope,new Date('2026-11-30T23:30:00Z'));
 await observeStorageCapacity(db,uid,id,scope,new Date('2026-12-01T00:30:00Z'));
 const rows=await events(root);assert.equal(rows.length,2);
 assert.deepEqual(rows.map(r=>r.createdAt.toDate().toISOString().slice(0,7)).sort(),['2026-11','2026-12']);
 for(const month of ['2026-11','2026-12'])assert.equal((await root.collection('periods').doc(`month_${month}`).get()).get('storage_classifiedByteHours'),giB/2);
});
test('a class change or missing evidence keeps the gap pending and does not apply the Standard tariff',async()=>{
 const {uid,root,id}=await seed();const nearline={...scope,storageClass:'NEARLINE'};
 await observeStorageCapacity(db,uid,id,scope,at);
 await observeStorageCapacity(db,uid,id,nearline,new Date(at.getTime()+hour));
 await observeStorageCapacity(db,uid,id,nearline,new Date(at.getTime()+2*hour));
 const rows=await events(root);assert.equal(rows.length,2);
 const gap=rows.find(r=>r.quality==='pending'),classified=rows.find(r=>r.quality==='estimated');
 assert.equal(evaluateUsageEventCost(gap,REVIEWED_RESOURCE_TARIFFS).knownSubtotalUsd,null);
 assert.equal(classified.storageClass,'NEARLINE');assert.equal(evaluateUsageEventCost(classified,REVIEWED_RESOURCE_TARIFFS).knownSubtotalUsd,null);
});
test('deletion closes the last observed interval; replay cannot restore the meter or add more hours',async()=>{
 const {uid,root,id}=await seed();await observeStorageCapacity(db,uid,id,scope,at);
 await root.collection('objects').doc(id).update({deleted:true});
 await observeStorageCapacity(db,uid,id,null,new Date(at.getTime()+hour));
 await observeStorageCapacity(db,uid,id,scope,new Date(at.getTime()+2*hour));
 const rows=await events(root);assert.equal(rows.length,1);assert.equal(rows[0].units.byteHours,giB);
 const meter=await root.collection('storageCapacityMeters').doc(id).get();assert.equal(meter.get('closed'),true);assert.ok(meter.get('expiresAt'));
 const other=await seed();await other.root.collection('objects').doc(other.id).update({deleted:true});
 await observeStorageCapacity(db,other.uid,other.id,scope,at);assert.equal((await events(other.root)).length,0);
});
test('long outages resume bounded transactions without losing or duplicating intervals',async()=>{
 const {uid,root,id}=await seed(1);await observeStorageCapacity(db,uid,id,scope,at);
 const later=new Date(at.getTime()+400*86400000);
 await observeStorageCapacity(db,uid,id,scope,later);await observeStorageCapacity(db,uid,id,scope,later);
 const rows=await events(root);assert.equal(rows.reduce((n,r)=>n+r.units.byteHours,0),400*24);
 assert.equal((await root.collection('storageCapacityMeters').doc(id).get()).get('throughAt').toMillis(),later.getTime());
});
test('the occupancy diagnostic is excluded from cost sums while classified capacity is priced once',async()=>{
 const {uid,root,id}=await seed();
 await root.set({storageMeteredAt:Timestamp.fromDate(at),storageByteMilliseconds:0},{merge:true});
 await observeStorageCapacity(db,uid,id,scope,at);
 const later=new Date(at.getTime()+hour);await observeStorageCapacity(db,uid,id,scope,later);
 await recordStorageTime(db,uid,later);
 const rate=REVIEWED_RESOURCE_TARIFFS.find(t=>t.service==='storage');const {id:rateId,...data}=rate;await db.doc(`resourceTariffs/${rateId}`).set(data);
 await estimateUserCosts(db,'2026-11',{asOf:later});
 const cost=await root.collection('costs').doc('2026-11').get();assert.equal(cost.get('knownSubtotalUsd'),0.000027397);
 assert.equal(cost.get('totalEvents'),1);assert.equal(cost.get('excludedDiagnosticEvents'),1);
});
test('an upload missing from an older listing is not deleted or released until provider absence is confirmed',async()=>{
 assert.ok(process.env.STORAGE_EMULATOR_HOST||process.env.FIREBASE_STORAGE_EMULATOR_HOST);
 const uid=`capacity-race-${randomUUID()}`,id=randomUUID(),bytes=Buffer.from('synthetic');
 await db.doc(`users/${uid}`).set({dataGeneration:0,resetStatus:'ready'});
 await db.doc(`users/${uid}/documentImports/${id}`).set({dataGeneration:0,status:'prepared',size:bytes.length});
 const root=db.doc(`resourceUsage/${uid}`);await root.set({reservedBytes:bytes.length,reservedFiles:1});
 const bucket=getStorage().bucket('demo-clearbudget.appspot.com'),file=bucket.file(`users/${uid}/documentImports/0/${id}/source`);
 await file.save(bytes,{metadata:{contentType:'image/png'}});const [metadata]=await file.getMetadata();
 await trackDocumentObject(db,metadata,false);
 const ref=root.collection('objects').doc(eventId(`${metadata.name}:${metadata.generation}`));
 assert.equal(await reconcileStorageObjectAbsence(db,(await ref.get()).data(),bucket),true);
 assert.equal((await ref.get()).get('deleted'),false);assert.equal((await root.get()).get('temporaryBytes'),bytes.length);
 await file.delete();assert.equal(await reconcileStorageObjectAbsence(db,(await ref.get()).data(),bucket),false);
 assert.equal((await ref.get()).get('deleted'),true);assert.equal((await root.get()).get('temporaryBytes'),0);
});
