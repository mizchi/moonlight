import { defineConfig, devices } from '@playwright/test';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * 評価（eval/**\/*.eval.ts）用の設定。ふだんのテスト（e2e/）とは分けてある。
 * AI を呼ぶので遅く、費用もかかり、結果は合否より点数として読むものだから。
 *
 *   pnpm eval:ai-draw
 *   AI_DRAW_TASKS=pipeline,hub AI_DRAW_WORKERS=2 pnpm eval:ai-draw
 *
 * 詳しくは eval/ai-draw/README.md。
 */

const chromiumExecutable =
  process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ??
  (existsSync('/opt/pw-browsers/chromium') ? '/opt/pw-browsers/chromium' : undefined);
if (chromiumExecutable) process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ??= chromiumExecutable;

// 一回の評価の置き場所。ワーカーにも同じ値が渡るよう、ここで一度だけ決める
process.env.AI_DRAW_RUN ??= new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-');
process.env.AI_DRAW_RUN_DIR ??= join(
  fileURLToPath(new URL('./eval/ai-draw/runs/', import.meta.url)),
  process.env.AI_DRAW_RUN,
);

export default defineConfig({
  testDir: './eval',
  testMatch: '**/*.eval.ts',
  fullyParallel: true,
  workers: Number(process.env.AI_DRAW_WORKERS ?? 4),
  timeout: 30 * 60_000,
  reporter: [
    ['list'],
    ['html', { outputFolder: join(process.env.AI_DRAW_RUN_DIR, 'playwright-report'), open: 'never' }],
  ],
  globalTeardown: './eval/ai-draw/report.ts',
  use: {
    ...devices['Desktop Chrome'],
    launchOptions: chromiumExecutable ? { executablePath: chromiumExecutable } : {},
  },
});
