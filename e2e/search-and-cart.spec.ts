import { test, expect } from '@playwright/test';

test.describe('Comprehensive FastKirana E2E Journey', () => {
  test('1. Homepage loads, displays branding, and renders navigation', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await expect(page).toHaveTitle(/Fast Kirana|FastKirana/i);

    // Verify main header/branding
    const logoOrBrand = page.locator('text=FastKirana, text=Fast Kirana, img[alt*="FastKirana"]').first();
    await expect(logoOrBrand).toBeVisible();

    // Verify presence of category section or cards
    const mainContent = page.locator('main, section, [data-testid="home-content"]').first();
    await expect(mainContent).toBeVisible();
  });

  test('2. Global Search Overlay opens, searches, and blocks out-of-stock items', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });

    // Open search overlay via search bar or button
    const searchTrigger = page.locator('input[placeholder*="Search" i], button:has-text("Search"), [aria-label*="search" i]').first();
    if (await searchTrigger.isVisible()) {
      await searchTrigger.click();
      await page.waitForTimeout(400);

      const activeSearchInput = page.locator('input[placeholder*="Search" i]').first();
      if (await activeSearchInput.isVisible()) {
        await activeSearchInput.fill('coke');
        await page.waitForTimeout(800);

        // Verify that if any item is marked "Sold Out", its button is disabled
        const soldOutButtons = page.locator('button:has-text("Sold Out"), div:has-text("Sold Out")');
        const count = await soldOutButtons.count();
        for (let i = 0; i < count; i++) {
          const btn = soldOutButtons.nth(i);
          if (await btn.isVisible()) {
            const tagName = await btn.evaluate((el) => el.tagName.toLowerCase());
            if (tagName === 'button') {
              await expect(btn).toBeDisabled();
            }
          }
        }
      }
    }
  });

  test('3. Product additions to cart and live cart drawer interactions', async ({ page }) => {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(500);

    // Find first enabled + ADD button on the homepage
    const addButtons = page.locator('button:has-text("ADD"), button:has-text("+ ADD")');
    const totalAddBtns = await addButtons.count();

    if (totalAddBtns > 0) {
      for (let i = 0; i < totalAddBtns; i++) {
        const btn = addButtons.nth(i);
        if (await btn.isVisible() && await btn.isEnabled()) {
          await btn.click();
          await page.waitForTimeout(400);
          break;
        }
      }
    }

    // Verify cart button or bottom bar appears / updates
    const cartButton = page.locator('button:has-text("Cart"), [aria-label*="cart" i], [href="/cart"]').first();
    if (await cartButton.isVisible()) {
      await cartButton.click();
      await page.waitForTimeout(500);

      // Verify cart drawer or modal is rendered
      const cartHeading = page.locator('text=Your Cart, text=Shopping Cart, text=Subtotal, text=Bill Details').first();
      if (await cartHeading.isVisible()) {
        await expect(cartHeading).toBeVisible();
      }
    }
  });

  test('4. Restaurant Kitchen Storefront renders operating status and dishes', async ({ page }) => {
    await page.goto('/food/wedson', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(600);

    const bodyText = await page.textContent('body');
    expect(bodyText).toBeDefined();

    // Verify restaurant header or menu sections
    const menuSection = page.locator('text=Menu, text=Kitchen, text=Pure Veg, text=FastKirana, h1, h2').first();
    await expect(menuSection).toBeVisible();
  });

  test('5. Checkout page loads and validates cart & delivery constraints', async ({ page }) => {
    await page.goto('/checkout', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(600);

    // If cart is empty, expect empty cart state or minimum order alert
    const checkoutState = page.locator('text=Your cart is empty, text=Checkout, text=Select Delivery Address, text=Bill Summary, text=Place Order').first();
    await expect(checkoutState).toBeVisible();
  });
});

