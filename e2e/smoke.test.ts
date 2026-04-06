import { test, expect, type Page } from '@playwright/test';

/**
 * A11y-driven probabilistic smoke test (inspired by vrt smoke)
 *
 * Discovers interactive elements from the accessibility tree,
 * performs random actions, and detects crashes/errors.
 */

const ROLE_ACTION_MAP: Record<string, 'click' | 'type' | 'check'> = {
  button: 'click',
  link: 'click',
  tab: 'click',
  menuitem: 'click',
  checkbox: 'check',
  switch: 'check',
  radio: 'click',
  textbox: 'type',
  searchbox: 'type',
};

const SAMPLE_INPUTS = [
  'hello',
  'test@example.com',
  '12345',
  '日本語テスト',
  '',
  'a'.repeat(100),
];

// Edge case inputs for text editing
const EDGE_INPUTS = [
  '<script>alert("xss")</script>',
  '🔥🚀✨ Unicode 测试',
  '\n\n\n',
  '   spaces   ',
  'a'.repeat(1000),
  '🎉'.repeat(50),
];

interface ActionCandidate {
  role: string;
  name: string;
  action: 'click' | 'type' | 'check';
}

function seededRandom(seed: number): () => number {
  let s = seed;
  return () => {
    s = (s * 1664525 + 1013904223) & 0x7fffffff;
    return s / 0x7fffffff;
  };
}

async function discoverActions(page: Page): Promise<ActionCandidate[]> {
  const candidates: ActionCandidate[] = [];

  for (const [role, action] of Object.entries(ROLE_ACTION_MAP)) {
    try {
      const locators = page.getByRole(role as any);
      const count = await locators.count();

      for (let i = 0; i < count; i++) {
        const el = locators.nth(i);
        const isVisible = await el.isVisible().catch(() => false);
        if (!isVisible) continue;

        const isDisabled = await el.isDisabled().catch(() => false);
        if (isDisabled) continue;

        const name = await el.getAttribute('aria-label').catch(() => null)
          ?? (await el.textContent().catch(() => ''))?.slice(0, 50)
          ?? '';

        candidates.push({ role, name, action });
      }
    } catch {
      // skip this role
    }
  }

  return candidates;
}

