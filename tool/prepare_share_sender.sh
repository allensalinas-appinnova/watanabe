#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
device="${1:-emulator-5554}"
[[ "$device" == emulator-* ]] || { echo 'Emulator only' >&2; exit 1; }
python3 - <<'PY'
import base64,pathlib,re
folder=pathlib.Path('tool/qa_share_sender/build/generated/assets');folder.mkdir(parents=True,exist_ok=True)
s=pathlib.Path('integration_test/fixtures/purchase_pdf.dart').read_text()
a=re.search(r"purchasePdfBase64\s*=\s*((?:'[^']*'\s*)+);",s).group(1)
folder.joinpath('receipt.pdf').write_bytes(base64.b64decode(''.join(re.findall("'([^']*)'",a))))
folder.joinpath('receipt.png').write_bytes(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGP4DwQACfsD/fteaysAAAAASUVORK5CYII='))
PY
android/gradlew -p tool/qa_share_sender --console=plain assembleDebug
adb -s "$device" install -r tool/qa_share_sender/build/outputs/apk/debug/LumioQAShareSender-debug.apk
