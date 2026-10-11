import { expect, test, type Locator, type Page } from '@playwright/test'
import campaign from '../public/navratri/navratri.json'
import diwaliTemplate from '../public/navratri/templates/diwali.json'
import dailyTemplate from '../public/navratri/templates/daily-essentials.json'
import templateIndex from '../public/navratri/templates/index.json'
import type { Product } from '../src/types'
import { parseCampaignConfig, type CampaignConfig } from '../src/lib/campaign-config'
import { loadEnvConfig } from '@next/env'
import { encode } from 'next-auth/jwt'

// All browser catalogue/session calls are fixtures. No cart or order mutations
// are needed to verify this campaign's integration into the real homepage.
const products: Product[] = [
  ['test-puja', 'Puja Brass Diya', 'puja-thali.svg', ['pooja', 'decor']],
  ['test-flowers', 'Marigold Flowers', 'flowers-leaves.svg', ['flowers']],
  ['test-chunri', 'Mata Chunri', 'chunri.svg', ['chunri']],
  ['test-snacks', 'Vrat Chips', 'vrat-chips.svg', ['vrat', 'snacks']],
].map(([id, name, image, tags]) => ({
  id: id as string, name: name as string, slug: id as string,
  description: null, imageUrl: `/navratri/${image}`, categoryId: null,
  mrp: 120, price: 90, discount: 25, unit: '1 piece', stock: 20,
  isAvailable: true, tags: tags as string[], restaurantId: null,
}))

async function prepareHome(page: Page, catalogue = products, published: CampaignConfig | null = null,
  detailProducts: Record<string, Product | number> = {}) {
  const catalogueRequests: string[] = []
  const detailRequests: URL[] = []
  const apiRequests: string[] = []
  const browserErrors: string[] = []
  page.on('pageerror', error => browserErrors.push(error.message))
  page.on('requestfailed', request => browserErrors.push(`${new URL(request.url()).pathname}: ${request.failure()?.errorText}`))
  await page.route('**/api/**', async route => {
    const url = new URL(route.request().url())
    const { pathname, search } = url
    apiRequests.push(`${pathname}${search}`)
    if (pathname === '/api/products') catalogueRequests.push(`${pathname}${search}`)
    let body: unknown = {}
    if (pathname === '/api/auth/session') body = null
    else if (pathname === '/api/homepage-campaign') body = { campaign: published }
    else if (pathname === '/api/products') body = { products: catalogue, total: catalogue.length }
    else if (pathname.startsWith('/api/products/')) {
      detailRequests.push(url)
      const item = detailProducts[decodeURIComponent(pathname.slice('/api/products/'.length))]
      if (!item || typeof item === 'number') {
        await route.fulfill({ status: typeof item === 'number' ? item : 404, json: { error: 'Product not found' } })
        return
      }
      body = item
    }
    else if (pathname === '/api/stores/hubs') body = { hubs: [{ id: 'navratri-test-hub', city: 'Ghatampur', latitude: 26.1534185, longitude: 80.1714024, deliveryRadiusKm: 5 }] }
    else if (['/api/banners', '/api/restaurants', '/api/categories', '/api/wishlist'].includes(pathname)) body = []
    else if (pathname === '/api/store-status') body = { grocery_mart_open: 'true', cafe_open: 'true', restaurant_open: 'true' }
    else if (pathname === '/api/cart') body = { items: [] }
    await route.fulfill({ json: body })
  })
  // A fixture hub makes the existing StorefrontClient fetch a deterministic
  // catalogue immediately instead of depending on the server's ISR inventory.
  await page.addInitScript(() => {
    localStorage.setItem('fk-location', 'Navratri Test Hub')
    localStorage.setItem('fk-store-id', 'navratri-test-hub')
    localStorage.setItem('fk-coords', JSON.stringify({ lat: 26.1534185, lng: 80.1714024 }))
    localStorage.setItem('fk-city', 'Ghatampur')
    localStorage.setItem('fk-theme', 'light')
  })
  await page.goto('/', { waitUntil: 'domcontentloaded' })
  if (published?.enabled === false) {
    await expect(page.getByTestId('navratri-section')).toHaveCount(0, { timeout: 15000 })
    return { catalogueRequests, detailRequests }
  }
  await expect(page.getByTestId('navratri-section')).toBeVisible()
  if (catalogue.length) {
    try {
      await expect(page.getByTestId('navratri-section').getByRole('tabpanel')).toContainText(catalogue[0].name, { timeout: 15000 })
    } catch (error) {
      await test.info().attach('mock-catalogue-requests', { body: JSON.stringify(catalogueRequests, null, 2), contentType: 'application/json' })
      console.info('Homepage fixture diagnostics:', JSON.stringify({ apiRequests, browserErrors }))
      throw error
    }
  }
  return { catalogueRequests, detailRequests }
}

async function visibility(page: Page, state: 'visible' | 'hidden') {
  // Headless browsers do not reliably hide a tab when another tab is selected.
  // Dispatch the browser lifecycle signal directly, while preserving handlers.
  await page.evaluate(value => {
    Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => value })
    document.dispatchEvent(new Event('visibilitychange'))
  }, state)
}

async function freezeAndRestartRotations(page: Page) {
  await page.clock.pauseAt(await page.evaluate(() => Date.now() + 1000))
  // Finish the incumbent storefront's entrance motion before measuring a
  // stationary campaign grid; then start its independent timers together.
  await page.clock.runFor(500)
  await visibility(page, 'hidden')
  await visibility(page, 'visible')
}

