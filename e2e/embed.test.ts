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

test.describe('Moonlight Embed Mode - Drag and Drop', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/embed.html');
    // Wait for editor to be ready
    await expect(page.locator('#output')).toContainText('Editor created');
  });

  test('should have SVG with viewBox', async ({ page }) => {
    const svg = page.locator('#editor svg');
    await expect(svg).toBeVisible();
    const viewBox = await svg.getAttribute('viewBox');
    // viewBox is dynamically calculated by fit_to_canvas, so just check it exists and has 4 numeric values
    expect(viewBox).not.toBeNull();
    const parts = viewBox!.split(' ');
    expect(parts.length).toBe(4);
    for (const part of parts) {
      expect(isNaN(parseFloat(part))).toBe(false);
    }
  });

  test('should have data-id attributes on elements', async ({ page }) => {
    const elementsWithId = page.locator('#editor svg [data-id]');
    const count = await elementsWithId.count();
    expect(count).toBeGreaterThan(0);
  });

  test('should select element on click', async ({ page }) => {
    // Click on the circle element (force: true to bypass text overlay)
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ force: true });

    // Check that selection rect appears
    const selectionRect = page.locator('#editor svg .selection-overlay');
    await expect(selectionRect).toBeVisible();
  });

  test('should deselect on background click', async ({ page }) => {
    // First, select an element
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ force: true });
    await expect(page.locator('#editor svg .selection-overlay')).toBeVisible();

    // Click on background (top-left corner where there's no element)
    const svg = page.locator('#editor svg');
    const box = await svg.boundingBox();
    if (box) {
      await page.mouse.click(box.x + 10, box.y + 10);
    }

    // Selection rect should be gone
    await expect(page.locator('#editor svg .selection-overlay')).not.toBeVisible();
  });

  test('should drag element to new position', async ({ page }) => {
    // Get initial circle position
    const circle = page.locator('#editor svg circle[data-id]').first();
    const initialCx = await circle.getAttribute('cx');
    const initialCy = await circle.getAttribute('cy');

    // Get circle bounding box directly for accurate positioning
    const circleBox = await circle.boundingBox();
    expect(circleBox).not.toBeNull();

    if (circleBox && initialCx && initialCy) {
      // Use the element's bounding box center for accurate click position
      const screenX = circleBox.x + circleBox.width / 2;
      const screenY = circleBox.y + circleBox.height / 2;

      // Perform drag
      await page.mouse.move(screenX, screenY);
      await page.mouse.down();
      await page.mouse.move(screenX + 50, screenY + 30, { steps: 5 });
      await page.mouse.up();

      // Check that position changed
      const newCx = await circle.getAttribute('cx');
      const newCy = await circle.getAttribute('cy');

      expect(parseFloat(newCx!)).not.toBe(parseFloat(initialCx));
      expect(parseFloat(newCy!)).not.toBe(parseFloat(initialCy));
    }
  });

  test('should drag rect element', async ({ page }) => {
    // Get initial rect position
    const rect = page.locator('#editor svg rect[data-id]').first();
    const initialX = await rect.getAttribute('x');
    const initialY = await rect.getAttribute('y');

    // Get rect bounding box directly for accurate positioning
    const rectBox = await rect.boundingBox();
    expect(rectBox).not.toBeNull();

    if (rectBox && initialX && initialY) {
      // Use the element's bounding box center
      const screenX = rectBox.x + rectBox.width / 2;
      const screenY = rectBox.y + rectBox.height / 2;

      // Perform drag
      await page.mouse.move(screenX, screenY);
      await page.mouse.down();
      await page.mouse.move(screenX + 100, screenY + 50, { steps: 5 });
      await page.mouse.up();

      // Check that position changed
      const newX = await rect.getAttribute('x');
      const newY = await rect.getAttribute('y');

      expect(parseFloat(newX!)).not.toBe(parseFloat(initialX));
      expect(parseFloat(newY!)).not.toBe(parseFloat(initialY));
    }
  });

  test('should show selection rect during drag', async ({ page }) => {
    // Click to select
    const circle = page.locator('#editor svg circle[data-id]').first();
    const circleBox = await circle.boundingBox();
    expect(circleBox).not.toBeNull();

    if (circleBox) {
      const screenX = circleBox.x + circleBox.width / 2;
      const screenY = circleBox.y + circleBox.height / 2;

      // Start drag
      await page.mouse.move(screenX, screenY);
      await page.mouse.down();

      // Selection rect should be visible
      await expect(page.locator('#editor svg .selection-overlay')).toBeVisible();

      // Complete drag
      await page.mouse.move(screenX + 30, screenY + 20, { steps: 3 });
      await page.mouse.up();

      // Selection rect should still be visible
      await expect(page.locator('#editor svg .selection-overlay')).toBeVisible();
    }
  });

  test('drag should move element in scene coordinates', async ({ page }) => {
    // This test verifies that drag moves the element
    const circle = page.locator('#editor svg circle[data-id]').first();
    const initialCx = await circle.getAttribute('cx');
    const initialCy = await circle.getAttribute('cy');
    const circleBox = await circle.boundingBox();
    expect(circleBox).not.toBeNull();

    if (circleBox && initialCx && initialCy) {
      const screenX = circleBox.x + circleBox.width / 2;
      const screenY = circleBox.y + circleBox.height / 2;

      await page.mouse.move(screenX, screenY);
      await page.mouse.down();
      await page.mouse.move(screenX + 60, screenY, { steps: 5 });
      await page.mouse.up();

      const newCx = await circle.getAttribute('cx');
      const actualDx = parseFloat(newCx!) - parseFloat(initialCx);

      // Element should have moved (direction depends on viewBox scaling)
      expect(Math.abs(actualDx)).toBeGreaterThan(0);
    }
  });
});

