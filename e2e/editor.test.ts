import { test, expect } from '@playwright/test';

test.describe('Moonlight SVG Editor', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should display the title', async ({ page }) => {
    await expect(page.locator('h1')).toHaveText('Moonlight SVG Editor');
  });

  test('should display status text', async ({ page }) => {
    await expect(page.locator('p').first()).toHaveText('Click a shape to select');
  });

  test('should have Add Rectangle and Add Circle buttons', async ({ page }) => {
    await expect(page.getByRole('button', { name: 'Add Rectangle' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Add Circle' })).toBeVisible();
  });

  test('should have an SVG element', async ({ page }) => {
    const svg = page.locator('svg');
    await expect(svg).toBeVisible();
    await expect(svg).toHaveAttribute('width', '800');
    await expect(svg).toHaveAttribute('height', '600');
  });

  test('should have initial shapes (2 rects, 1 circle)', async ({ page }) => {
    const rects = page.locator('svg rect');
    const circles = page.locator('svg circle');

    await expect(rects).toHaveCount(2);
    await expect(circles).toHaveCount(1);
  });

  test('should select a shape on click', async ({ page }) => {
    const rect = page.locator('svg rect').first();
    await rect.click();

    // Check that status shows selected
    await expect(page.locator('p').first()).toContainText('Selected:');
  });

  test('should add a rectangle when clicking Add Rectangle', async ({ page }) => {
    const initialCount = await page.locator('svg rect').count();

    await page.getByRole('button', { name: 'Add Rectangle' }).click();

    await expect(page.locator('svg rect')).toHaveCount(initialCount + 1);
  });

  test('should add a circle when clicking Add Circle', async ({ page }) => {
    const initialCount = await page.locator('svg circle').count();

    await page.getByRole('button', { name: 'Add Circle' }).click();

    await expect(page.locator('svg circle')).toHaveCount(initialCount + 1);
  });

  test('should drag a shape to move it', async ({ page }) => {
    const rect = page.locator('svg rect').first();

    // Get initial position
    const initialX = await rect.getAttribute('x');

    // Drag the shape
    await rect.dragTo(page.locator('svg'), {
      targetPosition: { x: 400, y: 300 }
    });

    // Check position changed
    const newX = await rect.getAttribute('x');
    expect(newX).not.toBe(initialX);
  });

  test('should show context menu on right-click', async ({ page }) => {
    const rect = page.locator('svg rect').first();

    // Right-click on shape
    await rect.click({ button: 'right' });

    // Check context menu is visible with Delete button
    const contextMenu = page.locator('button:has-text("Delete")');
    await expect(contextMenu).toBeVisible();
  });

  test('should hide context menu on left-click', async ({ page }) => {
    const rect = page.locator('svg rect').first();

    // Right-click to show menu
    await rect.click({ button: 'right' });
    await expect(page.locator('button:has-text("Delete")')).toBeVisible();

    // Left-click on SVG to hide menu
    await page.locator('svg').click({ position: { x: 10, y: 10 } });

    // Check context menu is hidden
    await expect(page.locator('button:has-text("Delete")')).not.toBeVisible();
  });

  test('should delete shape via context menu', async ({ page }) => {
    const initialRectCount = await page.locator('svg rect').count();

    // Right-click on first rect
    await page.locator('svg rect').first().click({ button: 'right' });

    // Click Delete
    await page.locator('button:has-text("Delete")').click();

    // Check shape was deleted
    await expect(page.locator('svg rect')).toHaveCount(initialRectCount - 1);
  });

  test('should show "No element selected" when right-clicking empty area', async ({ page }) => {
    // Right-click on empty area of SVG
    await page.locator('svg').click({ button: 'right', position: { x: 700, y: 500 } });

    // Check message is shown
    await expect(page.locator('text=No element selected')).toBeVisible();
  });
});
