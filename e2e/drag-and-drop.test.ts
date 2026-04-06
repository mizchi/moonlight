import { test, expect, type Page } from '@playwright/test';

/**
 * Drag-and-Drop comprehensive tests.
 *
 * Covers: move, resize (all corners), line endpoints, multi-select,
 * grid snap, undo, cancel, edge cases.
 */

test.describe('Shape Drag (Move)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('svg rect[data-id][cursor="move"]').first()).toBeVisible();
  });

  test('should drag rectangle to new position', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    const initialX = parseFloat(await rect.getAttribute('x') || '0');
    const initialY = parseFloat(await rect.getAttribute('y') || '0');

    const box = await rect.boundingBox();
    expect(box).not.toBeNull();

    await page.mouse.move(box!.x + box!.width / 2, box!.y + box!.height / 2);
    await page.mouse.down();
    await page.mouse.move(box!.x + box!.width / 2 + 80, box!.y + box!.height / 2 + 60, { steps: 5 });
    await page.mouse.up();

    const newX = parseFloat(await rect.getAttribute('x') || '0');
    const newY = parseFloat(await rect.getAttribute('y') || '0');
    expect(newX).not.toBe(initialX);
    expect(newY).not.toBe(initialY);
  });

  test('should drag circle to new position', async ({ page }) => {
    // Select an existing circle (if any) or use rect for drag testing
    const circle = page.locator('svg circle[data-id][cursor="move"]');
    const count = await circle.count();
    test.skip(count === 0, 'No circle available for drag test');

    const initialCx = parseFloat(await circle.first().getAttribute('cx') || '0');

    // Click to select, then drag using mouse events
    const box = await circle.first().boundingBox();
    if (!box) return;

    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    await page.mouse.down();
    await page.mouse.move(box.x + box.width / 2 + 80, box.y + box.height / 2 + 60, { steps: 10 });
    await page.mouse.up();

    const newCx = parseFloat(await circle.first().getAttribute('cx') || '0');
    expect(newCx).not.toBe(initialCx);
  });

  test('should drag ellipse to new position', async ({ page }) => {
    // Select an existing ellipse (if any)
    const ellipse = page.locator('svg ellipse[data-id][cursor="move"]');
    const count = await ellipse.count();
    test.skip(count === 0, 'No ellipse available for drag test');

    const initialCx = parseFloat(await ellipse.first().getAttribute('cx') || '0');

    const box = await ellipse.first().boundingBox();
    if (!box) return;

    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    await page.mouse.down();
    await page.mouse.move(box.x + box.width / 2 + 70, box.y + box.height / 2 + 50, { steps: 10 });
    await page.mouse.up();

    const newCx = parseFloat(await ellipse.first().getAttribute('cx') || '0');
    expect(newCx).not.toBe(initialCx);
  });

  test('should drag text element to new position', async ({ page }) => {
    // Add a text element first
    await page.getByRole('button', { name: 'Text' }).click();
    await page.waitForTimeout(200);

    const textGroup = page.locator('svg g[data-element-type="text"]').last();
    const rect = textGroup.locator('rect').first();
    const initialX = parseFloat(await rect.getAttribute('x') || '0');

    const svg = page.locator('svg[viewBox]').first();
    const svgBox = await svg.boundingBox();
    expect(svgBox).not.toBeNull();

    await textGroup.dragTo(svg, {
      targetPosition: { x: svgBox!.width * 0.6, y: svgBox!.height * 0.5 },
      force: true,
    });

    const newX = parseFloat(await rect.getAttribute('x') || '0');
    expect(newX).not.toBe(initialX);
  });

  test('should not move shape on click without drag (zero-distance)', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    const initialX = await rect.getAttribute('x');

    const box = await rect.boundingBox();
    expect(box).not.toBeNull();

    // Click without moving
    await page.mouse.move(box!.x + box!.width / 2, box!.y + box!.height / 2);
    await page.mouse.down();
    await page.mouse.up();

    const newX = await rect.getAttribute('x');
    expect(newX).toBe(initialX);
  });

  test('should undo drag to restore position', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    const initialX = await rect.getAttribute('x');

    const box = await rect.boundingBox();
    expect(box).not.toBeNull();

    // Drag
    await page.mouse.move(box!.x + box!.width / 2, box!.y + box!.height / 2);
    await page.mouse.down();
    await page.mouse.move(box!.x + box!.width / 2 + 100, box!.y + box!.height / 2 + 50, { steps: 5 });
    await page.mouse.up();

    // Verify moved
    const movedX = await rect.getAttribute('x');
    expect(movedX).not.toBe(initialX);

    // Undo
    await page.keyboard.press('Control+z');
    await page.waitForTimeout(100);

    const restoredX = await rect.getAttribute('x');
    expect(restoredX).toBe(initialX);
  });
});