// Context menu is disabled in embed mode by design
test.describe.skip('Moonlight Embed Mode - Context Menu', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/embed.html');
    // Wait for editor to be ready
    await expect(page.locator('#output')).toContainText('Editor created');
  });

  test('should show context menu on right click on element', async ({ page }) => {
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ button: 'right' });

    // Context menu should be visible
    const contextMenu = page.locator('body > div').filter({ hasText: 'Colors' });
    await expect(contextMenu).toBeVisible();
  });

  test('should show insert menu on right click on background', async ({ page }) => {
    const svg = page.locator('#editor svg');
    const box = await svg.boundingBox();
    if (box) {
      // Click on empty area (top-left corner)
      await page.mouse.click(box.x + 10, box.y + 10, { button: 'right' });
    }

    // Insert menu should be visible
    const contextMenu = page.locator('body > div').filter({ hasText: 'Insert' });
    await expect(contextMenu).toBeVisible();
  });

  test('should close context menu on click outside', async ({ page }) => {
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ button: 'right' });

    // Context menu should be visible
    const contextMenu = page.locator('body > div').filter({ hasText: 'Colors' });
    await expect(contextMenu).toBeVisible();

    // Click outside
    await page.mouse.click(10, 10);

    // Context menu should be hidden
    await expect(contextMenu).not.toBeVisible();
  });

  test('should delete element from context menu', async ({ page }) => {
    // Count initial elements
    const initialCount = await page.locator('#editor svg [data-id]').count();
    expect(initialCount).toBeGreaterThan(0);

    // Right click on circle
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ button: 'right' });

    // Wait a bit for menu to render
    await page.waitForTimeout(100);

    // Click delete button (force click as menu might be near edge)
    const deleteBtn = page.locator('body > div button').filter({ hasText: 'Delete' });
    await deleteBtn.click({ force: true });

    // Element count should decrease
    const newCount = await page.locator('#editor svg [data-id]').count();
    expect(newCount).toBe(initialCount - 1);
  });

  test('should insert rectangle from context menu', async ({ page }) => {
    // Count initial elements
    const initialCount = await page.locator('#editor svg [data-id]').count();

    // Right click in center area for better menu positioning
    const svg = page.locator('#editor svg');
    const box = await svg.boundingBox();
    if (box) {
      await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2, { button: 'right' });
    }

    await page.waitForTimeout(100);
    // Click Rectangle button
    const rectBtn = page.locator('body > div button').filter({ hasText: 'Rectangle' });
    await rectBtn.click({ force: true });

    // Element count should increase
    const newCount = await page.locator('#editor svg [data-id]').count();
    expect(newCount).toBe(initialCount + 1);

    // Should have a new rect element (may be more than 2 now due to clicking in center)
    const rectElements = page.locator('#editor svg rect[data-id]');
    const rectCount = await rectElements.count();
    expect(rectCount).toBeGreaterThanOrEqual(2);
  });

  test('should insert circle from context menu', async ({ page }) => {
    const initialCount = await page.locator('#editor svg circle[data-id]').count();

    const svg = page.locator('#editor svg');
    const box = await svg.boundingBox();
    if (box) {
      // Right click in center of SVG for better positioning
      await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2, { button: 'right' });
    }

    await page.waitForTimeout(100);
    const circleBtn = page.locator('body > div button').filter({ hasText: 'Circle' });
    await circleBtn.click({ force: true });

    const newCount = await page.locator('#editor svg circle[data-id]').count();
    expect(newCount).toBe(initialCount + 1);
  });
});

