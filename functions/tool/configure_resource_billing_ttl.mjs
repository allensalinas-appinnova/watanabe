import firestore from '@google-cloud/firestore';

// Only technical billing records; never point this tool at user financial collections.
if(process.env.GCLOUD_PROJECT!=='lumiomoney'||process.env.FIRESTORE_EMULATOR_HOST)throw Error('explicit-live-target-required');
const group=process.argv.find(arg=>arg.startsWith('--collection-group='))?.split('=')[1]??'services';
if(!['services','storageCapacityMeters','accountDeletions','maintenanceJobs','anonymousUsageTotals'].includes(group))throw Error('technical-collection-group-required');
const client=new firestore.v1.FirestoreAdminClient();
try {
 const name=`projects/lumiomoney/databases/(default)/collectionGroups/${group}/fields/expiresAt`;
 const [field]=await client.getField({name});
 if(!process.argv.includes('--apply')||['ACTIVE','CREATING'].includes(field.ttlConfig?.state)) {
  console.log(JSON.stringify({mode:process.argv.includes('--apply')?'unchanged':'dry-run',collectionGroup:group,field:'expiresAt',state:field.ttlConfig?.state??'NOT_CONFIGURED'}));
 }else {
  const [operation]=await client.updateField({field:{name,ttlConfig:{}},updateMask:{paths:['ttl_config']}});
  console.log(JSON.stringify({mode:'requested',operation:operation.name,collectionGroup:group,field:'expiresAt'}));
 }
}catch(error){console.error(JSON.stringify({issue:'billing-ttl-configuration-failed',code:error.code??null}));process.exitCode=1;}
finally{await client.close();}