test.describe('Resize Handles', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('svg rect[data-id][cursor="move"]').first()).toBeVisible();
    // Select the first rect to show handles
    await page.locator('svg rect[data-id][cursor="move"]').first().click({ force: true });
    await page.waitForTimeout(100);
  });

  test('should show 4 resize handles on selection', async ({ page }) => {
    const handles = page.locator('svg rect[data-handle]');
    await expect(handles).toHaveCount(4);

    await expect(page.locator('svg rect[data-handle="nw"]')).toBeVisible();
    await expect(page.locator('svg rect[data-handle="ne"]')).toBeVisible();
    await expect(page.locator('svg rect[data-handle="sw"]')).toBeVisible();
    await expect(page.locator('svg rect[data-handle="se"]')).toBeVisible();
  });

  test('should resize via SE handle (grow right-down)', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    const initialWidth = parseFloat(await rect.getAttribute('width') || '0');
    const initialHeight = parseFloat(await rect.getAttribute('height') || '0');

    const handle = page.locator('svg rect[data-handle="se"]');
    const handleBox = await handle.boundingBox();
    expect(handleBox).not.toBeNull();

    await page.mouse.move(handleBox!.x + handleBox!.width / 2, handleBox!.y + handleBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(handleBox!.x + 50, handleBox!.y + 30, { steps: 5 });
    await page.mouse.up();

    const newWidth = parseFloat(await rect.getAttribute('width') || '0');
    const newHeight = parseFloat(await rect.getAttribute('height') || '0');
    expect(newWidth).toBeGreaterThan(initialWidth);
    expect(newHeight).toBeGreaterThan(initialHeight);
  });

  test('should resize via NW handle (grow left-up)', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    const initialX = parseFloat(await rect.getAttribute('x') || '0');
    const initialY = parseFloat(await rect.getAttribute('y') || '0');

    const handle = page.locator('svg rect[data-handle="nw"]');
    const handleBox = await handle.boundingBox();
    expect(handleBox).not.toBeNull();

    await page.mouse.move(handleBox!.x + handleBox!.width / 2, handleBox!.y + handleBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(handleBox!.x - 30, handleBox!.y - 20, { steps: 5 });
    await page.mouse.up();

    const newX = parseFloat(await rect.getAttribute('x') || '0');
    const newY = parseFloat(await rect.getAttribute('y') || '0');
    expect(newX).toBeLessThan(initialX);
    expect(newY).toBeLessThan(initialY);
  });

  test('should resize via NE handle', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    const initialX = parseFloat(await rect.getAttribute('x') || '0');

    const handle = page.locator('svg rect[data-handle="ne"]');
    const handleBox = await handle.boundingBox();
    expect(handleBox).not.toBeNull();

    await page.mouse.move(handleBox!.x + handleBox!.width / 2, handleBox!.y + handleBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(handleBox!.x + 40, handleBox!.y - 30, { steps: 5 });
    await page.mouse.up();

    // X stays the same (NE moves right and up, but x is from left edge)
    const newX = parseFloat(await rect.getAttribute('x') || '0');
    expect(newX).toBe(initialX);
  });

  test('should resize via SW handle', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    const initialY = parseFloat(await rect.getAttribute('y') || '0');

    const handle = page.locator('svg rect[data-handle="sw"]');
    const handleBox = await handle.boundingBox();
    expect(handleBox).not.toBeNull();

    await page.mouse.move(handleBox!.x + handleBox!.width / 2, handleBox!.y + handleBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(handleBox!.x - 40, handleBox!.y + 30, { steps: 5 });
    await page.mouse.up();

    // Y stays the same (SW moves left and down, but y is from top edge)
    const newY = parseFloat(await rect.getAttribute('y') || '0');
    expect(newY).toBe(initialY);
  });

  test('should undo resize to restore dimensions', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    const initialWidth = await rect.getAttribute('width');

    const handle = page.locator('svg rect[data-handle="se"]');
    const handleBox = await handle.boundingBox();
    expect(handleBox).not.toBeNull();

    await page.mouse.move(handleBox!.x + handleBox!.width / 2, handleBox!.y + handleBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(handleBox!.x + 60, handleBox!.y + 40, { steps: 5 });
    await page.mouse.up();

    // Verify resized
    const resizedWidth = await rect.getAttribute('width');
    expect(resizedWidth).not.toBe(initialWidth);

    // Undo
    await page.keyboard.press('Control+z');
    await page.waitForTimeout(100);

    const restoredWidth = await rect.getAttribute('width');
    expect(restoredWidth).toBe(initialWidth);
  });
});