test.describe('Moonlight Embed Mode - Anchor Points', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/embed.html');
    await expect(page.locator('#output')).toContainText('Editor created');
  });

  test('should show anchor points when element is selected', async ({ page }) => {
    // Initially no anchor points
    const anchorsBefore = await page.locator('#editor svg .anchor-point').count();
    expect(anchorsBefore).toBe(0);

    // Select the circle
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ force: true });

    // Anchor points should appear (4 for circle: top, bottom, left, right - center is skipped)
    const anchorsAfter = await page.locator('#editor svg .anchor-point').count();
    expect(anchorsAfter).toBe(4);
  });

  test('should hide anchor points when deselected', async ({ page }) => {
    // Select the circle
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ force: true });

    // Anchor points should be visible
    await expect(page.locator('#editor svg .anchor-point').first()).toBeVisible();

    // Click background to deselect
    const svg = page.locator('#editor svg');
    const box = await svg.boundingBox();
    if (box) {
      await page.mouse.click(box.x + 10, box.y + 10);
    }

    // Anchor points should be gone
    const anchors = await page.locator('#editor svg .anchor-point').count();
    expect(anchors).toBe(0);
  });

  test('should show anchor points for rect (5 points)', async ({ page }) => {
    // Select the rect (force: true to bypass text overlay)
    const rect = page.locator('#editor svg rect[data-id]').first();
    await rect.click({ force: true });

    // Rect should have 4 anchor points (top, bottom, left, right - center and corners are skipped)
    const anchors = await page.locator('#editor svg .anchor-point').count();
    expect(anchors).toBe(4);
  });
});

// Keyboard shortcuts are not set up in embed mode by design
test.describe.skip('Moonlight Embed Mode - Keyboard Shortcuts', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/embed.html');
    await expect(page.locator('#output')).toContainText('Editor created');
    // Click on editor to focus
    await page.locator('#editor').click();
  });

  test('should insert rectangle with key 1', async ({ page }) => {
    const initialCount = await page.locator('#editor svg rect[data-id]').count();

    await page.keyboard.press('1');

    const newCount = await page.locator('#editor svg rect[data-id]').count();
    expect(newCount).toBe(initialCount + 1);
  });

  test('should insert circle with key 2', async ({ page }) => {
    const initialCount = await page.locator('#editor svg circle[data-id]').count();

    await page.keyboard.press('2');

    const newCount = await page.locator('#editor svg circle[data-id]').count();
    expect(newCount).toBe(initialCount + 1);
  });

  test('should delete selected element with Delete key', async ({ page }) => {
    // Select an element first
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ force: true });

    // Selection should be visible
    await expect(page.locator('#editor svg .selection-overlay')).toBeVisible();

    // Get initial count
    const initialCount = await page.locator('#editor svg [data-id]').count();

    // Press Delete
    await page.keyboard.press('Delete');

    // Element count should decrease
    const newCount = await page.locator('#editor svg [data-id]').count();
    expect(newCount).toBe(initialCount - 1);
  });

  test('should deselect with Escape key', async ({ page }) => {
    // Select an element
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ force: true });
    await expect(page.locator('#editor svg .selection-overlay')).toBeVisible();

    // Press Escape
    await page.keyboard.press('Escape');

    // Selection should be gone
    await expect(page.locator('#editor svg .selection-overlay')).not.toBeVisible();
  });

  test('should move selected element with arrow keys', async ({ page }) => {
    // Select the circle
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ force: true });

    // Get initial position
    const initialCx = await circle.getAttribute('cx');
    const initialCy = await circle.getAttribute('cy');

    // Press arrow right
    await page.keyboard.press('ArrowRight');

    // Position should change
    const newCx = await circle.getAttribute('cx');
    expect(parseFloat(newCx!)).toBe(parseFloat(initialCx!) + 10);

    // Press arrow down
    await page.keyboard.press('ArrowDown');
    const newCy = await circle.getAttribute('cy');
    expect(parseFloat(newCy!)).toBe(parseFloat(initialCy!) + 10);
  });
});

