import { test, expect, type Page, type Locator } from '@playwright/test';

/**
 * Drag-and-Drop comprehensive tests.
 *
 * Covers: move, resize (all corners), line endpoints, multi-select,
 * grid snap, undo, cancel, edge cases.
 */

// --- Helpers ---

const shapes = (page: Page) => page.locator('svg rect[data-id][cursor="move"]');
const handles = (page: Page, dir: string) => page.locator(`svg rect[data-handle="${dir}"]`);
const lineHandles = (page: Page, end: string) => page.locator(`svg circle[data-handle="line-${end}"]`);

async function centerOf(locator: Locator) {
  const box = await locator.boundingBox();
  expect(box).not.toBeNull();
  return { x: box!.x + box!.width / 2, y: box!.y + box!.height / 2, box: box! };
}

async function dragBy(page: Page, cx: number, cy: number, dx: number, dy: number, steps = 5) {
  await page.mouse.move(cx, cy);
  await page.mouse.down();
  await page.mouse.move(cx + dx, cy + dy, { steps });
  await page.mouse.up();
}

async function dragHandle(page: Page, handle: Locator, dx: number, dy: number, steps = 5) {
  const c = await centerOf(handle);
  await dragBy(page, c.x, c.y, dx, dy, steps);
}

async function attr(locator: Locator, name: string) {
  return parseFloat(await locator.getAttribute(name) || '0');
}

async function undo(page: Page) {
  await page.keyboard.press('Control+z');
  await page.waitForTimeout(100);
}

async function waitForEditor(page: Page) {
  await expect(shapes(page).first()).toBeVisible();
}

async function selectShape(page: Page, locator: Locator) {
  await locator.click({ force: true });
  await page.waitForTimeout(100);
}

// --- Tests ---

test.describe('Shape Drag (Move)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForEditor(page);
  });

  test('should drag rectangle to new position', async ({ page }) => {
    const rect = shapes(page).first();
    const [x0, y0] = await Promise.all([attr(rect, 'x'), attr(rect, 'y')]);
    const c = await centerOf(rect);

    await dragBy(page, c.x, c.y, 80, 60);

    expect(await attr(rect, 'x')).not.toBe(x0);
    expect(await attr(rect, 'y')).not.toBe(y0);
  });

  test('should drag circle to new position', async ({ page }) => {
    const circle = page.locator('svg circle[data-id][cursor="move"]');
    test.skip(await circle.count() === 0, 'No circle available');

    const el = circle.first();
    const cx0 = await attr(el, 'cx');
    const c = await centerOf(el);

    await dragBy(page, c.x, c.y, 80, 60, 10);
    expect(await attr(el, 'cx')).not.toBe(cx0);
  });

  test('should drag ellipse to new position', async ({ page }) => {
    const ellipse = page.locator('svg ellipse[data-id][cursor="move"]');
    test.skip(await ellipse.count() === 0, 'No ellipse available');

    const el = ellipse.first();
    const cx0 = await attr(el, 'cx');
    const c = await centerOf(el);

    await dragBy(page, c.x, c.y, 70, 50, 10);
    expect(await attr(el, 'cx')).not.toBe(cx0);
  });

  test('should drag text element to new position', async ({ page }) => {
    await page.getByRole('button', { name: 'Text' }).click();
    await page.waitForTimeout(200);

    const textGroup = page.locator('svg g[data-element-type="text"]').last();
    const rect = textGroup.locator('rect').first();
    const x0 = await attr(rect, 'x');

    const svg = page.locator('svg[viewBox]').first();
    const svgBox = await svg.boundingBox();
    expect(svgBox).not.toBeNull();

    await textGroup.dragTo(svg, {
      targetPosition: { x: svgBox!.width * 0.6, y: svgBox!.height * 0.5 },
      force: true,
    });

    expect(await attr(rect, 'x')).not.toBe(x0);
  });

  test('should not move shape on zero-distance drag', async ({ page }) => {
    const rect = shapes(page).first();
    const x0 = await rect.getAttribute('x');
    const c = await centerOf(rect);

    await page.mouse.move(c.x, c.y);
    await page.mouse.down();
    await page.mouse.up();

    expect(await rect.getAttribute('x')).toBe(x0);
  });

  test('should undo drag to restore position', async ({ page }) => {
    const rect = shapes(page).first();
    const x0 = await rect.getAttribute('x');
    const c = await centerOf(rect);

    await dragBy(page, c.x, c.y, 100, 50);
    expect(await rect.getAttribute('x')).not.toBe(x0);

    await undo(page);
    expect(await rect.getAttribute('x')).toBe(x0);
  });
});

