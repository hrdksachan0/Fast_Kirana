import { test, expect, type Page } from '@playwright/test'
import { loadEnvConfig } from '@next/env'
import { encode } from 'next-auth/jwt'
import { readFileSync } from 'node:fs'
import {
  featuredCategoriesSchema,
  type FeaturedCategoriesConfig,
} from '../src/lib/featured-categories'

const categories = [
  {
    id: 'fruit',
    name: 'Fruits & vegetables',
    slug: 'fruits-vegetables',
    sortOrder: 1,
    imageUrl: '/fruits_vegetables_category.webp',
  },
  {
    id: 'milk',
    name: 'Dairy & breakfast',
    slug: 'dairy-breakfast',
    sortOrder: 2,
    imageUrl: '/dairy_breakfast_category.webp',
  },
  {
    id: 'snacks',
    name: 'Snacks & munchies',
    slug: 'snacks-munchies',
    sortOrder: 3,
    imageUrl: '/snacks_munchies_category.webp',
  },
  {
    id: 'drinks',
    name: 'Cold drinks & juices',
    slug: 'beverages',
    sortOrder: 4,
    imageUrl: '/beverages_category.webp',
  },
  { id: 'bakery', name: 'Bakery & biscuits', slug: 'bakery', sortOrder: 5 },
  { id: 'rice', name: 'Atta, rice & dal', slug: 'atta-rice-dal', sortOrder: 6 },
  { id: 'care', name: 'Personal care', slug: 'personal-care', sortOrder: 7 },
].map((category) => ({ ...category, parentId: null, _count: { products: 4 } }))
const initial = () =>
  featuredCategoriesSchema.parse({
    version: 1,
    items: [
      { categoryId: 'snacks', badge: 'Featured', tint: 'peach' },
      { categoryId: 'milk', badge: 'Everyday', tint: 'cream' },
      { categoryId: 'fruit', badge: 'Seasonal', tint: 'mint' },
      { categoryId: 'drinks', tint: 'sky' },
    ],
  })
