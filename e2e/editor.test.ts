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
});
