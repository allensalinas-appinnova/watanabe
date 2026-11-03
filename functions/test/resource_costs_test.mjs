import assert from 'node:assert/strict';
import test from 'node:test';
import {Timestamp} from 'firebase-admin/firestore';
import {priceUsageEvent,evaluateUsageEventCost,groupBillingRows,resourceBillingQueryOptions} from '../lib/resource_costs.js';
import {REVIEWED_RESOURCE_TARIFFS,tariffConfigurationPlan} from '../lib/resource_tariffs.js';
const at=Timestamp.fromDate(new Date('2026-11-01T12:00:00Z'));
const rates=[['billableInputTokens',0.75e-6],['billableOutputTokens',3.75e-6],['cachedTokens',0.075e-6]].map(([unit,usdPerUnit])=>({service:'ai',model:'gemini-3.8-flash',region:'global',effectiveFrom:'2026-11-01T00:00:00Z',effectiveUntil:'2027-01-01T00:00:00Z',unit,usdPerUnit}));
const event={service:'ai',model:'gemini-3.8-flash',region:'global',createdAt:at,quality:'measured',units:{billableInputTokens:1000,billableOutputTokens:500,cachedTokens:0}};
test('token cost includes reasoning output and never assumes an unknown service is free',()=>{
 assert.equal(priceUsageEvent(event,rates),0.002625);
 assert.equal(priceUsageEvent({...event,service:'firestore'},rates),null);
 assert.equal(priceUsageEvent({...event,quality:'pending'},rates),null);
 assert.equal(priceUsageEvent({...event,units:{inputTokens:1000}},rates),null);
});
test('pricing is versioned by model, region and effective date without adding overlapping versions',()=>{
 assert.equal(priceUsageEvent({...event,region:'eu'},rates),null);
 assert.equal(priceUsageEvent({...event,createdAt:Timestamp.fromDate(new Date('2027-01-01'))},rates),null);
 const older=rates.map(r=>({...r,effectiveFrom:'2026-10-01T00:00:00Z',usdPerUnit:100}));
 assert.equal(priceUsageEvent(event,[...older,...rates]),0.002625);
});

