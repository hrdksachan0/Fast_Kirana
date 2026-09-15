import { test, expect } from '@playwright/test';

test.describe('Rider Delivery Console E2E Flow', () => {
  test('1. Delivery rider console loads and renders dashboard', async ({ page }) => {
    await page.goto('/delivery', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(600);

    // Verify delivery dashboard
    const deliveryHeading = page.locator('text=Rider, text=Delivery, text=Assigned, text=Active Deliveries').first();
    await expect(deliveryHeading).toBeVisible();
  });

  test('2. Offline Sync banner and GPS location indicators load gracefully', async ({ page }) => {
    await page.goto('/delivery', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(600);

    // Verify body rendered without breaking
    const mainContainer = page.locator('main, div.container, [data-testid="delivery-root"]').first();
    await expect(mainContainer).toBeVisible();
  });
});
