import {initializeApp} from 'firebase-admin/app';
// Historical bootstrap only. Reviewed cost rates use review_resource_tariffs.mjs (dry-run by default).
import {getFirestore} from 'firebase-admin/firestore';
if(process.env.GCLOUD_PROJECT!=='lumiomoney'||process.env.FIRESTORE_EMULATOR_HOST)throw Error('Explicit live target required');
initializeApp({projectId:'lumiomoney'});const db=getFirestore();
const rates=[['input','billableInputTokens',0.75/1000000],['output','billableOutputTokens',3.75/1000000],['cached','cachedTokens',0.075/1000000]];
for(const [suffix,unit,usdPerUnit] of rates)await db.doc(`resourceTariffs/gemini38-global-20261101-${suffix}`).set({service:'ai',model:'gemini-3.8-flash',region:'global',unit,usdPerUnit,effectiveFrom:'2026-11-01T00:00:00Z',effectiveUntil:'2027-01-01T00:00:00Z',source:'https://cloud.google.com/gemini-enterprise-agent-platform/generative-ai/pricing',quality:'estimated'});
await db.doc('servicePolicies/billing').set({exportTable:'lumiomoney.lumio_billing.gcp_billing_export_v1_014C92_1DF729_146ED1'},{merge:true});
// Never enable imports from provisioning. Qualification enables them separately.
const policy=await db.doc('servicePolicies/documentImports').get();
if(!policy.exists)await policy.ref.create({enabled:false,dailyAnalyses:5,monthlyAnalyses:20,attachmentBytes:100000000,temporaryFiles:2,temporaryBytes:20000000,imageBytes:5000000,pdfBytes:10000000,pdfPages:3});
console.log('Versioned AI tariffs and disabled document policy prepared.');
