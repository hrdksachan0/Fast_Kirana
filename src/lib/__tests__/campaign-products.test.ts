import test from 'node:test'
import assert from 'node:assert/strict'
import type { Product } from '../../types'
import { navratriData } from '../../components/home/navratri/data'
import { loadCampaignProductDetails, missingCampaignProductIds } from '../../components/home/navratri/promotion-products'

const product = (id: string, extra: Partial<Product> = {}): Product => ({
  id, name: 'Live Puja Thali', slug: id, description: null, imageUrl: '/navratri/puja-thali.svg',
  price: 180, mrp: 240, discount: 25, stock: 4, isAvailable: true, unit: '1 piece', tags: [], ...extra,
})

test('linked IDs outside the home feed are resolved once while existing identities stay authoritative', () => {
  const config = { ...navratriData, products: navratriData.products.map((slot, index) => ({ ...slot, productId: index === 0 ? 'listed' : 'outside-feed' })) }
  assert.deepEqual(missingCampaignProductIds(config, [product('listed', { stock: 0 })]), ['outside-feed'])
  assert.deepEqual(missingCampaignProductIds(navratriData, []), [])
})

test('missing promotions load current store data and reject unavailable, mismatched and failed identities', async () => {
  const requests: string[] = []
  const responses = new Map<string, Product>([
    ['available', product('available')], ['sold-out', product('sold-out', { stock: 0 })],
    ['unavailable', product('unavailable', { isAvailable: false })],
    ['restaurant', product('restaurant', { restaurantId: 'restaurant-1' })],
    ['wrong-id', product('another-product')], ['bad-price', product('bad-price', { price: -1 })],
  ])
  const request: typeof fetch = async (input) => {
    const url = String(input)
    requests.push(url)
    const id = new URL(url, 'https://test.local').pathname.split('/').at(-1)!
    const value = responses.get(id)
    return value ? Response.json(value) : new Response(null, { status: 404 })
  }
  const loaded = await loadCampaignProductDetails([...responses.keys(), 'deleted'], 'hub-changed', new AbortController().signal, request)
  assert.deepEqual(loaded, [product('available')])
  assert.equal(requests.length, 7)
  assert.ok(requests.every(url => new URL(url, 'https://test.local').searchParams.get('storeId') === 'hub-changed'))
  assert.equal(loaded[0].price, 180)
})

test('failed or superseded store requests return no cached cross-store promotion', async () => {
  const failed: typeof fetch = async () => { throw new Error('offline') }
  assert.deepEqual(await loadCampaignProductDetails(['outside-feed'], 'hub-new', new AbortController().signal, failed), [])
  const controller = new AbortController()
  const superseded: typeof fetch = async () => { controller.abort(); return Response.json(product('outside-feed')) }
  assert.deepEqual(await loadCampaignProductDetails(['outside-feed'], 'hub-old', controller.signal, superseded), [])
})