test.describe('Line Endpoint Drag', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('button', { name: 'Line' })).toBeVisible();
    // Add a fresh line to ensure we have a visible one
    await page.getByRole('button', { name: 'Line' }).click();
    await page.waitForTimeout(200);
  });

  test('should show line handles on selection', async ({ page }) => {
    const lineGroup = page.locator('svg g[data-element-type="line"]').first();
    await lineGroup.click({ force: true });
    await page.waitForTimeout(100);

    const handles = page.locator('svg circle[data-handle]');
    await expect(handles).toHaveCount(2);
    await expect(page.locator('svg circle[data-handle="line-start"]')).toBeVisible();
    await expect(page.locator('svg circle[data-handle="line-end"]')).toBeVisible();
  });

  test('should drag line start endpoint', async ({ page }) => {
    const lineGroup = page.locator('svg g[data-element-type="line"]').first();
    const line = lineGroup.locator('line').last();
    await lineGroup.click({ force: true });
    await page.waitForTimeout(100);

    const initialX1 = await line.getAttribute('x1');
    const initialY1 = await line.getAttribute('y1');

    const handle = page.locator('svg circle[data-handle="line-start"]');
    const handleBox = await handle.boundingBox();
    expect(handleBox).not.toBeNull();

    await page.mouse.move(handleBox!.x + handleBox!.width / 2, handleBox!.y + handleBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(handleBox!.x - 40, handleBox!.y - 20, { steps: 5 });
    await page.mouse.up();

    const newX1 = await line.getAttribute('x1');
    const newY1 = await line.getAttribute('y1');
    expect(newX1).not.toBe(initialX1);
    expect(newY1).not.toBe(initialY1);
  });

  test('should drag line end endpoint', async ({ page }) => {
    const lineGroup = page.locator('svg g[data-element-type="line"]').first();
    const line = lineGroup.locator('line').last();
    await lineGroup.click({ force: true });
    await page.waitForTimeout(100);

    const initialX2 = await line.getAttribute('x2');
    const initialY2 = await line.getAttribute('y2');

    const handle = page.locator('svg circle[data-handle="line-end"]');
    const handleBox = await handle.boundingBox();
    expect(handleBox).not.toBeNull();

    await page.mouse.move(handleBox!.x + handleBox!.width / 2, handleBox!.y + handleBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(handleBox!.x + 60, handleBox!.y + 40, { steps: 5 });
    await page.mouse.up();

    const newX2 = await line.getAttribute('x2');
    const newY2 = await line.getAttribute('y2');
    expect(newX2).not.toBe(initialX2);
    expect(newY2).not.toBe(initialY2);
  });

  test('should undo line endpoint drag', async ({ page }) => {
    const lineGroup = page.locator('svg g[data-element-type="line"]').first();
    const line = lineGroup.locator('line').last();
    await lineGroup.click({ force: true });
    await page.waitForTimeout(100);

    const initialX2 = await line.getAttribute('x2');

    const handle = page.locator('svg circle[data-handle="line-end"]');
    const handleBox = await handle.boundingBox();
    expect(handleBox).not.toBeNull();

    await page.mouse.move(handleBox!.x + handleBox!.width / 2, handleBox!.y + handleBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(handleBox!.x + 50, handleBox!.y + 30, { steps: 5 });
    await page.mouse.up();

    // Undo
    await page.keyboard.press('Control+z');
    await page.waitForTimeout(100);

    const restoredX2 = await line.getAttribute('x2');
    expect(restoredX2).toBe(initialX2);
  });
});

test.describe('Multi-Select Drag', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('svg rect[data-id][cursor="move"]').first()).toBeVisible();
  });

  test('should drag two selected shapes together', async ({ page }) => {
    const rects = page.locator('svg rect[data-id][cursor="move"]');
    const initialX1 = parseFloat(await rects.nth(0).getAttribute('x') || '0');
    const initialX2 = parseFloat(await rects.nth(1).getAttribute('x') || '0');

    // Select both
    await rects.nth(0).click({ force: true });
    await rects.nth(1).click({ force: true, modifiers: ['Shift'] });

    // Drag first
    const box = await rects.nth(0).boundingBox();
    expect(box).not.toBeNull();

    await page.mouse.move(box!.x + box!.width / 2, box!.y + box!.height / 2);
    await page.mouse.down();
    await page.mouse.move(box!.x + box!.width / 2 + 80, box!.y + box!.height / 2 + 40, { steps: 5 });
    await page.mouse.up();

    const newX1 = parseFloat(await rects.nth(0).getAttribute('x') || '0');
    const newX2 = parseFloat(await rects.nth(1).getAttribute('x') || '0');
    expect(newX1).not.toBe(initialX1);
    expect(newX2).not.toBe(initialX2);
  });

  test('should undo multi-select drag', async ({ page }) => {
    const rects = page.locator('svg rect[data-id][cursor="move"]');

    // Select both
    await rects.nth(0).click({ force: true });
    await rects.nth(1).click({ force: true, modifiers: ['Shift'] });

    // Get positions AFTER selection
    const initialX1 = parseFloat(await rects.nth(0).getAttribute('x') || '0');
    const initialX2 = parseFloat(await rects.nth(1).getAttribute('x') || '0');

    // Drag the first element
    await rects.nth(0).dragTo(page.locator('svg[viewBox]').first(), {
      targetPosition: { x: 300, y: 200 },
      force: true,
    });

    // Verify both moved (multi-select)
    const movedX1 = parseFloat(await rects.nth(0).getAttribute('x') || '0');
    const movedX2 = parseFloat(await rects.nth(1).getAttribute('x') || '0');
    expect(movedX1).not.toBe(initialX1);
    expect(movedX2).not.toBe(initialX2);

    // Undo - press multiple times to ensure full undo
    for (let i = 0; i < 3; i++) {
      await page.keyboard.press('Control+z');
      await page.waitForTimeout(50);
    }

    // After undo, positions should be restored
    const restoredX1 = parseFloat(await rects.nth(0).getAttribute('x') || '0');
    const restoredX2 = parseFloat(await rects.nth(1).getAttribute('x') || '0');
    expect(restoredX1).toBe(initialX1);
    expect(restoredX2).toBe(initialX2);
  });

  test('should drag Ctrl+A selected shapes', async ({ page }) => {
    const rects = page.locator('svg rect[data-id][cursor="move"]');
    const initialCount = await rects.count();

    // Select all
    await page.locator('svg[viewBox]').first().click({ position: { x: 10, y: 10 } });
    await page.keyboard.press('Control+a');
    await page.waitForTimeout(100);

    // Get all rects initial positions
    const initialPositions: number[] = [];
    for (let i = 0; i < initialCount; i++) {
      initialPositions.push(parseFloat(await rects.nth(i).getAttribute('x') || '0'));
    }

    // Drag first selected element
    const box = await rects.nth(0).boundingBox();
    expect(box).not.toBeNull();

    await page.mouse.move(box!.x + box!.width / 2, box!.y + box!.height / 2);
    await page.mouse.down();
    await page.mouse.move(box!.x + box!.width / 2 + 30, box!.y + box!.height / 2 + 20, { steps: 5 });
    await page.mouse.up();

    // At least the first one should have moved
    const newX = parseFloat(await rects.nth(0).getAttribute('x') || '0');
    expect(newX).not.toBe(initialPositions[0]);
  });
});

