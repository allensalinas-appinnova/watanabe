import assert from 'node:assert/strict';
import test,{after} from 'node:test';
import {randomUUID} from 'node:crypto';
import {deleteApp} from 'firebase-admin/app';
import {Timestamp} from 'firebase-admin/firestore';
import {app,db} from './projection_test_support.mjs';
import {estimateUserCosts} from '../lib/resource_costs.js';
import {runUserMaintenance} from '../lib/maintenance_jobs.js';
after(()=>deleteApp(app));

test('cost pages resume a committed checkpoint and publish a complete result only once',async()=>{
 const uid=`paged-cost-${randomUUID()}`,month='2026-09',root=db.doc(`resourceUsage/${uid}`);
 await root.set({synthetic:true});
 await root.collection('costs').doc(month).set({totalEvents:7,knownSubtotalUsd:7,syntheticPrevious:true});
 const stamp=Timestamp.fromDate(new Date('2026-09-01T12:00:00Z'));
 await db.doc(`resourceTariffs/${uid}`).set({service:'ai',model:uid,unit:'billableInputTokens',effectiveFrom:'2026-01-01',usdPerUnit:1});
 for(let offset=0;offset<501;offset+=250){const batch=db.batch();for(let i=offset;i<Math.min(offset+250,501);i++)batch.set(root.collection('events').doc(`e${String(i).padStart(4,'0')}`),{service:'ai',model:uid,units:{billableInputTokens:1},createdAt:stamp});await batch.commit();}
 let interrupted=false;
 await assert.rejects(estimateUserCosts(db,month,{afterPage:async current=>{if(current===uid&&!interrupted){interrupted=true;throw Error('synthetic-interruption');}}}),/synthetic-interruption/);
 assert.equal((await root.collection('costs').doc(month).get()).get('totalEvents'),7);
 assert.equal((await root.get()).get('costRefreshStatus'),'running');
 await estimateUserCosts(db,month);
 let result=await root.collection('costs').doc(month).get();assert.equal(result.get('totalEvents'),501);assert.equal(result.get('knownSubtotalUsd'),501);
 await estimateUserCosts(db,month);
 result=await root.collection('costs').doc(month).get();assert.equal(result.get('totalEvents'),501);assert.equal(result.get('knownSubtotalUsd'),501);
 assert.equal((await root.collection('maintenance').doc(`costs_${month}`).get()).exists,false);
});

test('user pages include more than 100 users and concurrent invocations have one owner',async()=>{
 const id=`test-${randomUUID()}`,prefix=`job-user-${randomUUID()}`;
 const batch=db.batch();for(let i=0;i<105;i++)batch.set(db.doc(`resourceUsage/${prefix}-${String(i).padStart(3,'0')}`),{synthetic:true});await batch.commit();
 const seen=new Set();let entered;const gate=new Promise(resolve=>{entered=resolve;});let release;const hold=new Promise(resolve=>{release=resolve;});
 const first=runUserMaintenance(db,id,async uid=>{seen.add(uid);if(uid===`${prefix}-000`){entered();await hold;}return true;});
 await gate;
 let foreign=0;await runUserMaintenance(db,id,async()=>{foreign++;return true;});assert.equal(foreign,0);release();await first;
 assert.equal([...seen].filter(uid=>uid.startsWith(prefix)).length,105);
 assert.equal((await db.doc(`maintenanceJobs/${id}`).get()).get('status'),'complete');
});
