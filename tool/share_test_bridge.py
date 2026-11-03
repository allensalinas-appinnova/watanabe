"""Emulator-only host bridge: exercise Android's actual chooser using synthetic fixtures."""
import http.server, subprocess, os, re, time, xml.etree.ElementTree as ET
ADB=os.environ.get('ADB_BIN','adb'); DEVICE=os.environ.get('E2E_DEVICE','emulator-5554')
if not DEVICE.startswith('emulator-') or os.environ.get('GCLOUD_PROJECT')!='demo-clearbudget':
    raise SystemExit('Explicit Emulator target required')
def adb(*args): return subprocess.check_output([ADB,'-s',DEVICE,*args],stderr=subprocess.STDOUT,text=True,timeout=25)
def share(kind):
    adb('shell','am','force-stop','co.appinnova.lumio.qa.sender')
    adb('shell','am','start','-W','-n','co.appinnova.lumio.qa.sender/.MainActivity','--es','kind',kind)
    for attempt in range(25):
        try:
            adb('shell','uiautomator','dump','/sdcard/lumio-qa-chooser.xml')
            tree=ET.fromstring(adb('shell','cat','/sdcard/lumio-qa-chooser.xml'))
            node=next((n for n in tree.iter('node') if n.get('text')=='LumioMoney'),None)
            if node is not None:
                x1,y1,x2,y2=map(int,re.findall(r'\d+',node.get('bounds')))
                adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2)); return
        except (subprocess.CalledProcessError,ET.ParseError): pass
        if attempt in [2,7,12]:
            size=adb('shell','wm','size');w,h=map(int,re.findall(r'(\d+)x(\d+)',size)[-1])
            adb('shell','input','swipe',str(w//2),str(int(h*.85)),str(w//2),str(int(h*.42)),'400')
        time.sleep(.2)
    raise RuntimeError('LumioMoney not offered by native chooser')
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def do_GET(self):
        if self.path=='/capture':
            import pathlib
            out=pathlib.Path('artifacts/document-imports/failure.png');out.parent.mkdir(parents=True,exist_ok=True)
            out.write_bytes(subprocess.check_output([ADB,'-s',DEVICE,'exec-out','screencap','-p']))
            self.send_response(200);self.end_headers();return
        if self.path not in ['/share/pdf','/share/image']:
            self.send_error(404);return
        try: share('pdf' if self.path.endswith('pdf') else 'image');self.send_response(200);self.end_headers();self.wfile.write(b'chooser-completed')
        except Exception:
            self.send_response(500);self.end_headers();self.wfile.write(b'native-share-failed')
if __name__=='__main__':
    http.server.HTTPServer(('127.0.0.1',59179),Handler).serve_forever()
