import { test, expect } from '@playwright/test';

test('debug: check page content and console', async ({ page }) => {
  // Collect console messages
  const consoleMessages: string[] = [];
  const consoleErrors: string[] = [];

  page.on('console', (msg) => {
    const text = `[${msg.type()}] ${msg.text()}`;
    consoleMessages.push(text);
    if (msg.type() === 'error') {
      consoleErrors.push(text);
    }
  });

  page.on('pageerror', (error) => {
    consoleErrors.push(`[pageerror] ${error.message}`);
  });

  await page.goto('/');

  // Wait for page to load
  await page.waitForTimeout(2000);

  // Get page HTML
  const html = await page.content();
  console.log('=== Page HTML ===');
  console.log(html);

  // Get #app content
  const appContent = await page.locator('#app').innerHTML();
  console.log('=== #app Content ===');
  console.log(appContent);

  // Print console messages
  console.log('=== Console Messages ===');
  consoleMessages.forEach((msg) => console.log(msg));

  // Print errors
  if (consoleErrors.length > 0) {
    console.log('=== Console Errors ===');
    consoleErrors.forEach((err) => console.log(err));
  }

  // Check if #app has content
  expect(appContent.length).toBeGreaterThan(0);
});
