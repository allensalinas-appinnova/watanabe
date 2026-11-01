import assert from 'node:assert/strict';
import test,{after} from 'node:test';
import {deleteApp} from 'firebase-admin/app';
import {app,db} from './projection_test_support.mjs';
import {observeFirestore,observeServerResources,newServerObservation,meteredFirestore} from '../lib/resource_observation.js';
after(()=>deleteApp(app));
test('transaction observations count committed writes without changing chaining or financial values',async()=>{
 const stats=newServerObservation(),observed=observeFirestore(db,stats),ref=db.doc('resourceObservationTests/committed');
 await ref.set({value:100});
 await observed.runTransaction(async tx=>{const row=await tx.get(ref);tx.update(ref,{value:row.get('value')-25}).set(db.doc('resourceObservationTests/second'),{value:25});});
 assert.equal((await ref.get()).get('value'),75);assert.equal(stats.documentLookups,1);assert.equal(stats.committedWrites,2);
});
test('rollback records reads but no committed writes',async()=>{
 const stats=newServerObservation(),observed=observeFirestore(db,stats),ref=db.doc('resourceObservationTests/rollback');
 await ref.set({value:100});
 await assert.rejects(observed.runTransaction(async tx=>{await tx.get(ref);tx.update(ref,{value:0});throw Error('synthetic rollback');}));
 assert.equal((await ref.get()).get('value'),100);assert.equal(stats.committedWrites,0);assert.equal(stats.documentLookups,1);
});
test('concurrent request scopes do not attribute another request resources',async()=>{
 const a=newServerObservation(),b=newServerObservation();
 await Promise.all([observeServerResources(a,()=>meteredFirestore().runTransaction(async tx=>{await tx.get(db.doc('resourceObservationTests/a'));})),
 observeServerResources(b,()=>meteredFirestore().runTransaction(async tx=>{await tx.get(db.doc('resourceObservationTests/b'));await tx.get(db.doc('resourceObservationTests/c'));}))]);
 assert.equal(a.documentLookups,1);assert.equal(b.documentLookups,2);
});
