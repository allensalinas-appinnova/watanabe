import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {observeStorageCapacity,storageCapacityScope} from '../lib/storage_capacity.js';

// Observation only: no inventory cleanup, quota repairs, file changes or financial writes.
if(process.env.GCLOUD_PROJECT!=='lumiomoney'||process.env.FIRESTORE_EMULATOR_HOST)throw Error('explicit-live-target-required');
const app=initializeApp({projectId:'lumiomoney',storageBucket:'lumiomoney.firebasestorage.app'});
try{
 const bucket=getStorage(app).bucket();const [bucketMetadata]=await bucket.getMetadata();
 process.env.RESOURCE_STORAGE_BUCKET=bucket.name;process.env.RESOURCE_STORAGE_LOCATION=String(bucketMetadata.location).toLowerCase();
 const db=getFirestore();const subjects=await db.collection('resourceUsage').get();let observed=0,unavailable=0;
 for(const subject of subjects.docs){
  const objects=await subject.ref.collection('objects').get();
  for(const object of objects.docs){
   const data=object.data();if(data.deleted)continue;
   if(typeof data.storagePath!=='string'||!data.storagePath.startsWith(`users/${subject.id}/documentImports/`)){unavailable++;continue;}
   try{
    const [metadata]=await bucket.file(data.storagePath,{generation:data.objectGeneration}).getMetadata();
    if(String(metadata.generation)!==String(data.objectGeneration)||Number(metadata.size)!==data.bytes){unavailable++;continue;}
    await observeStorageCapacity(db,subject.id,object.id,storageCapacityScope(metadata));observed++;
   }catch(error){if(error.code===404){unavailable++;continue;}throw error;}
  }
 }
 console.log(JSON.stringify({mode:'technical-meter-observation',bucketRegion:process.env.RESOURCE_STORAGE_LOCATION,observedObjects:observed,unavailableObjects:unavailable,
  note:'First observations establish a baseline; they do not invent historical storage costs.'}));
}catch(error){console.error(JSON.stringify({issue:'resource-storage-observation-failed',code:error.code??null}));process.exitCode=1;}
finally{await deleteApp(app);}
