import { test, expect, type Page } from '@playwright/test';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const BASELINE_DIR = join(__dirname, 'snapshots', 'baselines');
const CURRENT_DIR = join(__dirname, 'snapshots', 'current');
const DIFF_DIR = join(__dirname, 'snapshots', 'diff');
const THRESHOLD = 0.1;
const UPDATE = !!process.env.UPDATE_BASELINES;

// Quality thresholds from vrt
const WHITEOUT_THRESHOLD = 0.95;
const EMPTY_CONTENT_COLORS = 8;
const MAX_DIFF_RATIO = 0.005; // 0.5%

interface CompareResult {
  diffPixels: number;
  totalPixels: number;
  diffRatio: number;
  heatmapPath?: string;
  isNew: boolean;
}

function ensureDirs() {
  for (const dir of [BASELINE_DIR, CURRENT_DIR, DIFF_DIR]) {
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  }
}

function decodePng(path: string) {
  const buf = readFileSync(path);
  const png = PNG.sync.read(buf);
  return {
    width: png.width,
    height: png.height,
    data: new Uint8Array(png.data.buffer, png.data.byteOffset, png.data.byteLength),
  };
}

function encodePng(path: string, width: number, height: number, data: Uint8Array) {
  const png = new PNG({ width, height });
  Buffer.from(data.buffer, data.byteOffset, data.byteLength).copy(png.data);
  const buf = PNG.sync.write(png);
  writeFileSync(path, buf);
}

function compareScreenshots(baselinePath: string, currentPath: string, diffPath: string): CompareResult {
  const baseline = decodePng(baselinePath);
  const current = decodePng(currentPath);

  if (baseline.width !== current.width || baseline.height !== current.height) {
    // Size mismatch = visual regression
    return {
      diffPixels: baseline.width * baseline.height,
      totalPixels: baseline.width * baseline.height,
      diffRatio: 1.0,
      isNew: false,
    };
  }

  const { width, height, data } = baseline;
  const diffOutput = new Uint8Array(width * height * 4);
  const diffPixels = pixelmatch(baseline.data, current.data, diffOutput, width, height, {
    threshold: THRESHOLD,
  });

  const totalPixels = width * height;
  const diffRatio = diffPixels / totalPixels;

  let heatmapPath: string | undefined;
  if (diffPixels > 0) {
    encodePng(diffPath, width, height, diffOutput);
    heatmapPath = diffPath;
  }

  return { diffPixels, totalPixels, diffRatio, heatmapPath, isNew: false };
}

function detectWhiteout(data: Uint8Array, width: number, height: number): { isWhiteout: boolean; ratio: number } {
  const total = width * height;
  let whiteCount = 0;
  for (let i = 0; i < total; i++) {
    const off = i * 4;
    if (data[off] >= 250 && data[off + 1] >= 250 && data[off + 2] >= 250) whiteCount++;
  }
  const ratio = whiteCount / total;
  return { isWhiteout: ratio >= WHITEOUT_THRESHOLD, ratio };
}

function detectEmptyContent(data: Uint8Array, width: number, height: number): { isEmpty: boolean; uniqueColors: number } {
  const total = width * height;
  const colors = new Set<number>();
  const stride = Math.max(1, Math.floor(total / 10000));
  for (let i = 0; i < total; i += stride) {
    const off = i * 4;
    const color = (data[off] << 16) | (data[off + 1] << 8) | data[off + 2];
    colors.add(color);
  }
  return { isEmpty: colors.size <= EMPTY_CONTENT_COLORS, uniqueColors: colors.size };
}

async function captureAndCheck(page: Page, testId: string): Promise<CompareResult> {
  ensureDirs();
  const baselinePath = join(BASELINE_DIR, `${testId}.png`);
  const currentPath = join(CURRENT_DIR, `${testId}.png`);
  const diffPath = join(DIFF_DIR, `${testId}-diff.png`);

  // Capture SVG area
  const svg = page.locator('svg[viewBox]').first();
  const box = await svg.boundingBox();
  if (!box) throw new Error(`SVG not found for "${testId}"`);

  // Crop screenshot to SVG area only
  const fullScreenshot = await page.screenshot({ path: currentPath });

  // Quality checks on the screenshot
  const img = decodePng(currentPath);
  const whiteout = detectWhiteout(img.data, img.width, img.height);
  expect(whiteout.isWhiteout, `Whiteout detected in "${testId}": ${(whiteout.ratio * 100).toFixed(1)}% white`).toBe(false);

  const empty = detectEmptyContent(img.data, img.width, img.height);
  expect(empty.isEmpty, `Empty content detected in "${testId}": only ${empty.uniqueColors} unique colors`).toBe(false);

  if (UPDATE || !existsSync(baselinePath)) {
    // First run or update mode: create baseline
    writeFileSync(baselinePath, readFileSync(currentPath));
    return { diffPixels: 0, totalPixels: img.width * img.height, diffRatio: 0, isNew: true };
  }

  return compareScreenshots(baselinePath, currentPath, diffPath);
}

