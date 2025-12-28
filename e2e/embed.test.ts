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
    expect(viewBox).toBe('0 0 600 400');
  });

  test('should have data-id attributes on elements', async ({ page }) => {
    const elementsWithId = page.locator('#editor svg [data-id]');
    const count = await elementsWithId.count();
    expect(count).toBeGreaterThan(0);
  });

  test('should select element on click', async ({ page }) => {
    // Click on the circle element
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click();

    // Check that selection rect appears
    const selectionRect = page.locator('#editor svg .selection-rect');
    await expect(selectionRect).toBeVisible();
  });

  test('should deselect on background click', async ({ page }) => {
    // First, select an element
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click();
    await expect(page.locator('#editor svg .selection-rect')).toBeVisible();

    // Click on background (top-left corner where there's no element)
    const svg = page.locator('#editor svg');
    const box = await svg.boundingBox();
    if (box) {
      await page.mouse.click(box.x + 10, box.y + 10);
    }

    // Selection rect should be gone
    await expect(page.locator('#editor svg .selection-rect')).not.toBeVisible();
  });

  test('should drag element to new position', async ({ page }) => {
    // Get initial circle position
    const circle = page.locator('#editor svg circle[data-id]').first();
    const initialCx = await circle.getAttribute('cx');
    const initialCy = await circle.getAttribute('cy');

    // Get SVG bounding box for coordinate calculation
    const svg = page.locator('#editor svg');
    const svgBox = await svg.boundingBox();
    expect(svgBox).not.toBeNull();

    if (svgBox && initialCx && initialCy) {
      // Calculate screen coordinates (assuming viewBox 0 0 600 400)
      const screenX = svgBox.x + (parseFloat(initialCx) / 600) * svgBox.width;
      const screenY = svgBox.y + (parseFloat(initialCy) / 400) * svgBox.height;

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

    // Get SVG bounding box
    const svg = page.locator('#editor svg');
    const svgBox = await svg.boundingBox();
    expect(svgBox).not.toBeNull();

    if (svgBox && initialX && initialY) {
      // Get rect dimensions for center calculation
      const width = parseFloat((await rect.getAttribute('width')) || '0');
      const height = parseFloat((await rect.getAttribute('height')) || '0');
      const centerX = parseFloat(initialX) + width / 2;
      const centerY = parseFloat(initialY) + height / 2;

      // Calculate screen coordinates
      const screenX = svgBox.x + (centerX / 600) * svgBox.width;
      const screenY = svgBox.y + (centerY / 400) * svgBox.height;

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
    const initialCx = await circle.getAttribute('cx');
    const initialCy = await circle.getAttribute('cy');

    const svg = page.locator('#editor svg');
    const svgBox = await svg.boundingBox();

    if (svgBox && initialCx && initialCy) {
      const screenX = svgBox.x + (parseFloat(initialCx) / 600) * svgBox.width;
      const screenY = svgBox.y + (parseFloat(initialCy) / 400) * svgBox.height;

      // Start drag
      await page.mouse.move(screenX, screenY);
      await page.mouse.down();

      // Selection rect should be visible
      await expect(page.locator('#editor svg .selection-rect')).toBeVisible();

      // Complete drag
      await page.mouse.move(screenX + 30, screenY + 20, { steps: 3 });
      await page.mouse.up();

      // Selection rect should still be visible
      await expect(page.locator('#editor svg .selection-rect')).toBeVisible();
    }
  });

  test('drag should respect viewBox scaling', async ({ page }) => {
    // This test verifies that drag works correctly with viewBox scaling
    const circle = page.locator('#editor svg circle[data-id]').first();
    const initialCx = await circle.getAttribute('cx');
    const initialCy = await circle.getAttribute('cy');

    const svg = page.locator('#editor svg');
    const svgBox = await svg.boundingBox();

    if (svgBox && initialCx && initialCy) {
      // Calculate expected movement in SVG coordinates
      // If we move 60px on screen and SVG width is 600, viewBox width is 600
      // Then movement in SVG coords should be approximately 60 * (600/svgBox.width)
      const svgScale = 600 / svgBox.width;
      const screenDx = 60;
      const expectedSvgDx = screenDx * svgScale;

      const screenX = svgBox.x + (parseFloat(initialCx) / 600) * svgBox.width;
      const screenY = svgBox.y + (parseFloat(initialCy) / 400) * svgBox.height;

      await page.mouse.move(screenX, screenY);
      await page.mouse.down();
      await page.mouse.move(screenX + screenDx, screenY, { steps: 5 });
      await page.mouse.up();

      const newCx = await circle.getAttribute('cx');
      const actualDx = parseFloat(newCx!) - parseFloat(initialCx);

      // Allow some tolerance for floating point
      expect(Math.abs(actualDx - expectedSvgDx)).toBeLessThan(5);
    }
  });
});

