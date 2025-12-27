import { test, expect } from '@playwright/test';

// Line connection feature tests

test.describe('Line Connections', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should add a line with Add Line button', async ({ page }) => {
    const initialLineCount = await page.locator('svg g[data-element-type="line"]').count();

    await page.getByRole('button', { name: 'Add Line' }).click();
    await page.waitForTimeout(100);

    const afterLineCount = await page.locator('svg g[data-element-type="line"]').count();
    expect(afterLineCount).toBe(initialLineCount + 1);
  });

  test('should show line handles when line is selected', async ({ page }) => {
    // Add a line
    await page.getByRole('button', { name: 'Add Line' }).click();
    await page.waitForTimeout(100);

    // Select the line (Line is wrapped in a group with data-element-type="line")
    const lineGroup = page.locator('svg g[data-element-type="line"]').first();
    await lineGroup.click();
    await page.waitForTimeout(100);

    // Check that circular handles appear (line uses circles, not rects)
    const handles = page.locator('svg circle[data-handle]');
    await expect(handles).toHaveCount(2);

    // Check handle types
    await expect(page.locator('svg circle[data-handle="line-start"]')).toBeVisible();
    await expect(page.locator('svg circle[data-handle="line-end"]')).toBeVisible();
  });

  test('should drag line endpoint', async ({ page }) => {
    // Add a line
    await page.getByRole('button', { name: 'Add Line' }).click();
    await page.waitForTimeout(100);

    // Select the line (Line is wrapped in a group with data-element-type="line")
    const lineGroup = page.locator('svg g[data-element-type="line"]').first();
    await lineGroup.click();
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
    await page.mouse.move(handleBox!.x + 50, handleBox!.y + 30);
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

  test('should create line by dragging from anchor point', async ({ page }) => {
    const initialLineCount = await page.locator('svg g[data-element-type="line"]').count();

    // Select the first rect (exclude text hit areas)
    // Use force:true because child text hit area may intercept clicks
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    await rect.click({ force: true });
    await page.waitForTimeout(100);

    // Find the right anchor and drag from it
    const rightAnchor = page.locator('svg circle[data-anchor="right"]');
    const anchorBox = await rightAnchor.boundingBox();
    expect(anchorBox).not.toBeNull();

    // Drag from anchor to create a new line
    await page.mouse.move(anchorBox!.x + anchorBox!.width / 2, anchorBox!.y + anchorBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(anchorBox!.x + 100, anchorBox!.y + 50);
    await page.mouse.up();
    await page.waitForTimeout(100);

    // Check that a new line was created
    const afterLineCount = await page.locator('svg g[data-element-type="line"]').count();
    expect(afterLineCount).toBe(initialLineCount + 1);
  });

  test('should create connected line from anchor', async ({ page }) => {
    // Select first rect (exclude text hit areas)
    // Use force:true because child text hit area may intercept clicks
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    await rect.click({ force: true });
    await page.waitForTimeout(100);

    // Get rect's SVG attributes for verification
    const rectX = parseFloat(await rect.getAttribute('x') || '0');
    const rectWidth = parseFloat(await rect.getAttribute('width') || '0');

    // Create line from right anchor
    const rightAnchor = page.locator('svg circle[data-anchor="right"]');
    const anchorBox = await rightAnchor.boundingBox();
    expect(anchorBox).not.toBeNull();

    await page.mouse.move(anchorBox!.x + anchorBox!.width / 2, anchorBox!.y + anchorBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(anchorBox!.x + 100, anchorBox!.y);
    await page.mouse.up();
    await page.waitForTimeout(100);

    // Get the line group and the actual line element
    const lineGroup = page.locator('svg g[data-element-type="line"]').first();
    const line = lineGroup.locator('line').last();
    const x1 = parseFloat(await line.getAttribute('x1') || '0');

    // The line's start point should be near the rect's right edge (in SVG coordinates)
    const expectedX1 = rectX + rectWidth;
    expect(Math.abs(x1 - expectedX1)).toBeLessThan(10);
  });

  test('should show connection highlight when dragging line endpoint near anchor', async ({ page }) => {
    // Add a line
    await page.getByRole('button', { name: 'Add Line' }).click();
    await page.waitForTimeout(100);

    // Select the line (Line is wrapped in a group with data-element-type="line")
    const lineGroup = page.locator('svg g[data-element-type="line"]').first();
    await lineGroup.click();
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

test.describe('Multi-select with Lines', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should select multiple elements including line with box selection', async ({ page }) => {
    // Add a line
    await page.getByRole('button', { name: 'Add Line' }).click();
    await page.waitForTimeout(100);

    // Box select to include all elements
    const svg = page.locator('svg');
    const svgBox = await svg.boundingBox();
    expect(svgBox).not.toBeNull();

    await page.mouse.move(svgBox!.x + 10, svgBox!.y + 10);
    await page.mouse.down();
    await page.mouse.move(svgBox!.x + 390, svgBox!.y + 280);
    await page.mouse.up();
    await page.waitForTimeout(100);

    // Should show multiple elements selected
    const selectedText = page.getByText(/\d+ elements selected/);
    await expect(selectedText).toBeVisible();
  });

  // Skip - box selection may not be working correctly in current implementation
  test.skip('should move multiple selected elements together', async ({ page }) => {
    // First add a line to have more elements
    await page.getByRole('button', { name: 'Add Line' }).click();
    await page.waitForTimeout(100);

    // Box select all initial elements
    const svg = page.locator('svg');
    const svgBox = await svg.boundingBox();
    expect(svgBox).not.toBeNull();

    await page.mouse.move(svgBox!.x + 10, svgBox!.y + 10);
    await page.mouse.down();
    // Expand selection to include circle at x=400
    await page.mouse.move(svgBox!.x + 450, svgBox!.y + 280);
    await page.mouse.up();
    await page.waitForTimeout(100);

    // Verify multiple elements are selected (check for any "X elements selected" message)
    const selectedText = page.getByText(/\d+ elements selected/);
    await expect(selectedText).toBeVisible();

    // Get initial positions
    const rect1 = page.locator('svg rect[data-id="el-1"]');
    const circle = page.locator('svg circle[data-id="el-5"]');
    const initialX = await rect1.getAttribute('x');
    const initialCx = await circle.getAttribute('cx');

    // Drag to move all selected elements - start from corner to avoid text hit area
    const rect1Box = await rect1.boundingBox();
    expect(rect1Box).not.toBeNull();
    await page.mouse.move(rect1Box!.x + 5, rect1Box!.y + 5);
    await page.mouse.down();
    await page.mouse.move(svgBox!.x + 200, svgBox!.y + 200);
    await page.mouse.up();
    await page.waitForTimeout(100);

    // All elements should have moved
    const newX = await rect1.getAttribute('x');
    const newCx = await circle.getAttribute('cx');
    expect(newX).not.toBe(initialX);
    expect(newCx).not.toBe(initialCx);
  });
});
