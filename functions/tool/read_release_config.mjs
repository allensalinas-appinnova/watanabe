import {GoogleAuth} from 'google-auth-library';
const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
for(const id of ['mutateDebt','mutateOperation','resetUserData']) {
 const {data}=await client.request({url:`https://cloudfunctions.googleapis.com/v2/projects/lumiomoney/locations/us-central1/functions/${id}`});
 const env=data.serviceConfig?.environmentVariables??{};
 console.log(JSON.stringify({function:id,state:data.state,runtimeAccount:data.serviceConfig?.serviceAccountEmail,flags:Object.fromEntries(Object.entries(env).filter(([key])=>['DEBT_MUTATIONS_ENABLED','FUNCTIONS_CONTROL_API','DOCUMENT_AI_MODEL'].includes(key)))}));
}