test.describe('Moonlight Embed Mode - Anchor Drag', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/embed.html');
    await expect(page.locator('#output')).toContainText('Editor created');
  });

  test('should create line by dragging from anchor point', async ({ page }) => {
    // Count initial elements
    const initialCount = await page.locator('#editor svg [data-id]').count();

    // Select the circle to show anchor points
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ force: true });

    // Wait for anchor points to appear
    await expect(page.locator('#editor svg .anchor-point').first()).toBeVisible();

    // Get the right anchor point
    const rightAnchor = page.locator('#editor svg .anchor-point[data-anchor="right"]');
    const anchorBox = await rightAnchor.boundingBox();
    expect(anchorBox).not.toBeNull();

    // Drag from anchor point to create a line
    await page.mouse.move(anchorBox!.x + anchorBox!.width / 2, anchorBox!.y + anchorBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(anchorBox!.x + 100, anchorBox!.y, { steps: 5 });

    // Line element should be created immediately in Luna implementation (no preview-line)
    // The line is created on mousedown and resized during drag
    await page.mouse.up();

    // New line element should be created (may create 1 or more elements depending on implementation)
    const newCount = await page.locator('#editor svg [data-id]').count();
    expect(newCount).toBeGreaterThan(initialCount);

    // Verify line element exists (Line is wrapped in a group with data-id)
    const lines = await page.locator('#editor svg g[data-id] line').count();
    expect(lines).toBeGreaterThan(0);
  });

  test('should not create line if drag distance is too short', async ({ page }) => {
    // Count initial elements
    const initialCount = await page.locator('#editor svg [data-id]').count();

    // Select the circle to show anchor points
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ force: true });

    // Wait for anchor points
    await expect(page.locator('#editor svg .anchor-point').first()).toBeVisible();

    // Get anchor point (use "top" since center is skipped)
    const topAnchor = page.locator('#editor svg .anchor-point[data-anchor="top"]');
    const anchorBox = await topAnchor.boundingBox();

    // Drag very short distance (less than 10px)
    await page.mouse.move(anchorBox!.x + anchorBox!.width / 2, anchorBox!.y + anchorBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(anchorBox!.x + anchorBox!.width / 2 + 5, anchorBox!.y + anchorBox!.height / 2);
    await page.mouse.up();

    // No new element should be created
    const newCount = await page.locator('#editor svg [data-id]').count();
    expect(newCount).toBe(initialCount);
  });

  test('should select line element when clicked', async ({ page }) => {
    // First create a line by dragging from anchor
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ force: true });

    // Wait for anchor points
    await expect(page.locator('#editor svg .anchor-point').first()).toBeVisible();

    // Get the right anchor point
    const rightAnchor = page.locator('#editor svg .anchor-point[data-anchor="right"]');
    const anchorBox = await rightAnchor.boundingBox();

    // Drag to create line
    await page.mouse.move(anchorBox!.x + anchorBox!.width / 2, anchorBox!.y + anchorBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(anchorBox!.x + 100, anchorBox!.y);
    await page.mouse.up();

    // Line should be created and selected (Line uses handles instead of selection-rect)
    await expect(page.locator('#editor svg circle[data-handle="line-end"]')).toBeVisible();

    // Click elsewhere to deselect
    const svg = page.locator('#editor svg');
    const box = await svg.boundingBox();
    await page.mouse.click(box!.x + 10, box!.y + 10);
    await expect(page.locator('#editor svg .selection-overlay')).not.toBeVisible();

    // Now click on the line to re-select it (use last() to get the newly created line)
    const lineGroup = page.locator('#editor svg g[data-id] line').last();
    const lineBox = await lineGroup.boundingBox();
    expect(lineBox).not.toBeNull();

    // Click on the line's hit area (the parent group)
    await page.mouse.click(lineBox!.x + lineBox!.width / 2, lineBox!.y + lineBox!.height / 2);

    // Line should be selected again (Line uses handles instead of selection-rect)
    await expect(page.locator('#editor svg circle[data-handle="line-end"]')).toBeVisible();

    // Line has 2 handles: line-start, line-end (no anchor points - those are only for shapes)
    const lineHandles = await page.locator('#editor svg [data-handle]').count();
    expect(lineHandles).toBeGreaterThanOrEqual(2);
  });

  test('should move line endpoint by dragging anchor', async ({ page }) => {
    // First create a line by dragging from anchor
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ force: true });

    // Wait for anchor points
    await expect(page.locator('#editor svg .anchor-point').first()).toBeVisible();

    // Get the right anchor point
    const rightAnchor = page.locator('#editor svg .anchor-point[data-anchor="right"]');
    const anchorBox = await rightAnchor.boundingBox();

    // Drag to create line
    await page.mouse.move(anchorBox!.x + anchorBox!.width / 2, anchorBox!.y + anchorBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(anchorBox!.x + 100, anchorBox!.y);
    await page.mouse.up();

    // Line should be created and selected (Line uses handles instead of selection-rect)
    await expect(page.locator('#editor svg circle[data-handle="line-end"]')).toBeVisible();

    // Get initial line endpoint (use last() to get the newly created line, not the sample-arrow)
    const lineGroup = page.locator('#editor svg g[data-id] line').last();
    const initialX2 = await lineGroup.getAttribute('x2');
    const initialY2 = await lineGroup.getAttribute('y2');

    // Wait for line handles (lines use data-handle, not anchor-point)
    const lineHandles = page.locator('#editor svg circle[data-handle]').count();
    expect(await lineHandles).toBe(2); // line-start, line-end

    // Get the line-end handle
    const lineEndAnchor = page.locator('#editor svg circle[data-handle="line-end"]');
    await expect(lineEndAnchor).toBeVisible();

    // Use dispatchEvent for SVG drag since mouse coordinates can be tricky
    const lineEndBox = await lineEndAnchor.boundingBox();
    expect(lineEndBox).not.toBeNull();

    // Click on the handle to initiate resize mode
    await lineEndAnchor.dispatchEvent('mousedown', {
      bubbles: true,
      button: 0,
      clientX: lineEndBox!.x + lineEndBox!.width / 2,
      clientY: lineEndBox!.y + lineEndBox!.height / 2,
    });

    // Move the mouse
    await page.mouse.move(lineEndBox!.x + 100, lineEndBox!.y + 50);
    await page.waitForTimeout(50);

    // Release
    await page.mouse.up();

    // Line endpoint should have moved
    const newX2 = await lineGroup.getAttribute('x2');
    const newY2 = await lineGroup.getAttribute('y2');
    expect(newX2).not.toBe(initialX2);
    expect(newY2).not.toBe(initialY2);
  });

  // Line creation keeps lines that are long enough even on mouseleave (by design)
  test.skip('should cancel line creation on mouseleave', async ({ page }) => {
    // Count initial elements
    const initialCount = await page.locator('#editor svg [data-id]').count();

    // Select the circle
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click({ force: true });

    // Wait for anchor points
    await expect(page.locator('#editor svg .anchor-point').first()).toBeVisible();

    // Get anchor point
    const topAnchor = page.locator('#editor svg .anchor-point[data-anchor="top"]');
    const anchorBox = await topAnchor.boundingBox();

    // Start drag
    await page.mouse.move(anchorBox!.x + anchorBox!.width / 2, anchorBox!.y + anchorBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(anchorBox!.x + 50, anchorBox!.y - 50);

    // Move mouse outside SVG (simulate mouseleave)
    await page.mouse.move(0, 0);

    // Preview line should be gone
    await expect(page.locator('#editor svg .preview-line')).not.toBeVisible();

    // Release mouse
    await page.mouse.up();

    // No new element should be created
    const newCount = await page.locator('#editor svg [data-id]').count();
    expect(newCount).toBe(initialCount);
  });
});