test.describe('Resize Handles', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForEditor(page);
    await selectShape(page, shapes(page).first());
  });

  test('should show 4 resize handles on selection', async ({ page }) => {
    await expect(page.locator('svg rect[data-handle]')).toHaveCount(4);
    for (const dir of ['nw', 'ne', 'sw', 'se']) {
      await expect(handles(page, dir)).toBeVisible();
    }
  });

  test('should resize via SE handle', async ({ page }) => {
    const rect = shapes(page).first();
    const [w0, h0] = await Promise.all([attr(rect, 'width'), attr(rect, 'height')]);

    await dragHandle(page, handles(page, 'se'), 50, 30);

    expect(await attr(rect, 'width')).toBeGreaterThan(w0);
    expect(await attr(rect, 'height')).toBeGreaterThan(h0);
  });

  test('should resize via NW handle', async ({ page }) => {
    const rect = shapes(page).first();
    const [x0, y0] = await Promise.all([attr(rect, 'x'), attr(rect, 'y')]);

    await dragHandle(page, handles(page, 'nw'), -30, -20);

    expect(await attr(rect, 'x')).toBeLessThan(x0);
    expect(await attr(rect, 'y')).toBeLessThan(y0);
  });

  test('should resize via NE handle', async ({ page }) => {
    const rect = shapes(page).first();
    const x0 = await attr(rect, 'x');

    await dragHandle(page, handles(page, 'ne'), 40, -30);
    expect(await attr(rect, 'x')).toBe(x0);
  });

  test('should resize via SW handle', async ({ page }) => {
    const rect = shapes(page).first();
    const y0 = await attr(rect, 'y');

    await dragHandle(page, handles(page, 'sw'), -40, 30);
    expect(await attr(rect, 'y')).toBe(y0);
  });

  test('should undo resize to restore dimensions', async ({ page }) => {
    const rect = shapes(page).first();
    const w0 = await rect.getAttribute('width');

    await dragHandle(page, handles(page, 'se'), 60, 40);
    expect(await rect.getAttribute('width')).not.toBe(w0);

    await undo(page);
    expect(await rect.getAttribute('width')).toBe(w0);
  });
});

test.describe('Line Endpoint Drag', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('button', { name: 'Line' })).toBeVisible();
    await page.getByRole('button', { name: 'Line' }).click();
    await page.waitForTimeout(200);
  });

  async function selectLine(page: Page) {
    const lineGroup = page.locator('svg g[data-element-type="line"]').first();
    await lineGroup.click({ force: true });
    await page.waitForTimeout(100);
    return lineGroup.locator('line').last();
  }

  test('should show line handles on selection', async ({ page }) => {
    await selectLine(page);
    await expect(lineHandles(page, 'start')).toBeVisible();
    await expect(lineHandles(page, 'end')).toBeVisible();
  });

  test('should drag line start endpoint', async ({ page }) => {
    const line = await selectLine(page);
    const x1 = await line.getAttribute('x1');

    await dragHandle(page, lineHandles(page, 'start'), -40, -20);
    expect(await line.getAttribute('x1')).not.toBe(x1);
  });

  test('should drag line end endpoint', async ({ page }) => {
    const line = await selectLine(page);
    const x2 = await line.getAttribute('x2');

    await dragHandle(page, lineHandles(page, 'end'), 60, 40);
    expect(await line.getAttribute('x2')).not.toBe(x2);
  });

  test('should undo line endpoint drag', async ({ page }) => {
    const line = await selectLine(page);
    const x2 = await line.getAttribute('x2');

    await dragHandle(page, lineHandles(page, 'end'), 50, 30);
    expect(await line.getAttribute('x2')).not.toBe(x2);

    await undo(page);
    expect(await line.getAttribute('x2')).toBe(x2);
  });
});

test.describe('Multi-Select Drag', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForEditor(page);
  });

  async function selectBoth(page: Page) {
    const rects = shapes(page);
    await rects.nth(0).click({ force: true });
    await rects.nth(1).click({ force: true, modifiers: ['Shift'] });
  }

  test('should drag two selected shapes together', async ({ page }) => {
    const rects = shapes(page);
    const [x1_0, x2_0] = await Promise.all([attr(rects.nth(0), 'x'), attr(rects.nth(1), 'x')]);

    await selectBoth(page);
    const c = await centerOf(rects.nth(0));
    await dragBy(page, c.x, c.y, 80, 40);

    expect(await attr(rects.nth(0), 'x')).not.toBe(x1_0);
    expect(await attr(rects.nth(1), 'x')).not.toBe(x2_0);
  });

  test('should undo multi-select drag', async ({ page }) => {
    const rects = shapes(page);
    await selectBoth(page);

    const [x1_0, x2_0] = await Promise.all([attr(rects.nth(0), 'x'), attr(rects.nth(1), 'x')]);

    await rects.nth(0).dragTo(page.locator('svg[viewBox]').first(), {
      targetPosition: { x: 300, y: 200 }, force: true,
    });

    for (let i = 0; i < 3; i++) {
      await undo(page);
    }

    expect(await attr(rects.nth(0), 'x')).toBe(x1_0);
    expect(await attr(rects.nth(1), 'x')).toBe(x2_0);
  });

  test('should drag Ctrl+A selected shapes', async ({ page }) => {
    const rects = shapes(page);
    const x0 = await attr(rects.nth(0), 'x');

    await page.locator('svg[viewBox]').first().click({ position: { x: 10, y: 10 } });
    await page.keyboard.press('Control+a');
    await page.waitForTimeout(100);

    const c = await centerOf(rects.nth(0));
    await dragBy(page, c.x, c.y, 30, 20);

    expect(await attr(rects.nth(0), 'x')).not.toBe(x0);
  });
});

