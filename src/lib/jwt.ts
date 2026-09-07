import { SignJWT, jwtVerify } from 'jose'

const secretString = process.env.AUTH_SECRET || process.env.NEXTAUTH_SECRET || 'fastkirana-production-secret-jwt-key-2026'
const SECRET_KEY = new TextEncoder().encode(secretString)

export interface FastKiranaJWTPayload {
  userId: string
  phone?: string | null
  email?: string | null
  role: string
  assignedStoreId?: string | null
  assignedRestaurantId?: string | null
}

/**
 * Sign a cryptographic JWT token for mobile and API clients (valid for 30 days)
 */
export async function signFastKiranaJWT(payload: FastKiranaJWTPayload): Promise<string> {
  return new SignJWT({
    id: payload.userId,
    phone: payload.phone || null,
    email: payload.email || null,
    role: payload.role,
    assignedStoreId: payload.assignedStoreId || null,
    assignedRestaurantId: payload.assignedRestaurantId || null,
  })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setIssuedAt()
    .setExpirationTime('30d')
    .sign(SECRET_KEY)
}

/**
 * Verify a cryptographic JWT token and extract the trusted payload
 */
export async function verifyFastKiranaJWT(token: string): Promise<FastKiranaJWTPayload | null> {
  if (!token || typeof token !== 'string') return null
  const cleanToken = token.startsWith('Bearer ') ? token.slice(7).trim() : token.trim()
  if (!cleanToken) return null

  try {
    const { payload } = await jwtVerify(cleanToken, SECRET_KEY)
    return {
      userId: (payload.id as string) || (payload.sub as string),
      phone: (payload.phone as string) || null,
      email: (payload.email as string) || null,
      role: (payload.role as string) || 'USER',
      assignedStoreId: (payload.assignedStoreId as string) || null,
      assignedRestaurantId: (payload.assignedRestaurantId as string) || null,
    }
  } catch (err) {
    return null
  }
}
