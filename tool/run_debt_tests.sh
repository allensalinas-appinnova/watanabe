#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
if ! java -version >/dev/null 2>&1 && command -v brew >/dev/null 2>&1 && brew --prefix openjdk@21 >/dev/null 2>&1; then
  export JAVA_HOME="$(brew --prefix openjdk@21)"
  export PATH="$JAVA_HOME/bin:$PATH"
fi
npm --prefix functions run build
npx -y firebase-tools@latest emulators:exec --project demo-clearbudget --only firestore \
  "node --test functions/test/debt_commands_test.mjs functions/test/projection_store_test.mjs functions/test/projection_audit_test.mjs functions/test/operation_commands_test.mjs functions/test/operation_corrections_test.mjs && node functions/test/firestore_rules_test.mjs"
npx -y firebase-tools@latest emulators:exec --project demo-clearbudget --only auth,firestore,functions \
  "node --test functions/test/debt_callable_test.mjs functions/test/debt_commitments_callable_test.mjs functions/test/projection_trigger_test.mjs"
