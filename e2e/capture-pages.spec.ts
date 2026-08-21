import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

const routes = [
  { name: '01_home_mobile', path: '/' },
  { name: '02_category_mobile', path: '/category' },
  { name: '03_search_mobile', path: '/search' },
  { name: '04_cart_mobile', path: '/cart' },
  { name: '05_checkout_mobile', path: '/checkout' },
  { name: '06_account_mobile', path: '/account' },
  { name: '07_food_mobile', path: '/food' },
  { name: '08_restaurant_mobile', path: '/restaurant' },
  { name: '09_login_mobile', path: '/login' },
  { name: '10_delivery_mobile', path: '/delivery' },
];

test.describe('Capture Mobile UI Web Screenshots', () => {
  const outputDir = path.join(process.cwd(), 'scratch', 'web_screenshots');

  test.beforeAll(() => {
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }
  });

  for (const route of routes) {
    test(`Capture screenshot of ${route.path}`, async ({ page }) => {
      await page.goto(route.path, { waitUntil: 'networkidle', timeout: 30000 }).catch(() => {
        return page.goto(route.path, { waitUntil: 'domcontentloaded' });
      });

      await page.waitForTimeout(1500); // Wait for animations & fonts

      const filePath = path.join(outputDir, `${route.name}.png`);
      await page.screenshot({ path: filePath, fullPage: false });
      console.log(`Saved screenshot: ${filePath}`);
    });
  }
});
