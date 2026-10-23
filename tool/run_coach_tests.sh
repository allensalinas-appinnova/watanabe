#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

# Shared checkout: never launch a second Xcode build against the same cache.
if ps -axo args= | awk -v root="$project_root" \
  '$1 ~ /xcodebuild$/ && index($0, root) { busy = 1 } END { exit !busy }'; then
  echo 'An Xcode operation is active in this checkout. Rerun after it finishes.' >&2
  exit 1
fi

# Default: reuse running Auth/Firestore emulators without clearing shared data.
# COACH_START_EMULATORS=1 starts an isolated demo project run instead.
device="${1:-${E2E_DEVICE:-emulator-5554}}"
auth_port="${FIREBASE_AUTH_EMULATOR_PORT:-59199}"
firestore_port="${FIRESTORE_EMULATOR_PORT:-59180}"
case "${E2E_PLATFORM:-android}" in
  android)
    emulator_host="${FIREBASE_EMULATOR_HOST:-10.0.2.2}"
    test_command=(flutter test integration_test/coach_persistence_test.dart)
    ;;
  ios)
    emulator_host="${FIREBASE_EMULATOR_HOST:-127.0.0.1}"
    test_command=(flutter drive --driver=test_driver/integration_test.dart
      --target=integration_test/coach_persistence_test.dart)
    ;;
  *) echo 'E2E_PLATFORM must be android or ios.' >&2; exit 1 ;;
esac

test_command+=( -d "$device" --no-pub
  --dart-define=USE_FIREBASE_EMULATORS=true
  "--dart-define=FIREBASE_AUTH_EMULATOR_PORT=$auth_port"
  "--dart-define=FIRESTORE_EMULATOR_PORT=$firestore_port"
  "--dart-define=FIREBASE_EMULATOR_HOST=$emulator_host")

if [[ "${COACH_START_EMULATORS:-0}" == 1 ]]; then
  if [[ "$auth_port" != 59199 || "$firestore_port" != 59180 ]]; then
    echo 'Custom ports require already running emulators; firebase.json uses 59199/59180.' >&2
    exit 1
  fi
  if ! java -version >/dev/null 2>&1 && command -v brew >/dev/null 2>&1; then
    export JAVA_HOME="$(brew --prefix openjdk@21)"
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
  command_text="$(printf '%q ' "${test_command[@]}")"
  exec npx -y firebase-tools@latest emulators:exec \
    --project demo-clearbudget --only auth,firestore --config firebase.json "$command_text"
fi

for port in "$auth_port" "$firestore_port"; do
  if ! curl --fail --silent --max-time 5 "http://${COACH_PREFLIGHT_HOST:-127.0.0.1}:$port/" >/dev/null; then
    echo "Auth and Firestore must both be running (missing port $port)." >&2
    echo 'For an isolated run: COACH_START_EMULATORS=1 bash tool/run_coach_tests.sh [device]' >&2
    exit 1
  fi
done

exec "${test_command[@]}"