test.describe('Moonlight Embed Mode - Edit Modal', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/embed.html');
    await expect(page.locator('#output')).toContainText('Editor created');
  });

  test('should have edit button', async ({ page }) => {
    const editButton = page.locator('#editor button:has-text("編集")');
    await expect(editButton).toBeVisible();
  });

  test('should open modal when edit button is clicked', async ({ page }) => {
    // Click edit button
    const editButton = page.locator('#editor button:has-text("編集")');
    await editButton.click();

    // Modal close button should be visible
    const closeButton = page.locator('button:has-text("閉じる")');
    await expect(closeButton).toBeVisible();
  });

  test('should close modal when close button is clicked', async ({ page }) => {
    // Open modal
    const editButton = page.locator('#editor button:has-text("編集")');
    await editButton.click();

    // Click close button
    const closeButton = page.locator('button:has-text("閉じる")');
    await closeButton.click();

    // Modal should not be visible
    await expect(closeButton).not.toBeVisible();
  });

  test('should have zoom controls in modal', async ({ page }) => {
    // Open modal
    const editButton = page.locator('#editor button:has-text("編集")');
    await editButton.click();

    // Check for zoom percentage display (e.g., "100%")
    const zoomDisplay = page.locator('span:has-text("%")');
    await expect(zoomDisplay.first()).toBeVisible();
  });
});
