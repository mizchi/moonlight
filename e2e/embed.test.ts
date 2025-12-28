import { test, expect } from '@playwright/test';

test.describe('Moonlight Embed Mode', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/embed.html');
  });

  test('should display embed page title', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('Embed Mode');
  });

  test('should have editor container', async ({ page }) => {
    const container = page.locator('#editor');
    await expect(container).toBeVisible();
  });

  test('should create editor and display placeholder', async ({ page }) => {
    // Wait for editor to be created
    await expect(page.locator('#output')).toContainText('Editor created');

    // Check that editor container has content
    const editorContent = page.locator('#editor');
    await expect(editorContent).toBeVisible();
  });

  test('should have control buttons', async ({ page }) => {
    await expect(page.locator('#btn-export')).toBeVisible();
    await expect(page.locator('#btn-clear')).toBeVisible();
    await expect(page.locator('#btn-destroy')).toBeVisible();
  });

  test('should export SVG when clicking export button', async ({ page }) => {
    // Wait for editor to be ready
    await expect(page.locator('#output')).toContainText('Editor created');

    // Click export button
    await page.locator('#btn-export').click();

    // Check output contains SVG
    await expect(page.locator('#output')).toContainText('<svg');
  });

  test('should clear editor when clicking clear button', async ({ page }) => {
    // Wait for editor to be ready
    await expect(page.locator('#output')).toContainText('Editor created');

    // Click clear button
    await page.locator('#btn-clear').click();

    // Check output shows cleared message
    await expect(page.locator('#output')).toContainText('cleared');
  });

  test('should destroy editor when clicking destroy button', async ({ page }) => {
    // Wait for editor to be ready
    await expect(page.locator('#output')).toContainText('Editor created');

    // Click destroy button
    await page.locator('#btn-destroy').click();

    // Check output shows destroyed message
    await expect(page.locator('#output')).toContainText('destroyed');
  });

  test('MoonlightEditor should be available globally', async ({ page }) => {
    // Check that MoonlightEditor is available in window
    const hasEditor = await page.evaluate(() => {
      return typeof (window as any).MoonlightEditor !== 'undefined';
    });
    expect(hasEditor).toBe(true);
  });

  test('MoonlightEditor.create should be a function', async ({ page }) => {
    const isFunction = await page.evaluate(() => {
      return typeof (window as any).MoonlightEditor?.create === 'function';
    });
    expect(isFunction).toBe(true);
  });
});
