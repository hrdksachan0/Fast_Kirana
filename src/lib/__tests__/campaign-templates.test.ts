import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { campaignTemplates, createCampaignFromTemplate } from '../campaign-templates'
import { parseCampaignConfig } from '../campaign-config'
import { campaignContrast, campaignHeaderSecondary } from '../campaign-appearance'
import { destinationHref, filterDemoProducts, filterNavratriProducts } from '../../components/home/navratri/data'
import type { Product } from '../../types'

interface TemplateMetadata {
  id: string
  name: string
  type: string
  description: string
  manifest: string
  thumbnail: string
}

const sourceRoot = resolve('public', 'navratri')
const nativeRoot = resolve('fastkirana_flutter', 'assets', 'navratri')
const metadata = JSON.parse(readFileSync(resolve(sourceRoot, 'templates', 'index.json'), 'utf8')) as TemplateMetadata[]

test('template index and admin registry expose every supported campaign once', () => {
  assert.deepEqual(metadata.map(item => item.id), [
    'navratri', 'diwali', 'holi', 'ramadan', 'daily-essentials', 'value-picks', 'summer', 'monsoon',
  ])
  assert.deepEqual(campaignTemplates.map(item => item.id), metadata.map(item => item.id))
  assert.deepEqual(JSON.parse(readFileSync(resolve(nativeRoot, 'templates', 'index.json'), 'utf8')), metadata)
  for (const entry of metadata) {
    const registered = campaignTemplates.find(item => item.id === entry.id)!
    for (const field of ['name', 'type', 'description', 'thumbnail'] as const) {
      assert.ok(entry[field].trim(), `${entry.id} needs ${field}`)
      assert.equal(registered[field], entry[field], `${entry.id} registry differs from shared metadata`)
    }
  }
})

for (const entry of metadata) {
  test(`${entry.id} campaign is publishable as a demo and shares native assets and working collections`, () => {
    const canonical = JSON.parse(readFileSync(resolve(sourceRoot, entry.manifest), 'utf8'))
    const config = createCampaignFromTemplate(entry.id)
    assert.deepEqual(config, parseCampaignConfig(canonical))
    assert.deepEqual(JSON.parse(readFileSync(resolve(nativeRoot, entry.manifest), 'utf8')), canonical)
    assert.equal(config.version, 1)
    assert.equal(config.demo, true)
    assert.equal(config.enabled, true)
    assert.deepEqual(config.navigation, [])
    assert.equal(config.categories.length, 4)
    assert.ok(config.headers.length > 1, 'preset needs actual rotating header content')
    assert.ok(config.products.length > 1, 'preset needs actual rotating product content')
    assert.ok(config.searchSuggestions.length > 1, 'preset needs actual rotating search content')
    if (entry.id !== 'navratri') {
      assert.doesNotMatch(JSON.stringify(config.labels), /navratri|vrat|dandiya/i)
    }

    const images = new Set([
      entry.thumbnail,
      ...(config.decorationImage ? [config.decorationImage] : []),
      ...[...config.headers, ...config.products, ...config.categories, ...config.tabs]
        .flatMap(item => item.image ? [item.image] : []),
    ])
    for (const image of images) {
      assert.match(image, /^[a-z0-9-]+\.svg$/, `bundled preset should use local artwork: ${image}`)
      const content = readFileSync(resolve(sourceRoot, image), 'utf8')
      assert.match(content, /<svg\b[^>]*viewBox=/, `${image} needs scalable geometry`)
      assert.equal(readFileSync(resolve(nativeRoot, image), 'utf8'), content, `${image} differs between platforms`)
    }

    const catalogue = config.products.map((item): Product => ({
      id: item.id, name: item.name, slug: item.id, description: null,
      imageUrl: item.image, mrp: item.originalPrice, price: item.price, discount: 0,
      unit: '1 piece', stock: 1, isAvailable: true,
      tags: config.categories.find(category => category.id === item.categoryId)!.keywords,
    }))
    const food: Product = { ...catalogue[0], id: 'restaurant', restaurantId: 'restaurant' }
    for (const item of [...config.products, ...config.categories]) {
      assert.match(destinationHref(item.destinationId, config), /^\/search\?q=.+/, `${item.id} needs a search query`)
    }
    for (const tab of config.tabs) {
      if (entry.id !== 'navratri') {
        assert.ok(filterDemoProducts(tab, config).length > 0, `${tab.id} has no configured demonstration products`)
      }
      const matches = filterNavratriProducts([...catalogue, food], tab.keywords, config)
      if (entry.id !== 'navratri') assert.ok(matches.length > 0, `${tab.id} has no matching catalogue keywords`)
      assert.ok(matches.every(item => !item.restaurantId))
    }
  })
}

test('starting a template creates isolated editable state without altering registry defaults', () => {
  const original = createCampaignFromTemplate('diwali')
  const edited = createCampaignFromTemplate('diwali')
  edited.labels.sectionLabel = 'My edited Diwali'
  edited.appearance.background = '#123456'
  edited.products[0].name = 'Local special'
  edited.categories[0].keywords.push('custom keyword')
  edited.headers.reverse()
  edited.tabs.pop()
  assert.deepEqual(createCampaignFromTemplate('diwali'), original)
  assert.deepEqual(campaignTemplates.find(item => item.id === 'diwali')!.config, original)
})

test('unknown template IDs fail instead of silently replacing the draft', () => {
  assert.throws(() => createCampaignFromTemplate('missing-preset'), RangeError)
})

test('header supporting copy stays readable on every bundled theme background', () => {
  for (const { id, config } of campaignTemplates) {
    assert.ok(
      campaignContrast(campaignHeaderSecondary(config.appearance), config.appearance.background) >= 4.5,
      `${id} header supporting text needs sufficient contrast`,
    )
  }
})