test.describe('Drag with Grid Snap', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('button', { name: 'Grid Snap' })).toBeVisible();
    await page.getByRole('button', { name: 'Grid Snap' }).click();
    await page.waitForTimeout(50);
  });

  test('should snap to grid when dragging', async ({ page }) => {
    const rect = shapes(page).first();
    const c = await centerOf(rect);

    await dragBy(page, c.x, c.y, 73, 37);

    const [x, y] = await Promise.all([attr(rect, 'x'), attr(rect, 'y')]);
    expect(x % 20).toBe(0);
    expect(y % 20).toBe(0);
  });

  test('should snap resize to grid', async ({ page }) => {
    const rect = shapes(page).first();
    await selectShape(page, rect);

    await dragHandle(page, handles(page, 'se'), 33, 27);

    const [x, y, w, h] = await Promise.all([
      attr(rect, 'x'), attr(rect, 'y'), attr(rect, 'width'), attr(rect, 'height'),
    ]);
    expect((x + w) % 20).toBe(0);
    expect((y + h) % 20).toBe(0);
  });
});

test.describe('Drag Edge Cases', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForEditor(page);
  });

  test('should handle rapid drag-release cycles', async ({ page }) => {
    const c = await centerOf(shapes(page).first());

    for (let i = 0; i < 5; i++) {
      await dragBy(page, c.x, c.y, 10, 10, 2);
      await page.waitForTimeout(30);
    }

    await expect(page.locator('svg[viewBox]').first()).toBeVisible();
  });

  test('should handle Escape to cancel selection', async ({ page }) => {
    const rect = shapes(page).first();
    const x0 = await rect.getAttribute('x');

    await selectShape(page, rect);
    await expect(page.locator('svg rect[data-handle]').first()).toBeVisible();

    await page.keyboard.press('Escape');
    await page.waitForTimeout(100);

    await expect(page.locator('svg rect[data-handle]')).toHaveCount(0);
    expect(await rect.getAttribute('x')).toBe(x0);
  });

  test('should handle drag near edge of SVG', async ({ page }) => {
    await page.getByRole('button', { name: 'Rectangle' }).click();
    await page.waitForTimeout(100);

    const rect = shapes(page).last();
    const c = await centerOf(rect);
    const svgBox = await page.locator('svg[viewBox]').first().boundingBox();
    expect(svgBox).not.toBeNull();

    await page.mouse.move(c.x, c.y);
    await page.mouse.down();
    await page.mouse.move(svgBox!.x + svgBox!.width - 10, svgBox!.y + svgBox!.height - 10, { steps: 5 });
    await page.mouse.up();

    await expect(rect).toBeVisible();
  });

  test('should handle resize to very small size', async ({ page }) => {
    const rect = shapes(page).first();
    await selectShape(page, rect);

    const seBox = await centerOf(handles(page, 'se'));
    const nwBox = await centerOf(handles(page, 'nw'));

    await dragBy(page, seBox.x, seBox.y, nwBox.x - seBox.x + 5, nwBox.y - seBox.y + 5);

    const [w, h] = await Promise.all([attr(rect, 'width'), attr(rect, 'height')]);
    expect(w).toBeGreaterThanOrEqual(0);
    expect(h).toBeGreaterThanOrEqual(0);
  });

  test('should handle drag with different targets', async ({ page }) => {
    const rect = shapes(page).first();
    const svg = page.locator('svg[viewBox]').first();
    const svgBox = await svg.boundingBox();
    expect(svgBox).not.toBeNull();

    const x0 = await attr(rect, 'x');
    await rect.dragTo(svg, {
      targetPosition: { x: svgBox!.width * 0.3, y: svgBox!.height * 0.3 }, force: true,
    });
    expect(await attr(rect, 'x')).not.toBe(x0);

    await undo(page);

    const rects = shapes(page);
    if (await rects.count() >= 2) {
      const second = rects.nth(1);
      const x1 = await attr(second, 'x');
      await second.dragTo(svg, {
        targetPosition: { x: svgBox!.width * 0.8, y: svgBox!.height * 0.8 }, force: true,
      });
      expect(await attr(second, 'x')).not.toBe(x1);
    }
  });
});
