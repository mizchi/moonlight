import { test, expect } from '@playwright/test';

test.describe('Drag synchronization', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('resize handles should follow element when dragged', async ({ page }) => {
    const rect = page.locator('svg rect[data-id="el-1"]');

    // Get initial rect position
    const initialX = parseFloat(await rect.getAttribute('x') || '0');
    const initialY = parseFloat(await rect.getAttribute('y') || '0');
    const width = parseFloat(await rect.getAttribute('width') || '0');
    const height = parseFloat(await rect.getAttribute('height') || '0');

    // Drag the rect first (without selecting)
    await rect.dragTo(page.locator('svg'), {
      targetPosition: { x: 250, y: 200 }
    });
    await page.waitForTimeout(100);

    // Verify rect moved
    const newX = parseFloat(await rect.getAttribute('x') || '0');
    const newY = parseFloat(await rect.getAttribute('y') || '0');
    expect(newX).not.toBe(initialX);
    expect(newY).not.toBe(initialY);

    // Now click to select and show handles
    await rect.click();
    await page.waitForTimeout(100);

    // Verify SE handle is at correct position (matching new element position)
    const seHandle = page.locator('svg rect[data-handle="se"]');
    await expect(seHandle).toBeVisible();
    const handleX = parseFloat(await seHandle.getAttribute('x') || '0');
    const handleY = parseFloat(await seHandle.getAttribute('y') || '0');

    const handleSize = 8;
    const expectedHandleX = newX + width - handleSize / 2;
    const expectedHandleY = newY + height - handleSize / 2;

    expect(Math.abs(handleX - expectedHandleX)).toBeLessThan(1);
    expect(Math.abs(handleY - expectedHandleY)).toBeLessThan(1);
  });

  test('anchor points should follow element when dragged', async ({ page }) => {
    const rect = page.locator('svg rect[data-id="el-1"]');

    // Get initial rect position
    const initialX = parseFloat(await rect.getAttribute('x') || '0');
    const initialY = parseFloat(await rect.getAttribute('y') || '0');
    const width = parseFloat(await rect.getAttribute('width') || '0');

    // Drag the rect first
    await rect.dragTo(page.locator('svg'), {
      targetPosition: { x: 250, y: 200 }
    });
    await page.waitForTimeout(100);

    // Verify rect moved
    const newX = parseFloat(await rect.getAttribute('x') || '0');
    const newY = parseFloat(await rect.getAttribute('y') || '0');
    expect(newX).not.toBe(initialX);
    expect(newY).not.toBe(initialY);

    // Now click to select and show anchors
    await rect.click();
    await page.waitForTimeout(100);

    // Verify top anchor is at correct position
    const topAnchor = page.locator('svg circle[data-anchor="top"]');
    await expect(topAnchor).toBeVisible();
    const anchorCx = parseFloat(await topAnchor.getAttribute('cx') || '0');
    const anchorCy = parseFloat(await topAnchor.getAttribute('cy') || '0');

    const expectedAnchorCx = newX + width / 2;
    const expectedAnchorCy = newY;

    expect(Math.abs(anchorCx - expectedAnchorCx)).toBeLessThan(1);
    expect(Math.abs(anchorCy - expectedAnchorCy)).toBeLessThan(1);
  });

  test('handles should update during drag (not just after)', async ({ page }) => {
    const rect = page.locator('svg rect[data-id="el-1"]');

    // Click to select
    await rect.click();
    await page.waitForTimeout(100);

    // Get SE handle
    const seHandle = page.locator('svg rect[data-handle="se"]');
    await expect(seHandle).toBeVisible();
    const initialHandleX = parseFloat(await seHandle.getAttribute('x') || '0');
    const initialHandleY = parseFloat(await seHandle.getAttribute('y') || '0');

    // Get rect bounding box for drag
    const rectBox = await rect.boundingBox();
    expect(rectBox).not.toBeNull();

    // Perform manual drag with mouse events
    await page.mouse.move(rectBox!.x + rectBox!.width / 2, rectBox!.y + rectBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(rectBox!.x + rectBox!.width / 2 + 50, rectBox!.y + rectBox!.height / 2 + 30);

    // Check handle position during drag (before mouse up)
    await page.waitForTimeout(50);
    const duringDragHandleX = parseFloat(await seHandle.getAttribute('x') || '0');
    const duringDragHandleY = parseFloat(await seHandle.getAttribute('y') || '0');

    await page.mouse.up();
    await page.waitForTimeout(100);

    // Handle should have moved during drag
    expect(duringDragHandleX).not.toBe(initialHandleX);
    expect(duringDragHandleY).not.toBe(initialHandleY);
  });

  test('circle element handles should be at correct position after drag', async ({ page }) => {
    const circle = page.locator('svg circle[data-id="el-3"]');
    const radius = parseFloat(await circle.getAttribute('r') || '0');

    // Get initial position
    const initialCx = parseFloat(await circle.getAttribute('cx') || '0');
    const initialCy = parseFloat(await circle.getAttribute('cy') || '0');

    // Drag the circle
    await circle.dragTo(page.locator('svg'), {
      targetPosition: { x: 200, y: 150 }
    });
    await page.waitForTimeout(100);

    // Verify circle moved
    const newCx = parseFloat(await circle.getAttribute('cx') || '0');
    const newCy = parseFloat(await circle.getAttribute('cy') || '0');
    expect(newCx).not.toBe(initialCx);
    expect(newCy).not.toBe(initialCy);

    // Click to select
    await circle.click();
    await page.waitForTimeout(100);

    // Verify SE handle is at correct position (SE corner of bounding box)
    const seHandle = page.locator('svg rect[data-handle="se"]');
    await expect(seHandle).toBeVisible();
    const handleX = parseFloat(await seHandle.getAttribute('x') || '0');
    const handleY = parseFloat(await seHandle.getAttribute('y') || '0');

    const handleSize = 8;
    const expectedHandleX = newCx + radius - handleSize / 2;
    const expectedHandleY = newCy + radius - handleSize / 2;

    expect(Math.abs(handleX - expectedHandleX)).toBeLessThan(1);
    expect(Math.abs(handleY - expectedHandleY)).toBeLessThan(1);
  });
});
