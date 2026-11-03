import assert from 'node:assert/strict';
import test,{after} from 'node:test';
import {randomUUID} from 'node:crypto';
import {deleteApp} from 'firebase-admin/app';
import {Timestamp} from 'firebase-admin/firestore';
import {app,db} from './projection_test_support.mjs';
import {estimateUserCosts,reconcileProjectBilling} from '../lib/resource_costs.js';
import {adminResourceUsage,bootstrapAdminOperator} from '../lib/admin_portal.js';
import {configureReviewedResourceTariffs,REVIEWED_RESOURCE_TARIFFS} from '../lib/resource_tariffs.js';
after(()=>deleteApp(app));
const stamp=Timestamp.fromDate(new Date('2026-11-01T12:00:00Z'));
test('review mode never writes; concurrent tariff installation is additive and preserves unrelated policies',async()=>{
 const metadata={firestoreRegion:'nam5',firestoreEdition:'STANDARD',bucketRegion:'us-central1',storageClass:'STANDARD',functionsBillingMode:'request-based'};
 const now=new Date('2026-11-02T12:00:00Z');
 const policy=db.doc(`servicePolicies/cost-test-${randomUUID()}`);
 await policy.set({enabled:false,dailyAnalyses:5,synthetic:'preserved'});
 const dry=await configureReviewedResourceTariffs(db,metadata,false,now);assert.equal(dry.create.length,8);
 assert.equal((await db.doc(`resourceTariffs/${REVIEWED_RESOURCE_TARIFFS[0].id}`).get()).exists,false);
 const plans=await Promise.all([configureReviewedResourceTariffs(db,metadata,true,now),configureReviewedResourceTariffs(db,metadata,true,now)]);
 assert.equal(plans.reduce((n,p)=>n+p.create.length,0),8);
 const repeated=await configureReviewedResourceTariffs(db,metadata,true,now);assert.equal(repeated.create.length,0);
 assert.equal((await policy.get()).get('synthetic'),'preserved');
 assert.equal((await policy.get()).get('enabled'),false);
});