test.describe('Visual Regression (screenshot comparison)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForTimeout(500);
  });

  test('initial state matches baseline', async ({ page }) => {
    await expect(page.getByRole('button', { name: 'Rectangle' })).toBeVisible({ timeout: 10000 });
    const result = await captureAndCheck(page, 'initial-state');

    if (result.isNew) {
      console.log('Created new baseline: initial-state');
    } else {
      expect(
        result.diffRatio,
        `Visual regression in initial state: ${(result.diffRatio * 100).toFixed(3)}% diff (${result.diffPixels}px). Heatmap: ${result.heatmapPath}`
      ).toBeLessThan(MAX_DIFF_RATIO);
    }
  });

  test('after adding rectangle matches baseline', async ({ page }) => {
    await expect(page.getByRole('button', { name: 'Rectangle' })).toBeVisible({ timeout: 10000 });
    await page.getByRole('button', { name: 'Rectangle' }).click();
    await page.waitForTimeout(300);

    const result = await captureAndCheck(page, 'after-rect');

    if (result.isNew) {
      console.log('Created new baseline: after-rect');
    } else {
      expect(
        result.diffRatio,
        `Visual regression after adding rectangle: ${(result.diffRatio * 100).toFixed(3)}% diff`
      ).toBeLessThan(MAX_DIFF_RATIO);
    }
  });

  test('after adding circle matches baseline', async ({ page }) => {
    await expect(page.getByRole('button', { name: 'Circle' })).toBeVisible({ timeout: 10000 });
    await page.getByRole('button', { name: 'Circle' }).click();
    await page.waitForTimeout(300);

    const result = await captureAndCheck(page, 'after-circle');

    if (result.isNew) {
      console.log('Created new baseline: after-circle');
    } else {
      expect(
        result.diffRatio,
        `Visual regression after adding circle: ${(result.diffRatio * 100).toFixed(3)}% diff`
      ).toBeLessThan(MAX_DIFF_RATIO);
    }
  });

  test('after adding line matches baseline', async ({ page }) => {
    await expect(page.getByRole('button', { name: 'Line' })).toBeVisible({ timeout: 10000 });
    await page.getByRole('button', { name: 'Line' }).click();
    await page.waitForTimeout(300);

    const result = await captureAndCheck(page, 'after-line');

    if (result.isNew) {
      console.log('Created new baseline: after-line');
    } else {
      expect(
        result.diffRatio,
        `Visual regression after adding line: ${(result.diffRatio * 100).toFixed(3)}% diff`
      ).toBeLessThan(MAX_DIFF_RATIO);
    }
  });

  test('after multiple shapes matches baseline', async ({ page }) => {
    await expect(page.getByRole('button', { name: 'Rectangle' })).toBeVisible({ timeout: 10000 });

    // Add multiple shapes
    await page.getByRole('button', { name: 'Rectangle' }).click();
    await page.waitForTimeout(100);
    await page.getByRole('button', { name: 'Circle' }).click();
    await page.waitForTimeout(100);
    await page.getByRole('button', { name: 'Ellipse' }).click();
    await page.waitForTimeout(300);

    const result = await captureAndCheck(page, 'after-multiple');

    if (result.isNew) {
      console.log('Created new baseline: after-multiple');
    } else {
      expect(
        result.diffRatio,
        `Visual regression after multiple shapes: ${(result.diffRatio * 100).toFixed(3)}% diff`
      ).toBeLessThan(MAX_DIFF_RATIO);
    }
  });

  test('after undo matches baseline', async ({ page }) => {
    await expect(page.getByRole('button', { name: 'Rectangle' })).toBeVisible({ timeout: 10000 });

    // Add then undo
    await page.getByRole('button', { name: 'Rectangle' }).click();
    await page.waitForTimeout(100);
    await page.keyboard.press('Control+z');
    await page.waitForTimeout(300);

    const result = await captureAndCheck(page, 'after-undo');

    if (result.isNew) {
      console.log('Created new baseline: after-undo');
    } else {
      expect(
        result.diffRatio,
        `Visual regression after undo: ${(result.diffRatio * 100).toFixed(3)}% diff`
      ).toBeLessThan(MAX_DIFF_RATIO);
    }
  });

  test('full workflow sequence matches baselines', async ({ page }) => {
    await expect(page.getByRole('button', { name: 'Rectangle' })).toBeVisible({ timeout: 10000 });

    const steps = [
      { id: 'workflow-1-rect', action: () => page.getByRole('button', { name: 'Rectangle' }).click() },
      { id: 'workflow-2-circle', action: () => page.getByRole('button', { name: 'Circle' }).click() },
      { id: 'workflow-3-undo', action: () => page.keyboard.press('Control+z') },
      { id: 'workflow-4-redo', action: () => page.keyboard.press('Control+y') },
      { id: 'workflow-5-ellipse', action: () => page.getByRole('button', { name: 'Ellipse' }).click() },
    ];

    const failures: string[] = [];

    for (const step of steps) {
      await step.action();
      await page.waitForTimeout(300);

      const result = await captureAndCheck(page, step.id);
      if (result.isNew) {
        console.log(`Created new baseline: ${step.id}`);
      } else if (result.diffRatio >= MAX_DIFF_RATIO) {
        failures.push(`${step.id}: ${(result.diffRatio * 100).toFixed(3)}% (heatmap: ${result.heatmapPath})`);
      }
    }

    expect(failures, `Visual regressions in workflow:\n${failures.join('\n')}`).toHaveLength(0);
  });
});
