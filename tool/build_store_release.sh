#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
environment="${1:?Specify staging or prod explicitly}"
platform="${2:?Specify android or ios}"
[[ "$(node -p 'process.versions.node.split(".")[0]')" == 22 ]] || { echo 'Node 22 is required.' >&2; exit 1; }
expected_flutter="$(cat .flutter-version)"
actual_flutter="$(flutter --version --machine | python3 -c 'import json,sys;print(json.load(sys.stdin)["frameworkVersion"])')"
[[ "$actual_flutter" == "$expected_flutter" ]] || { echo 'Use the pinned Flutter version.' >&2; exit 1; }
bash tool/verify_release_config.sh "$environment" "$platform"
config_file="config/firebase.$environment.$platform.json"
[[ -f "$config_file" ]] || config_file="config/firebase.$environment.json"
if [[ "$platform" == android ]]; then
  flutter build appbundle --release --dart-define-from-file="$config_file" --dart-define="APP_ENV=$environment"
else
  flutter build ipa --release --dart-define-from-file="$config_file" --dart-define="APP_ENV=$environment"
fi
