import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
if(process.env.GCLOUD_PROJECT!=='demo-clearbudget'||!process.env.FIRESTORE_EMULATOR_HOST)throw Error('Emulator only');
initializeApp({projectId:'demo-clearbudget'});
await getFirestore().doc('servicePolicies/documentImports').set({enabled:true});
await getFirestore().doc('servicePolicies/documentImportTestFixture').set({extractionsByMime:{'application/pdf':{supported:true,amountMinor:39000,currency:'COP',date:'2026-11-01',description:'QA synthetic merchant purchase paid by bank transfer'}},extraction:{supported:true,amountMinor:25000,currency:'COP',date:'2026-10-20',description:'QA synthetic receipt',categoryId:'food',accountHint:{kind:'account',lastFour:'9999'}}});
console.log('Synthetic document provider and policy seeded in Emulator.');