function headerSlides(page: Page) { return page.getByTestId('navratri-header').locator('[data-active]') }
function productSlides(page: Page) { return page.getByTestId('navratri-special').locator('a[data-active]') }
function suggestionSlides(page: Page) {
  return page.getByRole('button', { name: 'Search FastKirana products' }).locator('[data-active]')
}
async function activeIndex(slides: Locator) {
  return slides.evaluateAll(elements => elements.findIndex(element => element.getAttribute('data-active') === 'true'))
}
async function assertCardGeometryUnchanged(page: Page, before: unknown) {
  expect(await cardGeometry(page)).toEqual(before)
}
async function cardGeometry(page: Page) {
  return page.getByTestId('navratri-special').locator('..').evaluate(element =>
    [element, ...element.children].map(card => {
      const rect = card.getBoundingClientRect()
      return { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
    }))
}

test.describe('Navratri homepage campaign', () => {
  test.use({ serviceWorkers: 'block' })
  test('hydrates linked products outside the capped homepage feed and hides unavailable or missing slots', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' })
    const linkedIds = ['campaign-live-puja', 'campaign-sold-out', 'campaign-unavailable', 'campaign-deleted']
    const published = parseCampaignConfig({ ...campaign, demo: false,
      products: campaign.products.map((slot, index) => ({ ...slot, productId: linkedIds[index] })) })
    const live: Product = { ...products[0], id: linkedIds[0], slug: linkedIds[0],
      name: 'Live Puja Thali Outside Homepage Feed', imageUrl: '/navratri/chunri.svg', price: 180, mrp: 240, stock: 7 }
    const { catalogueRequests, detailRequests } = await prepareHome(page, products, published, {
      [linkedIds[0]]: live,
      [linkedIds[1]]: { ...live, id: linkedIds[1], name: 'Sold Out Campaign Product', stock: 0 },
      [linkedIds[2]]: { ...live, id: linkedIds[2], name: 'Unavailable Campaign Product', isAvailable: false },
      [linkedIds[3]]: 404,
    })
    const special = page.getByTestId('navratri-special')
    const promotion = special.getByRole('link', { name: `Explore ${live.name}`, exact: true })
    await expect(promotion).toBeVisible({ timeout: 15000 })
    await expect(special.locator('a[data-active]')).toHaveCount(1)
    await expect(promotion.locator('strong')).toHaveText('₹180')
    await expect(promotion.locator('del')).toHaveText('₹240')
    await expect(promotion.locator('img')).toHaveAttribute('src', live.imageUrl!)
    await expect.poll(() => promotion.locator('img').evaluate(image =>
      (image as HTMLImageElement).complete && (image as HTMLImageElement).naturalWidth > 0)).toBe(true)
    const destination = published.destinations.find(item => item.id === published.products[0].destinationId)!
    await expect(promotion).toHaveAttribute('href', `/search?q=${encodeURIComponent(destination.query)}`)
    await expect(special).not.toContainText('Sold Out Campaign Product')
    await expect(special).not.toContainText('Unavailable Campaign Product')
    await expect(special).not.toContainText('Demo prices')
    expect(products.some(product => linkedIds.includes(product.id))).toBe(false)
    expect(catalogueRequests.some(request => new URL(request, page.url()).searchParams.get('limit') === '500')).toBe(true)
    for (const id of linkedIds) {
      expect(detailRequests.some(url => url.pathname === `/api/products/${id}` &&
        url.searchParams.get('storeId') === 'navratri-test-hub'), `linked detail read is scoped: ${id}`).toBe(true)
    }
  })

  for (const width of [320, 390, 1280]) {
    test(`keeps the three-column composition and unclipped content at ${width}px`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 })
      await page.emulateMedia({ reducedMotion: 'reduce' })
      await prepareHome(page)
      const special = page.getByTestId('navratri-special')
      const grid = special.locator('..')
      const cards = await grid.locator(':scope > *').evaluateAll(elements => elements.map(element => {
        const rect = element.getBoundingClientRect()
        return { x: rect.x, y: rect.y, width: rect.width, height: rect.height, right: rect.right, bottom: rect.bottom }
      }))
      expect(cards).toHaveLength(5)
      const [tall, puja, cooking, dandiya, snacks] = cards
      expect(tall.width).toBeCloseTo(puja.width, 0)
      expect(tall.width).toBeCloseTo(cooking.width, 0)
      expect(tall.y).toBeCloseTo(puja.y, 0)
      expect(tall.y).toBeCloseTo(cooking.y, 0)
      expect(dandiya.x).toBeCloseTo(puja.x, 0)
      expect(snacks.x).toBeCloseTo(cooking.x, 0)
      expect(dandiya.y).toBeCloseTo(snacks.y, 0)
      expect(tall.bottom).toBeCloseTo(snacks.bottom, 0)
      expect(tall.height).toBeCloseTo(puja.height + dandiya.height + dandiya.y - puja.bottom, 0)
      expect(tall.x).toBeGreaterThanOrEqual(12)
      expect(snacks.right).toBeLessThanOrEqual(width - 12)
      expect(puja.x - tall.right).toBeCloseTo(width < 700 ? 8 : 12, 0)
      if (width === 390) {
        expect(tall.height).toBeGreaterThanOrEqual(220)
        expect(tall.height).toBeLessThanOrEqual(250)
        expect((await page.getByTestId('navratri-header').boundingBox())?.height).toBe(100)
      }
      const clipped = await page.getByTestId('navratri-section').locator('h2, h3, a[data-active="true"], [role="tab"]').evaluateAll(elements =>
        elements.filter(element => {
          const style = getComputedStyle(element)
          // Tight display type can paint a few stroke/descender pixels outside
          // its line box. That is visible ink, not clipped content.
          return element.scrollWidth > element.clientWidth + 3 ||
            (['hidden', 'clip'].includes(style.overflowY) && element.scrollHeight > element.clientHeight + 1)
        })
          .map(element => element.textContent?.trim()))
      expect(clipped, 'campaign text fits its containers').toEqual([])
      const overflowingHeader = await page.getByTestId('navratri-header').evaluate(header => {
        const stage = header.getBoundingClientRect()
        return [...header.querySelectorAll('[data-active] > div')].filter(copy => {
          const rect = copy.getBoundingClientRect()
          return rect.top < stage.top - 1 || rect.bottom > stage.bottom + 1 || rect.left < stage.left - 1 || rect.right > stage.right + 1
        }).map(copy => copy.textContent)
      })
      expect(overflowingHeader, 'all header copy stays within its reserved stage').toEqual([])
      await expect(special).toHaveCSS('background-color', 'rgb(255, 248, 223)')
      await expect(grid.locator('..')).toHaveCSS('background-color', 'rgb(255, 131, 31)')
      await expect.poll(() => page.getByTestId('navratri-section').locator('img').evaluateAll(images =>
        images.every(image => (image as HTMLImageElement).complete && (image as HTMLImageElement).naturalWidth > 0))).toBe(true)
      const assets = await page.getByTestId('navratri-section').locator('img').evaluateAll(images =>
        images.map(image => ({ src: image.getAttribute('src'), complete: (image as HTMLImageElement).complete, width: (image as HTMLImageElement).naturalWidth })))
      expect(assets.length).toBeGreaterThan(10)
      for (const asset of assets) {
        const url = new URL(asset.src!, page.url())
        expect(url.origin).toBe(new URL(page.url()).origin)
        expect(url.pathname).toMatch(/^\/navratri\/.+\.svg$/)
        expect(asset.complete && asset.width > 0, `asset loads: ${asset.src}`).toBe(true)
      }
      if (width === 390 || width === 1280) {
        await page.screenshot({ path: `artifacts/navratri/storefront-${width === 390 ? 'mobile' : 'desktop'}.png`, fullPage: false })
      }
    })
  }

  test('rotates product, search suggestion and header on independent schedules without moving the grid', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 900 })
    await page.clock.install()
    await prepareHome(page)
    await freezeAndRestartRotations(page)
    const headers = headerSlides(page)
    const specials = productSlides(page)
    const suggestions = suggestionSlides(page)
    const initialHeader = await activeIndex(headers)
    const initialProduct = await activeIndex(specials)
    const initialSuggestion = await activeIndex(suggestions)
    const geometry = await cardGeometry(page)
    await page.clock.runFor(2499)
    expect(await activeIndex(specials)).toBe(initialProduct)
    expect(await activeIndex(headers)).toBe(initialHeader)
    await page.clock.runFor(1)
    expect(await activeIndex(specials)).toBe((initialProduct + 1) % campaign.products.length)
    expect(await activeIndex(headers)).toBe(initialHeader)
    expect(await activeIndex(suggestions)).toBe(initialSuggestion)
    const nextProduct = campaign.products[(initialProduct + 1) % campaign.products.length]
    const activeSpecial = specials.locator('xpath=self::*[@data-active="true"]')
    await expect(activeSpecial).toContainText(nextProduct.name)
    await expect(activeSpecial.locator('del')).toHaveText(`₹${nextProduct.originalPrice}`)
    await expect(activeSpecial.locator('strong')).toHaveText(`₹${nextProduct.price}`)
    await expect(activeSpecial.locator('img')).toHaveAttribute('src', `/navratri/${nextProduct.image}`)
    // Image, both prices and name share one transitioned link rather than
    // running separate timers or changing the stationary heading/card.
    await expect(activeSpecial).toHaveCSS('transition-duration', '0.4s')
    await page.clock.runFor(500)
    expect(await activeIndex(suggestions)).toBe((initialSuggestion + 1) % campaign.searchSuggestions.length)
    expect(await activeIndex(headers)).toBe(initialHeader)
    await page.clock.runFor(999)
    expect(await activeIndex(headers)).toBe(initialHeader)
    await page.clock.runFor(1)
    expect(await activeIndex(headers)).toBe((initialHeader + 1) % campaign.headers.length)
    await expect(headers.locator('xpath=self::*[@data-active="true"]')).toHaveCSS('transition-duration', '0.4s')
    await page.clock.runFor(400)
    await expect(headers.locator('xpath=self::*[@data-active="true"]')).toHaveCSS('opacity', '1')
    await expect(specials.locator('xpath=self::*[@data-active="true"]')).toHaveCSS('opacity', '1')
    await assertCardGeometryUnchanged(page, geometry)
    await expect(page.getByTestId('navratri-special').getByRole('heading')).toHaveText('Navratri Specials')
  })

  test('pauses for browser visibility, the pause control, and keyboard focus, then resumes', async ({ page }) => {
    await page.clock.install()
    await prepareHome(page)
    await freezeAndRestartRotations(page)
    const headers = headerSlides(page)
    const specials = productSlides(page)
    const before = [await activeIndex(headers), await activeIndex(specials)]
    await visibility(page, 'hidden')
    await page.clock.fastForward(10000)
    expect([await activeIndex(headers), await activeIndex(specials)]).toEqual(before)
    await visibility(page, 'visible')
    await page.clock.runFor(2500)
    expect(await activeIndex(specials)).toBe((before[1] + 1) % campaign.products.length)
    await page.getByRole('button', { name: 'Pause campaign animations' }).click()
    const paused = [await activeIndex(headers), await activeIndex(specials)]
    await page.clock.fastForward(10000)
    expect([await activeIndex(headers), await activeIndex(specials)]).toEqual(paused)
    await expect(page.getByRole('button', { name: 'Play campaign animations' })).toHaveAttribute('aria-pressed', 'true')
    await page.getByRole('button', { name: 'Play campaign animations' }).click()
    await page.clock.runFor(2500)
    expect(await activeIndex(specials)).toBe((paused[1] + 1) % campaign.products.length)
    await specials.locator('xpath=self::*[@data-active="true"]').focus()
    const focused = [await activeIndex(headers), await activeIndex(specials)]
    await page.clock.fastForward(8000)
    expect([await activeIndex(headers), await activeIndex(specials)]).toEqual(focused)
    await page.getByRole('button', { name: 'Pause campaign animations' }).focus()
    await page.clock.runFor(4000)
    expect(await activeIndex(headers)).toBe((focused[0] + 1) % campaign.headers.length)
  })

  test('all category and rotating product destinations use the existing catalogue search route', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' })
    await prepareHome(page)
    const section = page.getByTestId('navratri-section')
    for (const category of campaign.categories) {
      const destination = campaign.destinations.find(item => item.id === category.destinationId)!
      await expect(section.getByRole('link', { name: `Shop ${category.label}` })).toHaveAttribute('href', `/search?q=${encodeURIComponent(destination.query)}`)
    }
    const specials = productSlides(page)
    await expect(specials).toHaveCount(campaign.products.length)
    for (let i = 0; i < campaign.products.length; i++) {
      const product = campaign.products[i]
      const destination = campaign.destinations.find(item => item.id === product.destinationId)!
      await expect(specials.nth(i)).toHaveAttribute('href', `/search?q=${encodeURIComponent(destination.query)}`)
      await expect(specials.nth(i)).toHaveAttribute('aria-hidden', i === 0 ? 'false' : 'true')
      await expect(specials.nth(i)).toHaveAttribute('tabindex', i === 0 ? '0' : '-1')
      if (i !== 0) await expect(specials.nth(i)).toHaveAttribute('inert', '')
    }
    await expect(section.getByText('Demo prices', { exact: true })).toBeVisible()
    await section.getByRole('link', { name: 'Shop Puja Needs' }).click()
    await expect(page).toHaveURL(/\/search\?q=puja$/, { timeout: 25000 })
    await expect(page.getByRole('heading', { name: /puja/i }).first()).toBeVisible()
  })

  test('collection tabs support arrow, Home and End keys and filter the existing product cards', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' })
    await prepareHome(page)
    const collection = page.getByRole('tablist', { name: `${campaign.labels.sectionLabel} collections` })
    const panel = page.getByTestId('navratri-section').getByRole('tabpanel')
    const tabs = collection.getByRole('tab')
    await expect(tabs).toHaveCount(4)
    await tabs.nth(0).focus()
    await page.keyboard.press('ArrowRight')
    await expect(tabs.nth(1)).toBeFocused()
    await expect(tabs.nth(1)).toHaveAttribute('aria-selected', 'true')
    await expect(panel).toContainText('Puja Brass Diya')
    await expect(panel).not.toContainText('Marigold Flowers')
    await expect(panel).not.toContainText('Mata Chunri')
    await page.keyboard.press('ArrowRight')
    await expect(tabs.nth(2)).toBeFocused()
    await expect(panel).toContainText('Marigold Flowers')
    await expect(panel).not.toContainText('Puja Brass Diya')
    await page.keyboard.press('End')
    await expect(tabs.nth(3)).toBeFocused()
    await expect(panel).toContainText('Mata Chunri')
    await expect(panel).not.toContainText('Marigold Flowers')
    await page.keyboard.press('ArrowRight')
    await expect(tabs.nth(0)).toBeFocused()
    await expect(panel).toContainText('Vrat Chips')
    await page.keyboard.press('ArrowLeft')
    await expect(tabs.nth(3)).toBeFocused()
    await page.keyboard.press('Home')
    await expect(tabs.nth(0)).toBeFocused()
    await expect(tabs.nth(0)).toHaveAttribute('aria-selected', 'true')
    for (let i = 1; i < 4; i++) await expect(tabs.nth(i)).toHaveAttribute('tabindex', '-1')
    await expect(panel).toHaveAttribute('aria-labelledby', (await tabs.nth(0).getAttribute('id'))!)
  })

  test('reduced motion is static, removes transitions, and responds to preference changes', async ({ page }) => {
    await page.clock.install()
    await page.emulateMedia({ reducedMotion: 'reduce' })
    await prepareHome(page)
    await freezeAndRestartRotations(page)
    const headers = headerSlides(page)
    const specials = productSlides(page)
    const suggestions = suggestionSlides(page)
    await page.clock.fastForward(12000)
    expect([await activeIndex(headers), await activeIndex(specials), await activeIndex(suggestions)]).toEqual([0, 0, 0])
    await expect(headers.first()).toHaveCSS('transition-duration', '0s')
    await expect(specials.first()).toHaveCSS('transition-duration', '0s')
    expect(await suggestions.first().evaluate(element => {
      const transform = getComputedStyle(element).transform
      return transform === 'none' || new DOMMatrixReadOnly(transform).isIdentity
    })).toBe(true)
    await page.emulateMedia({ reducedMotion: 'no-preference' })
    // MediaQueryList change is delivered on the next rendering frame; let it
    // start autoplay before measuring the product's full 2500ms interval.
    await page.clock.runFor(32)
    await page.clock.runFor(2500)
    expect(await activeIndex(specials)).toBe(1)
  })

  test('search stays pinned while scrolling, department row is absent, and the existing overlay submits a query', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 750 })
    await page.emulateMedia({ reducedMotion: 'reduce' })
    await prepareHome(page)
    await page.evaluate(() => window.scrollTo({ top: 600, behavior: 'instant' }))
    const search = page.getByRole('button', { name: 'Search FastKirana products' })
    await expect(page.getByRole('navigation', { name: 'Shop departments' })).toHaveCount(0)
    await expect(page.getByRole('button', { name: /^(Fresh|Fashion|Mobiles|Pharmacy)$/ })).toHaveCount(0)
    await expect(search).toBeVisible()
    await expect(page.locator('[data-site-navbar]')).toHaveCSS('position', 'fixed')
    const searchRect = await search.boundingBox()
    expect(searchRect?.y).toBeGreaterThanOrEqual(0)
    expect((searchRect?.y ?? 750) + (searchRect?.height ?? 0)).toBeLessThan(150)
    await search.click()
    const input = page.getByPlaceholder('Search for groceries, brands...')
    await expect(input).toBeVisible()
    await input.fill('puja')
    await input.press('Enter')
    await expect(page).toHaveURL(/\/search\?q=puja$/, { timeout: 25000 })
  })

  test('published generic campaign metadata controls copy, colors, decoration and autoplay on the storefront', async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 900 })
    await page.clock.install()
    const published = parseCampaignConfig({ ...campaign, autoplay: false, searchPrefix: 'Find',
      decorationImage: null, searchSuggestions: ['Diyas', 'Sweets'],
      labels: { ...parseCampaignConfig(campaign).labels, sectionLabel: 'Celebrate Diwali', specialsHeading: 'Diwali Specials', curvedTabLabel: 'Festive Picks' },
      appearance: { ...parseCampaignConfig(campaign).appearance, background: '#A14413' },
    })
    await prepareHome(page, [], published)
    const section = page.getByTestId('navratri-section')
    await expect(section).toHaveAttribute('aria-label', 'Celebrate Diwali')
    await expect(page.getByTestId('navratri-special').getByRole('heading')).toHaveText('Diwali Specials')
    await expect(page.getByTestId('navratri-special').locator('../..')).toHaveCSS('background-color', 'rgb(161, 68, 19)')
    await expect(section.locator('img[src="/navratri/string-lights.svg"]')).toHaveCount(0)
    const search = page.getByRole('button', { name: 'Search FastKirana products' })
    await expect(search).toContainText('Find')
    await expect(search.locator('[data-active="true"]')).toHaveText('Diyas')
    await freezeAndRestartRotations(page)
    await page.clock.fastForward(12000)
    expect([await activeIndex(headerSlides(page)), await activeIndex(productSlides(page)), await activeIndex(suggestionSlides(page))]).toEqual([0, 0, 0])
  })

  test('renders the Daily Essentials template with its grid layout, artwork and searchable collections', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 900 })
    await page.emulateMedia({ reducedMotion: 'reduce' })
    const published = parseCampaignConfig(dailyTemplate)
    await prepareHome(page, [], published)
    const section = page.getByTestId('navratri-section')
    await expect(section).toHaveAttribute('aria-label', published.labels.sectionLabel)
    await expect(section).toHaveAttribute('data-layout', 'grid')
    await expect(section).toHaveCSS('--festival-orange', published.appearance.background)
    await expect(page.getByTestId('navratri-special').getByRole('heading')).toHaveText(published.labels.specialsHeading)
    await expect(headerSlides(page).locator('xpath=self::*[@data-active="true"]')).toContainText(published.headers[0].title)
    await expect(section.getByRole('tab')).toHaveCount(published.tabs.length)
    await expect(page.getByRole('button', { name: 'Search FastKirana products' }).locator('[data-active="true"]')).toHaveText(published.searchSuggestions[0])
    for (const category of published.categories) {
      const destination = published.destinations.find(item => item.id === category.destinationId)!
      await expect(section.getByRole('link', { name: `Shop ${category.label}`, exact: true })).toHaveAttribute('href', `/search?q=${encodeURIComponent(destination.query)}`)
    }
    await expect.poll(() => section.locator('img').evaluateAll(images =>
      images.every(image => (image as HTMLImageElement).complete && (image as HTMLImageElement).naturalWidth > 0))).toBe(true)
    const artwork = await section.locator('img').evaluateAll(images => images.map(image => image.getAttribute('src')))
    expect(artwork).toContain('/navratri/daily-grocery-basket.svg')
    expect(artwork).toContain('/navratri/daily-milk.svg')
    expect(artwork).not.toContain('/navratri/navratri-festive.svg')
    const boxes = await Promise.all(published.categories.map(category =>
      section.getByRole('link', { name: `Shop ${category.label}`, exact: true }).boundingBox()))
    expect(boxes.every(box => box !== null)).toBe(true)
    const [first, second, third, fourth] = boxes.map(box => box!)
    expect(first.y).toBeCloseTo(second.y, 0)
    expect(third.y).toBeCloseTo(fourth.y, 0)
    expect(first.x).toBeCloseTo(third.x, 0)
    expect(second.x).toBeCloseTo(fourth.x, 0)
    for (const box of [second, third, fourth]) {
      expect(box.width).toBeCloseTo(first.width, 0)
      expect(box.height).toBeCloseTo(first.height, 0)
    }
    const promotion = await section.getByTestId('navratri-special').boundingBox()
    expect(promotion?.y).toBeGreaterThanOrEqual(fourth.y + fourth.height)
    await page.screenshot({ path: 'artifacts/campaign-templates/daily-desktop.png', fullPage: false })
  })

  test('a disabled published campaign hides the festive section while the storefront remains available', async ({ page }) => {
    await prepareHome(page, products, parseCampaignConfig({ ...campaign, enabled: false }))
    await expect(page.getByTestId('navratri-section')).toHaveCount(0)
    await expect(page.getByRole('tab', { name: /Grocery$/ })).toBeVisible()
    await expect(page.getByRole('tab', { name: /Food$/ })).toBeVisible()
    await expect(page.getByRole('navigation', { name: 'Shop departments' })).toHaveCount(0)
  })

  test('unmounting the campaign clears its interval timers', async ({ page }) => {
    await page.clock.install()
    await prepareHome(page)
    await page.evaluate(() => {
      const intervals = new Map<number, number>()
      const originalSet = window.setInterval.bind(window)
      const originalClear = window.clearInterval.bind(window)
      window.setInterval = ((handler: TimerHandler, delay?: number, ...args: unknown[]) => {
        const id = originalSet(handler, delay, ...args)
        intervals.set(id, delay ?? 0)
        return id
      }) as typeof window.setInterval
      window.clearInterval = ((id?: any) => { if (id !== undefined) intervals.delete(id); originalClear(id) }) as typeof window.clearInterval
      Object.defineProperty(window, '__navratriTestIntervals', { value: intervals })
    })
    await freezeAndRestartRotations(page)
    const activeCampaignIntervals = (ids?: number[]) => page.evaluate(selectedIds => {
      const intervals = (window as unknown as { __navratriTestIntervals: Map<number, number> }).__navratriTestIntervals
      return [...intervals.entries()].filter(([id, delay]) => (!selectedIds || selectedIds.includes(id)) && (delay === 2500 || delay === 4000)).map(([, delay]) => delay).sort()
    }, ids)
    expect(await activeCampaignIntervals()).toEqual([2500, 4000])
    const initialIntervalIds = await page.evaluate(() => {
      const intervals = (window as unknown as { __navratriTestIntervals: Map<number, number> }).__navratriTestIntervals
      return [...intervals.entries()].filter(([, delay]) => delay === 2500 || delay === 4000).map(([id]) => id)
    })
    await page.getByRole('tab', { name: /Food$/ }).click()
    await page.clock.runFor(800)
    await expect(page.getByTestId('navratri-section')).toHaveCount(0)
    expect(await activeCampaignIntervals(initialIntervalIds)).toEqual([])
    await page.getByRole('tab', { name: /Grocery$/ }).click()
    await page.clock.runFor(800)
    await expect(page.getByTestId('navratri-section')).toBeVisible()
    expect(await activeCampaignIntervals(initialIntervalIds)).toEqual([])
    expect(await activeCampaignIntervals()).toContain(4000)
    const freshProduct = await activeIndex(productSlides(page))
    await page.clock.runFor(2500)
    expect(await activeIndex(productSlides(page))).toBe((freshProduct + 1) % campaign.products.length)
  })
})

