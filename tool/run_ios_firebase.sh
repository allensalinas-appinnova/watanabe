#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

config_file="${FIREBASE_CONFIG_FILE:-config/firebase.dev.json}"
if [[ ! -f "$config_file" ]]; then
  echo "Missing $config_file. See docs/flavors.md for Firebase setup." >&2
  exit 1
fi

project_id="$(sed -n 's/.*"FIREBASE_DEV_PROJECT_ID"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$config_file")"
if [[ "$project_id" != "studio-2659953950-840b8" ]]; then
  echo "Refusing to run: expected Firebase project studio-2659953950-840b8." >&2
  exit 1
fi

for key in FIREBASE_DEV_API_KEY FIREBASE_DEV_APP_ID FIREBASE_DEV_MESSAGING_SENDER_ID FIREBASE_DEV_STORAGE_BUCKET; do
  if ! rg -q "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" "$config_file"; then
    echo "Missing or empty required Firebase setting: $key" >&2
    exit 1
  fi
done

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Xcode not found at $DEVELOPER_DIR. Set DEVELOPER_DIR to the Xcode Developer directory." >&2
  exit 1
fi

flutter_bin="${FLUTTER_BIN:-flutter}"
device_arg=()
if [[ $# -gt 0 ]]; then
  device_arg=(-d "$1")
fi

echo "Running iOS against Firebase project $project_id (Firebase emulators disabled)."
"$flutter_bin" run "${device_arg[@]}" \
  --dart-define=APP_ENV=dev \
  --dart-define=USE_FIREBASE_EMULATORS=false \
  --dart-define-from-file="$config_file"
