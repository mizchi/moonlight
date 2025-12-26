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
