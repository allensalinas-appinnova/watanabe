// Synthetic native-share fixture. Never run against a real Firebase project.
import fs from 'node:fs';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
if (process.env.GCLOUD_PROJECT !== 'demo-clearbudget' || !process.env.FIREBASE_AUTH_EMULATOR_HOST || !process.env.FIRESTORE_EMULATOR_HOST) throw Error('Emulators required');
initializeApp({projectId:'demo-clearbudget'});
const email='native-share@example.test', uid='qa-native-share';
try { await getAuth().createUser({uid,email,password:'Synthetic-QA-12345'}); } catch (error) { if (error.code !== 'auth/uid-already-exists') throw error; } // Emulator-only synthetic password. gitleaks:allow
await getFirestore().doc(`users/${uid}`).set({onboardingStatus:'complete',dataGeneration:0,locale:'en',countryCode:'CO',defaultCurrency:'COP',categoryCatalogVersion:0,timeZone:'America/Bogota'});
fs.mkdirSync('artifacts/document-imports',{recursive:true});
fs.writeFileSync('artifacts/document-imports/native-fixture.json',JSON.stringify({project:'demo-clearbudget',qaEmail:email}));
console.log('Synthetic native-share identity ready');
