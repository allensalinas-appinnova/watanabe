import {GoogleAuth} from 'google-auth-library';
const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
for(const [app,type] of [['1:609783556202:android:a3e7aeb0a4600d42444213','playIntegrityConfig'],['1:609783556202:ios:33975c60988858c5444213','appAttestConfig']]) {
 const name=`projects/609783556202/apps/${app}/${type}`;
 try{const {data}=await client.request({url:`https://firebaseappcheck.googleapis.com/v1/${name}`,method:'PATCH',params:{updateMask:'tokenTtl'},data:{name,tokenTtl:'3600s'}});console.log(JSON.stringify({name:data.name,tokenTtl:data.tokenTtl}));}
 catch(e){console.log(JSON.stringify({name,status:e.response?.status,issue:e.response?.data?.error?.status}));}
}
