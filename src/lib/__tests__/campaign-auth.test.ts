import test from 'node:test'
import assert from 'node:assert/strict'
import { createRequire } from 'node:module'
import { resolve } from 'node:path'
import { SignJWT, jwtVerify } from 'jose'
import type { VerifiedGuardUser, VerifiedRoleDependencies } from '../auth-guard'

// Load the actual guard with hermetic Auth.js/config imports. The strict guard
// must choose verifiedAuth; legacy auth deliberately supplies an unsafe identity
// so the spoofing regression cannot pass by accidentally calling that fallback.
const testRequire = createRequire(resolve('src/lib/__tests__/campaign-auth.test.ts'))
const nativeModule = testRequire('node:module') as {
  _load: (specifier: string, parent: unknown, isMain: boolean) => unknown
}
const originalLoad = nativeModule._load
let legacyAuthCalls = 0
let verifiedSessionCalls = 0
nativeModule._load = function (specifier, parent, isMain) {
  if (specifier === '@/auth') return {
    auth: async () => { legacyAuthCalls++; return { user: { id: 'spoofed-admin' } } },
    verifiedAuth: async () => { verifiedSessionCalls++; return null },
  }
  if (specifier === '@/lib/superadmin-config') return {
    isSuperadminPhone: () => false,
    isRootAdminAccount: () => false,
  }
  if (specifier === '@/lib/logger') return { logger: { warn: () => {} } }
  return originalLoad.call(this, specifier, parent, isMain)
}
let guard: typeof import('../auth-guard')
try { guard = testRequire('../auth-guard') } finally { nativeModule._load = originalLoad }

const admin = (overrides: Partial<VerifiedGuardUser> = {}): VerifiedGuardUser => ({
  id: 'real-admin', role: 'ADMIN', email: 'current-admin@example.com', phone: null,
  assignedStoreId: 'hub-current', assignedRestaurantId: null,
  isBlocked: false, deletedAt: null, ...overrides,
})
const fixture = (overrides: Partial<VerifiedRoleDependencies> = {}) => {
  const lookups: string[] = []
  const dependencies: VerifiedRoleDependencies = {
    getSession: async () => null,
    verifyBearer: async () => null,
    findUser: async id => { lookups.push(id); return admin({ id }) },
    ...overrides,
  }
  return { check: guard.createVerifiedRoleGuard(dependencies), lookups }
}
const request = (headers: HeadersInit = {}) => new Request('https://fastkirana.test/api/admin/campaign', { headers })

test('production strict guard rejects identity headers without legacy auth or user lookup', async () => {
  const result = await guard.requireVerifiedRole(['ADMIN', 'SUPER_ADMIN'], request({
    'x-user-id': 'real-admin', 'x-user-email': 'admin@fastkirana.com',
    'x-user-phone': '9170942500', 'x-user-role': 'ADMIN',
  }))
  assert.equal(result.error?.status, 401)
  assert.equal(result.session, null)
  assert.equal(legacyAuthCalls, 0)
  assert.equal(verifiedSessionCalls, 1)
})

test('identity headers alone never query account metadata', async () => {
  const { check, lookups } = fixture()
  const result = await check(['ADMIN'], request({ 'x-user-id': 'real-admin', 'x-user-role': 'ADMIN' }))
  assert.equal(result.error?.status, 401)
  assert.deepEqual(lookups, [])
})

test('verified NextAuth session uses current database role and assigned store', async () => {
  const { check, lookups } = fixture({
    getSession: async () => ({ user: { id: 'real-admin', role: 'SUPER_ADMIN', assignedStoreId: null } }),
  })
  const result = await check(['ADMIN', 'SUPER_ADMIN'], request({ 'x-user-store-id': 'hub-spoof' }))
  assert.equal(result.error, null)
  assert.equal(result.session?.user.role, 'ADMIN')
  assert.equal(result.session?.user.assignedStoreId, 'hub-current')
  assert.equal(result.session?.user.email, 'current-admin@example.com')
  assert.deepEqual(lookups, ['real-admin'])
})

test('verified signed Bearer identity refreshes stale role and scope claims', async () => {
  const secret = new TextEncoder().encode('campaign-test-signing-secret-isolated')
  const token = await new SignJWT({ id: 'real-admin', role: 'SUPER_ADMIN', assignedStoreId: 'hub-old' })
    .setProtectedHeader({ alg: 'HS256' }).setExpirationTime('5m').sign(secret)
  const { check, lookups } = fixture({
    getSession: async () => { throw new Error('Bearer auth must not use cookie fallback') },
    verifyBearer: async authorization => {
      const { payload } = await jwtVerify(authorization.slice(7), secret)
      return { userId: payload.id }
    },
  })
  const result = await check(['ADMIN'], request({ authorization: `Bearer ${token}` }))
  assert.equal(result.error, null)
  assert.equal(result.session?.user.role, 'ADMIN')
  assert.equal(result.session?.user.assignedStoreId, 'hub-current')
  assert.deepEqual(lookups, ['real-admin'])
})

