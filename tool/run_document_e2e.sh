#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! java -version >/dev/null 2>&1 && [[ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"
fi
npm --prefix functions run build
platform="${E2E_PLATFORM:-android}"
if [[ "$platform" == "ios" ]]; then
  test_command="flutter drive --driver=test_driver/document_import_driver.dart --target=integration_test/document_import_flow_test.dart -d ${E2E_DEVICE:?Set E2E_DEVICE to an iOS Simulator UUID} --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1"
else
  test_command="flutter drive --driver=test_driver/document_import_driver.dart --target=integration_test/document_import_flow_test.dart -d ${E2E_DEVICE:-emulator-5554} --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2"
fi
firebase emulators:exec --project demo-clearbudget --only auth,firestore,storage,functions \
 "npm --prefix functions run seed:catalog && node functions/tool/seed_document_emulator.mjs && $test_command"