async function openCategories(page: Page) {
  // Server-rendered navigation can be visible before React can handle clicks.
  await expect(async () => {
    await page.getByRole('button', { name: /Products & Inventory/ }).click()
    await expect(page.getByRole('button', { name: /^Categories(?:\s|$)/ })).toBeVisible({
      timeout: 1500,
    })
  }).toPass({ timeout: 60000, intervals: [1000] })
  await page.getByRole('button', { name: /^Categories(?:\s|$)/ }).click()
}
async function prepare(page: Page, options: { failLoad?: boolean; full?: boolean } = {}) {
  loadEnvConfig(process.cwd())
  const secret = process.env.AUTH_SECRET || process.env.NEXTAUTH_SECRET
  test.skip(!secret, 'Local AUTH_SECRET is needed for the isolated admin fixture')
  const token = await encode({
    secret: secret!,
    salt: 'authjs.session-token',
    token: { name: 'Category Test Admin', email: 'superadmin@fastkirana.com', role: 'ADMIN' },
    maxAge: 3600,
  })
  await page.context().addCookies([
    {
      name: 'authjs.session-token',
      value: token,
      url: 'http://localhost:3000',
      httpOnly: true,
      sameSite: 'Lax',
    },
  ])
  let config: FeaturedCategoriesConfig = options.full
    ? featuredCategoriesSchema.parse({
        version: 1,
        items: categories.slice(0, 6).map((category) => ({ categoryId: category.id })),
      })
    : initial()
  let failLoad = options.failLoad
  const writes: { storeId: string; config: FeaturedCategoriesConfig }[] = []
  await page.context().route('https://images.test/**', (route) =>
    route.fulfill({
      contentType: 'image/webp',
      body: readFileSync('public/snacks_munchies_category.webp'),
    })
  )
  await page.context().route('**/api/**', async (route) => {
    const path = new URL(route.request().url()).pathname
    let body: unknown = {},
      status = 200
    if (path === '/api/auth/session')
      body = {
        user: { name: 'Category Test Admin', email: 'superadmin@fastkirana.com', role: 'ADMIN' },
        expires: '2099-01-01T00:00:00.000Z',
      }
    else if (path === '/api/admin/featured-categories') {
      if (route.request().method() === 'PUT') {
        const payload = route.request().postDataJSON()
        config = featuredCategoriesSchema.parse(payload.config)
        writes.push(structuredClone(payload))
        body = { success: true, config, inherited: false }
      } else if (failLoad) {
        status = 503
        body = { error: 'Settings temporarily unavailable' }
      } else body = { config, inherited: writes.length === 0 }
    } else if (path === '/api/upload') body = { url: 'https://images.test/artwork.webp' }
    else if (path === '/api/categories' || path === '/api/admin/categories') body = categories
    else if (path === '/api/products' || path === '/api/admin/products')
      body = { products: [], total: 0 }
    else if (path === '/api/admin/orders') {
      body = { orders: [], total: 0, totalPages: 1, stats: {} }
    } else if (path === '/api/admin/users') body = { users: [], total: 0 }
    else if (path === '/api/stores/hubs')
      body = {
        hubs: [
          {
            id: 'featured-hub',
            city: 'Ghatampur',
            latitude: 26.15,
            longitude: 80.17,
            deliveryRadiusKm: 5,
          },
        ],
      }
    else if (
      [
        '/api/admin/stores',
        '/api/banners',
        '/api/restaurants',
        '/api/admin/reviews',
        '/api/admin/coupons',
      ].includes(path)
    )
      body = []
    else if (path === '/api/store-status')
      body = { grocery_mart_open: 'true', cafe_open: 'true', restaurant_open: 'true' }
    await route.fulfill({ json: body, status })
  })
  await page.addInitScript(() => {
    localStorage.setItem('push-prompt-dismissed', 'true')
    localStorage.setItem('fk-location', 'Test Hub')
    localStorage.setItem('fk-store-id', 'featured-hub')
    localStorage.setItem('fk-coords', JSON.stringify({ lat: 26.15, lng: 80.17 }))
    localStorage.setItem('fk-city', 'Ghatampur')
    localStorage.setItem('fk-theme', 'light')
  })
  await page.goto('/admin?storeId=featured-hub', { waitUntil: 'domcontentloaded', timeout: 90000 })
  await openCategories(page)
  const editor = page.getByRole('region', { name: 'Featured categories editor' })
  await expect(editor).toBeVisible({ timeout: 30000 })
  return {
    editor,
    writes,
    getConfig: () => config,
    recover: () => {
      failLoad = false
    },
  }
}
test.describe('Flutter featured category admin editor', () => {
  test.use({ serviceWorkers: 'block' })
  test.setTimeout(120000)
  for (const viewport of [
    { width: 1280, height: 1000, name: 'desktop' },
    { width: 390, height: 844, name: 'mobile' },
  ]) {
    test(`edit, upload, reorder and reload store settings (${viewport.name})`, async ({ page }) => {
      await page.setViewportSize(viewport)
      const { editor, writes } = await prepare(page)
      await expect(editor.getByRole('button', { name: 'Save categories' })).toBeEnabled()
      await editor.getByLabel('Section heading').fill('Your everyday picks')
      await editor.getByLabel('Display name 1', { exact: true }).fill('Movie night')
      await editor.getByLabel('Badge 1', { exact: true }).selectOption('Seasonal')
      await editor.getByLabel('Background 1', { exact: true }).selectOption('lilac')
      await editor.getByLabel('Image fit 1', { exact: true }).selectOption('contain')
      await editor
        .getByLabel('Upload artwork 1', { exact: true })
        .setInputFiles('public/snacks_munchies_category.webp')
      await expect(editor.getByLabel('Image URL 1', { exact: true })).toHaveValue(
        'https://images.test/artwork.webp'
      )
      await editor.getByRole('button', { name: 'Move Snacks & munchies down' }).click()
      await editor.getByLabel('Show Fruits & vegetables', { exact: true }).uncheck()
      await editor.getByRole('button', { name: 'Save categories' }).click()
      await expect(editor.getByRole('status')).toContainText('Saved')
      expect(writes).toHaveLength(1)
      expect(writes[0].storeId).toBe('featured-hub')
      expect(writes[0].config.items[1]).toMatchObject({
        categoryId: 'snacks',
        label: 'Movie night',
        badge: 'Seasonal',
        imageFit: 'contain',
        tint: 'lilac',
        image: 'https://images.test/artwork.webp',
      })
      await page.reload({ waitUntil: 'domcontentloaded' })
      await openCategories(page)
      await expect(editor.getByLabel('Section heading')).toHaveValue('Your everyday picks')
      await expect(editor.getByLabel('Display name 2', { exact: true })).toHaveValue('Movie night')
      await editor.evaluate((element) =>
        window.scrollTo(0, window.scrollY + element.getBoundingClientRect().top - 112)
      )
      // Hide development-only chrome from the product capture.
      await page.addStyleTag({ content: 'nextjs-portal { visibility: hidden !important; }' })
      await page.screenshot({ path: `artifacts/featured-categories/editor-${viewport.name}.png` })
      expect(await editor.evaluate((element) => element.scrollWidth <= element.clientWidth)).toBe(
        true
      )
    })
  }
  test('load failure cannot overwrite configuration; retry recovers', async ({ page }) => {
    const { editor, writes, recover } = await prepare(page, { failLoad: true })
    await expect(editor.getByRole('alert')).toContainText('Settings temporarily unavailable')
    await expect(editor.getByRole('button', { name: 'Save categories' })).toBeDisabled()
    recover()
    await editor.getByRole('button', { name: 'Retry' }).click()
    await expect(editor.getByRole('button', { name: 'Save categories' })).toBeEnabled()
    expect(writes).toHaveLength(0)
  })
  test('invalid image, six-item limit and explicit hide persist safely', async ({ page }) => {
    const { editor, writes } = await prepare(page, { full: true })
    await expect(editor.getByLabel('Category to add')).toBeDisabled()
    await editor.getByLabel('Image URL 1', { exact: true }).fill('javascript:alert(1)')
    await editor.getByRole('button', { name: 'Save categories' }).click()
    await expect(editor.getByRole('alert')).toContainText('HTTPS')
    expect(writes).toHaveLength(0)
    await editor.getByLabel('Image URL 1', { exact: true }).fill('')
    await editor.getByLabel('Show section in app', { exact: true }).uncheck()
    await editor.getByRole('button', { name: 'Save categories' }).click()
    await expect(editor.getByRole('status')).toContainText('Saved')
    expect(writes[0].config.enabled).toBe(false)
  })
})