test.describe('Drag with Grid Snap', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('button', { name: 'Grid Snap' })).toBeVisible();
    // Enable grid snap
    await page.getByRole('button', { name: 'Grid Snap' }).click();
    await page.waitForTimeout(50);
  });

  test('should snap to grid when dragging', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    const box = await rect.boundingBox();
    expect(box).not.toBeNull();

    // Drag to non-grid-aligned position
    await page.mouse.move(box!.x + box!.width / 2, box!.y + box!.height / 2);
    await page.mouse.down();
    await page.mouse.move(box!.x + 73, box!.y + 37, { steps: 5 });
    await page.mouse.up();

    // Result should be grid-aligned
    const newX = parseFloat(await rect.getAttribute('x') || '0');
    const newY = parseFloat(await rect.getAttribute('y') || '0');
    expect(newX % 20).toBe(0);
    expect(newY % 20).toBe(0);
  });

  test('should snap resize to grid', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    await rect.click({ force: true });
    await page.waitForTimeout(100);

    const handle = page.locator('svg rect[data-handle="se"]');
    const handleBox = await handle.boundingBox();
    expect(handleBox).not.toBeNull();

    await page.mouse.move(handleBox!.x + handleBox!.width / 2, handleBox!.y + handleBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(handleBox!.x + 33, handleBox!.y + 27, { steps: 5 });
    await page.mouse.up();

    const x = parseFloat(await rect.getAttribute('x') || '0');
    const y = parseFloat(await rect.getAttribute('y') || '0');
    const width = parseFloat(await rect.getAttribute('width') || '0');
    const height = parseFloat(await rect.getAttribute('height') || '0');

    // SE corner should be grid-aligned
    expect((x + width) % 20).toBe(0);
    expect((y + height) % 20).toBe(0);
  });
});

