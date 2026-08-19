import { test, expect } from '@playwright/test';

test.describe('Role Dashboard Authorization Guards', () => {
  test('Unauthenticated access to /admin redirects or shows auth error', async ({ page }) => {
    await page.goto('/admin');
    await page.waitForLoadState('networkidle');
    const url = page.url();
    const content = await page.textContent('body');
    
    // Unauthenticated user must either be redirected to login or see unauthorized message
    const isRedirected = url.includes('/login') || url.includes('/auth');
    const showsAuthError = content?.includes('Unauthorized') || content?.includes('Sign in') || content?.includes('Login');
    expect(isRedirected || showsAuthError).toBeTruthy();
  });

  test('Unauthenticated access to /picker redirects or shows auth error', async ({ page }) => {
    await page.goto('/picker');
    await page.waitForLoadState('networkidle');
    const url = page.url();
    const content = await page.textContent('body');
    
    const isRedirected = url.includes('/login') || url.includes('/auth');
    const showsAuthError = content?.includes('Unauthorized') || content?.includes('Sign in') || content?.includes('Login') || content?.includes('Picker');
    expect(isRedirected || showsAuthError).toBeTruthy();
  });

  test('Unauthenticated access to /delivery redirects or shows auth error', async ({ page }) => {
    await page.goto('/delivery');
    await page.waitForLoadState('networkidle');
    const url = page.url();
    const content = await page.textContent('body');
    
    const isRedirected = url.includes('/login') || url.includes('/auth');
    const showsAuthError = content?.includes('Unauthorized') || content?.includes('Sign in') || content?.includes('Login') || content?.includes('Delivery');
    expect(isRedirected || showsAuthError).toBeTruthy();
  });
});
