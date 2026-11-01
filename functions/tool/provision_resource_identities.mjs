import {GoogleAuth} from 'google-auth-library';
import {BigQuery} from '@google-cloud/bigquery';
const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
const identities=['lumio-documents','lumio-resource-jobs'];
for(const id of identities) {
 const email=`${id}@lumiomoney.iam.gserviceaccount.com`;
 try{await client.request({url:`https://iam.googleapis.com/v1/projects/lumiomoney/serviceAccounts/${email}`});}
 catch(e){if(e.response?.status!==404)throw e;await client.request({url:'https://iam.googleapis.com/v1/projects/lumiomoney/serviceAccounts',method:'POST',data:{accountId:id,serviceAccount:{displayName:id}}});}
}
const {data:policy}=await client.request({url:'https://cloudresourcemanager.googleapis.com/v1/projects/lumiomoney:getIamPolicy',method:'POST',data:{}});
for(const id of identities)for(const role of ['roles/datastore.user','roles/serviceusage.serviceUsageConsumer',...(id==='lumio-documents'?['roles/aiplatform.user']:['roles/bigquery.jobUser','roles/eventarc.eventReceiver'])]) {
 const member=`serviceAccount:${id}@lumiomoney.iam.gserviceaccount.com`;
 let b=policy.bindings.find(x=>x.role===role&&!x.condition);if(!b){b={role,members:[]};policy.bindings.push(b);}if(!b.members.includes(member))b.members.push(member);
}
await client.request({url:'https://cloudresourcemanager.googleapis.com/v1/projects/lumiomoney:setIamPolicy',method:'POST',data:{policy}});
const bucketUrl='https://storage.googleapis.com/storage/v1/b/lumiomoney.firebasestorage.app';
const {data:bucketPolicy}=await client.request({url:`${bucketUrl}/iam`});
let objects=bucketPolicy.bindings.find(x=>x.role==='roles/storage.objectUser');if(!objects){objects={role:'roles/storage.objectUser',members:[]};bucketPolicy.bindings.push(objects);}
for(const id of identities){const m=`serviceAccount:${id}@lumiomoney.iam.gserviceaccount.com`;if(!objects.members.includes(m))objects.members.push(m);}
await client.request({url:`${bucketUrl}/iam`,method:'PUT',data:bucketPolicy});
await client.request({url:bucketUrl,method:'PATCH',data:{iamConfiguration:{publicAccessPrevention:'enforced'}}});
const ds=new BigQuery({projectId:'lumiomoney'}).dataset('lumio_billing');const [metadata]=await ds.getMetadata();
const email='lumio-resource-jobs@lumiomoney.iam.gserviceaccount.com';
if(!(metadata.access??[]).some(a=>a.userByEmail===email))await ds.setMetadata({access:[...(metadata.access??[]),{role:'READER',userByEmail:email}]});
console.log('Dedicated runtime identities provisioned with service roles and bucket/dataset scoped access. No user or public grants added.');
