import { test, expect } from '@playwright/test';

test.describe('Moonlight WebComponent Mode', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/webcomponent.html');
  });

  test('should display webcomponent page title', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('WebComponent Mode');
  });

  test('should register custom element', async ({ page }) => {
    // Wait for custom element to be defined
    await expect(page.locator('#output')).toContainText('registered');
  });

  test('should render moonlight-editor elements', async ({ page }) => {
    const editor1 = page.locator('#editor1');
    const editor2 = page.locator('#editor2');

    await expect(editor1).toBeVisible();
    await expect(editor2).toBeVisible();
  });

  test('moonlight-editor should have shadow DOM', async ({ page }) => {
    // Wait for web component to fully initialize
    await page.waitForTimeout(500);
    const hasShadowRoot = await page.evaluate(() => {
      const editor = document.getElementById('editor1');
      return editor?.shadowRoot !== null;
    });
    expect(hasShadowRoot).toBe(true);
  });

  test('should have width and height attributes', async ({ page }) => {
    await expect(page.locator('#editor1')).toHaveAttribute('width', '600');
    await expect(page.locator('#editor1')).toHaveAttribute('height', '300');
  });

  test('should have theme attribute', async ({ page }) => {
    await expect(page.locator('#editor1')).toHaveAttribute('theme', 'light');
    await expect(page.locator('#editor2')).toHaveAttribute('theme', 'dark');
  });

  test('editor2 should have gridsnap attribute', async ({ page }) => {
    const hasGridsnap = await page.evaluate(() => {
      const editor = document.getElementById('editor2');
      return editor?.hasAttribute('gridsnap');
    });
    expect(hasGridsnap).toBe(true);
  });

  test('should have control buttons', async ({ page }) => {
    await expect(page.locator('#btn-export')).toBeVisible();
    await expect(page.locator('#btn-clear')).toBeVisible();
  });

  test('should export SVG when clicking export button', async ({ page }) => {
    // Wait for component to be ready
    await expect(page.locator('#output')).toContainText('registered');

    // Click export button
    await page.locator('#btn-export').click();

    // Check output contains SVG
    await expect(page.locator('#output')).toContainText('<svg');
  });

  test('should clear editors when clicking clear button', async ({ page }) => {
    // Wait for component to be ready
    await expect(page.locator('#output')).toContainText('registered');

    // Click clear button
    await page.locator('#btn-clear').click();

    // Check output shows cleared message
    await expect(page.locator('#output')).toContainText('cleared');
  });

  test('moonlight-editor should be a defined custom element', async ({ page }) => {
    const isDefined = await page.evaluate(() => {
      return customElements.get('moonlight-editor') !== undefined;
    });
    expect(isDefined).toBe(true);
  });
});
