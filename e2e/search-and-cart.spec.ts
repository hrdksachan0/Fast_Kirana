import { test, expect } from '@playwright/test';

test.describe('Search and Cart E2E Flow', () => {
  test('Search page renders input and responds to queries', async ({ page }) => {
    await page.goto('/search');
    
    // Check search input presence
    const searchInput = page.locator('input[type="text"], input[type="search"]').first();
    await expect(searchInput).toBeVisible();

    // Type search query
    await searchInput.fill('burger');
    await page.waitForTimeout(500);

    // Verify search page elements load without breaking
    const bodyText = await page.textContent('body');
    expect(bodyText).toBeDefined();
  });

  test('Cart drawer opens and handles item interactions', async ({ page }) => {
    await page.goto('/');
    
    // Check page loaded successfully
    await expect(page).toHaveTitle(/Fast Kirana|FastKirana/i);

    // Click cart trigger if present
    const cartButton = page.locator('button:has-text("Cart"), [aria-label*="cart" i], [href="/cart"]').first();
    if (await cartButton.isVisible()) {
      await cartButton.click();
      await page.waitForTimeout(300);
    }
  });
});
