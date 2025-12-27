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

test('should insert shape from context menu', async ({ page }) => {
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

test('should duplicate shape with Ctrl+D', async ({ page }) => {
  await page.goto('/');

  // Only count shape rects (with data-id), not resize handles (with data-handle)
  const shapeRects = page.locator('svg rect[data-id]');

  // Initial count
  const initialCount = await shapeRects.count();

  // Select first shape
  await shapeRects.first().click();
  await page.waitForTimeout(100);

  // Press Meta+D (macOS) / Ctrl+D
  await page.keyboard.press('Meta+d');
  await page.waitForTimeout(200);

  // After count
  const afterCount = await shapeRects.count();
  expect(afterCount).toBe(initialCount + 1);
});
