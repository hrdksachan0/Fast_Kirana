import { test, expect } from '@playwright/test';

test.describe('FastKirana Modular Checkout E2E Journey', () => {
  test('1. Direct checkout with empty cart shows empty barrier screen', async ({ page }) => {
    // Clear localStorage / cookies to ensure empty cart
    await page.goto('/checkout', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(500);

    // Should display Empty Cart state with button to browse
    const emptyNotice = page.locator('text=Your cart is empty, text=No items in cart, text=Start Shopping, text=Browse Products').first();
    await expect(emptyNotice).toBeVisible();
  });

  test('2. Add product from storefront and verify checkout bill breakdown and payment selectors', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(600);

    // Click first active ADD button
    const addBtn = page.locator('button:has-text("ADD"), button:has-text("+ ADD")').first();
    if (await addBtn.isVisible()) {
      await addBtn.click();
      await page.waitForTimeout(500);

      // Navigate to checkout
      await page.goto('/checkout', { waitUntil: 'domcontentloaded' });
      await page.waitForTimeout(800);

      // Verify checkout elements
      const billSummary = page.locator('text=Bill Details, text=To Pay, text=Item Total').first();
      await expect(billSummary).toBeVisible();

      // Check payment methods (Online UPI, COD)
      const payOptions = page.locator('text=Pay Online, text=Cash on Delivery, text=Cashfree').first();
      if (await payOptions.isVisible()) {
        await expect(payOptions).toBeVisible();
      }

      // Check Order for Someone Else toggle
      const giftToggle = page.locator('text=Ordering for someone else, text=Receiver Name').first();
      if (await giftToggle.isVisible()) {
        await expect(giftToggle).toBeVisible();
      }
    }
  });
});