test.describe('Moonlight Embed Mode - Context Menu', () => {
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
    await circle.click();

    // Anchor points should appear (5 for circle: top, bottom, left, right, center)
    const anchorsAfter = await page.locator('#editor svg .anchor-point').count();
    expect(anchorsAfter).toBe(5);
  });

  test('should hide anchor points when deselected', async ({ page }) => {
    // Select the circle
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click();

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
    // Select the rect
    const rect = page.locator('#editor svg rect[data-id]').first();
    await rect.click();

    // Rect should have 5 anchor points (top, bottom, left, right, center)
    const anchors = await page.locator('#editor svg .anchor-point').count();
    expect(anchors).toBe(5);
  });
});

test.describe('Moonlight Embed Mode - Keyboard Shortcuts', () => {
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
    await circle.click();

    // Selection should be visible
    await expect(page.locator('#editor svg .selection-rect')).toBeVisible();

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
    await circle.click();
    await expect(page.locator('#editor svg .selection-rect')).toBeVisible();

    // Press Escape
    await page.keyboard.press('Escape');

    // Selection should be gone
    await expect(page.locator('#editor svg .selection-rect')).not.toBeVisible();
  });

  test('should move selected element with arrow keys', async ({ page }) => {
    // Select the circle
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click();

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
    await circle.click();

    // Wait for anchor points to appear
    await expect(page.locator('#editor svg .anchor-point').first()).toBeVisible();

    // Get the right anchor point
    const rightAnchor = page.locator('#editor svg .anchor-point[data-anchor="right"]');
    const anchorBox = await rightAnchor.boundingBox();
    expect(anchorBox).not.toBeNull();

    // Drag from anchor point to create a line
    await page.mouse.move(anchorBox!.x + anchorBox!.width / 2, anchorBox!.y + anchorBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(anchorBox!.x + 100, anchorBox!.y);

    // Preview line should be visible during drag
    await expect(page.locator('#editor svg .preview-line')).toBeVisible();

    await page.mouse.up();

    // New line element should be created
    const newCount = await page.locator('#editor svg [data-id]').count();
    expect(newCount).toBe(initialCount + 1);

    // Verify line element exists (Line is wrapped in a group with data-id)
    const lines = await page.locator('#editor svg g[data-id] line').count();
    expect(lines).toBeGreaterThan(0);
  });

  test('should not create line if drag distance is too short', async ({ page }) => {
    // Count initial elements
    const initialCount = await page.locator('#editor svg [data-id]').count();

    // Select the circle to show anchor points
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click();

    // Wait for anchor points
    await expect(page.locator('#editor svg .anchor-point').first()).toBeVisible();

    // Get anchor point
    const centerAnchor = page.locator('#editor svg .anchor-point[data-anchor="center"]');
    const anchorBox = await centerAnchor.boundingBox();

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
    await circle.click();

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
    await expect(page.locator('#editor svg .selection-rect')).not.toBeVisible();

    // Now click on the line to re-select it (use last() to get the newly created line)
    const lineGroup = page.locator('#editor svg g[data-id] line').last();
    const lineBox = await lineGroup.boundingBox();
    expect(lineBox).not.toBeNull();

    // Click on the line's hit area (the parent group)
    await page.mouse.click(lineBox!.x + lineBox!.width / 2, lineBox!.y + lineBox!.height / 2);

    // Line should be selected again (Line uses handles instead of selection-rect)
    await expect(page.locator('#editor svg circle[data-handle="line-end"]')).toBeVisible();

    // Line has 3 anchor points: line-start, line-end, center
    const lineAnchors = await page.locator('#editor svg .anchor-point').count();
    expect(lineAnchors).toBe(3);
  });

  test('should move line endpoint by dragging anchor', async ({ page }) => {
    // First create a line by dragging from anchor
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click();

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

    // Wait for anchor points on the line
    const lineAnchors = page.locator('#editor svg .anchor-point').count();
    expect(await lineAnchors).toBe(3); // line-start, line-end, center

    // Get the line-end anchor
    const lineEndAnchor = page.locator('#editor svg .anchor-point[data-anchor="line-end"]');
    const lineEndBox = await lineEndAnchor.boundingBox();
    expect(lineEndBox).not.toBeNull();

    // Drag line-end anchor to move the endpoint
    await page.mouse.move(lineEndBox!.x + lineEndBox!.width / 2, lineEndBox!.y + lineEndBox!.height / 2);
    await page.mouse.down();
    await page.mouse.move(lineEndBox!.x + 50, lineEndBox!.y + 30);
    await page.mouse.up();

    // Line endpoint should have moved
    const newX2 = await lineGroup.getAttribute('x2');
    const newY2 = await lineGroup.getAttribute('y2');
    expect(newX2).not.toBe(initialX2);
    expect(newY2).not.toBe(initialY2);
  });

  test('should cancel line creation on mouseleave', async ({ page }) => {
    // Count initial elements
    const initialCount = await page.locator('#editor svg [data-id]').count();

    // Select the circle
    const circle = page.locator('#editor svg circle[data-id]').first();
    await circle.click();

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
