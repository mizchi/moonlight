import { test, expect } from '@playwright/test';

test.describe('Moonlight Preview Mode', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/preview.html');
  });

  test('should display preview page title', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('Preview Mode');
  });

  test('should create previews', async ({ page }) => {
    // Wait for previews to be created
    await expect(page.locator('#output')).toContainText('created');
  });

  test('should have preview containers', async ({ page }) => {
    await expect(page.locator('#preview1')).toBeVisible();
    await expect(page.locator('#preview2')).toBeVisible();
  });

  test('should have control buttons', async ({ page }) => {
    await expect(page.locator('#btn-open1')).toBeVisible();
    await expect(page.locator('#btn-open2')).toBeVisible();
  });

  test('MoonlightPreview should be available globally', async ({ page }) => {
    const hasPreview = await page.evaluate(() => {
      return typeof (window as any).MoonlightPreview !== 'undefined';
    });
    expect(hasPreview).toBe(true);
  });

  test('MoonlightPreview.create should be a function', async ({ page }) => {
    const isFunction = await page.evaluate(() => {
      return typeof (window as any).MoonlightPreview?.create === 'function';
    });
    expect(isFunction).toBe(true);
  });

  test('should open modal when clicking preview', async ({ page }) => {
    // Wait for previews to be ready
    await expect(page.locator('#output')).toContainText('created');

    // Click on preview1
    await page.locator('#preview1').click();

    // Modal should be visible
    await expect(page.locator('text=Close')).toBeVisible();
  });

  test('should close modal when clicking close button', async ({ page }) => {
    // Wait for previews to be ready
    await expect(page.locator('#output')).toContainText('created');

    // Open modal
    await page.locator('#preview1').click();
    await expect(page.locator('text=Close')).toBeVisible();

    // Close modal
    await page.locator('button:has-text("Close")').click();

    // Modal should be hidden
    await expect(page.locator('text=Close')).not.toBeVisible();
  });

  test('should open modal programmatically', async ({ page }) => {
    // Wait for previews to be ready
    await expect(page.locator('#output')).toContainText('created');

    // Click open button
    await page.locator('#btn-open1').click();

    // Modal should be visible
    await expect(page.locator('text=Close')).toBeVisible();
    await expect(page.locator('#output')).toContainText('Opened Preview 1');
  });
});
