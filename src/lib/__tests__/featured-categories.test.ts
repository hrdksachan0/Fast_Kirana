import test, { beforeEach } from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { resolve } from 'node:path'
import { NextRequest, NextResponse } from 'next/server'
import {
  defaultFeaturedCategories,
  featuredCategoriesSchema,
  parseStoredFeaturedCategories,
} from '../featured-categories'

const grocery = {
  id: 'snacks',
  name: 'Snacks & Munchies',
  slug: 'snacks-munchies',
  sortOrder: 2,
  parentId: null as string | null,
  _count: { products: 4 },
}
const config = () =>
  featuredCategoriesSchema.parse({ version: 1, items: [{ categoryId: 'snacks' }] })
test('defaults choose six stocked grocery parents in catalogue order', () => {
  const input = [
    grocery,
    { ...grocery, id: 'milk', name: 'Milk', slug: 'dairy', sortOrder: 1 },
    { ...grocery, id: 'cafe', slug: 'restaurant-food' },
    { ...grocery, id: 'child', parentId: 'snacks' },
    { ...grocery, id: 'empty', _count: { products: 0 } },
  ]
  assert.deepEqual(
    defaultFeaturedCategories(input).items.map((item) => item.categoryId),
    ['milk', 'snacks']
  )
  assert.equal(input.length, 5)
  assert.equal(
    defaultFeaturedCategories(
      Array.from({ length: 9 }, (_, index) => ({ ...grocery, id: `cat-${index}` }))
    ).items.length,
    6
  )
})
test('empty and disabled selections remain explicit settings', () => {
  assert.deepEqual(
    featuredCategoriesSchema.parse({ version: 1, enabled: false, items: [] }).items,
    []
  )
  assert.equal(config().title, 'Featured categories')
  assert.equal(config().items[0].badge, '')
  assert.deepEqual(parseStoredFeaturedCategories(JSON.stringify(config())), config())
})
for (const invalid of [
  { version: true },
  { title: ' ' },
  { items: Array(7).fill({ categoryId: 'snacks' }) },
  { items: [{ categoryId: 'snacks' }, { categoryId: 'snacks' }] },
  ...['LIVE', '#1 MOST ORDERED', '20% OFF'].map((badge) => ({
    items: [{ categoryId: 'snacks', badge }],
  })),
  ...[
    'javascript:alert(1)',
    'http://example.test/img.png',
    '/%2e%2e/image.png',
    '//example.test/img.png',
    'https://user:password@example.test/img.png',
  ].map((image) => ({ items: [{ categoryId: 'snacks', image }] })),
])
  test(`invalid curation rejected: ${JSON.stringify(invalid)}`, () =>
    assert.equal(featuredCategoriesSchema.safeParse({ ...config(), ...invalid }).success, false))
test('bad persisted JSON falls back safely', () => {
  for (const value of ['{broken', 'null', '{}'])
    assert.equal(parseStoredFeaturedCategories(value), null)
})

const fixtureRequire = createRequire(resolve('src/lib/__tests__/featured-categories.test.ts'))
const nativeModule = fixtureRequire('node:module') as {
  _load: (specifier: string, parent: unknown, main: boolean) => unknown
}
const original = nativeModule._load
const state = {
  user: { role: 'SUPER_ADMIN', assignedStoreId: null } as {
    role: string
    assignedStoreId: string | null
  } | null,
  rows: new Map<string, string>(),
  writes: [] as string[],
  categories: [grocery],
  clears: 0,
}
nativeModule._load = function (specifier, parent, main) {
  if (specifier === '@/lib/prisma')
    return {
      prisma: {
        darkStore: {
          findUnique: async ({ where }: { where: { id: string } }) =>
            where.id === 'missing' ? null : { id: where.id },
        },
        category: { findMany: async () => state.categories },
        storeSetting: {
          findMany: async ({ where }: { where: { key: { in: string[] } } }) =>
            [...state.rows]
              .filter(([key]) => where.key.in.includes(key))
              .map(([key, value]) => ({ key, value })),
          upsert: async ({
            where,
            update,
          }: {
            where: { key: string }
            update: { value: string }
          }) => {
            state.rows.set(where.key, update.value)
            state.writes.push(where.key)
          },
        },
      },
    }
  if (specifier === '@/lib/auth-guard')
    return {
      requireVerifiedRole: async () =>
        state.user
          ? { session: { user: state.user }, error: null }
          : { error: NextResponse.json({ error: 'Login required' }, { status: 401 }) },
    }
  if (specifier === '@/lib/superadmin-config')
    return { isRootAdminAccount: (user: { role: string }) => user.role === 'SUPER_ADMIN' }
  if (specifier === '@/lib/settings-cache')
    return {
      clearSettingsCache: async () => {
        state.clears++
      },
    }
  return original.call(this, specifier, parent, main)
}
let endpoint: typeof import('../../app/api/admin/featured-categories/route')
try {
  endpoint = fixtureRequire('../../app/api/admin/featured-categories/route')
} finally {
  nativeModule._load = original
}
beforeEach(() => {
  state.user = { role: 'SUPER_ADMIN', assignedStoreId: null }
  state.rows.clear()
  state.writes = []
  state.clears = 0
  state.categories = [grocery]
})
const request = (storeId?: unknown, bodyConfig: unknown = config()) =>
  new NextRequest('https://local.test/api/admin/featured-categories', {
    method: 'PUT',
    body: JSON.stringify({ storeId, config: bodyConfig }),
    headers: { 'Content-Type': 'application/json' },
  })
test('Next route persists store overrides and invalidates settings', async () => {
  const savedFetch = globalThis.fetch
  globalThis.fetch = async () => new Response('{}')
  try {
    state.rows.set('featured_categories', JSON.stringify(config()))
    assert.equal(
      (
        await (
          await endpoint.GET(
            new NextRequest('https://local.test/api/admin/featured-categories?storeId=hub-one')
          )
        ).json()
      ).inherited,
      true
    )
    assert.equal(
      (await endpoint.PUT(request('hub-one', { ...config(), title: 'Weekend picks' }))).status,
      200
    )
    assert.deepEqual(state.writes, ['store:hub-one:featured_categories'])
    assert.equal(state.clears, 1)
    assert.equal(JSON.parse(state.rows.get('featured_categories')!).title, 'Featured categories')
    const scoped = await endpoint.GET(
      new NextRequest('https://local.test/api/admin/featured-categories?storeId=hub-one')
    )
    assert.equal((await scoped.json()).config.title, 'Weekend picks')
    assert.match(scoped.headers.get('cache-control')!, /no-store/)
  } finally {
    globalThis.fetch = savedFetch
  }
})
test('Next route rejects cross-store, unverified, missing and invalid category settings', async () => {
  state.user = { role: 'ADMIN', assignedStoreId: 'hub-one' }
  assert.equal((await endpoint.PUT(request('hub-two'))).status, 403)
  assert.equal((await endpoint.PUT(request('all'))).status, 403)
  state.user = null
  assert.equal((await endpoint.PUT(request())).status, 401)
  state.user = { role: 'SUPER_ADMIN', assignedStoreId: null }
  assert.equal((await endpoint.PUT(request('missing'))).status, 404)
  assert.equal((await endpoint.PUT(request(undefined, { ...config(), title: '' }))).status, 422)
  state.categories = [{ ...grocery, parentId: 'parent' }]
  assert.equal((await endpoint.PUT(request())).status, 422)
  assert.deepEqual(state.writes, [])
})
