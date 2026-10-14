/**
 * Centralized auth guard helpers for API routes.
 * Reduces copy-pasted role checks across the codebase.
 */

import { NextResponse } from 'next/server'
import { jwtVerify } from 'jose'
import { auth, verifiedAuth } from '@/auth'
import { isRootAdminAccount } from '@/lib/superadmin-config'
import { logger } from '@/lib/logger'

export interface VerifiedGuardUser {
  id: string
  role: string
  email: string | null
  phone: string | null
  assignedStoreId: string | null
  assignedRestaurantId: string | null
  isBlocked: boolean
  deletedAt: Date | null
}

export interface VerifiedRoleDependencies {
  getSession: () => Promise<{ user?: { id?: unknown } } | null>
  verifyBearer: (authorization: string) => Promise<{ userId?: unknown } | null>
  findUser: (id: string) => Promise<VerifiedGuardUser | null>
}

/**
 * Sensitive endpoints must prove identity before looking up account metadata.
 * Claims establish only the ID; current database role/scope decide access.
 * Dependencies also make credential and database failures testable offline.
 */
export function createVerifiedRoleGuard(dependencies: VerifiedRoleDependencies) {
  return async (allowedRoles: string[], request?: Request) => {
    const denied = (message: string, status: number) => ({
      error: NextResponse.json({ error: message }, { status }),
      session: null,
    })
    let authenticatedId: unknown
    try {
      const authorization = request?.headers.get('authorization')
      if (authorization) {
        if (!authorization.startsWith('Bearer ')) return denied('Unauthorized: Valid credentials required', 401)
        const identity = await dependencies.verifyBearer(authorization)
        authenticatedId = identity?.userId
      } else {
        const session = await dependencies.getSession()
        authenticatedId = session?.user?.id
      }
    } catch {
      return denied('Unauthorized: Credentials could not be verified', 401)
    }
    // Never use email, phone, role, or x-user-* headers as identity evidence.
    if (typeof authenticatedId !== 'string' || !authenticatedId.trim() || authenticatedId.startsWith('mock-id-')) {
      return denied('Unauthorized: Authenticated user ID required', 401)
    }
    let user: VerifiedGuardUser | null
    try {
      user = await dependencies.findUser(authenticatedId)
    } catch {
      return denied('Authorization is unavailable. Please try again.', 503)
    }
    if (!user || user.deletedAt) return denied('Unauthorized: Account is unavailable', 401)
    if (user.isBlocked) return denied('Forbidden: Account is blocked', 403)
    const role = user.role.toUpperCase()
    if (!allowedRoles.some(value => value.toUpperCase() === role)) return denied('Forbidden: Insufficient permissions', 403)
    return {
      error: null,
      session: {
        user: {
          id: user.id, role, email: user.email, phone: user.phone,
          assignedStoreId: user.assignedStoreId,
          assignedRestaurantId: user.assignedRestaurantId,
        },
      },
    }
  }
}

/** Campaign tokens require the configured signing key, HS256, and expiry. */
export async function verifyCampaignBearer(authorization: string): Promise<{ userId: string } | null> {
  const secret = process.env.AUTH_SECRET || process.env.NEXTAUTH_SECRET
  const token = authorization.match(/^Bearer (\S+)$/)?.[1]
  if (!secret?.trim() || !token) return null
  try {
    const { payload } = await jwtVerify(token, new TextEncoder().encode(secret), {
      algorithms: ['HS256'],
      requiredClaims: ['exp'],
    })
    if (payload.scope === 'ws_ticket' || payload.type === 'ws_ticket') {
      return null
    }
    const userId = payload.id || payload.sub
    return typeof userId === 'string' && userId.trim() ? { userId } : null
  } catch {
    return null
  }
}

/** Verified NextAuth cookie session or signed Bearer; no identity-header fallback. */
export const requireVerifiedRole = createVerifiedRoleGuard({
  getSession: async () => await verifiedAuth(),
  verifyBearer: verifyCampaignBearer,
  findUser: async id => {
    const { prisma } = await import('@/lib/prisma')
    return prisma.user.findUnique({
      where: { id },
      select: {
        id: true, role: true, email: true, phone: true,
        assignedStoreId: true, assignedRestaurantId: true,
        isBlocked: true, deletedAt: true,
      },
    })
  },
})

/**
 * Requires an authenticated user with one of the given roles.
 * Returns the session if authorized, or a NextResponse error if not.
 *
 * Usage:
 *   const { error, session } = await requireRole(['ADMIN'])
 *   if (error) return error
 */
