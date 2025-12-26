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

test('debug: double-click to add text', async ({ page }) => {
  await page.goto('/');

  // Initial text count
  const initialTextCount = await page.locator('svg text').count();
  console.log('Initial text count:', initialTextCount);

  // Double-click on a rect (simulate with two clicks within 300ms)
  const rect = page.locator('svg rect[data-id]').first();
  await rect.click();
  await page.waitForTimeout(50);
  await rect.click();

  // Wait for the text input to appear
  const textInput = page.locator('input[type=text]');
  await expect(textInput).toBeVisible({ timeout: 2000 });

  // Type "Hello World" and press Enter
  await textInput.fill('Hello World');
  await textInput.press('Enter');
  await page.waitForTimeout(100);

  // Check text was added
  const afterTextCount = await page.locator('svg text').count();
  console.log('After dblclick text count:', afterTextCount);

  expect(afterTextCount).toBe(initialTextCount + 1);
  await expect(page.locator('svg text').last()).toHaveText('Hello World');
});

test('debug: re-edit text by double-clicking', async ({ page }) => {
  await page.goto('/');

  // First, add text via double-click
  const rect = page.locator('svg rect[data-id]').first();
  await rect.click();
  await page.waitForTimeout(50);
  await rect.click();

  // Wait for input and type initial text
  const textInput = page.locator('input[type=text]');
  await expect(textInput).toBeVisible({ timeout: 2000 });
  await textInput.fill('Initial Text');
  await textInput.press('Enter');
  await page.waitForTimeout(200);

  // Verify text was added
  await expect(page.locator('svg text').last()).toHaveText('Initial Text');

  // Double-click on the text to edit it
  // Need to re-locate since DOM may have changed
  const textElement = page.locator('svg text').last();
  await textElement.click();
  await page.waitForTimeout(100);
  await textElement.click();

  // Wait for input to appear with existing text
  await expect(textInput).toBeVisible({ timeout: 2000 });

  // Clear and type new text
  await textInput.fill('Updated Text');
  await textInput.press('Enter');
  await page.waitForTimeout(200);

  // Verify text was updated
  await expect(page.locator('svg text').last()).toHaveText('Updated Text');
});

test('debug: edit line endpoints', async ({ page }) => {
  await page.goto('/');

  // Add a line
  await page.getByRole('button', { name: 'Add Line' }).click();
  await page.waitForTimeout(100);

  // Select the line
  const line = page.locator('svg line[data-id]').first();
  await line.click();
  await page.waitForTimeout(100);

  // Check that circular handles appear (line uses circles, not rects)
  const handles = page.locator('svg circle[data-handle]');
  await expect(handles).toHaveCount(2);

  // Check handle types
  await expect(page.locator('svg circle[data-handle="line-start"]')).toBeVisible();
  await expect(page.locator('svg circle[data-handle="line-end"]')).toBeVisible();
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