type CampaignMutation = { action: 'save-draft' | 'publish' | 'disable'; storeId?: string; campaign: CampaignConfig }

async function prepareCampaignManager(page: Page, catalogue: Product[] = [], storeId = 'all') {
  // This session is signed only for the local test server. The token contains
  // no user ID, so the legacy dashboard does not query a real admin account.
  loadEnvConfig(process.cwd())
  const secret = process.env.AUTH_SECRET || process.env.NEXTAUTH_SECRET
  test.skip(!secret, 'Local AUTH_SECRET is required to render the protected admin dashboard')
  const sessionToken = await encode({ secret: secret!, salt: 'authjs.session-token',
    token: { name: 'Campaign Test Admin', email: 'superadmin@fastkirana.com', role: 'ADMIN' }, maxAge: 3600 })
  await page.context().addCookies([{ name: 'authjs.session-token', value: sessionToken,
    url: 'http://localhost:3000', httpOnly: true, sameSite: 'Lax' }])
  let draft = parseCampaignConfig(campaign)
  let published = parseCampaignConfig(campaign)
  let dashboardHydrated = false
  const mutations: CampaignMutation[] = []
  const catalogueRequests: URL[] = []
  await page.context().route('**/api/**', async route => {
    const url = new URL(route.request().url())
    const pathname = url.pathname
    let body: unknown = {}
    if (pathname === '/api/auth/session') body = { user: { name: 'Campaign Test Admin', email: 'superadmin@fastkirana.com', role: 'ADMIN' }, expires: '2099-01-01T00:00:00.000Z' }
    else if (pathname === '/api/admin/campaign') {
      if (route.request().method() === 'PUT') {
        const payload = route.request().postDataJSON() as CampaignMutation
        mutations.push(structuredClone(payload))
        if (payload.action === 'save-draft') draft = parseCampaignConfig(payload.campaign)
        if (payload.action === 'publish') { draft = parseCampaignConfig(payload.campaign); published = draft }
        if (payload.action === 'disable') published = { ...published, enabled: false }
        body = { success: true, draft, published }
      } else body = { draft, published }
    } else if (pathname === '/api/homepage-campaign') body = { campaign: published }
    else if (pathname === '/api/admin/products' || pathname === '/api/products') {
      if (pathname === '/api/admin/products') catalogueRequests.push(url)
      body = { products: catalogue, total: catalogue.length }
    }
    else if (pathname === '/api/admin/orders') { dashboardHydrated = true; body = { orders: [], total: 0, totalPages: 1, stats: {} } }
    else if (pathname === '/api/admin/users') body = { users: [], total: 0 }
    else if (pathname === '/api/stores/hubs') body = { hubs: [] }
    else if (['/api/admin/stores', '/api/banners', '/api/restaurants', '/api/categories', '/api/admin/categories', '/api/admin/reviews', '/api/admin/coupons'].includes(pathname)) body = []
    else if (pathname === '/api/store-status') body = { grocery_mart_open: 'true', cafe_open: 'true', restaurant_open: 'true' }
    await route.fulfill({ json: body })
  })
  await page.addInitScript(() => localStorage.setItem('push-prompt-dismissed', 'true'))
  await page.setViewportSize({ width: 1280, height: 1000 })
  await page.goto(`/admin?storeId=${encodeURIComponent(storeId)}`, { waitUntil: 'domcontentloaded', timeout: 90000 })
  await expect.poll(() => dashboardHydrated, { timeout: 25000 }).toBe(true)
  await page.getByRole('button', { name: /Marketing/ }).click()
  await page.getByRole('button', { name: 'Campaign Manager', exact: true }).click()
  const manager = page.getByTestId('campaign-manager')
  await expect(manager).toBeVisible({ timeout: 20000 })
  await expect(manager.getByRole('button', { name: 'Save Draft', exact: true })).toBeEnabled({ timeout: 20000 })
  // Capture the actual viewport with the manager below the fixed site navbar.
  // A tall element screenshot moves fixed chrome through the form as it scrolls.
  await manager.evaluate(element => window.scrollTo({ top: window.scrollY + element.getBoundingClientRect().top - 100, behavior: 'instant' }))
  await expect(manager.locator('..')).toHaveCSS('opacity', '1')
  await page.screenshot({ path: 'artifacts/navratri/campaign-manager.png', fullPage: false })
  return { manager, mutations, catalogueRequests, published: () => published, draft: () => draft }
}

