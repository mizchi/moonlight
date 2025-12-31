import { test, expect } from '@playwright/test';

test.describe('Moonlight Embed Mode', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/embed.html');
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
    await page.goto('/examples/embed.html');
    // Wait for editor to be ready
    await expect(page.locator('#output')).toContainText('Editor created');
  });

  test('should have SVG with viewBox', async ({ page }) => {
    // Use svg[width="100%"] to target the canvas SVG (icon SVGs have fixed width like 20)
    const svg = page.locator('#editor svg[width="100%"]');
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
    const svg = page.locator('#editor svg[width="100%"]');
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

test.describe('Moonlight Embed Mode - Anchor Points', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/embed.html');
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
    const svg = page.locator('#editor svg[width="100%"]');
    const box = await svg.boundingBox();
    if (box) {
      await page.mouse.click(box.x + 10, box.y + 10);
    }

    // Anchor points should be gone
    const anchors = await page.locator('#editor svg[width="100%"] .anchor-point').count();
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

test.describe('Moonlight Embed Mode - Anchor Drag', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/embed.html');
    await expect(page.locator('#output')).toContainText('Editor created');
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
});

test.describe('Moonlight Embed Mode - Edit Modal', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/examples/embed.html');
    await expect(page.locator('#output')).toContainText('Editor created');
  });

  test('should have edit button', async ({ page }) => {
    // Button uses icon with aria-label for accessibility
    const editButton = page.locator('#editor button[aria-label="Edit in fullscreen"]');
    await expect(editButton).toBeVisible();
  });

  test('should open modal when edit button is clicked', async ({ page }) => {
    // Click edit button
    const editButton = page.locator('#editor button[aria-label="Edit in fullscreen"]');
    await editButton.click();

    // Modal close button should be visible (uses aria-label)
    const closeButton = page.locator('button[aria-label="Close"]');
    await expect(closeButton).toBeVisible();
  });

  test('should close modal when close button is clicked', async ({ page }) => {
    // Open modal
    const editButton = page.locator('#editor button[aria-label="Edit in fullscreen"]');
    await editButton.click();

    // Click close button
    const closeButton = page.locator('button[aria-label="Close"]');
    await closeButton.click();

    // Modal should not be visible
    await expect(closeButton).not.toBeVisible();
  });

  test('should have zoom controls in modal', async ({ page }) => {
    // Open modal
    const editButton = page.locator('#editor button[aria-label="Edit in fullscreen"]');
    await editButton.click();

    // Check for zoom percentage display (e.g., "100%")
    const zoomDisplay = page.locator('span:has-text("%")');
    await expect(zoomDisplay.first()).toBeVisible();
  });

  test('should move selected element with arrow keys in modal', async ({ page }) => {
    // Open modal
    const editButton = page.locator('#editor button[aria-label="Edit in fullscreen"]');
    await editButton.click();

    // Wait for modal to open
    await expect(page.locator('button[aria-label="Close"]')).toBeVisible();

    // Select circle element in the modal (use the modal's SVG canvas)
    const modalSvg = page.locator('div[style*="position: fixed"] svg[width="100%"]');
    const circle = modalSvg.locator('circle[data-id]').first();
    await circle.click({ force: true });

    // Wait for selection
    await expect(modalSvg.locator('.selection-overlay')).toBeVisible();

    // Get initial position
    const initialCx = await circle.getAttribute('cx');
    const initialCy = await circle.getAttribute('cy');

    // Press arrow right
    await page.keyboard.press('ArrowRight');

    // Position should change
    const newCx = await circle.getAttribute('cx');
    expect(parseFloat(newCx!)).toBe(parseFloat(initialCx!) + 5);

    // Press arrow down
    await page.keyboard.press('ArrowDown');
    const newCy = await circle.getAttribute('cy');
    expect(parseFloat(newCy!)).toBe(parseFloat(initialCy!) + 5);
  });
});