test('expired and forged Bearer tokens never trigger database lookup', async () => {
  const secret = new TextEncoder().encode('campaign-test-signing-secret-isolated')
  const wrong = new TextEncoder().encode('campaign-test-wrong-signing-secret')
  const { check, lookups } = fixture({
    verifyBearer: async authorization => {
      const { payload } = await jwtVerify(authorization.slice(7), secret)
      return { userId: payload.id }
    },
  })
  const tokens = [
    await new SignJWT({ id: 'real-admin' }).setProtectedHeader({ alg: 'HS256' }).setExpirationTime(1).sign(secret),
    await new SignJWT({ id: 'real-admin' }).setProtectedHeader({ alg: 'HS256' }).setExpirationTime('5m').sign(wrong),
  ]
  for (const token of tokens) {
    const result = await check(['ADMIN'], request({ authorization: `Bearer ${token}`, 'x-user-id': 'real-admin' }))
    assert.equal(result.error?.status, 401)
    assert.equal(result.session, null)
  }
  assert.deepEqual(lookups, [])
})

test('signed credentials without a real user ID are rejected before account lookup', async () => {
  for (const id of [undefined, '', 'mock-id-admin', 123]) {
    const { check, lookups } = fixture({ getSession: async () => ({ user: { id } }) })
    assert.equal((await check(['ADMIN'], request())).error?.status, 401)
    assert.deepEqual(lookups, [])
  }
  const { check, lookups } = fixture({ verifyBearer: async () => ({}) })
  assert.equal((await check(['ADMIN'], request({ authorization: 'Bearer missing-id' }))).error?.status, 401)
  assert.deepEqual(lookups, [])
})

test('database role revocation overrides stale signed admin claims', async () => {
  const { check } = fixture({
    getSession: async () => ({ user: { id: 'real-admin', role: 'ADMIN' } }),
    findUser: async () => admin({ role: 'USER' }),
  })
  assert.equal((await check(['ADMIN', 'SUPER_ADMIN'], request())).error?.status, 403)
})

test('blocked, deleted, and missing accounts fail closed', async () => {
  for (const [user, status] of [[admin({ isBlocked: true }), 403], [admin({ deletedAt: new Date() }), 401], [null, 401]] as const) {
    const { check } = fixture({ getSession: async () => ({ user: { id: 'real-admin' } }), findUser: async () => user })
    const result = await check(['ADMIN'], request())
    assert.equal(result.error?.status, status)
    assert.equal(result.session, null)
  }
})

test('database verification outage returns an error without trusting cached identity claims', async () => {
  const { check } = fixture({
    getSession: async () => ({ user: { id: 'real-admin', role: 'ADMIN' } }),
    findUser: async () => { throw new Error('Database unavailable') },
  })
  const result = await check(['ADMIN'], request())
  assert.equal(result.error?.status, 503)
  assert.equal(result.session, null)
})

test('production campaign verifier requires HS256, expiry, a configured key, and real identity', async () => {
  const savedAuthSecret = process.env.AUTH_SECRET
  const savedNextAuthSecret = process.env.NEXTAUTH_SECRET
  const secret = 'campaign-production-verifier-test-key-at-least-32-bytes'
  process.env.AUTH_SECRET = secret
  delete process.env.NEXTAUTH_SECRET
  try {
    const key = new TextEncoder().encode(secret)
    const valid = await new SignJWT({ id: 'real-admin' }).setProtectedHeader({ alg: 'HS256' }).setExpirationTime('5m').sign(key)
    assert.deepEqual(await guard.verifyCampaignBearer(`Bearer ${valid}`), { userId: 'real-admin' })
    const invalid = [
      await new SignJWT({ id: 'real-admin' }).setProtectedHeader({ alg: 'HS256' }).sign(key),
      await new SignJWT({ id: 'real-admin' }).setProtectedHeader({ alg: 'HS384' }).setExpirationTime('5m').sign(key),
      await new SignJWT({ id: 'real-admin' }).setProtectedHeader({ alg: 'HS256' }).setExpirationTime(1).sign(key),
      await new SignJWT({}).setProtectedHeader({ alg: 'HS256' }).setExpirationTime('5m').sign(key),
    ]
    for (const token of invalid) assert.equal(await guard.verifyCampaignBearer(`Bearer ${token}`), null)
    delete process.env.AUTH_SECRET
    assert.equal(await guard.verifyCampaignBearer(`Bearer ${valid}`), null)
  } finally {
    if (savedAuthSecret === undefined) delete process.env.AUTH_SECRET
    else process.env.AUTH_SECRET = savedAuthSecret
    if (savedNextAuthSecret === undefined) delete process.env.NEXTAUTH_SECRET
    else process.env.NEXTAUTH_SECRET = savedNextAuthSecret
  }
})
