import { SignJWT, jwtVerify } from 'jose'

function getSecretKey(): Uint8Array {
  const secret = process.env.AUTH_SECRET || process.env.NEXTAUTH_SECRET
  if (!secret || !secret.trim()) {
    throw new Error('AUTH_SECRET is not configured. JWT operations require a configured secret key.')
  }
  if (
    process.env.NODE_ENV === 'production' &&
    (secret.startsWith('ci_test_') || secret === 'placeholder' || secret === 'secret' || secret === 'changeme')
  ) {
    throw new Error('Insecure placeholder AUTH_SECRET detected in production environment')
  }
  return new TextEncoder().encode(secret.trim())
}

export interface FastKiranaJWTPayload {
  userId: string
  phone?: string | null
  email?: string | null
  role: string
  assignedStoreId?: string | null
  assignedRestaurantId?: string | null
  assignedVendorId?: string | null
  vendorId?: string | null
  vendor?: any
}

/**
 * Sign a cryptographic JWT token for mobile and API clients (valid for 30 days)
 */
export async function signFastKiranaJWT(payload: FastKiranaJWTPayload): Promise<string> {
  const key = getSecretKey()
  return new SignJWT({
    id: payload.userId,
    phone: payload.phone || null,
    email: payload.email || null,
    role: payload.role,
    assignedStoreId: payload.assignedStoreId || null,
    assignedRestaurantId: payload.assignedRestaurantId || null,
    assignedVendorId: payload.assignedVendorId || null,
    vendorId: payload.vendorId || null,
    vendor: payload.vendor || null,
  })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setIssuedAt()
    .setExpirationTime('30d')
    .sign(key)
}

/**
 * Verify a cryptographic JWT token and extract the trusted payload
 */
export async function verifyFastKiranaJWT(token: string): Promise<FastKiranaJWTPayload | null> {
  if (!token || typeof token !== 'string') return null
  const cleanToken = token.startsWith('Bearer ') ? token.slice(7).trim() : token.trim()
  if (!cleanToken) return null

  try {
    const key = getSecretKey()
    const { payload } = await jwtVerify(cleanToken, key, {
      algorithms: ['HS256'],
    })
    // 1. Expiration claim is strictly required
    if (!payload.exp || typeof payload.exp !== 'number') {
      return null
    }
    // 2. Reject single-purpose WebSocket tickets from acting as REST access tokens
    if (payload.scope === 'ws_ticket' || payload.type === 'ws_ticket') {
      return null
    }
    const userId = (payload.id as string) || (payload.sub as string)
    if (!userId) return null
    return {
      userId,
      phone: (payload.phone as string) || null,
      email: (payload.email as string) || null,
      role: (payload.role as string) || 'USER',
      assignedStoreId: (payload.assignedStoreId as string) || null,
      assignedRestaurantId: (payload.assignedRestaurantId as string) || null,
      assignedVendorId: (payload.assignedVendorId as string) || null,
      vendorId: (payload.vendorId as string) || null,
      vendor: payload.vendor || null,
    }
  } catch (err) {
    return null
  }
}

