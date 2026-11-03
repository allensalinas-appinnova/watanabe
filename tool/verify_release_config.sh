#!/usr/bin/env bash
set -euo pipefail

environment="${1:-staging}"
platform="${2:-android}"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$environment" in
  staging|prod) ;;
  *) echo "Environment must be staging or prod." >&2; exit 1 ;;
esac

case "$platform" in
  android|ios) ;;
  *) echo "Platform must be android or ios." >&2; exit 1 ;;
esac

platform_config_file="$project_root/config/firebase.$environment.$platform.json"
generic_config_file="$project_root/config/firebase.$environment.json"
if [[ -f "$platform_config_file" ]]; then
  config_file="$platform_config_file"
else
  config_file="$generic_config_file"
fi
if [[ ! -f "$config_file" ]]; then
  echo "Missing $platform_config_file. Copy the platform example and fill the Firebase app values." >&2
  exit 1
fi
if rg -q 'REPLACE_WITH|YOUR_|example' "$config_file"; then
  echo "$config_file still contains placeholder values." >&2
  exit 1
fi

python3 - "$config_file" "$environment" "$platform" <<'PYCODE'
import json,sys
file,environment,platform=sys.argv[1:]
data=json.load(open(file))
if data.get('APP_ENV') != environment or str(data.get('USE_FIREBASE_EMULATORS',False)).lower() == 'true':
    raise SystemExit('Release defines must explicitly select the requested environment without emulators.')
prefix='FIREBASE_'+environment.upper()+'_'
if not all(data.get(prefix+k) for k in ['API_KEY','APP_ID','MESSAGING_SENDER_ID','PROJECT_ID','STORAGE_BUCKET']):
    raise SystemExit('Required release Firebase values are missing.')
if environment == 'prod' and data[prefix+'PROJECT_ID'] != 'lumiomoney':
    raise SystemExit('Unexpected production Firebase project.')
if ':'+platform+':' not in data[prefix+'APP_ID']:
    raise SystemExit('Firebase registration does not match the release platform.')
PYCODE

if [[ "$platform" == "android" ]]; then
  signing_file="$project_root/android/key.properties"
  if [[ ! -f "$signing_file" ]]; then
    echo "Missing android/key.properties; release signing is intentionally blocked." >&2
    exit 1
  fi
  store_file="$(sed -n 's/^storeFile=//p' "$signing_file")"
  if [[ -z "$store_file" || ! -f "$store_file" ]]; then
    echo "The Android upload keystore does not exist: $store_file" >&2
    exit 1
  fi
else
  project_file="$project_root/ios/Runner.xcodeproj/project.pbxproj"
  if ! rg -q 'DEVELOPMENT_TEAM = [A-Z0-9]+;' "$project_file"; then
    echo "iOS DEVELOPMENT_TEAM is not configured in the Xcode project." >&2
    exit 1
  fi
fi

echo "Release configuration prerequisites passed for $environment/$platform."
