import { test, expect, type Page } from '@playwright/test';
import { DEMO } from './demo-scene';

/** 図形の中のラベルの <text>。並び順に頼らず、文言で探す */
function label(page: Page, text: string) {
  return page
    .locator('g[data-element-type="text"]')
    .filter({ has: page.locator('text', { hasText: new RegExp(`^${text}$`) }) })
    .locator('text');
}

test.describe('Text Fill Color Inheritance', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/embed.html');
    await page.waitForSelector('svg');
    await page.waitForTimeout(200);
  });

  // ラベルの文字色は親図形の線の色（Excalidraw と同じ決まり）
  for (const { text, fill } of Object.values(DEMO.labels)) {
    test(`the label "${text}" is drawn in the stroke colour of its shape`, async ({ page }) => {
      await expect(label(page, text)).toHaveAttribute('fill', fill);
    });
  }

  test('all text elements should have fill attribute set', async ({ page }) => {
    const textGroups = page.locator('g[data-element-type="text"]');
    const count = await textGroups.count();

    for (let i = 0; i < count; i++) {
      const textEl = textGroups.nth(i).locator('text');
      const fill = await textEl.getAttribute('fill');
      expect(fill).not.toBeNull();
      expect(fill).not.toBe('');
      // Fill should be a color value, not a CSS variable like var(--ml-text)
      // (CSS variables are only used for standalone text, not child text)
    }
  });

  test('text fill should remain correct after moving parent element', async ({ page }) => {
    const { text, fill } = DEMO.labels.draw;
    const textEl = label(page, text);
    await expect(textEl).toHaveAttribute('fill', fill);

    // Move the parent ellipse by dragging
    const ellipse = page.locator('ellipse[data-id]').first();
    const box = await ellipse.boundingBox();
    expect(box).not.toBeNull();

    if (box) {
      const x = box.x + box.width / 2;
      const y = box.y + box.height / 2;

      await page.mouse.move(x, y);
      await page.mouse.down();
      await page.mouse.move(x + 50, y + 30, { steps: 5 });
      await page.mouse.up();
    }

    // Wait for update
    await page.waitForTimeout(100);

    // Fill should still be correct
    await expect(textEl).toHaveAttribute('fill', fill);
  });
});

test.describe('Text Fill in Main Editor', () => {
  test('text elements should have correct fill on initial load', async ({ page }) => {
    await page.goto('/');
    await page.waitForSelector('g[data-element-type="text"]');

    for (const { text, fill } of Object.values(DEMO.labels)) {
      await expect(label(page, text), `the label "${text}"`).toHaveAttribute('fill', fill);
    }
  });
});
