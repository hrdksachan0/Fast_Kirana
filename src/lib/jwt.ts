import { SignJWT, jwtVerify, createRemoteJWKSet } from 'jose'

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

function getSupabaseSecretKey(): Uint8Array | null {
  const secret = process.env.SUPABASE_JWT_SECRET
  if (!secret || !secret.trim()) return null
  return new TextEncoder().encode(secret.trim())
}

let supabaseJWKS: any = null
function getSupabaseJWKS() {
  if (!supabaseJWKS) {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://bberzasmxwioxjynbuaf.supabase.co'
    supabaseJWKS = createRemoteJWKSet(new URL(`${supabaseUrl}/auth/v1/.well-known/jwks.json`))
  }
  return supabaseJWKS
}

function extractSupabasePayload(payload: any): FastKiranaJWTPayload {
  const userMeta = (payload.user_metadata as any) || {}
  const appMeta = (payload.app_metadata as any) || {}
  // Security: NEVER trust user_metadata for roles or privilege assignments (user-editable).
  // Only read authorization claims from app_metadata. Also map Postgres 'authenticated' -> 'USER'.
  const appRole = typeof appMeta.role === 'string' && appMeta.role.trim() ? appMeta.role.trim() : null
  return {
    userId: payload.sub,
    phone: (payload.phone as string) || (userMeta.phone as string) || null,
    email: (payload.email as string) || (userMeta.email as string) || null,
    role: appRole || 'USER',
    assignedStoreId: (appMeta.assignedStoreId as string) || null,
    assignedRestaurantId: (appMeta.assignedRestaurantId as string) || null,
    assignedVendorId: (appMeta.assignedVendorId as string) || null,
    vendorId: (appMeta.vendorId as string) || null,
    vendor: null,
  }
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
 * Verify a cryptographic JWT token and extract the trusted payload.
 * Supports Dual-Token Bridge:
 * 1. Checks FastMinute legacy JWT (signed with AUTH_SECRET)
 * 2. Checks Supabase Auth JWT (signed with HS256 shared secret or ECC P-256 via JWKS)
 * Guarantees zero logouts for existing app users during migration.
 */
export async function verifyFastKiranaJWT(token: string): Promise<FastKiranaJWTPayload | null> {
  if (!token || typeof token !== 'string') return null
  const cleanToken = token.startsWith('Bearer ') ? token.slice(7).trim() : token.trim()
  if (!cleanToken) return null

  // 1. First attempt: Verify using FastMinute legacy AUTH_SECRET
  try {
    const key = getSecretKey()
    const { payload } = await jwtVerify(cleanToken, key, {
      algorithms: ['HS256'],
    })
    // Expiration claim is strictly required
    if (payload.exp && typeof payload.exp === 'number') {
      // Reject single-purpose WebSocket tickets from acting as REST access tokens
      if (payload.scope !== 'ws_ticket' && payload.type !== 'ws_ticket') {
        const userId = (payload.id as string) || (payload.sub as string)
        if (userId) {
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
        }
      }
    }
  } catch (err) {
    // Legacy token verification failed or expired, try Supabase JWT next
  }

  const supabaseUrl = (process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://bberzasmxwioxjynbuaf.supabase.co').replace(/\/+$/, '')
  const expectedIssuer = `${supabaseUrl}/auth/v1`

  // 2. Second attempt: Dual-Token Bridge for Supabase Auth JWT (HS256 shared secret)
  const supabaseKey = getSupabaseSecretKey()
  if (supabaseKey) {
    try {
      const { payload } = await jwtVerify(cleanToken, supabaseKey, {
        algorithms: ['HS256'],
        audience: 'authenticated',
        issuer: expectedIssuer,
      })
      if (payload.exp && typeof payload.exp === 'number' && payload.sub && !payload.is_anonymous) {
        return extractSupabasePayload(payload)
      }
    } catch (err) {
      // Try JWKS next
    }
  }

  // 3. Third attempt: Supabase Auth ECC (P-256 / ES256) via JWKS
  try {
    const jwks = getSupabaseJWKS()
    const { payload } = await jwtVerify(cleanToken, jwks, {
      algorithms: ['ES256'],
      audience: 'authenticated',
      issuer: expectedIssuer,
    })
    if (payload.exp && typeof payload.exp === 'number' && payload.sub && !payload.is_anonymous) {
      return extractSupabasePayload(payload)
    }
  } catch (err) {
    // Neither legacy nor Supabase token was valid
  }

  return null
}



