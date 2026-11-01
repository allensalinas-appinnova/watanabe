import {GoogleAuth} from 'google-auth-library';
const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
const {data}=await client.request({method:'POST',url:'https://serviceusage.googleapis.com/v1/projects/lumiomoney/services/aiplatform.googleapis.com:enable',data:{}});
console.log(JSON.stringify({operation:data.name,done:data.done??false}));
