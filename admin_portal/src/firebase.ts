import {getApp, getApps, initializeApp} from 'firebase/app';
import {getAuth} from 'firebase/auth';
import {connectAuthEmulator} from 'firebase/auth';
import {getFunctions, connectFunctionsEmulator} from 'firebase/functions';

const config = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};
export const configurationReady = Object.values(config).every(Boolean);
const app = getApps().length ? getApp() : initializeApp(config);
export const auth = getAuth(app);
export const functions = getFunctions(app, 'us-central1');

if (import.meta.env.VITE_USE_FIREBASE_EMULATORS === 'true') {
  connectAuthEmulator(auth, import.meta.env.VITE_AUTH_EMULATOR_URL || 'http://127.0.0.1:59199', {disableWarnings: true});
  connectFunctionsEmulator(functions, '127.0.0.1', 59192);
}
