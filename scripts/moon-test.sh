#!/bin/bash
# moon test wrapper that handles ESM/CJS compatibility
# Usage: ./scripts/moon-test.sh [moon test arguments]

set -e

# Backup current package.json type
PACKAGE_JSON="package.json"
HAS_TYPE_MODULE=$(node -e "const p=require('./$PACKAGE_JSON');console.log(p.type==='module'?'1':'0')")

if [ "$HAS_TYPE_MODULE" = "1" ]; then
  # Temporarily remove "type": "module"
  node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PACKAGE_JSON'));delete p.type;fs.writeFileSync('$PACKAGE_JSON',JSON.stringify(p,null,2))"

  # Run moon test with all arguments
  moon test "$@"
  TEST_EXIT_CODE=$?

  # Restore "type": "module"
  node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PACKAGE_JSON'));p.type='module';fs.writeFileSync('$PACKAGE_JSON',JSON.stringify(p,null,2))"

  exit $TEST_EXIT_CODE
else
  # No "type": "module", just run normally
  moon test "$@"
fi