test('partial AI usage retains a known subtotal with explicit missing output instead of assuming zero',()=>{
 const cost=evaluateUsageEventCost({...event,units:{billableInputTokens:1000,cachedTokens:0}},rates.map((r,i)=>({...r,id:`rate-${i}`})));
 assert.equal(cost.complete,false);assert.equal(cost.knownSubtotalUsd,0.00075);
 assert.deepEqual(cost.tariffVersions,['rate-0']);
 assert.deepEqual(cost.pendingReasons,['ai:billableOutputTokens:measurement-unavailable']);
 assert.equal(priceUsageEvent({...event,units:{billableInputTokens:1000,cachedTokens:0}},rates),null);
});
test('explicit zero needs no tariff; missing, negative, nonfinite and pending units remain unknown',()=>{
 const zero={...event,units:{billableInputTokens:0,billableOutputTokens:0,cachedTokens:0}};
 assert.equal(priceUsageEvent(zero,[]),0);
 for(const value of [undefined,-1,NaN,Infinity])assert.equal(priceUsageEvent({...zero,units:{...zero.units,billableInputTokens:value}},rates),null);
 assert.equal(priceUsageEvent({...zero,quality:'pending'},rates),null);
 assert.equal(priceUsageEvent({...event,createdAt:null},rates),null);
});
test('equal-precedence conflicting tariffs stay pending while exact model and region win over generic rates',()=>{
 const specific=rates.map((r,i)=>({...r,id:`specific-${i}`}));
 const generic=rates.map((r,i)=>({...r,id:`generic-${i}`,model:undefined,region:undefined,usdPerUnit:100}));
 assert.equal(priceUsageEvent(event,[...generic,...specific]),0.002625);
 const conflict={...specific[0],id:'conflicting-rate',usdPerUnit:1};
 const cost=evaluateUsageEventCost(event,[...specific,conflict]);
 assert.equal(cost.complete,false);assert.ok(cost.pendingReasons.includes('ai:billableInputTokens:tariff-ambiguous'));
 assert.ok(Math.abs(cost.knownSubtotalUsd-0.001875)<1e-12);
 assert.equal(priceUsageEvent(event,[...specific,...rates.map(r=>({...r,effectiveFrom:'2026-11-02',usdPerUnit:100}))]),0.002625);
});
test('function estimates split Firestore components and never price elapsed wall time as CPU',()=>{
 const tariff=(service,unit,usdPerUnit)=>({id:unit,service,region:'us-central1',unit,usdPerUnit,effectiveFrom:'2026-11-01'});
 const functionRates=[tariff('functions','calls',0.1),tariff('firestore','documentReads',0.2),tariff('firestore','documentWrites',0.3),tariff('firestore','documentDeletes',0.4)];
 const cost=evaluateUsageEventCost({service:'functions',createdAt:at,region:'us-central1',firestoreRegion:'us-central1',units:{calls:1,durationMs:90000,
 transactionDocumentLookups:2,transactionQueryReadUnits:1,committedDocumentWrites:3,committedDocumentDeletes:1}},functionRates);
 assert.equal(cost.complete,false);assert.ok(Math.abs(cost.knownSubtotalUsd-2)<1e-12);
 assert.deepEqual(cost.pendingReasons,['functions:compute:shared-compute-unattributed']);
 assert.equal(cost.components.filter(c=>c.service==='functions'&&c.amountUsd!==null).reduce((n,c)=>n+c.amountUsd,0),0.1);
 assert.equal(cost.components.some(c=>c.unit==='durationMs'),false);
 const legacy=evaluateUsageEventCost({service:'functions',createdAt:at,units:{calls:1,committedTransactionWrites:2,transactionQueryResults:4}},functionRates);
 assert.ok(legacy.pendingReasons.some(r=>r.includes('legacy-write')));assert.ok(legacy.pendingReasons.some(r=>r.includes('legacy-query')));
});
test('storage transport and advisory reads cannot be priced as invoice units',()=>{
 const storage={service:'storage',createdAt:at,units:{byteHours:100,servedBytes:10000}};
 const cost=evaluateUsageEventCost(storage,[{id:'capacity',service:'storage',unit:'byteHours',usdPerUnit:0.01,effectiveFrom:'2026-11-01'}]);
 assert.equal(cost.knownSubtotalUsd,1);assert.equal(cost.complete,false);assert.match(cost.pendingReasons[0],/billing-route-unverified/);
 assert.equal(priceUsageEvent({service:'firestore',createdAt:at,units:{documentResults:10}},[{service:'firestore',unit:'documentResults',usdPerUnit:1,effectiveFrom:'2026-11-01'}]),null);
});
test('billing normalization groups provider products once and keeps currencies and unknown services apart',()=>{
 const rows=groupBillingRows([
 {day:{value:'2026-11-01'},service:'Cloud Functions',currency:'USD',grossCost:10,credits:-1},
 {day:'2026-11-01',service:'Cloud Run Functions',currency:'USD',grossCost:5,credits:-2},
 {day:'2026-11-01',service:'Cloud Run',currency:'COP',grossCost:8000,credits:0},
 {day:'2026-11-01',service:'Cloud Logging',currency:'USD',grossCost:1,credits:0},
 ]);
 assert.equal(rows.length,3);const usd=rows.find(r=>r.service==='functions'&&r.currency==='USD');
 assert.equal(usd.netCost,12);assert.deepEqual(usd.providerServices,['Cloud Functions','Cloud Run Functions']);
 assert.equal(rows.find(r=>r.service==='Cloud Logging').measuredService,null);
 assert.throws(()=>groupBillingRows([{day:'invalid',service:'Cloud Run',currency:'USD',grossCost:1,credits:0}]),/billing-row-invalid/);
 for(const value of [null,undefined,'',false,NaN])assert.throws(()=>groupBillingRows([{day:'2026-11-01',service:'Cloud Run',currency:'USD',grossCost:value,credits:0}]),/billing-row-invalid/);
});
test('Firestore location is independent of the function location and reviewed NAM5 prices are used only with evidence',()=>{
 const event={service:'functions',region:'us-central1',createdAt:at,units:{calls:0,transactionDocumentLookups:100000}};
 const when=Timestamp.fromDate(new Date('2026-11-02T12:00:00Z'));
 const missing=evaluateUsageEventCost({...event,createdAt:when},REVIEWED_RESOURCE_TARIFFS);
 assert.ok(missing.pendingReasons.some(r=>r.endsWith('resource-location-unverified')));
 const priced=evaluateUsageEventCost({...event,createdAt:when,firestoreRegion:'nam5'},REVIEWED_RESOURCE_TARIFFS);
 assert.equal(priced.components.find(c=>c.service==='firestore').amountUsd,0.06);
 assert.equal(evaluateUsageEventCost({...event,createdAt:when,firestoreRegion:'us-central1'},REVIEWED_RESOURCE_TARIFFS).components.find(c=>c.service==='firestore').amountUsd,null);
});
test('reviewed tariff provisioning is additive, repeatable, immutable and topology-gated',()=>{
 const metadata={firestoreRegion:'nam5',firestoreEdition:'STANDARD',bucketRegion:'us-central1',storageClass:'STANDARD',functionsBillingMode:'request-based'};
 const now=new Date('2026-11-02T12:00:00Z');
 assert.equal(tariffConfigurationPlan([],metadata,now).create.length,8);
 assert.equal(tariffConfigurationPlan(REVIEWED_RESOURCE_TARIFFS,metadata,now).create.length,0);
 assert.throws(()=>tariffConfigurationPlan([{...REVIEWED_RESOURCE_TARIFFS[0],usdPerUnit:0}],metadata,now),/immutable-tariff-conflict/);
 assert.throws(()=>tariffConfigurationPlan([],{...metadata,firestoreEdition:'ENTERPRISE'},now),/topology-needs-review/);
 assert.throws(()=>tariffConfigurationPlan([],metadata,new Date('2027-01-01T00:00:00Z')),/tariff-review-expired/);
 const at=Timestamp.fromDate(new Date('2026-11-02T12:00:00Z'));
 const storage={service:'storage',region:'us-central1',createdAt:at,units:{byteHours:2**30}};
 assert.equal(priceUsageEvent(storage,REVIEWED_RESOURCE_TARIFFS),null);
 assert.equal(priceUsageEvent({...storage,storageClass:'STANDARD'},REVIEWED_RESOURCE_TARIFFS),0.000027397);
 assert.equal(priceUsageEvent({...storage,storageClass:'NEARLINE'},REVIEWED_RESOURCE_TARIFFS),null);
});
test('conversion uses each exported row rate before aggregating and never replaces a missing rate with zero',()=>{
 const row={day:'2026-11-01',service:'Cloud Run',currency:'COP',grossCost:4000,credits:0,currencyConversionRate:4000};
 const [cost]=groupBillingRows([row,{...row,grossCost:8000,credits:-4000,currencyConversionRate:2000}]);
 assert.equal(cost.netCost,8000);assert.equal(cost.netCostUsd,3);assert.deepEqual(cost.conversionRates,[2000,4000]);
 for(const rate of [undefined,null,0,-1,Infinity])assert.equal(groupBillingRows([{...row,currencyConversionRate:rate}])[0].netCostUsd,null);
 assert.equal(groupBillingRows([{...row,credits:-8000}])[0].netCostUsd,-1);
});
test('billing preflight uses the same bounded project-scoped SQL as reconciliation',()=>{
 const options=resourceBillingQueryOptions('demo-clearbudget.synthetic.billing','demo-clearbudget');
 assert.equal(options.params.projectId,'demo-clearbudget');assert.equal(options.maximumBytesBilled,'1000000000');
 assert.match(options.query,/GROUP BY day,service,currency,currencyConversionRate/);
 assert.match(options.query,/TIMESTAMP\(CURRENT_DATE\('UTC'\)\)/);
 for(const table of ['unsafe`table','project.dataset.table; DROP TABLE other',''])assert.throws(()=>resourceBillingQueryOptions(table,'demo-clearbudget'),/billing-table-invalid/);
});

test('tariff expiry warnings use the latest version and distinguish missing coverage',async()=>{
 const {tariffHealth}=await import('../lib/resource_costs.js');
 const now=new Date('2026-12-15T00:00:00Z');
 assert.equal(tariffHealth([],now).state,'unknown');
 const rate={id:'current',service:'ai',unit:'tokens',effectiveFrom:'2026-11-01',effectiveUntil:'2027-01-01'};
 assert.equal(tariffHealth([rate],now).state,'expiring');
 assert.equal(tariffHealth([rate],new Date('2027-01-02')).state,'expired');
 assert.equal(tariffHealth([rate,{...rate,id:'renewed',effectiveFrom:'2026-12-01',effectiveUntil:'2027-04-01'}],now).state,'ready');
});