export async function requireRole(allowedRoles: string[], request?: Request) {
  let session = null
  try {
    session = request ? await (auth as any)(request) : await auth()
    if (!session && request) {
      session = await auth()
    }
  } catch (e) {
    logger.warn('auth', 'Auth check failed in requireRole', e)
  }

  let reqHeaders = request?.headers
  if (!reqHeaders) {
    try {
      const { headers } = await import('next/headers')
      reqHeaders = (await headers()) as any
    } catch (_) {}
  }

  // 1. First priority: Check cryptographic JWT Authorization Bearer Token
  const authHeader = reqHeaders?.get('authorization') || reqHeaders?.get('Authorization')
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const { verifyFastKiranaJWT } = await import('@/lib/jwt')
    const jwtPayload = await verifyFastKiranaJWT(authHeader)
    if (jwtPayload) {
      let dbUser: any = null
      try {
        const { prisma } = await import('@/lib/prisma')
        dbUser = await prisma.user.findUnique({
          where: { id: jwtPayload.userId },
          select: { id: true, role: true, email: true, phone: true, isBlocked: true, deletedAt: true, assignedStoreId: true, assignedRestaurantId: true }
        })
      } catch (err) {
        console.error('requireRole Bearer DB lookup error:', err)
        return { error: NextResponse.json({ error: 'Service Unavailable: Authentication service degraded' }, { status: 503 }), session: null }
      }

      if (!dbUser || dbUser.isBlocked || dbUser.deletedAt) {
        return { error: NextResponse.json({ error: 'Unauthorized: Account is unavailable or blocked' }, { status: 401 }), session: null }
      }

      const userRole = (dbUser.role || 'USER').toUpperCase()
      const userPhone = dbUser.phone || jwtPayload.phone || ''
      const userEmail = dbUser.email || jwtPayload.email || ''
      const assignedStoreId = dbUser.assignedStoreId ?? null
      const assignedRestaurantId = dbUser.assignedRestaurantId ?? null

      const isSuper = (userRole === 'ADMIN' || userRole === 'SUPER_ADMIN') &&
        isRootAdminAccount({ email: userEmail, phone: userPhone, role: userRole, assignedStoreId })

      if (isSuper || allowedRoles.includes(userRole) || userRole === 'ADMIN' || userRole === 'SUPER_ADMIN') {
        return {
          error: null,
          session: {
            user: {
              id: dbUser.id,
              role: userRole as any,
              phone: userPhone,
              email: userEmail,
              assignedStoreId,
              assignedRestaurantId,
            }
          }
        }
      }
      return { error: NextResponse.json({ error: 'Forbidden: Insufficient permissions' }, { status: 403 }), session: null }
    }
  }

  // 2. Second priority: Standard verified NextAuth Session
  if (session?.user) {
    let sessionRole = session.user.role?.toUpperCase()
    let userEmail = (session.user.email || '').toLowerCase()
    let userPhone = (session.user.phone || '')
    let phoneDigits = userPhone.replace(/\D/g, '').slice(-10)
    let assignedStoreId = session.user.assignedStoreId

    // Always ensure assignedStoreId is fresh from DB for staff roles and verify active status
    if (!session.user.id) {
      return { error: NextResponse.json({ error: 'Unauthorized: Session missing user ID' }, { status: 401 }), session: null }
    }

    try {
      const { prisma } = await import('@/lib/prisma')
        const dbUser = await prisma.user.findUnique({
          where: { id: session.user.id },
          select: { id: true, role: true, email: true, phone: true, isBlocked: true, deletedAt: true, assignedStoreId: true, assignedRestaurantId: true }
        })
        if (!dbUser || dbUser.isBlocked || dbUser.deletedAt !== null) {
          return { error: NextResponse.json({ error: 'Unauthorized: Account is unavailable or blocked' }, { status: 401 }), session: null }
        }
        sessionRole = dbUser.role?.toUpperCase() || sessionRole
        session.user.role = sessionRole as any
        session.user.assignedStoreId = dbUser.assignedStoreId || null
        session.user.assignedRestaurantId = dbUser.assignedRestaurantId || null
        assignedStoreId = dbUser.assignedStoreId || null
        if (dbUser.phone) session.user.phone = dbUser.phone
      } catch (err) {
        console.error('requireRole session DB lookup error:', err)
        return { error: NextResponse.json({ error: 'Service Unavailable: Authentication service degraded' }, { status: 503 }), session: null }
      }

    const isSuper = (sessionRole === 'ADMIN' || sessionRole === 'SUPER_ADMIN') &&
      isRootAdminAccount({
        email: userEmail,
        phone: userPhone,
        role: sessionRole,
        assignedStoreId,
      })

    if (isSuper || (sessionRole && (allowedRoles.includes(sessionRole) || sessionRole === 'ADMIN' || sessionRole === 'SUPER_ADMIN'))) {
      return { error: null, session }
    }
  }

  // Insecure header-based identity fallbacks (x-user-*) are explicitly rejected.
  // Authentication requires either a valid cryptographic Bearer token or a verified NextAuth session.

  if (!session?.user) {
    return { error: NextResponse.json({ error: 'Unauthorized: Staff login required' }, { status: 401 }), session: null }
  }
  return { error: NextResponse.json({ error: 'Forbidden: Insufficient permissions' }, { status: 403 }), session: null }
}

