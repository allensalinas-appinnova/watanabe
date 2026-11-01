import {GoogleAuth} from 'google-auth-library';
const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
for(const service of ['firebasestorage.googleapis.com','firebaseappcheck.googleapis.com']) {
 const {data:op}=await client.request({method:'POST',url:`https://serviceusage.googleapis.com/v1/projects/lumiomoney/services/${service}:enable`,data:{}});
 if(op.name && !op.done) for(let i=0;i<20;i++){await new Promise(r=>setTimeout(r,1000));const {data}=await client.request({url:`https://serviceusage.googleapis.com/v1/${op.name}`});if(data.done)break;}
}
const url='https://firebasestorage.googleapis.com/v1alpha/projects/lumiomoney/defaultBucket';
try {
 const {data}=await client.request({url:'https://firebasestorage.googleapis.com/v1alpha/projects/lumiomoney/defaultBucket'});
 console.log(JSON.stringify({existing:data.name,location:data.location}));
} catch(e) {
 if(e.response?.status!==404)throw e;
 const {data}=await client.request({url,method:'POST',data:{location:'US-CENTRAL1'}});
 console.log(JSON.stringify({created:data.name,location:data.location,bucket:data.bucket?.name}));
}
