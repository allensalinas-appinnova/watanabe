import assert from 'node:assert/strict';
import test from 'node:test';
import {Timestamp} from 'firebase-admin/firestore';
import {priceUsageEvent} from '../lib/resource_costs.js';
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
