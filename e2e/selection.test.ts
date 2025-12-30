import { test, expect } from '@playwright/test';

test.describe('Multi-Selection', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for initial shapes to load
    await expect(page.locator('svg rect[data-id][cursor="move"]').first()).toBeVisible();
  });

  test('should select multiple elements with Shift+click', async ({ page }) => {
    const shapeRects = page.locator('svg rect[data-id][cursor="move"]');

    // Click first element
    await shapeRects.nth(0).click({ force: true });

    // Count anchor points for single selection (each element has ~5 anchors)
    const anchorsBefore = await page.locator('svg .anchor-point').count();

    // Shift+click second element
    await shapeRects.nth(1).click({ force: true, modifiers: ['Shift'] });

    // More anchor points should be visible (two elements selected)
    const anchorsAfter = await page.locator('svg .anchor-point').count();
    expect(anchorsAfter).toBeGreaterThan(anchorsBefore);
  });

  test('should select all elements with Ctrl+A', async ({ page }) => {
    // First select one element to ensure selection is working
    const shapeRects = page.locator('svg rect[data-id][cursor="move"]');
    await shapeRects.first().click({ force: true });
    const anchorsSingle = await page.locator('svg .anchor-point').count();

    // Press Ctrl+A to select all
    await page.keyboard.press('Control+a');
    await page.waitForTimeout(100);

    // More anchors should appear for all selected elements
    const anchorsAll = await page.locator('svg .anchor-point').count();
    expect(anchorsAll).toBeGreaterThan(anchorsSingle);
  });

  test('should deselect all with Escape', async ({ page }) => {
    // Select an element
    const shapeRects = page.locator('svg rect[data-id][cursor="move"]');
    await shapeRects.first().click({ force: true });
    await expect(page.locator('svg .anchor-point').first()).toBeVisible();

    // Press Escape
    await page.keyboard.press('Escape');

    // No anchor points visible (no selection)
    await expect(page.locator('svg .anchor-point')).toHaveCount(0);
  });

  test('should move multiple selected elements together', async ({ page }) => {
    const shapeRects = page.locator('svg rect[data-id][cursor="move"]');

    // Get initial positions
    const initialX1 = parseFloat(await shapeRects.nth(0).getAttribute('x') || '0');
    const initialX2 = parseFloat(await shapeRects.nth(1).getAttribute('x') || '0');

    // Select multiple elements
    await shapeRects.nth(0).click({ force: true });
    await shapeRects.nth(1).click({ force: true, modifiers: ['Shift'] });

    // Drag first element
    const rect = await shapeRects.nth(0).boundingBox();
    if (rect) {
      await page.mouse.move(rect.x + rect.width / 2, rect.y + rect.height / 2);
      await page.mouse.down();
      await page.mouse.move(rect.x + rect.width / 2 + 50, rect.y + rect.height / 2 + 50, { steps: 5 });
      await page.mouse.up();
    }

    // Both elements should have moved
    const newX1 = parseFloat(await shapeRects.nth(0).getAttribute('x') || '0');
    const newX2 = parseFloat(await shapeRects.nth(1).getAttribute('x') || '0');

    expect(newX1).not.toBe(initialX1);
    expect(newX2).not.toBe(initialX2);
  });
});

test.describe('Copy and Paste', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('svg rect[data-id][cursor="move"]').first()).toBeVisible();
  });

  test('should copy and paste element with Ctrl+C/V', async ({ page }) => {
    const shapeRects = page.locator('svg rect[data-id][cursor="move"]');
    const initialCount = await shapeRects.count();

    // Select an element
    await shapeRects.first().click({ force: true });

    // Copy
    await page.keyboard.press('Control+c');

    // Paste
    await page.keyboard.press('Control+v');

    // Should have one more element
    await expect(shapeRects).toHaveCount(initialCount + 1);
  });

  test('should paste element offset from original', async ({ page }) => {
    const shapeRects = page.locator('svg rect[data-id][cursor="move"]');

    // Select first element
    await shapeRects.first().click({ force: true });
    const originalX = parseFloat(await shapeRects.first().getAttribute('x') || '0');

    // Copy and paste
    await page.keyboard.press('Control+c');
    await page.keyboard.press('Control+v');

    // New element should be offset
    const newElementX = parseFloat(await shapeRects.last().getAttribute('x') || '0');
    expect(newElementX).toBeGreaterThan(originalX);
  });

  test('should copy and paste multiple selected elements', async ({ page }) => {
    const shapeRects = page.locator('svg rect[data-id][cursor="move"]');
    const initialCount = await shapeRects.count();

    // Select multiple elements
    await shapeRects.nth(0).click({ force: true });
    await shapeRects.nth(1).click({ force: true, modifiers: ['Shift'] });

    // Copy and paste
    await page.keyboard.press('Control+c');
    await page.keyboard.press('Control+v');

    // Should have two more elements
    await expect(shapeRects).toHaveCount(initialCount + 2);
  });
});

