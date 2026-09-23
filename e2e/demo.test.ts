import { test, expect, type Page, type Locator } from '@playwright/test';
import {
  createReviewer,
  isVlmConfigured,
  positiveMs,
  reviewClaims,
  reviewerName,
  VLM_SKIP_REASON,
} from './vlm-reviewer';

/**
 * 起動時のデモ（src/sample_shapes.mbt）のテスト。
 *
 * デモは最初に開いた人へ「何ができるエディタか」を見せるためのもの。見えていな
 * ければ意味がないので、画面幅ごとにツールバーやパネルに隠れていないことを
 * 確かめ、絵が主張どおりに描けているかを vlmkit のレビュアーに見せて確かめる。
 * 配色（ラベルが塗りの上で読めるか）と配置の約束は src/sample_shapes_wbtest.mbt。
 */

type Box = { x: number; y: number; width: number; height: number };

const VIEWPORTS = [
  { width: 1280, height: 800 },
  { width: 768, height: 900 },
  { width: 375, height: 700 },
];

function canvas(page: Page) {
  return page.locator('svg[width="100%"][height="100%"]').first();
}

async function openEditor(page: Page, viewport: { width: number; height: number }) {
  await page.setViewportSize(viewport);
  await page.goto('/');
  await expect(canvas(page).locator('[data-id]').first()).toBeVisible();
  await page.waitForTimeout(300);
}

function overlaps(a: Box, b: Box) {
  return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
}

/** デモの要素それぞれの画面上の範囲 */
async function demoBoxes(page: Page): Promise<Array<{ id: string; box: Box }>> {
  const elements = canvas(page).locator('[data-id]');
  const out: Array<{ id: string; box: Box }> = [];
  for (let i = 0; i < (await elements.count()); i++) {
    const el = elements.nth(i);
    const box = await el.boundingBox();
    if (box && box.width > 0 && box.height > 0) {
      out.push({ id: (await el.getAttribute('data-id')) ?? `#${i}`, box });
    }
  }
  return out;
}

/** キャンバスの上に重なって見える UI（ツールバー・パネル・パネルの開閉ボタン） */
async function overlayBoxes(page: Page): Promise<Array<{ name: string; box: Box }>> {
  return page.evaluate(() => {
    const out: Array<{ name: string; box: Box }> = [];
    for (const el of Array.from(document.querySelectorAll<HTMLElement>('body *'))) {
      const style = getComputedStyle(el);
      if (style.position !== 'fixed' || style.display === 'none' || style.visibility === 'hidden') {
        continue;
      }
      // キャンバスそのもの（全面に敷かれた fixed の入れ物）は除く
      if (el.querySelector('svg[width="100%"][height="100%"]')) continue;
      const r = el.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) continue;
      const text = (el.textContent ?? '').trim().slice(0, 24);
      out.push({ name: text || el.tagName.toLowerCase(), box: { x: r.x, y: r.y, width: r.width, height: r.height } });
    }
    return out;
  });
}

test.describe('Demo scene', () => {
  for (const viewport of VIEWPORTS) {
    test(`at ${viewport.width}px the whole demo is on screen and nothing covers it`, async ({ page }) => {
      await openEditor(page, viewport);
      const demo = await demoBoxes(page);
      expect(demo.length, 'the demo should draw its elements').toBeGreaterThanOrEqual(10);
      const overlays = await overlayBoxes(page);
      for (const { id, box } of demo) {
        expect(box.x, `${id} should start inside the window`).toBeGreaterThanOrEqual(0);
        expect(box.y, `${id} should start inside the window`).toBeGreaterThanOrEqual(0);
        expect(box.x + box.width, `${id} should end inside the window`).toBeLessThanOrEqual(viewport.width);
        expect(box.y + box.height, `${id} should end inside the window`).toBeLessThanOrEqual(viewport.height);
        for (const overlay of overlays) {
          expect(overlaps(box, overlay.box), `${id} is covered by "${overlay.name}"`).toBe(false);
        }
      }
    });
  }

  test('on a phone the panel starts closed, and the toggle opens it', async ({ page }) => {
    await openEditor(page, { width: 375, height: 700 });
    const panel = page.getByText('Canvas Settings');
    await expect(panel).toHaveCount(0);
    await page.getByRole('button', { name: '☰' }).click();
    await expect(panel).toBeVisible();
  });

  test('dragging a shape of the demo keeps its arrows attached', async ({ page }) => {
    await openEditor(page, { width: 1280, height: 800 });
    const ellipse = canvas(page).locator('ellipse[data-id]').first();
    const box = (await ellipse.boundingBox())!;
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    await page.mouse.down();
    await page.mouse.move(box.x + box.width / 2 + 40, box.y + box.height / 2 + 60, { steps: 6 });
    await page.mouse.move(box.x + box.width / 2 + 80, box.y + box.height / 2 + 120, { steps: 6 });
    await page.mouse.up();
    await page.waitForTimeout(150);

    const num = async (locator: Locator, name: string) => Number(await locator.getAttribute(name));
    const [cx, cy, rx, ry] = await Promise.all(['cx', 'cy', 'rx', 'ry'].map((n) => num(ellipse, n)));
    const lines = canvas(page).locator('g[data-element-type="line"]');
    const ends: Array<{ x1: number; y1: number; x2: number; y2: number }> = [];
    for (let i = 0; i < (await lines.count()); i++) {
      const line = lines.nth(i).locator('line').last();
      ends.push({
        x1: await num(line, 'x1'),
        y1: await num(line, 'y1'),
        x2: await num(line, 'x2'),
        y2: await num(line, 'y2'),
      });
    }
    const near = (ax: number, ay: number, bx: number, by: number) => Math.hypot(ax - bx, ay - by) <= 0.5;
    // Draw の右端から出る矢印と、Draw の下端に戻ってくる破線の矢印
    expect(ends.some((l) => near(l.x1, l.y1, cx + rx, cy)), 'an arrow should leave the right of Draw').toBe(true);
    expect(ends.some((l) => near(l.x2, l.y2, cx, cy + ry)), 'an arrow should come back to the bottom of Draw').toBe(true);
  });
});

test.describe('Demo scene — what the picture says (vlmkit)', () => {
  test.skip(!isVlmConfigured(), VLM_SKIP_REASON);
  test.setTimeout(positiveMs(process.env.VLMKIT_TEST_TIMEOUT_MS, 900_000));

  /** 絵を見て判定できる粒度の主張。デモが見せたい機能を一つずつ言葉にしたもの。 */
  const CLAIMS = [
    'The drawing shows three labeled shapes, labeled "Draw", "Plain SVG" and "Embed anywhere", joined in a loop by arrows.',
    'Exactly one of the three arrows between the labeled shapes is drawn with a dashed line; the other two are solid.',
    'Between the three labeled shapes there is a hand-drawn circular arrow, and the caption "Round trip" is written just below it.',
    'Every label inside a shape is easy to read against the fill color of its shape.',
    'Below the diagram, two short lines of text say that dragging a shape keeps its arrows attached, and that Ctrl+Shift+C copies SVG.',
  ];

  test('the demo shows what the editor can do', async ({ page }) => {
    await openEditor(page, { width: 1280, height: 800 });
    console.log(`[vlmkit] reviewer: ${reviewerName()}`);
    const failures = await reviewClaims(CLAIMS, canvas(page), createReviewer());
    expect(failures, `the demo does not show what it should:\n${failures.join('\n')}`).toEqual([]);
  });
});
