#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

if ! java -version >/dev/null 2>&1 && command -v brew >/dev/null 2>&1 && brew --prefix openjdk@21 >/dev/null 2>&1; then
  export JAVA_HOME="$(brew --prefix openjdk@21)"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

if ! java -version >/dev/null 2>&1; then
  echo "Java 21+ is required by the Firestore emulator." >&2
  exit 1
fi

npm --prefix functions run build
# Direct transaction tests must run without automatic trigger delivery.
npx -y firebase-tools@latest emulators:exec \
  --project demo-clearbudget --only firestore --config firebase.json \
  "npm --prefix functions run test:projections:emulator"

# Separate suite: test the actual deployed-in-emulator trigger adapter.
npx -y firebase-tools@latest emulators:exec \
  --project demo-clearbudget --only firestore,functions --config firebase.json \
  "npm --prefix functions run test:projections:trigger"
