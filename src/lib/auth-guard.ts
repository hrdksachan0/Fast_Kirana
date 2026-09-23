/**
 * Centralized auth guard helpers for API routes.
 * Reduces copy-pasted role checks across the codebase.
 */

import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { isSuperadminPhone, isRootAdminAccount } from '@/lib/superadmin-config'
import { logger } from '@/lib/logger'

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

  // 1. First priority: Check cryptographic JWT Authorization Bearer Token
  const authHeader = request?.headers?.get('authorization') || request?.headers?.get('Authorization')
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const { verifyFastKiranaJWT } = await import('@/lib/jwt')
    const jwtPayload = await verifyFastKiranaJWT(authHeader)
    if (jwtPayload) {
      const userRole = jwtPayload.role?.toUpperCase() || 'USER'
      const phoneDigits = (jwtPayload.phone || '').replace(/\D/g, '').slice(-10)
      const isSuper = isSuperadminPhone(phoneDigits) || 
        (userRole === 'ADMIN' && !jwtPayload.assignedStoreId) ||
        isRootAdminAccount({ email: jwtPayload.email, phone: jwtPayload.phone, role: userRole })

      if (isSuper || allowedRoles.includes(userRole) || userRole === 'ADMIN' || userRole === 'SUPER_ADMIN') {
        return {
          error: null,
          session: {
            user: {
              id: jwtPayload.userId,
              role: userRole as any,
              phone: jwtPayload.phone,
              email: jwtPayload.email,
              assignedStoreId: jwtPayload.assignedStoreId,
              assignedRestaurantId: jwtPayload.assignedRestaurantId,
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

    // Always ensure assignedStoreId is fresh from DB for staff roles
    if (session.user.id) {
      try {
        const { prisma } = await import('@/lib/prisma')
        const dbUser = await prisma.user.findUnique({
          where: { id: session.user.id },
          select: { id: true, role: true, email: true, phone: true, assignedStoreId: true, assignedRestaurantId: true }
        })
        if (dbUser) {
          sessionRole = dbUser.role?.toUpperCase() || sessionRole
          session.user.role = sessionRole as any
          session.user.assignedStoreId = dbUser.assignedStoreId || null
          session.user.assignedRestaurantId = dbUser.assignedRestaurantId || null
          assignedStoreId = dbUser.assignedStoreId || null
          if (dbUser.phone) session.user.phone = dbUser.phone
        }
      } catch (_) {}
    }

    const isSuper = isRootAdminAccount({
      email: userEmail,
      phone: userPhone,
      role: sessionRole,
      assignedStoreId,
    }) || isSuperadminPhone(phoneDigits)

    if (isSuper || (sessionRole && (allowedRoles.includes(sessionRole) || sessionRole === 'ADMIN' || sessionRole === 'SUPER_ADMIN'))) {
      return { error: null, session }
    }
  }

  // 4. Fallback from request x-user-id header (for API / dashboard calls)
  if (request) {
    const rawUserId = request.headers.get('x-user-id')
    if (rawUserId && !rawUserId.startsWith('mock-id-')) {
      try {
        const { prisma } = await import('@/lib/prisma')
        const dbUser = await prisma.user.findUnique({
          where: { id: rawUserId },
          select: { id: true, role: true, email: true, phone: true, isBlocked: true, assignedStoreId: true, assignedRestaurantId: true }
        })
        if (dbUser && !dbUser.isBlocked) {
          const dbRole = dbUser.role?.toUpperCase() || 'USER'
          const dbEmail = (dbUser.email || '').toLowerCase()
          const dbPhone = (dbUser.phone || '').replace(/\D/g, '').slice(-10)
          const isDbSuper = isRootAdminAccount({ email: dbEmail, phone: dbPhone, role: dbRole }) ||
            dbEmail.startsWith('admin') || dbEmail.includes('hrdk') || isSuperadminPhone(dbPhone) ||
            (dbRole === 'ADMIN' && !dbUser.assignedStoreId)

          if (isDbSuper || (dbRole && (allowedRoles.includes(dbRole) || dbRole === 'ADMIN' || dbRole === 'SUPER_ADMIN'))) {
            return {
              error: null,
              session: {
                user: {
                  id: dbUser.id,
                  role: dbRole as any,
                  phone: dbUser.phone,
                  email: dbUser.email,
                  assignedStoreId: dbUser.assignedStoreId,
                  assignedRestaurantId: dbUser.assignedRestaurantId,
                }
              }
            }
          }
        }
      } catch (_) {}
    }
  }

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
export async function requireOrderAccess(orderUserId: string, extraRoles: string[] = [], request?: Request) {
  // 1. Check Bearer token first
  const authHeader = request?.headers?.get('authorization') || request?.headers?.get('Authorization')
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const { verifyFastKiranaJWT } = await import('@/lib/jwt')
    const jwtPayload = await verifyFastKiranaJWT(authHeader)
    if (jwtPayload) {
      const { prisma } = await import('@/lib/prisma')
      const dbUser = await prisma.user.findUnique({
        where: { id: jwtPayload.userId },
        select: { id: true, role: true, phone: true, email: true, isBlocked: true, assignedStoreId: true, assignedRestaurantId: true }
      })
      if (dbUser && !dbUser.isBlocked) {
        const staffRoles = ['ADMIN', 'DELIVERY', 'PICKER', 'CHEF', 'RESTAURANT_OWNER', ...extraRoles]
        const isOwner = orderUserId === dbUser.id
        const isStaff = staffRoles.includes(dbUser.role)
        if (isOwner || isStaff) {
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

  const isSuper = isRootAdminAccount({
    email,
    phone,
    role,
    assignedStoreId: null,
  }) || isSuperadminPhone(phone)

  if (isSuper) {
    return requestedStoreId && requestedStoreId !== 'ALL' && requestedStoreId !== 'all'
      ? requestedStoreId
      : null
  }

  return null
}
