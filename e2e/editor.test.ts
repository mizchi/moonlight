import { test, expect } from '@playwright/test';

test.describe('Moonlight SVG Editor', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should display the title', async ({ page }) => {
    await expect(page.locator('h1')).toHaveText('Moonlight SVG Editor');
  });

  test('should display status text in sidebar', async ({ page }) => {
    // Sidebar should show "Select an element to view details" when nothing is selected
    await expect(page.getByText('Select an element to view details')).toBeVisible();
  });

  test('should have Add Rectangle and Add Circle buttons', async ({ page }) => {
    await expect(page.getByRole('button', { name: 'Add Rectangle' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Add Circle' })).toBeVisible();
  });

  test('should have an SVG element', async ({ page }) => {
    const svg = page.locator('svg');
    await expect(svg).toBeVisible();
    await expect(svg).toHaveAttribute('width', '400');
    await expect(svg).toHaveAttribute('height', '300');
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

    // Check that sidebar shows the element ID
    await expect(page.getByText('el-1')).toBeVisible();
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

  test('should add an ellipse when clicking Add Ellipse', async ({ page }) => {
    const initialCount = await page.locator('svg ellipse').count();

    await page.getByRole('button', { name: 'Add Ellipse' }).click();

    await expect(page.locator('svg ellipse')).toHaveCount(initialCount + 1);
  });

  test('should add a line when clicking Add Line', async ({ page }) => {
    const initialCount = await page.locator('svg line').count();

    await page.getByRole('button', { name: 'Add Line' }).click();

    await expect(page.locator('svg line')).toHaveCount(initialCount + 1);
  });

  test('should add text when clicking Add Text', async ({ page }) => {
    const initialCount = await page.locator('svg text').count();

    await page.getByRole('button', { name: 'Add Text' }).click();

    await expect(page.locator('svg text')).toHaveCount(initialCount + 1);
    // Check that the text content is correct
    await expect(page.locator('svg text').last()).toHaveText('Hello');
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
    // Right-click on empty area of SVG (bottom-right corner, away from shapes)
    await page.locator('svg').click({ button: 'right', position: { x: 380, y: 280 } });

    // Check message is shown
    await expect(page.locator('text=No element selected')).toBeVisible();
  });

  test('should have Undo and Redo buttons', async ({ page }) => {
    await expect(page.getByRole('button', { name: 'Undo' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Redo' })).toBeVisible();
  });

  test('should undo adding a shape', async ({ page }) => {
    const initialRectCount = await page.locator('svg rect').count();

    // Add a rectangle
    await page.getByRole('button', { name: 'Add Rectangle' }).click();
    await expect(page.locator('svg rect')).toHaveCount(initialRectCount + 1);

    // Undo
    await page.getByRole('button', { name: 'Undo' }).click();
    await expect(page.locator('svg rect')).toHaveCount(initialRectCount);
  });

  test('should redo after undo', async ({ page }) => {
    const initialRectCount = await page.locator('svg rect').count();

    // Add a rectangle
    await page.getByRole('button', { name: 'Add Rectangle' }).click();
    await expect(page.locator('svg rect')).toHaveCount(initialRectCount + 1);

    // Undo
    await page.getByRole('button', { name: 'Undo' }).click();
    await expect(page.locator('svg rect')).toHaveCount(initialRectCount);

    // Redo
    await page.getByRole('button', { name: 'Redo' }).click();
    await expect(page.locator('svg rect')).toHaveCount(initialRectCount + 1);
  });

  test('should undo deleting a shape', async ({ page }) => {
    const initialRectCount = await page.locator('svg rect').count();

    // Delete first rect via context menu
    await page.locator('svg rect').first().click({ button: 'right' });
    await page.locator('button:has-text("Delete")').click();
    await expect(page.locator('svg rect')).toHaveCount(initialRectCount - 1);

    // Undo
    await page.getByRole('button', { name: 'Undo' }).click();
    await expect(page.locator('svg rect')).toHaveCount(initialRectCount);
  });

  test('should undo moving a shape', async ({ page }) => {
    const rect = page.locator('svg rect').first();
    const initialX = await rect.getAttribute('x');

    // Drag the shape
    await rect.dragTo(page.locator('svg'), {
      targetPosition: { x: 400, y: 300 }
    });

    // Verify position changed
    const movedX = await rect.getAttribute('x');
    expect(movedX).not.toBe(initialX);

    // Undo
    await page.getByRole('button', { name: 'Undo' }).click();

    // Verify position restored
    const restoredX = await rect.getAttribute('x');
    expect(restoredX).toBe(initialX);
  });

  test('should show resize handles when shape is selected', async ({ page }) => {
    // Click on a rect to select it
    await page.locator('svg rect').first().click();

    // Check that 4 resize handles are visible (small rects with data-handle attribute)
    const handles = page.locator('svg rect[data-handle]');
    await expect(handles).toHaveCount(4);
  });

  test('should resize shape by dragging SE handle', async ({ page }) => {
    const rect = page.locator('svg rect[data-id]').first();

    // Get initial size
    const initialWidth = await rect.getAttribute('width');

    // Click to select and show handles
    await rect.click();

    // Get SE handle and drag it
    const seHandle = page.locator('svg rect[data-handle="se"]');
    await seHandle.dragTo(page.locator('svg'), {
      targetPosition: { x: 300, y: 250 }
    });

    // Check that width changed
    const newWidth = await rect.getAttribute('width');
    expect(newWidth).not.toBe(initialWidth);
  });

  test('should undo resize operation', async ({ page }) => {
    const rect = page.locator('svg rect[data-id]').first();

    // Get initial size
    const initialWidth = await rect.getAttribute('width');

    // Click to select and show handles
    await rect.click();

    // Get SE handle and drag it
    const seHandle = page.locator('svg rect[data-handle="se"]');
    await seHandle.dragTo(page.locator('svg'), {
      targetPosition: { x: 300, y: 250 }
    });

    // Verify size changed
    const resizedWidth = await rect.getAttribute('width');
    expect(resizedWidth).not.toBe(initialWidth);

    // Undo
    await page.getByRole('button', { name: 'Undo' }).click();

    // Verify size restored
    const restoredWidth = await rect.getAttribute('width');
    expect(restoredWidth).toBe(initialWidth);
  });

  test('should delete shape with Delete key', async ({ page }) => {
    const initialRectCount = await page.locator('svg rect').count();

    // Select a shape
    await page.locator('svg rect').first().click();
    await expect(page.getByText('el-1')).toBeVisible();

    // Press Delete key
    await page.keyboard.press('Delete');

    // Verify shape was deleted
    await expect(page.locator('svg rect')).toHaveCount(initialRectCount - 1);
  });

  test('should deselect shape with Escape key', async ({ page }) => {
    // Select a shape
    await page.locator('svg rect').first().click();
    await expect(page.getByText('el-1')).toBeVisible();

    // Press Escape key
    await page.keyboard.press('Escape');

    // Verify shape was deselected (sidebar shows "Select an element")
    await expect(page.getByText('Select an element to view details')).toBeVisible();
  });

  test('should duplicate shape with Ctrl+D', async ({ page }) => {
    // Use data-id to only count shape rects, not resize handles
    const shapeRects = page.locator('svg rect[data-id]');
    const initialRectCount = await shapeRects.count();

    // Select a shape
    await shapeRects.first().click();
    await page.waitForTimeout(100);

    // Press Ctrl+D (use Meta for macOS)
    const isMac = process.platform === 'darwin';
    await page.keyboard.press(isMac ? 'Meta+d' : 'Control+d');

    // Verify shape was duplicated
    await expect(shapeRects).toHaveCount(initialRectCount + 1);
  });

  test('should undo with Ctrl+Z', async ({ page }) => {
    const initialRectCount = await page.locator('svg rect').count();

    // Add a shape
    await page.getByRole('button', { name: 'Add Rectangle' }).click();
    await expect(page.locator('svg rect')).toHaveCount(initialRectCount + 1);

    // Press Ctrl+Z
    await page.keyboard.press('Control+z');

    // Verify shape was removed
    await expect(page.locator('svg rect')).toHaveCount(initialRectCount);
  });
});
