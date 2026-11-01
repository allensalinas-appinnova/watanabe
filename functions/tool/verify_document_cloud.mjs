import {GoogleAuth} from 'google-auth-library';
const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
for(const [name,url] of Object.entries({vertex:'https://serviceusage.googleapis.com/v1/projects/lumiomoney/services/aiplatform.googleapis.com',bigquery:'https://bigquery.googleapis.com/bigquery/v2/projects/lumiomoney/datasets',buckets:'https://storage.googleapis.com/storage/v1/b?project=lumiomoney',appcheck:'https://firebaseappcheck.googleapis.com/v1/projects/609783556202/apps'})) {
 try {const {data}=await client.request({url});console.log(JSON.stringify({name,...(name==='vertex'?{state:data.state}:name==='buckets'?{buckets:data.items?.map(x=>({name:x.name,location:x.location}))}:name==='bigquery'?{datasets:data.datasets?.map(x=>x.datasetReference.datasetId)}:{apps:data.apps?.map(x=>({name:x.name}))})}));}
 catch(e){console.log(JSON.stringify({name,status:e.response?.status,issue:e.response?.data?.error?.status}));}
}
