import test from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { resolve } from 'node:path'

type Inventory = { stock: number; isAvailable: boolean; priceOverride?: number | null }
const baseProduct = {
  id: 'catalogue-product', slug: 'catalogue-slug', restaurantId: null, restaurant: null,
  price: 80, mrp: 100, discount: 20, stock: 50, isAvailable: true,
}
let inventory: Inventory | null = null
let inventoryLookups: unknown[] = []

// Exercise the real GET handler while preventing database and unrelated mutation
// dependencies from initializing. Each request receives a fresh product object.
const testRequire = createRequire(resolve('src/lib/__tests__/product-detail-scope.test.ts'))
const nativeModule = testRequire('node:module') as {
  _load: (specifier: string, parent: unknown, isMain: boolean) => unknown
}
const originalLoad = nativeModule._load
nativeModule._load = function (specifier, parent, isMain) {
  if (specifier === '@/lib/prisma') return {
    prisma: {
      product: { findFirst: async () => ({ ...baseProduct }) },
      storeInventory: {
        findUnique: async (query: unknown) => { inventoryLookups.push(query); return inventory },
      },
    },
  }
  if (specifier === '@/auth') return { auth: async () => null }
  if (specifier === '@/lib/auth-guard') return { requireAdmin: async () => null }
  if (specifier === '@/lib/revalidate') return { revalidateStorefront: () => {} }
  if (specifier === '@/lib/search-cache') return { invalidateProductCache: () => {} }
  if (specifier === '@/lib/restaurant-ids') return { normalizeRestaurantId: (id: string) => id }
  if (specifier === '@/lib/logger') return { logger: { error: () => {}, warn: () => {} } }
  return originalLoad.call(this, specifier, parent, isMain)
}
let route: typeof import('../../app/api/products/[id]/route')
try { route = testRequire('../../app/api/products/[id]/route') } finally { nativeModule._load = originalLoad }

async function getProduct(value: Inventory | null, storeId: string | null = 'hub-selected') {
  inventory = value
  inventoryLookups = []
  const url = new URL('https://fastkirana.test/api/products/catalogue-slug')
  if (storeId) url.searchParams.set('storeId', storeId)
  const response = await route.GET(new Request(url), { params: Promise.resolve({ id: 'catalogue-slug' }) })
  assert.equal(response.status, 200)
  return await response.json() as typeof baseProduct
}

test('scoped product detail uses the selected hub price and recomputes discount', async () => {
  const product = await getProduct({ stock: 4, isAvailable: true, priceOverride: 60 })
  assert.equal(product.price, 60)
  assert.equal(product.discount, 40)
  assert.equal(product.stock, 4)
  assert.equal(product.isAvailable, true)
  assert.deepEqual(inventoryLookups, [{
    where: { productId_storeId: { productId: 'catalogue-product', storeId: 'hub-selected' } },
  }])
})

test('zero store price is an override rather than a missing price', async () => {
  const product = await getProduct({ stock: 2, isAvailable: true, priceOverride: 0 })
  assert.equal(product.price, 0)
  assert.equal(product.discount, 100)
  assert.equal(product.isAvailable, true)
})

test('absent and null price overrides preserve catalogue price and discount', async () => {
  for (const value of [{ stock: 3, isAvailable: true }, { stock: 3, isAvailable: true, priceOverride: null }]) {
    const product = await getProduct(value)
    assert.equal(product.price, 80)
    assert.equal(product.discount, 20)
    assert.equal(product.stock, 3)
  }
})

test('missing hub inventory preserves catalogue pricing and disables availability', async () => {
  const product = await getProduct(null)
  assert.equal(product.price, 80)
  assert.equal(product.discount, 20)
  assert.equal(product.stock, 0)
  assert.equal(product.isAvailable, false)
})

test('store price at or above MRP does not report a negative discount', async () => {
  for (const priceOverride of [100, 120]) {
    const product = await getProduct({ stock: 3, isAvailable: true, priceOverride })
    assert.equal(product.price, priceOverride)
    assert.equal(product.discount, 0)
  }
})

test('unscoped product detail preserves global inventory and pricing', async () => {
  const product = await getProduct({ stock: 3, isAvailable: true, priceOverride: 0 }, null)
  assert.deepEqual(product, baseProduct)
  assert.deepEqual(inventoryLookups, [])
})
