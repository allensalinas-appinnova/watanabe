#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

device_id="${1:?Usage: bash tool/run_android_qa.sh <physical-android-id>}"
adb_bin="${ADB_BIN:-adb}"
flutter_bin="${FLUTTER_BIN:-flutter}"
config_file="${FIREBASE_CONFIG_FILE:-config/firebase.dev.android.json}"
if [[ "$device_id" == emulator-* ]] || [[ "$("$adb_bin" -s "$device_id" shell getprop ro.kernel.qemu | tr -d '\r')" == "1" ]]; then
  echo 'A physical Android device is required.' >&2
  exit 1
fi
if [[ "$("$adb_bin" -s "$device_id" get-state)" != device ]]; then
  echo 'Android is not connected and authorized.' >&2
  exit 1
fi
python3 - "$config_file" <<'PY'
import json, sys
config = json.load(open(sys.argv[1]))
native = json.load(open('android/app/google-services.json'))
if config.get('FIREBASE_DEV_PROJECT_ID') != 'lumiomoney' or native['project_info']['project_id'] != 'lumiomoney':
    raise SystemExit('Expected lumiomoney in both Dart and native Android configuration.')
PY
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
export PATH="$JAVA_HOME/bin:$PATH"
"$flutter_bin" run -d "$device_id" --target=test_driver/main_qa.dart \
  --dart-define=APP_ENV=dev --dart-define=USE_FIREBASE_EMULATORS=false \
  --dart-define-from-file="$config_file"
