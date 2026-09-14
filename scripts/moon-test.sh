#!/bin/bash
# moon test wrapper that handles ESM/CJS compatibility
#
# `moon test --target js` emits CommonJS, so "type": "module" has to come out of
# package.json for the duration of the run. A trap puts it back even when the
# tests fail or the run is interrupted — otherwise a red test run leaves the
# repository in a state where Vite and Playwright cannot load ESM.
#
# Usage: ./scripts/moon-test.sh [moon test arguments]

set -u

PACKAGE_JSON="package.json"

HAS_TYPE_MODULE=$(node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('$PACKAGE_JSON','utf8'));process.stdout.write(p.type==='module'?'1':'0')")

restore_type_module() {
  node -e "
    const fs = require('fs');
    const path = '$PACKAGE_JSON';
    const pkg = JSON.parse(fs.readFileSync(path, 'utf8'));
    if (pkg.type === 'module') process.exit(0);
    const out = {};
    for (const [k, v] of Object.entries(pkg)) {
      out[k] = v;
      if (k === 'description') out.type = 'module';
    }
    if (!out.type) out.type = 'module';
    fs.writeFileSync(path, JSON.stringify(out, null, 2) + '\n');
  "
}

if [ "$HAS_TYPE_MODULE" = "1" ]; then
  trap restore_type_module EXIT INT TERM
  node -e "
    const fs = require('fs');
    const path = '$PACKAGE_JSON';
    const pkg = JSON.parse(fs.readFileSync(path, 'utf8'));
    delete pkg.type;
    fs.writeFileSync(path, JSON.stringify(pkg, null, 2) + '\n');
  "
fi

moon test "$@"
