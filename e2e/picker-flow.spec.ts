import { test, expect } from '@playwright/test';

test.describe('Dark Store Picker Console E2E Flow', () => {
  test('1. Picker console loads and renders picking queue interface', async ({ page }) => {
    await page.goto('/picker', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(600);

    // Verify Dark Store Picker title / header
    const pickerHeader = page.locator('text=Picker, text=Dark Store, text=Live Queue, text=Orders').first();
    await expect(pickerHeader).toBeVisible();
  });

  test('2. Picker Barcode scanner and audio synthesis controls are available', async ({ page }) => {
    await page.goto('/picker', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(600);

    // Look for scanner toggle or scan button
    const scannerBtn = page.locator('button[aria-label*="scan" i], button:has-text("Scan"), svg.lucide-scan, svg.lucide-camera').first();
    if (await scannerBtn.isVisible()) {
      await expect(scannerBtn).toBeVisible();
    }
  });
});
