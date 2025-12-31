import { test, expect } from '@playwright/test';

test.describe('Text Fill Color Inheritance', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/embed.html');
    await page.waitForSelector('svg');
    await page.waitForTimeout(200);
  });

  test('text inside magenta circle should have magenta fill', async ({ page }) => {
    // Moonbit text is inside the magenta circle (#c030c0 stroke)
    const textGroups = page.locator('g[data-element-type="text"]');
    const moonbitText = textGroups.first();
    const textEl = moonbitText.locator('text');

    const fill = await textEl.getAttribute('fill');
    expect(fill).toBe('#c030c0');
  });

  test('text inside blue rect should have blue fill', async ({ page }) => {
    // Luna text is inside the blue rectangle (#3355aa stroke)
    const textGroups = page.locator('g[data-element-type="text"]');
    // Second text element is Luna
    const lunaText = textGroups.nth(1);
    const textEl = lunaText.locator('text');

    const fill = await textEl.getAttribute('fill');
    expect(fill).toBe('#3355aa');
  });

  test('text inside yellow rect should have yellow fill', async ({ page }) => {
    // JS text is inside the yellow rectangle (#ddcc00 stroke)
    const textGroups = page.locator('g[data-element-type="text"]');
    // Fourth text element is JS (after Moonbit, Luna, Excalidraw)
    const jsText = textGroups.nth(3);
    const textEl = jsText.locator('text');

    const fill = await textEl.getAttribute('fill');
    expect(fill).toBe('#ddcc00');
  });

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
    // Get initial fill
    const textGroups = page.locator('g[data-element-type="text"]');
    const moonbitText = textGroups.first();
    const textEl = moonbitText.locator('text');
    const initialFill = await textEl.getAttribute('fill');
    expect(initialFill).toBe('#c030c0');

    // Move the parent circle by dragging
    const circle = page.locator('circle[data-id]').first();
    const circleBox = await circle.boundingBox();
    expect(circleBox).not.toBeNull();

    if (circleBox) {
      const x = circleBox.x + circleBox.width / 2;
      const y = circleBox.y + circleBox.height / 2;

      await page.mouse.move(x, y);
      await page.mouse.down();
      await page.mouse.move(x + 50, y + 30, { steps: 5 });
      await page.mouse.up();
    }

    // Wait for update
    await page.waitForTimeout(100);

    // Fill should still be correct
    const fillAfterMove = await textEl.getAttribute('fill');
    expect(fillAfterMove).toBe('#c030c0');
  });
});

test.describe('Text Fill in Main Editor', () => {
  test('text elements should have correct fill on initial load', async ({ page }) => {
    await page.goto('/');
    await page.waitForSelector('g[data-element-type="text"]');

    const textGroups = page.locator('g[data-element-type="text"]');
    const moonbitText = textGroups.first();
    const textEl = moonbitText.locator('text');

    const fill = await textEl.getAttribute('fill');
    expect(fill).toBe('#c030c0');
  });
});