test.describe('Keyboard Shortcuts for Shape Insertion', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('svg[viewBox]').first()).toBeVisible();
  });

  test('should insert rectangle with key 1', async ({ page }) => {
    const shapeRects = page.locator('svg rect[data-id][cursor="move"]');
    const initialCount = await shapeRects.count();

    // Focus on SVG area first
    await page.locator('svg[viewBox]').first().click({ position: { x: 200, y: 150 } });

    // Press 1
    await page.keyboard.press('1');

    await expect(shapeRects).toHaveCount(initialCount + 1);
  });

  test('should insert circle with key 2', async ({ page }) => {
    const circles = page.locator('svg circle[data-id]');
    const initialCount = await circles.count();

    // Focus on SVG area
    await page.locator('svg[viewBox]').first().click({ position: { x: 200, y: 150 } });

    // Press 2
    await page.keyboard.press('2');

    await expect(circles).toHaveCount(initialCount + 1);
  });

  test('should insert ellipse with key 3', async ({ page }) => {
    const ellipses = page.locator('svg ellipse[data-id]');
    const initialCount = await ellipses.count();

    // Focus on SVG area
    await page.locator('svg[viewBox]').first().click({ position: { x: 200, y: 150 } });

    // Press 3
    await page.keyboard.press('3');

    await expect(ellipses).toHaveCount(initialCount + 1);
  });

  test('should insert line with key 4', async ({ page }) => {
    const lines = page.locator('svg g[data-element-type="line"]');
    const initialCount = await lines.count();

    // Focus on SVG area
    await page.locator('svg[viewBox]').first().click({ position: { x: 200, y: 150 } });

    // Press 4
    await page.keyboard.press('4');

    await expect(lines).toHaveCount(initialCount + 1);
  });

  test('should insert arrow with key 5', async ({ page }) => {
    // Arrow is a Line with arrow markers, uses same g[data-element-type="line"]
    const lines = page.locator('svg g[data-element-type="line"]');
    const initialCount = await lines.count();

    // Focus on SVG area
    await page.locator('svg[viewBox]').first().click({ position: { x: 200, y: 150 } });
    await page.waitForTimeout(50);

    // Press 5
    await page.keyboard.press('5');
    await page.waitForTimeout(100);

    await expect(lines).toHaveCount(initialCount + 1);
  });

  test('should insert text with key 6', async ({ page }) => {
    // Text elements are wrapped in <g data-element-type="text">
    const texts = page.locator('svg g[data-element-type="text"]');
    const initialCount = await texts.count();

    // Focus on SVG area
    await page.locator('svg[viewBox]').first().click({ position: { x: 200, y: 150 } });
    await page.waitForTimeout(50);

    // Press 6 to insert text
    await page.keyboard.press('6');
    await page.waitForTimeout(100);

    await expect(texts).toHaveCount(initialCount + 1);
  });
});

test.describe('Coordinate Rounding', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('svg rect[data-id][cursor="move"]').first()).toBeVisible();
  });

  test('should have integer coordinates after drag', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();

    // Get rect bounding box
    const rectBox = await rect.boundingBox();
    expect(rectBox).not.toBeNull();

    if (rectBox) {
      // Perform drag to a non-integer position
      await page.mouse.move(rectBox.x + rectBox.width / 2, rectBox.y + rectBox.height / 2);
      await page.mouse.down();
      await page.mouse.move(rectBox.x + 73.7, rectBox.y + 41.3, { steps: 5 });
      await page.mouse.up();

      // Check coordinates are integers
      const newX = await rect.getAttribute('x');
      const newY = await rect.getAttribute('y');

      expect(parseFloat(newX!)).toBe(Math.round(parseFloat(newX!)));
      expect(parseFloat(newY!)).toBe(Math.round(parseFloat(newY!)));
    }
  });

  test('should have integer dimensions after resize', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();

    // Select element
    await rect.click({ force: true });

    // Get SE handle and drag it
    const seHandle = page.locator('svg rect[data-handle="se"]');
    const handleBox = await seHandle.boundingBox();
    expect(handleBox).not.toBeNull();

    if (handleBox) {
      // Drag to non-integer position
      await page.mouse.move(handleBox.x + handleBox.width / 2, handleBox.y + handleBox.height / 2);
      await page.mouse.down();
      await page.mouse.move(handleBox.x + 47.3, handleBox.y + 23.7, { steps: 5 });
      await page.mouse.up();

      // Check dimensions are integers
      const width = await rect.getAttribute('width');
      const height = await rect.getAttribute('height');

      expect(parseFloat(width!)).toBe(Math.round(parseFloat(width!)));
      expect(parseFloat(height!)).toBe(Math.round(parseFloat(height!)));
    }
  });
});

test.describe('Pointer Events', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('svg[viewBox]').first()).toBeVisible();
  });

  test('should have touch-action none on SVG', async ({ page }) => {
    const svg = page.locator('svg[viewBox]').first();
    const style = await svg.getAttribute('style');
    expect(style).toContain('touch-action');
  });

  test('should respond to pointer events', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    const initialX = await rect.getAttribute('x');

    // Use pointer events directly via evaluate
    const rectBox = await rect.boundingBox();
    expect(rectBox).not.toBeNull();

    if (rectBox) {
      const centerX = rectBox.x + rectBox.width / 2;
      const centerY = rectBox.y + rectBox.height / 2;

      // Simulate pointer events
      await page.mouse.move(centerX, centerY);
      await page.mouse.down();
      await page.mouse.move(centerX + 30, centerY + 20, { steps: 3 });
      await page.mouse.up();

      const newX = await rect.getAttribute('x');
      expect(newX).not.toBe(initialX);
    }
  });
});
