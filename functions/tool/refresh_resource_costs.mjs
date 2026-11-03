import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {estimateUserCosts,reconcileProjectBilling} from '../lib/resource_costs.js';

// Deliberately omit inventory/cleanup: refreshing estimates must not delete source files or drafts.
if(process.env.GCLOUD_PROJECT!=='lumiomoney'||process.env.FIRESTORE_EMULATOR_HOST)throw Error('explicit-live-target-required');
const app=initializeApp({projectId:'lumiomoney'});
try {
 const db=getFirestore();const now=new Date();const current=now.toISOString().slice(0,7);
 const prior=new Date(Date.UTC(now.getUTCFullYear(),now.getUTCMonth()-1,1)).toISOString().slice(0,7);
 await estimateUserCosts(db,current);await estimateUserCosts(db,prior);await reconcileProjectBilling(db);
 const status=await db.doc('resourceBilling/status').get();
 console.log(JSON.stringify({months:[prior,current],billingAvailable:status.get('available'),issue:status.get('issue')??null,
  runId:status.get('runId')??null,updatedAt:status.get('updatedAt')?.toDate?.().toISOString()??null}));
 if(status.get('available')!==true)process.exitCode=1;
}catch(error){console.error(JSON.stringify({issue:'resource-cost-refresh-failed',code:error.code??null}));process.exitCode=1;}
finally{await deleteApp(app);}
