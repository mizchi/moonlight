# Moonlight tasks

# Run all e2e tests
test:
  pnpm test

# Run probabilistic smoke tests (vrt-style)
smoke:
  npx playwright test e2e/smoke.test.ts --reporter=list

# Run smoke tests with a specific seed for reproducibility
smoke-seed seed="":
  VRT_SEED={{seed}} npx playwright test e2e/smoke.test.ts --reporter=list

# Run visual regression tests
vrt:
  npx playwright test e2e/visual-regression.test.ts --reporter=list

# Update VRT baselines (run after intentional visual changes)
vrt-update:
  UPDATE_BASELINES=true npx playwright test e2e/visual-regression.test.ts --reporter=list

# Run unit tests
test-unit:
  pnpm test:unit

# Type check
check:
  moon check

# Format
fmt:
  moon fmt

# Build all
build:
  pnpm build:all

# Dev server
dev:
  pnpm dev
