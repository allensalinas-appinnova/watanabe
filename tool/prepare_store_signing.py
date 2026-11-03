"""CI-only signing material. Secrets stay in environment/private temporary files, never stdout."""
import base64
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import zipfile
import io

root = Path(__file__).resolve().parents[1]
temporary = Path(os.environ.get('RUNNER_TEMP', '/tmp')) / 'lumio-store-signing'
keychain = temporary / 'release.keychain-db'
if '--cleanup' in sys.argv:
    import shutil
    if sys.platform == 'darwin' and keychain.exists():
        subprocess.run(['security', 'delete-keychain', str(keychain)], capture_output=True)
    shutil.rmtree(temporary, ignore_errors=True)
    raise SystemExit(0)
if os.environ.get('CI') != 'true':
    raise SystemExit('This signing helper runs only on ephemeral CI runners.')
platform = os.environ['RELEASE_PLATFORM']
environment = os.environ['RELEASE_ENVIRONMENT']
if platform not in ('android', 'ios') or environment not in ('prod', 'staging'):
    raise SystemExit('Explicit supported platform and environment required.')
required = ['RELEASE_CONFIG'] + (['ANDROID_KEYSTORE', 'ANDROID_PROPERTIES'] if platform == 'android' else ['IOS_CERTIFICATE', 'IOS_CERTIFICATE_PASSWORD', 'IOS_PROFILES'])
if any(not os.environ.get(key) for key in required):
    raise SystemExit('Required release configuration/signing secrets are missing; no artefact will be generated.')
temporary.mkdir(mode=0o700, parents=True, exist_ok=True)
def private(path, content):
    path.write_bytes(content)
    path.chmod(0o600)
config = json.loads(os.environ['RELEASE_CONFIG'])
if config.get('APP_ENV') != environment:
    raise SystemExit('Release configuration environment mismatch.')
private(root / 'config' / f'firebase.{environment}.{platform}.json', json.dumps(config).encode())
if platform == 'android':
    keystore = temporary / 'upload.jks'
    private(keystore, base64.b64decode(os.environ['ANDROID_KEYSTORE'], validate=True))
    properties = '\n'.join(line for line in os.environ['ANDROID_PROPERTIES'].splitlines() if not line.startswith('storeFile='))
    private(root / 'android' / 'key.properties', (properties + '\nstoreFile=' + str(keystore) + '\n').encode())
else:
    certificate = temporary / 'certificate.p12'
    private(certificate, base64.b64decode(os.environ['IOS_CERTIFICATE'], validate=True))
    password = secrets.token_urlsafe(32)
    commands = [
        ['security', 'create-keychain', '-p', password, str(keychain)],
        ['security', 'set-keychain-settings', '-lut', '21600', str(keychain)],
        ['security', 'unlock-keychain', '-p', password, str(keychain)],
        ['security', 'import', str(certificate), '-P', os.environ['IOS_CERTIFICATE_PASSWORD'], '-T', '/usr/bin/codesign', '-T', '/usr/bin/security', '-t', 'cert', '-f', 'pkcs12', '-k', str(keychain)],
        ['security', 'list-keychains', '-d', 'user', '-s', str(keychain)],
        ['security', 'set-key-partition-list', '-S', 'apple-tool:,apple:', '-k', password, str(keychain)],
    ]
    for command in commands:
        result = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if result.returncode:
            raise SystemExit('Signing setup failed; inspect protected CI configuration, not secret values.')
    profiles = Path.home() / 'Library' / 'MobileDevice' / 'Provisioning Profiles'
    profiles.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(base64.b64decode(os.environ['IOS_PROFILES'], validate=True))) as archive:
        for name in archive.namelist():
            if name.endswith('.mobileprovision'):
                private(profiles / Path(name).name, archive.read(name))
