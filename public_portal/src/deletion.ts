import {initializeApp} from 'firebase/app';
import {initializeAppCheck, ReCaptchaV3Provider} from 'firebase/app-check';
import {getAuth, signInWithEmailAndPassword, signInWithPopup, GoogleAuthProvider, OAuthProvider, signOut, onAuthStateChanged, reauthenticateWithPopup, revokeAccessToken} from 'firebase/auth';
import {getFunctions, httpsCallable} from 'firebase/functions';
import {getFirestore, getDoc, doc} from 'firebase/firestore';

export async function prepareDeletion() {
  const response = await fetch('/__/firebase/init.json');
  if (!response.ok) throw Error('configuration-unavailable');
  const app = initializeApp(await response.json());
  const env = import.meta as unknown as {env: Record<string,string|undefined>};
  const key = env.env.VITE_APP_CHECK_WEB_SITE_KEY;
  if (key) initializeAppCheck(app,{provider:new ReCaptchaV3Provider(key),isTokenAutoRefreshEnabled:true});
  const auth=getAuth(app), db=getFirestore(app), functions=getFunctions(app,'us-central1');
  const status=document.querySelector<HTMLElement>('#status')!, section=document.querySelector<HTMLElement>('#identity')!;
  const deletion=document.querySelector<HTMLButtonElement>('#delete')!, confirmation=document.querySelector<HTMLInputElement>('#confirm')!;
  let requestId=crypto.randomUUID(); let uid:string|null=null, generation:number|null=null, busy=false;
  const fail=()=>{status.textContent='No pudimos confirmar la acción. Inicia sesión nuevamente y reintenta. No compartas contraseñas con soporte.';};
  const apple=document.querySelector<HTMLButtonElement>('#apple')!;
  apple.hidden=env.env.VITE_APPLE_ENABLED!=='true';
  document.querySelector('#login')!.addEventListener('submit',event=>{
    event.preventDefault();
    const email=document.querySelector<HTMLInputElement>('#email')!.value;
    const password=document.querySelector<HTMLInputElement>('#password')!;
    void signInWithEmailAndPassword(auth,email,password.value).catch(fail).finally(()=>{password.value='';});
  });
  document.querySelector('#google')!.addEventListener('click',()=>{void signInWithPopup(auth,new GoogleAuthProvider()).catch(fail);});
  apple.addEventListener('click',()=>{void signInWithPopup(auth,new OAuthProvider('apple.com')).catch(fail);});
  document.querySelector('#logout')!.addEventListener('click',()=>{if(!busy)void signOut(auth);});
  confirmation.addEventListener('change',()=>{deletion.disabled=busy||!confirmation.checked||generation===null||!key;});
  onAuthStateChanged(auth,user=>{
    const nextUid=user?.uid??null; if(nextUid!==uid)requestId=crypto.randomUUID();
    uid=nextUid; generation=null; confirmation.checked=false;deletion.disabled=true;section.hidden=!user;
    document.querySelector('#account')!.textContent=user?.email??'Cuenta sin correo';
    if(!key)status.textContent='La verificación de esta instalación web no está configurada. La eliminación está deshabilitada.';
    if(user)void getDoc(doc(db,'users',user.uid)).then(profile=>{
      if(auth.currentUser?.uid!==user.uid)return;
      generation=profile.exists()?(profile.data().dataGeneration??0):0;
    }).catch(fail);
  });
  deletion.addEventListener('click',()=>{void (async()=>{
    if(busy||!key||!uid||generation===null||!confirmation.checked||auth.currentUser?.uid!==uid)return;
    const owner=uid, commandId=requestId, commandGeneration=generation;
    busy=true; deletion.disabled=true;
    try{
      if (auth.currentUser.providerData.some(provider=>provider.providerId==='apple.com')) {
        const fresh=await reauthenticateWithPopup(auth.currentUser,new OAuthProvider('apple.com'));
        const token=OAuthProvider.credentialFromResult(fresh)?.accessToken;
        if(!token||auth.currentUser?.uid!==owner)throw Error('apple-revocation-unavailable');
        await revokeAccessToken(auth,token);
      }
      const result=await httpsCallable(functions,'requestAccountDeletion')({requestId:commandId,expectedOwnerUid:owner,expectedGeneration:commandGeneration,confirmed:true});
      if((result.data as {status?:string}).status!=='accepted')throw Error('not-accepted');
      if(auth.currentUser?.uid!==owner){busy=false;deletion.disabled=!confirmation.checked;return;}
      status.textContent='Tu solicitud fue aceptada. La cuenta está bloqueada mientras termina la eliminación.';
      await signOut(auth);
      document.querySelectorAll<HTMLButtonElement>('button').forEach(b=>{b.disabled=true;});
    }catch{fail();busy=false;deletion.disabled=!confirmation.checked;}
  })();});
}