test('monthly and daily estimates preserve partial costs, service attribution and only used tariff versions on rerun',async()=>{
 const uid=`cost-${randomUUID()}`,root=db.doc(`resourceUsage/${uid}`);
 await root.set({synthetic:true});
 const tariffId=`cost-${randomUUID()}`;
 await db.doc(`resourceTariffs/${tariffId}`).set({service:'ai',model:uid,unit:'billableInputTokens',effectiveFrom:'2026-11-01',usdPerUnit:0.001});
 await db.doc(`resourceTariffs/unused-${tariffId}`).set({service:'ai',model:'unrelated',unit:'billableOutputTokens',effectiveFrom:'2026-11-01',usdPerUnit:100});
 await root.collection('events').doc('partial').set({service:'ai',model:uid,units:{billableInputTokens:1000,cachedTokens:0},createdAt:stamp,quality:'measured'});
 await root.collection('events').doc('unknown').set({service:'storage',units:{servedBytes:100},createdAt:stamp});
 await estimateUserCosts(db,'2026-11');
 const first=(await root.collection('costs').doc('2026-11').get()).data();
 assert.equal(first.amountUsd,null);assert.equal(first.knownSubtotalUsd,1);assert.equal(first.totalEvents,2);
 assert.equal(first.partiallyPricedEvents,1);assert.deepEqual(first.tariffVersions,[tariffId]);assert.equal(first.byService.ai,1);
 assert.ok(first.pendingReasons['ai:billableOutputTokens:measurement-unavailable']);
 const daily=(await root.collection('costDays').doc('2026-11-01').get()).data();assert.equal(daily.knownSubtotalUsd,1);
 await estimateUserCosts(db,'2026-11');const again=(await root.collection('costs').doc('2026-11').get()).data();
 assert.equal(again.knownSubtotalUsd,1);assert.equal(again.totalEvents,2);
 await assert.rejects(estimateUserCosts(db,'2026-13'),/cost-month-invalid/);
});
test('billing attributes users once per service, isolates non-USD, and publishes only a successful snapshot',async()=>{
 const operator={uid:`cost-admin-${randomUUID()}`,token:{email:'cost-owner@example.test',email_verified:true,firebase:{sign_in_provider:'google.com'}}};
 await bootstrapAdminOperator(db,operator,'cost-owner@example.test');
 await db.doc('servicePolicies/billing').set({exportTable:'demo-clearbudget.synthetic.billing'});
 const uid=`billing-${randomUUID()}`;await db.doc(`resourceUsage/${uid}`).set({synthetic:true});
 await db.doc(`resourceUsage/${uid}/costDays/2026-10-31`).set({byService:{functions:3}});
 const rows=[{day:'2026-10-31',service:'Cloud Functions',currency:'USD',grossCost:10,credits:-1},
 {day:'2026-10-31',service:'Cloud Run',currency:'USD',grossCost:5,credits:-2},
 {day:'2026-10-30',service:'Cloud Run',currency:'COP',grossCost:10000,credits:0}];
 await reconcileProjectBilling(db,async options=>{
  assert.equal(options.params.projectId,'demo-clearbudget');assert.equal(options.maximumBytesBilled,'1000000000');
  assert.match(options.query,/project.id=@projectId/);assert.match(options.query,/TIMESTAMP\(CURRENT_DATE\('UTC'\)\)/);return [rows];
 });
 const status=(await db.doc('resourceBilling/status').get()).data();assert.equal(status.available,true);
 const entries=(await db.collection('resourceBilling/daily/services').where('runId','==',status.runId).get()).docs.map(d=>d.data());
 const visible=await adminResourceUsage.run({auth:operator,data:{}});
 assert.equal(visible.billing.services.length,2);assert.ok(visible.billing.updatedAtIso);
 assert.equal(entries.length,2);const usd=entries.find(r=>r.currency==='USD'),cop=entries.find(r=>r.currency==='COP');
 assert.equal(usd.knownSubtotalUsd,3);assert.equal(usd.netCost,12);assert.equal(usd.unattributedDifferenceUsd,9);
 assert.equal(cop.knownSubtotalUsd,null);assert.equal(cop.unattributedDifferenceUsd,null);assert.equal(cop.comparisonIssue,'currency-not-comparable');
 await reconcileProjectBilling(db,async()=>{throw Object.assign(Error('synthetic unavailable'),{code:403});});
 const failed=(await db.doc('resourceBilling/status').get()).data();assert.equal(failed.available,false);assert.equal(failed.runId,status.runId);
 const unavailable=await adminResourceUsage.run({auth:operator,data:{}});assert.deepEqual(unavailable.billing.services,[]);
 assert.equal(failed.issue,'billing-query-unavailable');assert.ok(failed.lastSuccessfulAt);
 await reconcileProjectBilling(db,async()=>[[]]);const empty=(await db.doc('resourceBilling/status').get()).data();
 assert.equal(empty.available,false);assert.equal(empty.issue,'billing-export-awaiting-data');assert.notEqual(empty.runId,status.runId);
 await reconcileProjectBilling(db,async()=>[rows]);const recovered=(await db.doc('resourceBilling/status').get()).data();
 assert.equal(recovered.available,true);assert.notEqual(recovered.runId,status.runId);
 const current=await db.collection('resourceBilling/daily/services').where('runId','==',recovered.runId).get();assert.equal(current.size,2);
 const refreshed=await adminResourceUsage.run({auth:operator,data:{}});assert.equal(refreshed.billing.services.length,2);
 assert.ok(refreshed.billing.services.every(row=>row.runId===recovered.runId));
 await db.doc(`resourceUsage/${uid}/costDays/2026-10-29`).set({byService:{functions:0.7}});
 const convertedRows=[{day:'2026-10-29',service:'Cloud Run',currency:'COP',grossCost:4000,credits:0,currencyConversionRate:4000},
  {day:'2026-10-29',service:'Cloud Run Functions',currency:'COP',grossCost:6000,credits:-3000,currencyConversionRate:3000}];
 await reconcileProjectBilling(db,async()=>[convertedRows]);
 const converted=(await adminResourceUsage.run({auth:operator,data:{}})).billing.services;
 assert.equal(converted.length,1);assert.equal(converted[0].netCostUsd,2);assert.equal(converted[0].unattributedDifferenceUsd,1.3);
 await reconcileProjectBilling(db,async()=>[[...rows,{day:'2026-10-31',service:'Cloud Run',currency:'COP',grossCost:3000,credits:0,currencyConversionRate:3000}]]);
 const mixed=(await adminResourceUsage.run({auth:operator,data:{}})).billing.services.filter(row=>row.day==='2026-10-31');
 assert.ok(mixed.every(row=>row.knownSubtotalUsd===null&&row.comparisonIssue==='mixed-provider-currencies'));
});
