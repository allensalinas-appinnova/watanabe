#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "${GCLOUD_PROJECT:-}" == demo-clearbudget ]] || { echo 'Emulator only' >&2; exit 1; }
export ANDROID_HOME="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
export E2E_DEVICE="${E2E_DEVICE:-emulator-5554}"
bash tool/prepare_share_sender.sh "$E2E_DEVICE"
python3 tool/share_test_bridge.py > /tmp/lumio-share-bridge.log 2>&1 &
bridge_pid=$!
trap 'kill "$bridge_pid" 2>/dev/null || true' EXIT
flutter drive --driver=test_driver/document_import_driver.dart --target=integration_test/document_import_flow_test.dart \
  -d "$E2E_DEVICE" --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2 --dart-define=QA_NATIVE_SHARE=true
cp artifacts/document-imports/result.json artifacts/document-imports/result-android.json
# A separate normal entry point proves the initial-intent route with the process stopped.
flutter build apk --debug --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
adb -s "$E2E_DEVICE" install -r build/app/outputs/flutter-apk/app-debug.apk
python3 tool/verify_cold_share_android.py
