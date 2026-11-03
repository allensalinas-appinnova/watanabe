"""Native cold-start share check on the synthetic Emulator user; no analysis/posting."""
import hashlib,json,os,re,time,urllib.request,xml.etree.ElementTree as ET,pathlib,subprocess
from share_test_bridge import adb,share,DEVICE,ADB

def financial_snapshot():
    result={}
    for collection in ['operations','accounts']:
        body={'structuredQuery':{'from':[{'collectionId':collection,'allDescendants':True}]}}
        req=urllib.request.Request('http://127.0.0.1:59180/v1/projects/demo-clearbudget/databases/(default)/documents:runQuery',
            data=json.dumps(body).encode(),headers={'Content-Type':'application/json','Authorization':'Bearer owner'})
        rows=json.load(urllib.request.urlopen(req));docs=[r['document'] for r in rows if 'document' in r]
        normalized=sorted(docs,key=lambda d:d['name'])
        result[collection]={'count':len(docs),'digest':hashlib.sha256(json.dumps(normalized,sort_keys=True).encode()).hexdigest()}
    return result

def labels():
    adb('shell','rm','-f','/sdcard/lumio-qa-cold.xml')
    adb('shell','uiautomator','dump','/sdcard/lumio-qa-cold.xml')
    try: tree=ET.fromstring(adb('shell','cat','/sdcard/lumio-qa-cold.xml'))
    except (subprocess.CalledProcessError,ET.ParseError): return []
    return [(n,(n.get('text','')+' '+n.get('content-desc','')).strip()) for n in tree.iter('node')]

data=json.loads(pathlib.Path(os.environ.get('QA_NATIVE_FIXTURE','artifacts/document-imports/result.json')).read_text())
email=data['qaEmail']
if data['project']!='demo-clearbudget' or not email.endswith('@example.test'): raise SystemExit('Synthetic Emulator identity required')
login_attempted=False
invitation_accepted=False
before=financial_snapshot()
adb('shell','am','force-stop','com.appinnova.lumiomoney')
# This Emulator-only check starts unauthenticated to cover receipt handoff through login.
adb('shell','pm','clear','com.appinnova.lumiomoney')
share('pdf')
ready=False
for _ in range(45):
    nodes=labels()
    if not nodes: time.sleep(.2);continue
    fields=[n for n,text in nodes if n.get('class')=='android.widget.EditText']
    if any(text in ['Shared file','Archivo compartido','Arquivo compartilhado'] for n,text in nodes):
        login=next((n for n,text in nodes if text in ['Log in','Iniciar sesión','Entrar'] and n.get('clickable')=='true'),None)
        if login is not None:
            x1,y1,x2,y2=map(int,re.findall(r'\d+',login.get('bounds')))
            adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2));invitation_accepted=True;continue
    if invitation_accepted and len(fields)>=2 and not login_attempted:
        node=fields[0]
        x1,y1,x2,y2=map(int,re.findall(r'\d+',node.get('bounds')))
        adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
        time.sleep(.3)
        adb('shell','input','text',email)
        adb('shell','input','keyevent','61')
        adb('shell','input','text','Synthetic-QA-12345')
        ime=adb('shell','dumpsys','input_method')
        if 'mInputShown=true' in ime or 'isInputViewShown=true' in ime:
            adb('shell','input','keyevent','4')
        for attempt in range(5):
            nodes=labels()
            buttons=[n for n,text in nodes if text=='Log in' and n.get('clickable')=='true']
            if buttons:
                node=max(buttons,key=lambda n:int(re.findall(r'\d+',n.get('bounds'))[1]))
                x1,y1,x2,y2=map(int,re.findall(r'\d+',node.get('bounds')))
                adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2));login_attempted=True;break
            time.sleep(.3)
        continue
    # Explicitly accept account confirmation / the discard-old-draft choices on this disposable Emulator session only.
    action=next((n for n,text in nodes if text in ['Continue','Continuar','Use new file','Usar el nuevo','Usar o novo']),None)
    if action is not None:
        x1,y1,x2,y2=map(int,re.findall(r'\d+',action.get('bounds')))
        adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2));continue
    if any(
        label in text
        for _, text in nodes
        for label in (
            'Prepare expense',
            'Preparar gasto',
            'Preparar despesa',
        )
    ):
        ready=True;break
    time.sleep(.2)
if not ready:
    pathlib.Path('artifacts/document-imports/cold-failure.png').write_bytes(subprocess.check_output([ADB,'-s',DEVICE,'exec-out','screencap','-p'],timeout=25))
    raise SystemExit('Cold share did not reach receipt preview')
if not login_attempted or not invitation_accepted: raise SystemExit('Cold share did not exercise the login handoff')
after=financial_snapshot()
if before!=after:raise SystemExit('Cold share changed financial records')
folder=pathlib.Path('artifacts/document-imports');folder.mkdir(parents=True,exist_ok=True)
(folder/'native-cold-share.png').write_bytes(subprocess.check_output([ADB,'-s',DEVICE,'exec-out','screencap','-p'],timeout=25))
(folder/'cold-share.json').write_text(json.dumps({'project':'demo-clearbudget','nativeChooser':True,'coldStartPreview':True,'signInFormSubmitted':login_attempted,'sharedFileInvitationAccepted':invitation_accepted,'financialRecordsUnchanged':True,'operations':after['operations']['count']}))
print('Cold native share reached preview without changing financial records')
