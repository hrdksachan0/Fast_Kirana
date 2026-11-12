import test from 'node:test'
import assert from 'node:assert/strict'
import type { Product } from '../../types'
import {
  autoLinkBentoConfigProducts,
  campaignBentoConfigSchema,
  collectBentoProductIds,
  computePerUnitLabel,
  defaultCampaignBentoConfig,
  parseCampaignBentoConfig,
  resolveBentoSlotProduct,
} from '../campaign-bento-config'

const makeProduct = (id: string, overrides: Partial<Product> = {}): Product => ({
  id,
  name: id,
  slug: id.toLowerCase(),
  description: null,
  imageUrl: `/products/${id}.png`,
  mrp: 100,
  price: 80,
  discount: 20,
  unit: '500 g',
  stock: 15,
  isAvailable: true,
  tags: [],
  ...overrides,
})

test('defaultCampaignBentoConfig validates strictly against campaignBentoConfigSchema', () => {
  const parsed = campaignBentoConfigSchema.safeParse(defaultCampaignBentoConfig)
  assert.equal(parsed.success, true)
  const fallback = parseCampaignBentoConfig({ invalid: true })
  assert.equal(fallback.freshMarket.title, 'Fresh Market')
  assert.equal(fallback.breakfastClub.items.length, 3)
})

test('resolveBentoSlotProduct prefers explicit productId, excludes restaurant items, and tracks stock', () => {
  const catalogue: Product[] = [
    makeProduct('prod-milk-real', {
      name: 'Amul Taaza Toned Milk',
      unit: '500 ml',
      price: 28,
      mrp: 30,
      stock: 42,
      imageUrl: 'https://cdn.fastminute.in/milk.jpg',
    }),
    makeProduct('prod-milk-cafe', {
      name: 'Hot Café Milk',
      restaurantId: 'rest-1',
      price: 60,
    }),
  ]

  const slot = {
    ...defaultCampaignBentoConfig.dailyRestock.items[0],
    productId: 'prod-milk-real',
  }
  const resolved = resolveBentoSlotProduct(slot, catalogue)
  assert.equal(resolved.isLinked, true)
  assert.equal(resolved.isExplicitLink, true)
  assert.equal(resolved.inStock, true)
  assert.equal(resolved.name, 'Amul Taaza Toned Milk')
  assert.equal(resolved.price, 28)
  assert.equal(resolved.imageUrl, 'https://cdn.fastminute.in/milk.jpg')

  // Out of stock explicit product is flagged accurately
  const outResolved = resolveBentoSlotProduct(slot, [
    { ...catalogue[0], stock: 0 },
  ])
  assert.equal(outResolved.isLinked, true)
  assert.equal(outResolved.inStock, false)

  // Explicit link pointing to a restaurant item is ignored
  const cafeSlot = { ...slot, productId: 'prod-milk-cafe' }
  const cafeResolved = resolveBentoSlotProduct(cafeSlot, [catalogue[1]], {
    allowAutoMatch: false,
  })
  assert.equal(cafeResolved.isLinked, false)
  assert.equal(cafeResolved.product, null)
})

test('auto-match differentiates 1 kg vs 5 kg packs accurately', () => {
  const atta1kg = makeProduct('atta-1', {
    name: 'Aashirvaad Shudh Chakki Atta',
    unit: '1 kg',
    price: 58,
    mrp: 65,
  })
  const atta5kg = makeProduct('atta-5', {
    name: 'Aashirvaad Shudh Chakki Atta',
    unit: '5 kg',
    price: 245,
    mrp: 290,
  })

  const slot1kg = defaultCampaignBentoConfig.valuePicks.items[0]
  const slot5kg = defaultCampaignBentoConfig.valuePicks.items[1]

  const res1 = resolveBentoSlotProduct(slot1kg, [atta5kg, atta1kg])
  const res5 = resolveBentoSlotProduct(slot5kg, [atta1kg, atta5kg])

  assert.equal(res1.product?.id, 'atta-1')
  assert.equal(res5.product?.id, 'atta-5')
  assert.equal(computePerUnitLabel(245, '5 kg'), '₹49/kg')
  assert.equal(computePerUnitLabel(35, '750 ml'), '₹47/L')
})

test('autoLinkBentoConfigProducts links matching real products across all 6 cards without duplicating IDs', () => {
  const catalogue: Product[] = [
    makeProduct('p-tomato', { name: 'Desi Tomato', unit: '500 g', price: 22 }),
    makeProduct('p-milk', { name: 'Amul Gold Milk', unit: '500 ml', price: 33 }),
    makeProduct('p-atta5', { name: 'Fortune Atta 5kg', unit: '5 kg', price: 230 }),
    makeProduct('p-chips', { name: 'Lays Classic Chips', unit: '52 g', price: 20 }),
  ]

  const { config, matchedCount, totalSlots } = autoLinkBentoConfigProducts(
    defaultCampaignBentoConfig,
    catalogue
  )

  assert.equal(totalSlots, 19)
  assert.ok(matchedCount >= 4)
  const ids = collectBentoProductIds(config)
  assert.ok(ids.includes('p-tomato'))
  assert.ok(ids.includes('p-milk'))
  assert.ok(ids.includes('p-atta5'))
  assert.ok(ids.includes('p-chips'))
  assert.equal(ids.length, new Set(ids).size)
})