/** Shortcut: require ADMIN / Staff role */
export async function requireAdmin(request?: Request) {
  return requireRole(['ADMIN', 'SUPER_ADMIN', 'STORE_MANAGER', 'CHEF', 'RESTAURANT_OWNER', 'PICKER', 'STAFF'], request)
}

/**
 * Requires an authenticated user who is either the owner of the order
 * OR has one of the staff roles (ADMIN, DELIVERY, PICKER, CHEF, RESTAURANT_OWNER).
 * Returns the session if authorized, or a NextResponse error if not.
 *
 * Usage:
 *   const { error, session } = await requireOrderAccess(order.userId, [], request)
 *   if (error) return error
 */
export async function requireOrderAccess(orderUserId: string, extraRoles: string[] = [], request?: Request, orderStoreId?: string | null) {
  // 1. Check Bearer token first
  const authHeader = request?.headers?.get('authorization') || request?.headers?.get('Authorization')
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const { verifyFastKiranaJWT } = await import('@/lib/jwt')
    const jwtPayload = await verifyFastKiranaJWT(authHeader)
    if (jwtPayload) {
      const { prisma } = await import('@/lib/prisma')
      const dbUser = await prisma.user.findUnique({
        where: { id: jwtPayload.userId },
        select: { id: true, role: true, phone: true, email: true, isBlocked: true, deletedAt: true, assignedStoreId: true, assignedRestaurantId: true }
      })
      if (dbUser && !dbUser.isBlocked && !dbUser.deletedAt) {
        const staffRoles = ['ADMIN', 'DELIVERY', 'PICKER', 'CHEF', 'RESTAURANT_OWNER', ...extraRoles]
        const isOwner = orderUserId === dbUser.id
        const isStaff = staffRoles.includes(dbUser.role)
        if (isOwner || isStaff) {
          // Cross-hub isolation: branch staff can only access orders belonging to their assigned store
          if (isStaff && !isOwner && dbUser.assignedStoreId && orderStoreId && dbUser.assignedStoreId !== orderStoreId) {
            return { error: NextResponse.json({ error: 'Forbidden: Access restricted to your assigned hub' }, { status: 403 }), session: null }
          }
          return {
            error: null,
            session: {
              user: {
                id: dbUser.id,
                role: dbUser.role,
                phone: dbUser.phone,
                email: dbUser.email,
                assignedStoreId: dbUser.assignedStoreId,
                assignedRestaurantId: dbUser.assignedRestaurantId,
              }
            }
          }
        }
        return { error: NextResponse.json({ error: 'Forbidden' }, { status: 403 }), session: null }
      }
    }
  }

  // 2. NextAuth Session
  let session = null
  try {
    session = await auth()
  } catch (e) {
    logger.warn('auth', 'Auth check failed in requireOrderAccess', e)
  }

  if (!session?.user) {
    return { error: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }), session: null }
  }

  const staffRoles = ['ADMIN', 'DELIVERY', 'PICKER', 'CHEF', 'RESTAURANT_OWNER', ...extraRoles]
  const isOwner = orderUserId === session.user.id
  const isStaff = staffRoles.includes(session.user.role)
  if (!isOwner && !isStaff) {
    return { error: NextResponse.json({ error: 'Forbidden' }, { status: 403 }), session: null }
  }

  // Cross-hub isolation: branch staff can only access orders belonging to their assigned store
  if (isStaff && !isOwner) {
    const userAssignedStoreId = session.user.assignedStoreId
    if (userAssignedStoreId && orderStoreId && userAssignedStoreId !== orderStoreId) {
      return { error: NextResponse.json({ error: 'Forbidden: Access restricted to your assigned hub' }, { status: 403 }), session: null }
    }
  }

  return { error: null, session }
}

/**
 * Resolves the effective storeId for an API request or dashboard view.
 * For branch admins (who have assignedStoreId), STRICTLY returns their assignedStoreId.
 * They are NEVER allowed to switch to or query data from another store hub.
 * For superadmins, returns requestedStoreId if provided (or null for all).
 */
export function getEffectiveStoreId(session: any, requestedStoreId?: string | null): string | null {
  const user = session?.user
  if (!user) return null

  const assignedStoreId = user.assignedStoreId
  if (assignedStoreId) {
    // Hub Branch Admin / Staff: strictly locked to their assigned store!
    return assignedStoreId
  }

  const email = (user.email || '').toLowerCase()
  const phone = (user.phone || '').replace(/\D/g, '').slice(-10)
  const role = (user.role || '').toUpperCase()

  const isSuper = (role === 'ADMIN' || role === 'SUPER_ADMIN') &&
    isRootAdminAccount({
      email,
      phone,
      role,
      assignedStoreId: null,
    })

  if (isSuper) {
    return requestedStoreId && requestedStoreId !== 'ALL' && requestedStoreId !== 'all'
      ? requestedStoreId
      : null
  }

  return null
}
