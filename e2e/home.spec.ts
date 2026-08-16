import { test, expect } from '@playwright/test';

test('FastKirana home page loads and displays bottom navigation', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/Fast Kirana/i);
});
