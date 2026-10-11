import test from 'node:test'
import assert from 'node:assert/strict'
import { existsSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { destinationHref, filterDemoProducts, filterNavratriProducts, navratriData, resolveCampaignPromotions } from '../../components/home/navratri/data'
import type { Product } from '../../types'
import { campaignAppearance, campaignLabels, campaignSchema, parseCampaignConfig } from '../campaign-config'

const product = (id: string, overrides: Partial<Product>): Product => ({
  id, name: 'Catalogue item', slug: id, description: null, imageUrl: null,
  mrp: 100, price: 80, discount: 20, unit: '1 piece', stock: 1,
  isAvailable: true, tags: [], ...overrides,
})

test('shared campaign data resolves every local asset and existing search destination', () => {
  const flutterContent = JSON.parse(readFileSync(resolve('fastkirana_flutter', 'assets', 'navratri', 'navratri.json'), 'utf8'))
  const webContent = JSON.parse(readFileSync(resolve('public', 'navratri', 'navratri.json'), 'utf8'))
  assert.deepEqual(flutterContent, webContent)
  assert.deepEqual(parseCampaignConfig(flutterContent), navratriData)
  assert.equal(navratriData.demo, true)
  assert.equal(navratriData.timings.headerMs, 4000)
  assert.equal(navratriData.timings.productMs, 2500)
  assert.equal(navratriData.timings.crossfadeMs, 400)
  const images = [
    'string-lights.svg',
    ...navratriData.headers.flatMap(header => header.image ? [header.image] : []),
    ...navratriData.products.map(item => item.image),
    ...navratriData.categories.map(item => item.image),
    ...navratriData.tabs.map(item => item.image),
  ]
  for (const image of images) {
    assert.match(image, /^[a-z0-9-]+\.svg$/)
    assert.ok(existsSync(resolve('public', 'navratri', image)), `missing local illustration: ${image}`)
    assert.equal(readFileSync(resolve('fastkirana_flutter', 'assets', 'navratri', image), 'utf8'), readFileSync(resolve('public', 'navratri', image), 'utf8'), `platform illustrations differ: ${image}`)
  }
  const ids = new Set(navratriData.destinations.map(destination => destination.id))
  for (const item of [...navratriData.products, ...navratriData.categories, ...navratriData.navigation]) {
    if (!item.destinationId) continue
    assert.ok(ids.has(item.destinationId), `unresolved destination: ${item.destinationId}`)
    assert.match(destinationHref(item.destinationId), /^\/search\?q=/)
  }
  assert.equal(destinationHref('search-mata-chunri'), '/search?q=Mata%20Chunri')
  assert.equal(destinationHref('unknown'), '/')
})

test('catalogue filtering handles names, slugs, descriptions, tags, categories, and missing metadata', () => {
  const catalogue = [
    product('name', { name: 'MARIGOLD Flowers' }),
    product('description', { description: 'Fresh puja leaves' }),
    product('tags', { tags: ['Pooja'] }),
    product('category', { category: {
      id: 'cat', name: 'Chunri & Idols', slug: 'festival', imageUrl: null, parentId: 'parent', sortOrder: 0,
      parent: { id: 'parent', name: 'Chunri & Idols', slug: 'chunri-idols', imageUrl: null, parentId: null, sortOrder: 0 },
    } }),
    product('plain', {}),
    product('restaurant', { name: 'Puja Thali', restaurantId: 'restaurant-1' }),
    product('slug', { slug: 'puja-thali' }),
    product('dandiya', { name: 'Dandiya Sticks' }),
  ]
  assert.deepEqual(filterNavratriProducts(catalogue, ['flower', 'leaves']).map(item => item.id), ['name', 'description'])
  assert.deepEqual(filterNavratriProducts(catalogue, ['pooja']).map(item => item.id), ['tags'])
  assert.deepEqual(filterNavratriProducts(catalogue, ['idol']).map(item => item.id), ['category'])
  assert.deepEqual(filterNavratriProducts(catalogue, ['nonexistent']), [])
  assert.deepEqual(filterNavratriProducts(catalogue, ['diya']).map(item => item.id), [])
  assert.deepEqual(filterNavratriProducts(catalogue, ['thali']).map(item => item.id), ['slug'])
  assert.deepEqual(filterNavratriProducts(catalogue, []).map(item => item.id), ['name', 'description', 'tags', 'category', 'slug', 'dandiya'])
  assert.deepEqual(filterNavratriProducts([], []), [])
})

test('demo collection tabs filter data and support an honest empty flowers collection', () => {
  const [top, pooja, flowers, chunri] = navratriData.tabs
  assert.equal(filterDemoProducts(top).length, 4)
  assert.deepEqual(filterDemoProducts(pooja).map(item => item.id), ['mata-chunri'])
  assert.deepEqual(filterDemoProducts(flowers), [])
  assert.deepEqual(filterDemoProducts(chunri).map(item => item.id), ['mata-chunri'])
})

test('generic campaign metadata remains optional for the bundled Navratri JSON', () => {
  const config = parseCampaignConfig(navratriData)
  assert.equal(config.enabled, true)
  assert.equal(config.autoplay, true)
  assert.equal(config.searchPrefix, 'Search for')
  assert.deepEqual(config.labels, campaignLabels)
  assert.deepEqual(config.appearance, campaignAppearance)
  assert.equal(config.decorationImage, 'string-lights.svg')
})

test('generic metadata can rename and recolor a campaign without replacing its data contract', () => {
  const config = parseCampaignConfig({
    ...navratriData, enabled: false, autoplay: false, searchPrefix: 'Find', decorationImage: null,
    labels: { ...campaignLabels, sectionLabel: 'Celebrate Diwali', specialsHeading: 'Diwali Specials', curvedTabLabel: 'Festive Picks' },
    appearance: { ...campaignAppearance, background: '#123456', underline: '#AA3300' },
  })
  assert.equal(config.enabled, false)
  assert.equal(config.autoplay, false)
  assert.equal(config.labels.specialsHeading, 'Diwali Specials')
  assert.equal(config.appearance.background, '#123456')
  assert.equal(config.decorationImage, null)
})

test('campaign validation rejects invalid prices, bounds, duplicate IDs, and unresolved destinations', () => {
  const invalidChanges = [
    (config: typeof navratriData) => { config.products[0].price = config.products[0].originalPrice + 1 },
    (config: typeof navratriData) => { config.products[0].price = -1 },
    (config: typeof navratriData) => { config.timings.headerMs = 500 },
    (config: typeof navratriData) => { config.timings.crossfadeMs = 1500 },
    (config: typeof navratriData) => { config.headers[1].id = config.headers[0].id },
    (config: typeof navratriData) => { config.products[0].destinationId = 'missing-destination' },
    (config: typeof navratriData) => { config.products[0].categoryId = 'missing-category' },
    (config: typeof navratriData) => { config.categories.pop() },
    (config: typeof navratriData) => { config.headers[0].kind = 'illustration'; config.headers[0].image = null },
    (config: typeof navratriData) => { config.headers[0].kind = 'brand'; config.headers[0].image = null },
  ]
  for (const change of invalidChanges) {
    const config = structuredClone(navratriData)
    change(config)
    assert.equal(campaignSchema.safeParse(config).success, false)
  }
  assert.equal(campaignSchema.safeParse({ ...navratriData, appearance: { ...campaignAppearance, background: 'orange' } }).success, false)
  const textOnly = structuredClone(navratriData)
  textOnly.headers[0].kind = 'title'
  textOnly.headers[0].image = null
  assert.equal(campaignSchema.safeParse(textOnly).success, true)
})

test('live campaigns require catalogue product links and image inputs reject unsafe schemes', () => {
  assert.equal(campaignSchema.safeParse({ ...navratriData, demo: false }).success, false)
  const live = structuredClone(navratriData)
  live.demo = false
  live.products.forEach((item, index) => { Object.assign(item, { productId: `catalogue-${index}` }) })
  assert.equal(campaignSchema.safeParse(live).success, true)
  for (const image of ['javascript:alert(1)', '//other.example/image.svg', 'http://other.example/image.png', '/images/../secrets.svg']) {
    const config = structuredClone(navratriData)
    config.products[0].image = image
    assert.equal(campaignSchema.safeParse(config).success, false, `unsafe image accepted: ${image}`)
  }
  for (const image of ['replacement.svg', '/campaigns/diwali.jpg', 'https://cdn.example.com/diwali.webp']) {
    const config = structuredClone(navratriData)
    config.products[0].image = image
    assert.equal(campaignSchema.safeParse(config).success, true, `valid image rejected: ${image}`)
  }
})

test('linked promotional slots use current store prices and omit unavailable or restaurant products', () => {
  const config = parseCampaignConfig({
    ...navratriData, demo: false,
    products: navratriData.products.map((slot, index) => ({ ...slot, productId: ['available', 'sold-out', 'unavailable', 'restaurant'][index] })),
  })
  const catalogue = [
    product('available', { name: 'Live Puja Thali', price: 180, mrp: 150, imageUrl: '/catalogue/live-thali.svg' }),
    product('sold-out', { stock: 0 }),
    product('unavailable', { isAvailable: false }),
    product('restaurant', { restaurantId: 'food-store' }),
  ]
  const resolved = resolveCampaignPromotions(config, catalogue)
  assert.equal(resolved.products.length, 1)
  assert.equal(resolved.products[0].name, 'Live Puja Thali')
  assert.equal(resolved.products[0].price, 180)
  assert.equal(resolved.products[0].originalPrice, 180)
  assert.equal(resolved.products[0].image, '/catalogue/live-thali.svg')
  assert.equal(config.products[0].name, 'Dandiya Sticks')
  assert.deepEqual(resolveCampaignPromotions(config, []).products, [])
  for (const imageUrl of ['📦', 'javascript:alert(1)', '../missing.svg']) {
    assert.equal(resolveCampaignPromotions(config, [{ ...catalogue[0], imageUrl }]).products[0].image, config.products[0].image)
  }
})
