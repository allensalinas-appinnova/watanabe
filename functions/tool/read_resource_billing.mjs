import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {BigQuery} from '@google-cloud/bigquery';
import {resourceBillingQueryOptions,groupBillingRows} from '../lib/resource_costs.js';

if(process.env.GCLOUD_PROJECT!=='lumiomoney'||process.env.FIRESTORE_EMULATOR_HOST)throw Error('explicit-live-review-target-required');
const app=initializeApp({projectId:'lumiomoney'});
try {
 const db=getFirestore();
 const [policy,status]=await Promise.all([db.doc('servicePolicies/billing').get(),db.doc('resourceBilling/status').get()]);
 const options=resourceBillingQueryOptions(policy.get('exportTable'),'lumiomoney');
 const [rows]=await new BigQuery({projectId:'lumiomoney'}).query(options);
 const groups=groupBillingRows(rows);
 console.log(JSON.stringify({mode:'read-only',project:'lumiomoney',window:'previous-seven-complete-UTC-days',
  providerRows:rows.length,serviceDays:groups.length,currencies:[...new Set(groups.map(g=>g.currency))],
  latestUsageDay:groups.map(g=>g.day).sort().at(-1)??null,
  convertedRows:groups.filter(g=>g.netCostUsd!==null).length,missingConversionRows:groups.filter(g=>g.netCostUsd===null).length,
  deployedReconciliation:{available:status.get('available')??false,issue:status.get('issue')??null,
   updatedAt:status.get('updatedAt')?.toDate?.().toISOString()??null},
  note:'Reads export aggregates and configuration only; does not refresh the dashboard or user estimates.'}));
}catch(error){console.error(JSON.stringify({issue:'resource-billing-review-failed',code:error.code??null,status:error.response?.status??null}));process.exitCode=1;}
finally{await deleteApp(app);}
