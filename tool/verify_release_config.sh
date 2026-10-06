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

config_file="$project_root/config/firebase.$environment.json"
if [[ ! -f "$config_file" ]]; then
  echo "Missing $config_file. Copy the example and fill the Firebase app values." >&2
  exit 1
fi
if rg -q 'REPLACE_WITH|YOUR_|example' "$config_file"; then
  echo "$config_file still contains placeholder values." >&2
  exit 1
fi

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
