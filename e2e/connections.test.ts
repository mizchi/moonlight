import { test, expect } from '@playwright/test';

// Line connection feature tests

test.describe('Line Connections', () => {
  test.beforeEach(async ({ page }) => {
    // Set viewport to match coordinate transformation expectations
    await page.setViewportSize({ width: 800, height: 600 });
    await page.goto('/');
  });

  test('should show line handles when line is selected', async ({ page }) => {
    // Use an existing line (scene already has lines)
    // Select the first line (Line is wrapped in a group with data-element-type="line")
    const lineGroup = page.locator('svg g[data-element-type="line"]').first();
    await lineGroup.click({ force: true });
    await page.waitForTimeout(100);

    // Check that circular handles appear (line uses circles, not rects)
    const handles = page.locator('svg circle[data-handle]');
    await expect(handles).toHaveCount(2);

    // Check handle types
    await expect(page.locator('svg circle[data-handle="line-start"]')).toBeVisible();
    await expect(page.locator('svg circle[data-handle="line-end"]')).toBeVisible();
  });

  test('should drag line endpoint', async ({ page }) => {
    // Use an existing line (scene already has lines)
    // Select the first line by clicking on it (use mouse.click for precise positioning)
    const lineGroup = page.locator('svg g[data-element-type="line"]').first();
    const lineGroupBox = await lineGroup.boundingBox();
    expect(lineGroupBox).not.toBeNull();

    // Click on the center of the line group to select it
    await page.mouse.click(
      lineGroupBox!.x + lineGroupBox!.width / 2,
      lineGroupBox!.y + lineGroupBox!.height / 2
    );
    await page.waitForTimeout(100);

    // Get the actual line element (the visible one, not the hit area)
    const line = lineGroup.locator('line').last();

    // Get initial position of the line end
    const initialX2 = await line.getAttribute('x2');
    const initialY2 = await line.getAttribute('y2');

    // Drag the end handle
    const endHandle = page.locator('svg circle[data-handle="line-end"]');
    const handleBox = await endHandle.boundingBox();
    expect(handleBox).not.toBeNull();

    await page.mouse.move(handleBox!.x + handleBox!.width / 2, handleBox!.y + handleBox!.height / 2);
    await page.mouse.down();
    await page.waitForTimeout(50);
    await page.mouse.move(handleBox!.x + 50, handleBox!.y + 30);
    await page.waitForTimeout(50);
    await page.mouse.up();
    await page.waitForTimeout(100);

    // Check that the end position changed
    const newX2 = await line.getAttribute('x2');
    const newY2 = await line.getAttribute('y2');
    expect(newX2).not.toBe(initialX2);
    expect(newY2).not.toBe(initialY2);
  });

  test('should show anchor points on selected shape', async ({ page }) => {
    // Select the first rect (exclude text hit areas which have fill="transparent")
    // Use force:true because child text hit area may intercept clicks
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    await rect.click({ force: true });
    await page.waitForTimeout(100);

    // Check that anchor points are visible (circles with data-anchor attribute)
    // We expect 4 edge anchors (top, bottom, left, right) - corners are skipped
    const anchors = page.locator('svg circle[data-anchor]');
    await expect(anchors).toHaveCount(4);

    // Verify the anchor types
    await expect(page.locator('svg circle[data-anchor="top"]')).toBeVisible();
    await expect(page.locator('svg circle[data-anchor="bottom"]')).toBeVisible();
    await expect(page.locator('svg circle[data-anchor="left"]')).toBeVisible();
    await expect(page.locator('svg circle[data-anchor="right"]')).toBeVisible();
  });

  test('should show connection highlight when dragging line endpoint near anchor', async ({ page }) => {
    // Use an existing line (scene already has lines)
    // Select the first line (Line is wrapped in a group with data-element-type="line")
    const lineGroup = page.locator('svg g[data-element-type="line"]').first();
    await lineGroup.click({ force: true });
    await page.waitForTimeout(100);

    // Get rect position for targeting (exclude text hit areas)
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    const rectBox = await rect.boundingBox();
    expect(rectBox).not.toBeNull();

    // Drag line end handle toward the rect
    const endHandle = page.locator('svg circle[data-handle="line-end"]');
    const handleBox = await endHandle.boundingBox();
    expect(handleBox).not.toBeNull();

    await page.mouse.move(handleBox!.x + handleBox!.width / 2, handleBox!.y + handleBox!.height / 2);
    await page.mouse.down();

    // Move toward right edge of the rect (where anchor is)
    await page.mouse.move(rectBox!.x + rectBox!.width, rectBox!.y + rectBox!.height / 2);
    await page.waitForTimeout(50);

    // During drag, anchor points should be visible
    const anchors = page.locator('svg circle:not([data-handle])').filter({ hasNot: page.locator('[data-id]') });
    const anchorCount = await anchors.count();
    expect(anchorCount).toBeGreaterThan(0);

    await page.mouse.up();
  });

  test('should maintain selection when resizing shape', async ({ page }) => {
    // Select first rect (exclude text hit areas which have fill="transparent")
    // Use force:true because child text hit area may intercept clicks
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    await rect.click({ force: true });
    await page.waitForTimeout(100);

    // Check resize handles are visible
    const resizeHandles = page.locator('svg rect[data-handle]');
    await expect(resizeHandles).toHaveCount(4);

    // Resize using SE handle
    const seHandle = page.locator('svg rect[data-handle="se"]');
    const handleBox = await seHandle.boundingBox();
    expect(handleBox).not.toBeNull();

    await page.mouse.move(handleBox!.x + handleBox!.width / 2, handleBox!.y + handleBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(handleBox!.x + 30, handleBox!.y + 20);
    await page.mouse.up();
    await page.waitForTimeout(100);

    // Shape should still be selected (has resize handles)
    await expect(resizeHandles).toHaveCount(4);
  });
});

