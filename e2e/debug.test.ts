import { test, expect } from '@playwright/test';

// Undo/Redo with empty stack should not cause errors
test('should handle undo/redo with empty stack', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (error) => {
    errors.push(error.message);
  });

  await page.goto('/');

  // Undo with empty stack
  await page.getByRole('button', { name: 'Undo' }).click();
  await page.waitForTimeout(50);

  // Redo with empty stack
  await page.getByRole('button', { name: 'Redo' }).click();
  await page.waitForTimeout(50);

  // Should have no errors
  expect(errors.length).toBe(0);
});

test('should duplicate shape with Ctrl+D', async ({ page }) => {
  await page.goto('/');

  // Only count shape rects (with cursor="move"), not text hit areas or resize handles
  const shapeRects = page.locator('svg rect[data-id][cursor="move"]');

  // 初期図形が出そろう前に数えると基準値が 0 になり、複製後の数と比べても
  // 意味のない比較になる（クリックの方は要素が現れるまで待つので食い違う）
  await expect(shapeRects).toHaveCount(4);
  const initialCount = await shapeRects.count();

  // Select first shape (use force:true because child text hit area may intercept clicks)
  await shapeRects.first().click({ force: true });
  await page.waitForTimeout(100);

  // Press Meta+D (macOS) / Ctrl+D
  await page.keyboard.press('Meta+d');

  // 固定待ちではなく、数が揃うまで待つ
  await expect(shapeRects).toHaveCount(initialCount + 1);
});
