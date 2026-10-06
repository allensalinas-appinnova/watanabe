#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

if ! java -version >/dev/null 2>&1 && command -v brew >/dev/null 2>&1 && brew --prefix openjdk@21 >/dev/null 2>&1; then
  export JAVA_HOME="$(brew --prefix openjdk@21)"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

if ! java -version >/dev/null 2>&1; then
  echo "Java is required by the Firebase Auth and Firestore emulators." >&2
  echo "Install a supported JDK and make its java executable available on PATH." >&2
  exit 1
fi

device="${1:-${E2E_DEVICE:-emulator-5554}}"
target_platform="${E2E_PLATFORM:-android}"
device_arg="$(printf '%q' "$device")"

case "$target_platform" in
  android)
    emulator_host="${FIREBASE_EMULATOR_HOST:-10.0.2.2}"
    app_test_command="flutter test integration_test/canonical_finance_flow_test.dart -d $device_arg"
    ;;
  ios)
    emulator_host="${FIREBASE_EMULATOR_HOST:-127.0.0.1}"
    app_test_command="flutter drive --driver=test_driver/integration_test.dart --target=integration_test/canonical_finance_flow_test.dart -d $device_arg"
    ;;
  *)
    echo "E2E_PLATFORM must be either android or ios (received: $target_platform)." >&2
    exit 1
    ;;
esac

host_arg="$(printf '%q' "$emulator_host")"

seed_command="npm --prefix functions run seed:catalog"

npx -y firebase-tools@latest emulators:exec \
  --project demo-clearbudget \
  --only auth,firestore,storage,functions \
  --config firebase.json \
  "$seed_command && $app_test_command --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=$host_arg"
