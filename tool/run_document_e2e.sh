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
  test_command="bash tool/run_document_share_ios.sh"
else
  test_command="bash tool/run_document_share_android.sh"
fi
firebase emulators:exec --project demo-clearbudget --only auth,firestore,storage,functions \
 "node functions/lib/seed_category_catalog.js && node functions/tool/seed_document_emulator.mjs && $test_command"
