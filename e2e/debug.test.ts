import { test, expect } from '@playwright/test';

// Undo/Redo with empty stack should not cause errors
test('should handle undo/redo with empty stack', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => {
    errors.push(error.message);
  });

  await page.goto('/');

  // Undo with empty stack
  await page.getByRole('button', { name: 'Undo' }).click();
  await page.waitForTimeout(50);

  // Redo with empty stack
  await page.getByRole('button', { name: 'Redo' }).click();
  await page.waitForTimeout(50);

  // Should have no errors
  expect(errors.length).toBe(0);
});

test('debug: edit line endpoints', async ({ page }) => {
  await page.goto('/');

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

test('debug: insert shape from context menu', async ({ page }) => {
  await page.goto('/');

  // Initial rect count
  const initialRectCount = await page.locator('svg rect[data-id]').count();

  // Right-click on empty area
  await page.locator('svg').click({ button: 'right', position: { x: 350, y: 250 } });
  await page.waitForTimeout(100);

  // Click Rectangle in insert menu (use exact match to avoid "Add Rectangle")
  await page.getByRole('button', { name: 'Rectangle', exact: true }).click();
  await page.waitForTimeout(100);

  // Check shape was added
  const afterRectCount = await page.locator('svg rect[data-id]').count();
  expect(afterRectCount).toBe(initialRectCount + 1);

  // Context menu should be closed
  await expect(page.locator('text=Insert')).not.toBeVisible();
});

test('debug: box selection', async ({ page }) => {
  await page.goto('/');

  // Initial - nothing selected
  await expect(page.getByText('Select an element to view details')).toBeVisible();

  // Drag to create selection box that covers all shapes
  // Start from top-left corner and drag to bottom-right
  const svg = page.locator('svg');
  const svgBox = await svg.boundingBox();
  expect(svgBox).not.toBeNull();

  await page.mouse.move(svgBox!.x + 10, svgBox!.y + 10);
  await page.mouse.down();
  await page.mouse.move(svgBox!.x + 390, svgBox!.y + 280);
  await page.mouse.up();
  await page.waitForTimeout(100);

  // Should show "3 elements selected" (2 rects + 1 circle)
  await expect(page.getByText('3 elements selected')).toBeVisible();
});

test('debug: multi-drag selected elements', async ({ page }) => {
  await page.goto('/');

  // Box select all elements
  const svg = page.locator('svg');
  const svgBox = await svg.boundingBox();
  expect(svgBox).not.toBeNull();

  await page.mouse.move(svgBox!.x + 10, svgBox!.y + 10);
  await page.mouse.down();
  await page.mouse.move(svgBox!.x + 390, svgBox!.y + 280);
  await page.mouse.up();
  await page.waitForTimeout(100);

  // Verify 3 elements selected
  await expect(page.getByText('3 elements selected')).toBeVisible();

  // Get initial positions
  const rect1 = page.locator('svg rect[data-id="el-1"]');
  const initialX1 = await rect1.getAttribute('x');
  const circle = page.locator('svg circle[data-id="el-3"]');
  const initialCx = await circle.getAttribute('cx');

  // Drag one of the selected elements
  const rect1Box = await rect1.boundingBox();
  expect(rect1Box).not.toBeNull();
  await page.mouse.move(rect1Box!.x + rect1Box!.width / 2, rect1Box!.y + rect1Box!.height / 2);
  await page.mouse.down();
  await page.mouse.move(svgBox!.x + 200, svgBox!.y + 200);
  await page.mouse.up();
  await page.waitForTimeout(100);

  // Both elements should have moved
  const newX1 = await rect1.getAttribute('x');
  const newCx = await circle.getAttribute('cx');
  expect(newX1).not.toBe(initialX1);
  expect(newCx).not.toBe(initialCx);
});

test('debug: Ctrl+D duplicate', async ({ page }) => {
  await page.goto('/');

  // Only count shape rects (with data-id), not resize handles (with data-handle)
  const shapeRects = page.locator('svg rect[data-id]');

  // Initial count
  const initialCount = await shapeRects.count();
  console.log('Initial shape rect count:', initialCount);

  // Select first shape
  await shapeRects.first().click();
  await page.waitForTimeout(100);

  // After selection, check resize handles
  const allRects = await page.locator('svg rect').count();
  console.log('Total rects after selection (includes handles):', allRects);

  // Press Meta+D (macOS)
  await page.keyboard.press('Meta+d');
  await page.waitForTimeout(200);

  // After count
  const afterCount = await shapeRects.count();
  console.log('After Ctrl+D shape rect count:', afterCount);

  expect(afterCount).toBe(initialCount + 1);
});