test.describe('Drag Edge Cases', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('svg rect[data-id][cursor="move"]').first()).toBeVisible();
  });

  test('should handle rapid drag-release cycles', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    const box = await rect.boundingBox();
    expect(box).not.toBeNull();

    const cx = box!.x + box!.width / 2;
    const cy = box!.y + box!.height / 2;

    // Rapid drag-release
    for (let i = 0; i < 5; i++) {
      await page.mouse.move(cx, cy);
      await page.mouse.down();
      await page.mouse.move(cx + 10, cy + 10, { steps: 2 });
      await page.mouse.up();
      await page.waitForTimeout(30);
    }

    // Should not crash - verify SVG is still visible
    await expect(page.locator('svg[viewBox]').first()).toBeVisible();
  });

  test('should handle drag then Escape to cancel selection', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    const initialX = await rect.getAttribute('x');

    // Select
    await rect.click({ force: true });
    await page.waitForTimeout(100);

    // Should have resize handles
    await expect(page.locator('svg rect[data-handle]').first()).toBeVisible();

    // Escape to deselect
    await page.keyboard.press('Escape');
    await page.waitForTimeout(100);

    // Handles should be gone
    await expect(page.locator('svg rect[data-handle]')).toHaveCount(0);

    // Position should not change
    const newX = await rect.getAttribute('x');
    expect(newX).toBe(initialX);
  });

  test('should handle drag near edge of SVG', async ({ page }) => {
    // Add a rectangle
    await page.getByRole('button', { name: 'Rectangle' }).click();
    await page.waitForTimeout(100);

    const rect = page.locator('svg rect[data-id][cursor="move"]').last();
    const box = await rect.boundingBox();
    expect(box).not.toBeNull();

    // Drag toward the edge
    const svg = page.locator('svg[viewBox]').first();
    const svgBox = await svg.boundingBox();
    expect(svgBox).not.toBeNull();

    await page.mouse.move(box!.x + box!.width / 2, box!.y + box!.height / 2);
    await page.mouse.down();
    // Move to near the SVG edge
    await page.mouse.move(svgBox!.x + svgBox!.width - 10, svgBox!.y + svgBox!.height - 10, { steps: 5 });
    await page.mouse.up();

    // Shape should still exist (not deleted)
    await expect(rect).toBeVisible();
  });

  test('should handle resize to very small size', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    await rect.click({ force: true });
    await page.waitForTimeout(100);

    const handle = page.locator('svg rect[data-handle="se"]');
    const handleBox = await handle.boundingBox();
    expect(handleBox).not.toBeNull();

    // Get NW handle position (fixed corner)
    const nwHandle = page.locator('svg rect[data-handle="nw"]');
    const nwBox = await nwHandle.boundingBox();
    expect(nwBox).not.toBeNull();

    // Drag SE to almost NW position
    await page.mouse.move(handleBox!.x + handleBox!.width / 2, handleBox!.y + handleBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(nwBox!.x + 5, nwBox!.y + 5, { steps: 5 });
    await page.mouse.up();

    // Width and height should be positive (or at minimum)
    const width = parseFloat(await rect.getAttribute('width') || '0');
    const height = parseFloat(await rect.getAttribute('height') || '0');
    expect(width).toBeGreaterThanOrEqual(0);
    expect(height).toBeGreaterThanOrEqual(0);
  });

  test('should handle drag with different step counts', async ({ page }) => {
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    const svg = page.locator('svg[viewBox]').first();
    const svgBox = await svg.boundingBox();
    expect(svgBox).not.toBeNull();

    // Test with 1 step (instant drag)
    const initialX = parseFloat(await rect.getAttribute('x') || '0');

    await rect.dragTo(svg, {
      targetPosition: { x: svgBox!.width * 0.3, y: svgBox!.height * 0.3 },
      force: true,
    });

    const afterDrag = parseFloat(await rect.getAttribute('x') || '0');
    expect(afterDrag).not.toBe(initialX);

    // Undo
    await page.keyboard.press('Control+z');
    await page.waitForTimeout(100);

    // Test with many steps on a different element
    const rects = page.locator('svg rect[data-id][cursor="move"]');
    const count = await rects.count();
    if (count >= 2) {
      const secondRect = rects.nth(1);
      const secondInitial = parseFloat(await secondRect.getAttribute('x') || '0');

      await secondRect.dragTo(svg, {
        targetPosition: { x: svgBox!.width * 0.8, y: svgBox!.height * 0.8 },
        force: true,
      });

      const secondAfter = parseFloat(await secondRect.getAttribute('x') || '0');
      expect(secondAfter).not.toBe(secondInitial);
    }
  });
});
