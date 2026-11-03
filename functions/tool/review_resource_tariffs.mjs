import {pathToFileURL} from 'node:url';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {GoogleAuth} from 'google-auth-library';
import {configureReviewedResourceTariffs} from '../lib/resource_tariffs.js';

export async function reviewResourceTariffs({apply=false}={}) {
 if(process.env.GCLOUD_PROJECT!=='lumiomoney'||process.env.FIRESTORE_EMULATOR_HOST)throw Error('explicit-live-review-target-required');
 const app=initializeApp({projectId:'lumiomoney'},`resource-review-${Date.now()}`);
 try {
  const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
  const [database,bucket,service]=await Promise.all([
   client.request({url:'https://firestore.googleapis.com/v1/projects/lumiomoney/databases/(default)'}),
   client.request({url:'https://storage.googleapis.com/storage/v1/b/lumiomoney.firebasestorage.app'}),
   client.request({url:'https://run.googleapis.com/v2/projects/lumiomoney/locations/us-central1/services/mutatedocumentimport'}),
  ]);
  const metadata={firestoreRegion:database.data.locationId,firestoreEdition:database.data.databaseEdition,
   bucketRegion:String(bucket.data.location).toLowerCase(),storageClass:bucket.data.storageClass,
   functionsBillingMode:service.data.template?.containers?.[0]?.resources?.cpuIdle===false?'instance-based':'request-based'};
  const db=getFirestore(app);
  const plan=await configureReviewedResourceTariffs(db,metadata,apply);
  return {mode:apply?'applied':'dry-run',reviewedFunction:'mutatedocumentimport',metadata,create:plan.create.map(t=>t.id),unchanged:plan.unchanged,
   requiredRuntimeConfiguration:{RESOURCE_FIRESTORE_LOCATION:metadata.firestoreRegion,RESOURCE_FUNCTIONS_BILLING_MODE:'request-based'},
   note:'Storage capacity pricing requires object-class/location evidence on the event; the bucket default alone is insufficient.'};
 } finally {await deleteApp(app);}
}

if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href) {
 try {console.log(JSON.stringify(await reviewResourceTariffs({apply:process.argv.includes('--apply')})));}
 catch(error){console.error(JSON.stringify({issue:'resource-tariff-review-failed',code:error.code??null,message:error.response?null:error.message}));process.exitCode=1;}
}
