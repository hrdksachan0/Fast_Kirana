import test from 'node:test'
import assert from 'node:assert/strict'
import 'dotenv/config'
import { SignJWT } from 'jose'
import { signFastKiranaJWT, verifyFastKiranaJWT } from '../jwt'

if (!process.env.AUTH_SECRET) {
  process.env.AUTH_SECRET = 'supersecretkey1234567890abcdef123456'
}

test('JWT signing and verification enforces cryptographic integrity', async () => {
  const payload = {
    userId: 'usr_test_123',
    email: 'staff@fastkirana.in',
    phone: '9876543210',
    role: 'CHEF',
    assignedRestaurantId: 'rest_01',
    assignedStoreId: null,
  }

  const token = await signFastKiranaJWT(payload)
  assert.ok(token && typeof token === 'string')

  const verified = await verifyFastKiranaJWT(token)
  assert.ok(verified)
  assert.equal(verified?.userId, 'usr_test_123')
  assert.equal(verified?.role, 'CHEF')
  assert.equal(verified?.assignedRestaurantId, 'rest_01')
})

test('JWT verification rejects forged tokens signed with untrusted keys', async () => {
  const forgedKey = new TextEncoder().encode('attacker-provided-untrusted-secret-key-123')
  const forgedToken = await new SignJWT({
    id: 'usr_attacker',
    role: 'ADMIN',
  })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(forgedKey)

  const verified = await verifyFastKiranaJWT(forgedToken)
  assert.equal(verified, null)
})

test('JWT verification rejects expired tokens', async () => {
  const secret = process.env.AUTH_SECRET || process.env.NEXTAUTH_SECRET || 'supersecretkey1234567890abcdef123456'
  const key = new TextEncoder().encode(secret)
  const expiredToken = await new SignJWT({
    id: 'usr_expired',
    role: 'ADMIN',
  })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setIssuedAt(Math.floor(Date.now() / 1000) - 7200)
    .setExpirationTime(Math.floor(Date.now() / 1000) - 3600)
    .sign(key)

  const verified = await verifyFastKiranaJWT(expiredToken)
  assert.equal(verified, null)
})

test('JWT verification rejects empty, malformed, or missing tokens', async () => {
  assert.equal(await verifyFastKiranaJWT(''), null)
  assert.equal(await verifyFastKiranaJWT('Bearer '), null)
  assert.equal(await verifyFastKiranaJWT('not.a.valid.jwt'), null)
})

test('JWT signing throws when AUTH_SECRET is missing or empty', async () => {
  const origAuth = process.env.AUTH_SECRET
  const origNextAuth = process.env.NEXTAUTH_SECRET
  try {
    delete process.env.AUTH_SECRET
    delete process.env.NEXTAUTH_SECRET
    await assert.rejects(
      async () => {
        await signFastKiranaJWT({ userId: 'u1', role: 'USER' })
      },
      /AUTH_SECRET is not configured/
    )
  } finally {
    process.env.AUTH_SECRET = origAuth
    if (origNextAuth) process.env.NEXTAUTH_SECRET = origNextAuth
  }
})

test('JWT verification rejects tokens without an expiration claim', async () => {
  const secret = process.env.AUTH_SECRET || process.env.NEXTAUTH_SECRET || 'supersecretkey1234567890abcdef123456'
  const key = new TextEncoder().encode(secret)
  const tokenNoExp = await new SignJWT({
    id: 'usr_no_exp',
    role: 'ADMIN',
  })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setIssuedAt()
    .sign(key)

  const verified = await verifyFastKiranaJWT(tokenNoExp)
  assert.equal(verified, null)
})

test('JWT verification rejects WebSocket tickets from being used as REST credentials', async () => {
  const secret = process.env.AUTH_SECRET || process.env.NEXTAUTH_SECRET || 'supersecretkey1234567890abcdef123456'
  const key = new TextEncoder().encode(secret)
  const wsTicket = await new SignJWT({
    id: 'usr_ws_user',
    role: 'ADMIN',
    channel: 'order_123',
    scope: 'ws_ticket',
    type: 'ws_ticket',
  })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setIssuedAt()
    .setExpirationTime('2m')
    .sign(key)

  const verified = await verifyFastKiranaJWT(wsTicket)
  assert.equal(verified, null)
})

test('R1: isRootAdminAccount strictly requires explicit ADMIN or SUPER_ADMIN role', async () => {
  const { isRootAdminAccount } = await import('../superadmin-config')

  // Case 1: USER with superadmin phone MUST be rejected
  assert.equal(
    isRootAdminAccount({ phone: '9876543210', role: 'USER' }),
    false,
    'USER role with superadmin phone must not be elevated'
  )

  // Case 2: Undefined role with superadmin phone MUST be rejected
  assert.equal(
    isRootAdminAccount({ phone: '9876543210' }),
    false,
    'Missing/undefined role must never be promoted to root admin'
  )

  // Case 3: DELIVERY or PICKER role with superadmin phone MUST be rejected
  assert.equal(
    isRootAdminAccount({ phone: '9876543210', role: 'DELIVERY' }),
    false,
    'DELIVERY role with superadmin phone must not be elevated'
  )

  // Case 4: Branch Admin (assignedStoreId set) is NEVER root admin
  assert.equal(
    isRootAdminAccount({ phone: '9876543210', role: 'ADMIN', assignedStoreId: 'store_hub_1' }),
    false,
    'Branch admin with assignedStoreId must never be root admin'
  )

  // Case 5: Legitimate unassigned ADMIN with verified credentials succeeds
  assert.equal(
    isRootAdminAccount({ email: 'admin@fastkirana.com', role: 'ADMIN', assignedStoreId: null }),
    true,
    'Legitimate global unassigned ADMIN must succeed'
  )
})

test('R1: getEffectiveStoreId rejects non-admin users with superadmin phone', async () => {
  const { getEffectiveStoreId } = await import('../auth-guard')

  // Non-admin user cannot access arbitrary store via superadmin phone
  const userSession = {
    user: {
      id: 'usr_normal',
      role: 'USER',
      phone: '9876543210',
      email: 'user@test.com',
      assignedStoreId: null,
    }
  }

  const effectiveStore = getEffectiveStoreId(userSession, 'store_target_hub')
  assert.equal(effectiveStore, null, 'Non-admin user cannot obtain requested store ID')
})