test.describe('Probabilistic Smoke Test', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForTimeout(500);
  });

  test('random interactions should not crash', async ({ page }) => {
    const seed = parseInt(process.env.VRT_SEED || '', 10) || Date.now();
    const rand = seededRandom(seed);
    const maxActions = 20;
    const errors: Array<{ step: number; type: string; message: string }> = [];
    const actions: Array<{ step: number; action: string; target: string; result: string }> = [];

    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        errors.push({ step: actions.length, type: 'console-error', message: msg.text() });
      }
    });

    page.on('pageerror', (err) => {
      errors.push({ step: actions.length, type: 'uncaught-exception', message: err.message });
    });

    for (let step = 0; step < maxActions; step++) {
      const candidates = await discoverActions(page);
      if (candidates.length === 0) break;

      const candidate = candidates[Math.floor(rand() * candidates.length)];
      let result = 'ok';

      try {
        const locator = page.getByRole(candidate.role as any, { name: candidate.name || undefined }).first();

        switch (candidate.action) {
          case 'click':
            await locator.click({ timeout: 3000 });
            break;
          case 'type': {
            const value = SAMPLE_INPUTS[Math.floor(rand() * SAMPLE_INPUTS.length)];
            await locator.fill(value).catch(() => locator.click());
            break;
          }
          case 'check':
            await locator.check({ timeout: 2000 }).catch(() => locator.click());
            break;
        }

        await page.waitForTimeout(200);
      } catch (e) {
        const msg = String(e);
        if (msg.includes('timeout') || msg.includes('Timeout')) {
          result = 'timeout';
        } else if (msg.includes('navigation')) {
          result = 'navigation';
        } else {
          result = 'error';
        }
      }

      actions.push({
        step,
        action: candidate.action,
        target: `${candidate.role}:${candidate.name}`,
        result,
      });

      // Check if page is still responsive
      try {
        await page.title();
      } catch {
        errors.push({ step, type: 'crash', message: 'Page became unresponsive' });
        break;
      }
    }

    // Assert no crashes
    const crashes = errors.filter((e) => e.type === 'crash');
    expect(crashes, `Page crashed during smoke test (seed: ${seed})`).toHaveLength(0);

    // Assert no uncaught exceptions (console errors are warnings, not failures)
    const uncaughtExceptions = errors.filter((e) => e.type === 'uncaught-exception');
    expect(
      uncaughtExceptions,
      `Uncaught exceptions during smoke test (seed: ${seed}): ${uncaughtExceptions.map((e) => e.message).join('; ')}`
    ).toHaveLength(0);

    // Log summary for debugging
    const failedActions = actions.filter((a) => a.result !== 'ok');
    if (failedActions.length > 0) {
      console.log(`Smoke test (seed: ${seed}): ${actions.length} actions, ${failedActions.length} non-ok results`);
    }
  });

  test('stress test: rapid shape operations', async ({ page }) => {
    const seed = Date.now();
    const rand = seededRandom(seed);
    const shapeButtons = ['Rectangle', 'Circle', 'Ellipse', 'Line', 'Text'];
    const errors: string[] = [];

    page.on('pageerror', (err) => {
      errors.push(err.message);
    });

    // Wait for editor to be ready
    await expect(page.getByRole('button', { name: 'Rectangle' })).toBeVisible({ timeout: 10000 });

    // Rapidly add and delete shapes
    for (let i = 0; i < 10; i++) {
      const shapeName = shapeButtons[Math.floor(rand() * shapeButtons.length)];

      // Add shape
      await page.getByRole('button', { name: shapeName }).click();
      await page.waitForTimeout(50);

      // Select and delete with 50% probability
      if (rand() > 0.5) {
        const shapeRects = page.locator('svg rect[data-id][cursor="move"]');
        const count = await shapeRects.count();
        if (count > 0) {
          await shapeRects.first().click({ force: true });
          await page.waitForTimeout(50);
          await page.keyboard.press('Delete');
          await page.waitForTimeout(50);
        }
      }
    }

    expect(errors, `Errors during stress test (seed: ${seed}): ${errors.join('; ')}`).toHaveLength(0);
  });

  test('stress test: rapid undo/redo', async ({ page }) => {
    const errors: string[] = [];

    page.on('pageerror', (err) => {
      errors.push(err.message);
    });

    // Wait for editor to be ready
    await expect(page.getByRole('button', { name: 'Rectangle' })).toBeVisible({ timeout: 10000 });

    // Add several shapes
    for (let i = 0; i < 5; i++) {
      await page.getByRole('button', { name: 'Rectangle' }).click();
      await page.waitForTimeout(30);
    }

    // Rapidly undo all
    for (let i = 0; i < 5; i++) {
      await page.keyboard.press('Control+z');
      await page.waitForTimeout(30);
    }

    // Rapidly redo all
    for (let i = 0; i < 5; i++) {
      await page.keyboard.press('Control+y');
      await page.waitForTimeout(30);
    }

    expect(errors, `Errors during undo/redo stress test: ${errors.join('; ')}`).toHaveLength(0);
  });

  test('stress test: random drag and resize', async ({ page }) => {
    const seed = Date.now();
    const rand = seededRandom(seed);
    const errors: string[] = [];

    page.on('pageerror', (err) => {
      errors.push(err.message);
    });

    // Wait for editor to be ready
    await expect(page.getByRole('button', { name: 'Rectangle' })).toBeVisible({ timeout: 10000 });

    // Add some shapes first
    for (let i = 0; i < 3; i++) {
      await page.getByRole('button', { name: 'Rectangle' }).click();
      await page.waitForTimeout(50);
    }

    const svg = page.locator('svg[viewBox]').first();
    const box = await svg.boundingBox();
    if (!box) throw new Error('SVG not found');

    // Random drag operations
    for (let i = 0; i < 10; i++) {
      const rect = page.locator('svg rect[data-id][cursor="move"]').first();
      const rectVisible = await rect.isVisible().catch(() => false);

      if (rectVisible) {
        const targetX = box.x + rand() * box.width;
        const targetY = box.y + rand() * box.height;

        await rect.dragTo(svg, {
          targetPosition: { x: targetX - box.x, y: targetY - box.y },
          force: true,
        }).catch(() => {});

        await page.waitForTimeout(100);
      }
    }

    expect(errors, `Errors during drag stress test (seed: ${seed}): ${errors.join('; ')}`).toHaveLength(0);
  });

  test('stress test: keyboard navigation', async ({ page }) => {
    const errors: string[] = [];

    page.on('pageerror', (err) => {
      errors.push(err.message);
    });

    await expect(page.getByRole('button', { name: 'Rectangle' })).toBeVisible({ timeout: 10000 });

    // Add some shapes first
    for (const shape of ['Rectangle', 'Circle', 'Ellipse']) {
      await page.getByRole('button', { name: shape }).click();
      await page.waitForTimeout(50);
    }

    // Select a shape and cycle through keyboard operations
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    await rect.click({ force: true });
    await page.waitForTimeout(100);

    // Escape to deselect, then Tab to cycle focus
    await page.keyboard.press('Escape');
    await page.waitForTimeout(50);

    for (let i = 0; i < 10; i++) {
      await page.keyboard.press('Tab');
      await page.waitForTimeout(30);
      await page.keyboard.press('Shift+Tab');
      await page.waitForTimeout(30);
    }

    // Arrow key nudge (should not crash without selection)
    for (const key of ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight']) {
      await page.keyboard.press(key);
      await page.waitForTimeout(20);
    }

    // Select and arrow key nudge (should move shape)
    await rect.click({ force: true });
    await page.waitForTimeout(100);
    for (let i = 0; i < 5; i++) {
      await page.keyboard.press('ArrowRight');
      await page.keyboard.press('ArrowDown');
      await page.waitForTimeout(20);
    }

    expect(errors, `Errors during keyboard navigation: ${errors.join('; ')}`).toHaveLength(0);
  });

  test('stress test: zoom in/out', async ({ page }) => {
    const errors: string[] = [];

    page.on('pageerror', (err) => {
      errors.push(err.message);
    });

    await expect(page.getByLabel('Zoom In')).toBeVisible({ timeout: 10000 });

    // Rapid zoom in
    for (let i = 0; i < 20; i++) {
      await page.getByLabel('Zoom In').click();
      await page.waitForTimeout(20);
    }

    // Rapid zoom out
    for (let i = 0; i < 20; i++) {
      await page.getByLabel('Zoom Out').click();
      await page.waitForTimeout(20);
    }

    // Fit to canvas reset
    await page.getByLabel('Fit to Canvas').click();
    await page.waitForTimeout(100);

    // Zoom in again
    for (let i = 0; i < 10; i++) {
      await page.getByLabel('Zoom In').click();
      await page.waitForTimeout(20);
    }

    expect(errors, `Errors during zoom stress test: ${errors.join('; ')}`).toHaveLength(0);
  });

  test('stress test: context menu operations', async ({ page }) => {
    const seed = Date.now();
    const rand = seededRandom(seed);
    const errors: string[] = [];

    page.on('pageerror', (err) => {
      errors.push(err.message);
    });

    await expect(page.getByRole('button', { name: 'Rectangle' })).toBeVisible({ timeout: 10000 });

    // Add shapes
    for (let i = 0; i < 3; i++) {
      await page.getByRole('button', { name: 'Rectangle' }).click();
      await page.waitForTimeout(50);
    }

    const svg = page.locator('svg[viewBox]').first();
    const box = await svg.boundingBox();
    if (!box) throw new Error('SVG not found');

    // Repeatedly right-click on shapes and random positions
    for (let i = 0; i < 10; i++) {
      const x = rand() * box.width;
      const y = rand() * box.height;

      await svg.click({ button: 'right', position: { x, y }, force: true });
      await page.waitForTimeout(100);

      // Maybe click a context menu button
      if (rand() > 0.5) {
        const deleteBtn = page.locator('button:has-text("Delete")');
        const deleteVisible = await deleteBtn.isVisible().catch(() => false);
        if (deleteVisible) {
          await deleteBtn.click();
          await page.waitForTimeout(50);
          continue;
        }

        // Insert menu buttons
        const insertBtn = page.locator('button').filter({ hasText: 'Rectangle' }).first();
        const insertVisible = await insertBtn.isVisible().catch(() => false);
        if (insertVisible && rand() > 0.5) {
          await insertBtn.click();
          await page.waitForTimeout(50);
          continue;
        }
      }

      // Click elsewhere to dismiss
      await svg.click({ position: { x: 10, y: 10 }, force: true });
      await page.waitForTimeout(50);
    }

    expect(errors, `Errors during context menu stress test (seed: ${seed}): ${errors.join('; ')}`).toHaveLength(0);
  });

  test('stress test: text editing with edge cases', async ({ page }) => {
    const seed = Date.now();
    const rand = seededRandom(seed);
    const errors: string[] = [];

    page.on('pageerror', (err) => {
      errors.push(err.message);
    });

    await expect(page.getByRole('button', { name: 'Text' })).toBeVisible({ timeout: 10000 });

    // Add text elements and edit with edge case inputs
    for (let i = 0; i < 5; i++) {
      await page.getByRole('button', { name: 'Text' }).click();
      await page.waitForTimeout(100);

      const textElement = page.locator('svg g[data-element-type="text"]').last();
      const bbox = await textElement.boundingBox();
      if (!bbox) continue;

      // Double-click to edit
      await page.mouse.dblclick(bbox.x + bbox.width / 2, bbox.y + bbox.height / 2);
      await page.waitForTimeout(100);

      const textarea = page.locator('textarea');
      const textareaVisible = await textarea.isVisible().catch(() => false);
      if (!textareaVisible) continue;

      // Type edge case input
      const edgeInput = EDGE_INPUTS[Math.floor(rand() * EDGE_INPUTS.length)];
      await textarea.selectText();
      await page.keyboard.type(edgeInput, { delay: 0 });
      await page.waitForTimeout(50);

      // 50% confirm with Enter, 50% cancel with Escape
      if (rand() > 0.5) {
        await page.keyboard.press('Enter');
      } else {
        await page.keyboard.press('Escape');
      }
      await page.waitForTimeout(100);
    }

    expect(errors, `Errors during text editing stress test (seed: ${seed}): ${errors.join('; ')}`).toHaveLength(0);
  });

  test('stress test: select all and delete', async ({ page }) => {
    const errors: string[] = [];

    page.on('pageerror', (err) => {
      errors.push(err.message);
    });

    await expect(page.getByRole('button', { name: 'Rectangle' })).toBeVisible({ timeout: 10000 });

    for (let round = 0; round < 3; round++) {
      // Add several shapes
      for (const shape of ['Rectangle', 'Circle', 'Ellipse', 'Line']) {
        await page.getByRole('button', { name: shape }).click();
        await page.waitForTimeout(30);
      }

      // Select all and delete
      const isMac = process.platform === 'darwin';
      await page.keyboard.press(isMac ? 'Meta+a' : 'Control+a');
      await page.waitForTimeout(100);
      await page.keyboard.press('Delete');
      await page.waitForTimeout(100);
    }

    expect(errors, `Errors during select-all/delete stress test: ${errors.join('; ')}`).toHaveLength(0);
  });

  test('stress test: grid snap toggle', async ({ page }) => {
    const errors: string[] = [];

    page.on('pageerror', (err) => {
      errors.push(err.message);
    });

    await expect(page.getByRole('button', { name: 'Grid Snap' })).toBeVisible({ timeout: 10000 });

    // Toggle grid snap repeatedly while adding shapes
    for (let i = 0; i < 10; i++) {
      await page.getByRole('button', { name: 'Grid Snap' }).click();
      await page.waitForTimeout(30);
      await page.getByRole('button', { name: 'Rectangle' }).click();
      await page.waitForTimeout(30);
    }

    expect(errors, `Errors during grid snap stress test: ${errors.join('; ')}`).toHaveLength(0);
  });

  test('stress test: rapid duplicate (Ctrl+D)', async ({ page }) => {
    const errors: string[] = [];

    page.on('pageerror', (err) => {
      errors.push(err.message);
    });

    await expect(page.getByRole('button', { name: 'Rectangle' })).toBeVisible({ timeout: 10000 });

    // Add a shape
    await page.getByRole('button', { name: 'Rectangle' }).click();
    await page.waitForTimeout(100);

    // Select it
    const rect = page.locator('svg rect[data-id][cursor="move"]').first();
    await rect.click({ force: true });
    await page.waitForTimeout(100);

    // Rapidly duplicate
    const isMac = process.platform === 'darwin';
    for (let i = 0; i < 8; i++) {
      await page.keyboard.press(isMac ? 'Meta+d' : 'Control+d');
      await page.waitForTimeout(50);
    }

    expect(errors, `Errors during rapid duplicate stress test: ${errors.join('; ')}`).toHaveLength(0);
  });
});