test.describe('Generic admin campaign editor', () => {
  test.use({ serviceWorkers: 'block' })
  test.setTimeout(120000)

  test('selects campaign types without changing edits; explicit replacement saves a private Diwali draft and publishes it after reload', async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' })
    const preset = parseCampaignConfig(diwaliTemplate)
    const { manager, mutations, draft, published } = await prepareCampaignManager(page)
    const picker = manager.getByRole('combobox', { name: 'Campaign template', exact: true })
    await expect(picker).toHaveValue('navratri')
    await expect(picker.locator('option')).toHaveCount(templateIndex.length)
    for (const template of templateIndex) {
      await expect(picker.locator(`option[value="${template.id}"]`)).toHaveText(template.name)
    }
    const heading = manager.getByRole('textbox', { name: 'Tall card heading', exact: true })
    await heading.fill('My unsaved campaign')
    await picker.selectOption('diwali')
    await expect(heading).toHaveValue('My unsaved campaign')
    await expect(manager.getByTestId('campaign-preview').getByTestId('navratri-special').locator('h3')).toHaveText('My unsaved campaign')
    expect(mutations).toHaveLength(0)
    await manager.getByRole('button', { name: 'Load template', exact: true }).click()
    await expect(manager.getByRole('alert')).toContainText('Loading Diwali will replace your unsaved edits.')
    await manager.getByRole('button', { name: 'Cancel template change', exact: true }).click()
    await expect(heading).toHaveValue('My unsaved campaign')
    await expect(manager.getByRole('button', { name: 'Replace current draft', exact: true })).toHaveCount(0)
    await manager.getByRole('button', { name: 'Load template', exact: true }).click()
    await manager.getByRole('button', { name: 'Replace current draft', exact: true }).click()
    await expect(manager.getByRole('status')).toContainText('Diwali template loaded.')
    await expect(heading).toHaveValue(preset.labels.specialsHeading)
    await expect(manager.getByRole('textbox', { name: 'Campaign name', exact: true })).toHaveValue(preset.labels.sectionLabel)
    const preview = manager.getByTestId('campaign-preview')
    await expect(preview).toHaveAttribute('inert', '')
    await expect(preview.getByTestId('navratri-section')).toHaveAttribute('data-layout', 'classic')
    await expect(preview.getByTestId('navratri-header').locator('[data-active="true"]')).toContainText(preset.headers[0].title)
    await expect.poll(() => preview.locator('img').evaluateAll(images =>
      images.every(image => (image as HTMLImageElement).complete && (image as HTMLImageElement).naturalWidth > 0))).toBe(true)
    expect(published().labels.specialsHeading).toBe(campaign.labels.specialsHeading)
    expect(mutations).toHaveLength(0)
    await manager.evaluate(element => window.scrollTo({ top: window.scrollY + element.getBoundingClientRect().top - 100, behavior: 'instant' }))
    await page.screenshot({ path: 'artifacts/campaign-templates/diwali-manager.png', fullPage: false })

    await heading.fill('Diwali Weekend Picks')
    await page.setViewportSize({ width: 1280, height: 1400 })
    const layout = manager.getByRole('combobox', { name: 'Campaign layout', exact: true })
    for (const value of ['split', 'grid', 'banner', 'deals', 'classic']) {
      await layout.selectOption(value)
      await expect(heading).toHaveValue('Diwali Weekend Picks')
      await expect(preview.getByTestId('navratri-section')).toHaveAttribute('data-layout', value)
      await expect(preview.getByTestId('navratri-header').locator('[data-active="true"]')).toContainText(preset.headers[0].title)
      await expect(preview.getByTestId('navratri-special').locator('a[data-active="true"]')).toContainText(preset.products[0].name)
      await expect.poll(() => preview.locator('img').evaluateAll(images =>
        images.every(image => (image as HTMLImageElement).complete && (image as HTMLImageElement).naturalWidth > 0))).toBe(true)
      await preview.screenshot({ path: `artifacts/campaign-templates/layout-${value}.png`, animations: 'disabled' })
    }
    await page.setViewportSize({ width: 1280, height: 1000 })
    await manager.getByRole('button', { name: 'Save Draft', exact: true }).click()
    await expect(manager.getByRole('status')).toContainText('Draft saved. Customers still see the published campaign.')
    expect(mutations).toHaveLength(1)
    expect(mutations[0].action).toBe('save-draft')
    expect(draft()).toEqual({ ...preset, labels: { ...preset.labels, specialsHeading: 'Diwali Weekend Picks' } })
    expect(published().labels.specialsHeading).toBe(campaign.labels.specialsHeading)
    const shopper = await page.context().newPage()
    try {
      await shopper.setViewportSize({ width: 390, height: 900 })
      await shopper.emulateMedia({ reducedMotion: 'reduce' })
      await shopper.goto('/', { waitUntil: 'domcontentloaded' })
      await expect(shopper.getByTestId('navratri-special').getByRole('heading')).toHaveText(campaign.labels.specialsHeading, { timeout: 15000 })
      await page.getByRole('button', { name: 'Offers', exact: true }).click()
      await expect(manager).toHaveCount(0)
      await page.getByRole('button', { name: 'Campaign Manager', exact: true }).click()
      await expect(manager.getByRole('button', { name: 'Save Draft', exact: true })).toBeEnabled()
      await expect(heading).toHaveValue('Diwali Weekend Picks')
      await manager.getByRole('button', { name: 'Publish', exact: true }).click()
      await expect(manager.getByRole('status')).toContainText('Campaign published. Both apps will load this configuration.')
      expect(mutations).toHaveLength(2)
      expect(mutations[1].action).toBe('publish')
      expect(published()).toEqual(draft())
      await shopper.reload({ waitUntil: 'domcontentloaded' })
      const liveSection = shopper.getByTestId('navratri-section')
      await expect(liveSection).toHaveAttribute('aria-label', preset.labels.sectionLabel)
      await expect(liveSection).toHaveAttribute('data-layout', 'classic')
      await expect(shopper.getByTestId('navratri-special').getByRole('heading')).toHaveText('Diwali Weekend Picks')
      await expect(liveSection).toHaveCSS('--festival-orange', preset.appearance.background)
      await expect.poll(() => liveSection.locator('img').evaluateAll(images =>
        images.every(image => (image as HTMLImageElement).complete && (image as HTMLImageElement).naturalWidth > 0))).toBe(true)
      await shopper.screenshot({ path: 'artifacts/campaign-templates/diwali-mobile.png', fullPage: false })
    } finally { await shopper.close() }
  })

  test('edits copy, imagery, timings and ordering; draft stays private until publish, then hide retains the draft', async ({ page }) => {
    const { manager, mutations, published, draft } = await prepareCampaignManager(page)
    await manager.getByRole('textbox', { name: 'Tall card heading', exact: true }).fill('Diwali Specials')
    await manager.getByRole('textbox', { name: 'Campaign name', exact: true }).fill('Celebrate Diwali')
    await manager.locator('summary').filter({ hasText: 'Header slides' }).click()
    await manager.getByRole('textbox', { name: 'Slide 1 title', exact: true }).fill('Diwali, together')
    await manager.getByRole('textbox', { name: 'Slide 1 image', exact: true }).fill('fastkirana-basket.svg')
    await manager.getByRole('button', { name: 'Move Slide 1 down', exact: true }).click()
    await expect(manager.getByRole('textbox', { name: 'Slide 2 title', exact: true })).toHaveValue('Diwali, together')
    await manager.locator('summary').filter({ hasText: 'Colours, artwork & motion' }).click()
    await manager.getByRole('spinbutton', { name: 'Header interval (milliseconds)', exact: true }).fill('5000')
    await expect(manager.getByTestId('campaign-preview')).toHaveAttribute('inert', '')
    await manager.getByRole('button', { name: 'Save Draft', exact: true }).click()
    await expect(manager.getByRole('status')).toContainText('Draft saved. Customers still see the published campaign.')
    expect(mutations).toHaveLength(1)
    expect(mutations[0].action).toBe('save-draft')
    expect(mutations[0]).not.toHaveProperty('storeId')
    expect(draft().labels.specialsHeading).toBe('Diwali Specials')
    expect(draft().headers[0].id).toBe(campaign.headers[1].id)
    expect(draft().headers[1].image).toBe('fastkirana-basket.svg')
    expect(draft().timings.headerMs).toBe(5000)
    expect(published().labels.specialsHeading).toBe('Navratri Specials')
    const shopper = await page.context().newPage()
    try {
      await shopper.goto('/', { waitUntil: 'domcontentloaded' })
      await expect(shopper.getByTestId('navratri-special').getByRole('heading')).toHaveText('Navratri Specials', { timeout: 15000 })
      await manager.getByRole('button', { name: 'Publish', exact: true }).click()
      await expect(manager.getByRole('status')).toContainText('Campaign published. Both apps will load this configuration.')
      expect(mutations[1].action).toBe('publish')
      await shopper.reload({ waitUntil: 'domcontentloaded' })
      await expect(shopper.getByTestId('navratri-special').getByRole('heading')).toHaveText('Diwali Specials', { timeout: 15000 })
      await manager.getByRole('button', { name: 'Hide Campaign', exact: true }).click()
      await expect(manager.getByRole('status')).toContainText('Campaign hidden. Your draft is retained.')
      expect(mutations[2].action).toBe('disable')
      expect(published().enabled).toBe(false)
      expect(draft().labels.specialsHeading).toBe('Diwali Specials')
      await shopper.reload({ waitUntil: 'domcontentloaded' })
      await expect(shopper.getByTestId('navratri-section')).toHaveCount(0, { timeout: 15000 })
    } finally { await shopper.close() }
  })

  test('invalid copy, timing and image values show validation errors without issuing a mutation', async ({ page }) => {
    const { manager, mutations } = await prepareCampaignManager(page)
    const heading = manager.getByRole('textbox', { name: 'Tall card heading', exact: true })
    await heading.fill('')
    await manager.getByRole('button', { name: 'Save Draft', exact: true }).click()
    await expect(manager.getByRole('alert')).toContainText('specialsHeading')
    expect(mutations).toHaveLength(0)
    await heading.fill('Navratri Specials')
    await manager.locator('summary').filter({ hasText: 'Colours, artwork & motion' }).click()
    await manager.getByRole('spinbutton', { name: 'Header interval (milliseconds)', exact: true }).fill('500')
    await manager.getByRole('button', { name: 'Publish', exact: true }).click()
    await expect(manager.getByRole('alert')).toContainText('headerMs')
    expect(mutations).toHaveLength(0)
    await manager.getByRole('spinbutton', { name: 'Header interval (milliseconds)', exact: true }).fill('4000')
    await manager.locator('summary').filter({ hasText: 'Header slides' }).click()
    await manager.getByRole('textbox', { name: 'Slide 1 image', exact: true }).fill('javascript:alert(1)')
    await manager.getByRole('button', { name: 'Save Draft', exact: true }).click()
    await expect(manager.getByRole('alert')).toContainText('Choose a local image or an HTTPS image URL')
    expect(mutations).toHaveLength(0)
    const preview = manager.getByTestId('campaign-preview')
    await expect(preview).toHaveAttribute('inert', '')
    await preview.locator('a').first().focus()
    await expect(preview.locator('a').first()).not.toBeFocused()
  })

  test('links the scoped grocery catalogue and preserves typed keyword commas and suggestion newlines', async ({ page }) => {
    const liveProduct: Product = { ...products[0], id: 'scoped-puja-thali', slug: 'scoped-puja-thali',
      name: 'Live Puja Thali', price: 80, mrp: 100, stock: 10 }
    const { manager, mutations, catalogueRequests, draft } = await prepareCampaignManager(page, [liveProduct], 'navratri-test-hub')
    await manager.locator('summary').filter({ hasText: 'Rotating product card' }).click()
    const link = manager.getByRole('combobox', { name: 'Product 1 catalogue link', exact: true })
    await expect(link).toBeEnabled()
    await expect(link.locator('option', { hasText: 'Live Puja Thali' })).toHaveCount(1)
    expect(catalogueRequests.some(url => url.searchParams.get('type') === 'grocery' &&
      url.searchParams.get('limit') === '1000' && url.searchParams.get('storeId') === 'navratri-test-hub')).toBe(true)
    await link.selectOption(liveProduct.id)
    await expect(manager.getByRole('textbox', { name: 'Product name', exact: true }).first()).toHaveValue(liveProduct.name)
    await expect(manager.getByRole('spinbutton', { name: 'Original price (demo)', exact: true }).first()).toHaveValue('100')
    await expect(manager.getByRole('spinbutton', { name: 'Sale price (demo)', exact: true }).first()).toHaveValue('80')

    await manager.locator('summary').filter({ hasText: 'Four category cards' }).click()
    const categoryKeywords = manager.getByRole('textbox', { name: 'Category keywords (comma separated)', exact: true }).first()
    await categoryKeywords.fill('')
    await categoryKeywords.pressSequentially('diya,flower')
    await expect(categoryKeywords).toHaveValue('diya,flower')
    await categoryKeywords.blur()
    await expect(categoryKeywords).toHaveValue('diya, flower')

    await manager.locator('summary').filter({ hasText: 'Collection tabs & product filters' }).click()
    await manager.getByRole('button', { name: 'Add collection', exact: true }).click()
    const tabKeywords = manager.getByRole('textbox', { name: 'Product filter keywords (comma separated)', exact: true }).last()
    await tabKeywords.pressSequentially('diya')
    await tabKeywords.pressSequentially(',')
    await expect(tabKeywords).toHaveValue('diya,')
    await tabKeywords.pressSequentially(' flower')
    await tabKeywords.blur()
    await expect(tabKeywords).toHaveValue('diya, flower')

    await manager.locator('summary').filter({ hasText: 'Search suggestions' }).click()
    const suggestions = manager.getByRole('textbox', { name: 'Suggestions (one per line)', exact: true })
    await suggestions.fill('Diyas')
    await suggestions.press('End')
    await suggestions.press('Enter')
    await expect(suggestions).toHaveValue('Diyas\n')
    await suggestions.pressSequentially('Sweets')
    await expect(suggestions).toHaveValue('Diyas\nSweets')
    await suggestions.blur()
    await manager.getByRole('button', { name: 'Save Draft', exact: true }).click()
    await expect(manager.getByRole('status')).toContainText('Draft saved. Customers still see the published campaign.')
    expect(mutations).toHaveLength(1)
    expect(mutations[0].storeId).toBe('navratri-test-hub')
    expect(mutations[0].campaign.products[0]).toMatchObject({ productId: liveProduct.id, name: liveProduct.name,
      image: liveProduct.imageUrl, originalPrice: 100, price: 80 })
    expect(draft().categories[0].keywords).toEqual(['diya', 'flower'])
    expect(draft().tabs.at(-1)?.keywords).toEqual(['diya', 'flower'])
    expect(draft().searchSuggestions).toEqual(['Diyas', 'Sweets'])

    await page.getByRole('button', { name: 'Offers', exact: true }).click()
    await expect(manager).toHaveCount(0)
    await page.getByRole('button', { name: 'Campaign Manager', exact: true }).click()
    await expect(manager.getByRole('button', { name: 'Save Draft', exact: true })).toBeEnabled()
    await manager.locator('summary').filter({ hasText: 'Four category cards' }).click()
    await manager.locator('summary').filter({ hasText: 'Search suggestions' }).click()
    await manager.locator('summary').filter({ hasText: 'Collection tabs & product filters' }).click()
    await expect(categoryKeywords).toHaveValue('diya, flower')
    await expect(suggestions).toHaveValue('Diyas\nSweets')
    await expect(manager.getByRole('textbox', { name: 'Product filter keywords (comma separated)', exact: true }).last()).toHaveValue('diya, flower')

    // Replacing the loaded values must also replace each field's temporary raw
    // text, rather than leaving the just-edited comma/newline strings onscreen.
    await manager.getByRole('combobox', { name: 'Campaign template', exact: true }).selectOption('navratri')
    await manager.getByRole('button', { name: 'Load template', exact: true }).click()
    await expect(categoryKeywords).toHaveValue(campaign.categories[0].keywords.join(', '))
    await expect(suggestions).toHaveValue(campaign.searchSuggestions.join('\n'))
    await expect(manager.getByRole('textbox', { name: 'Product filter keywords (comma separated)', exact: true })).toHaveCount(campaign.tabs.length)
    expect(mutations).toHaveLength(1)
  })
})
