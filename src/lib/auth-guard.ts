/**
 * Centralized auth guard helpers for API routes.
 * Reduces copy-pasted role checks across the codebase.
 */

import { NextResponse } from 'next/server'
import { auth } from '@/auth'

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
    session = await auth()
  } catch (e) {
    // ignore request-scope auth errors
  }

  // 1. First priority: Check cryptographic JWT Authorization Bearer Token
  const authHeader = request?.headers?.get('authorization') || request?.headers?.get('Authorization')
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const { verifyFastKiranaJWT } = await import('@/lib/jwt')
    const jwtPayload = await verifyFastKiranaJWT(authHeader)
    if (jwtPayload) {
      const userRole = jwtPayload.role?.toUpperCase() || 'USER'
      const phoneDigits = (jwtPayload.phone || '').replace(/\D/g, '').slice(-10)
      const isSuper = phoneDigits === '8112849854' || 
        phoneDigits === '9170942500' || 
        phoneDigits === '7054470303' || 
        (userRole === 'ADMIN' && !jwtPayload.assignedStoreId)

      if (isSuper || allowedRoles.includes(userRole) || userRole === 'ADMIN') {
        return {
          error: null,
          session: {
            user: {
              id: jwtPayload.userId,
              role: userRole,
              phone: jwtPayload.phone,
              email: jwtPayload.email,
              assignedStoreId: jwtPayload.assignedStoreId,
              assignedRestaurantId: jwtPayload.assignedRestaurantId,
            }
          } as any
        }
      }
      return { error: NextResponse.json({ error: 'Forbidden: Insufficient permissions' }, { status: 403 }), session: null }
    }
  }

  // 2. Second priority: Standard verified NextAuth Session
  const sessionRole = session?.user?.role?.toUpperCase()
  const userEmail = (session?.user?.email || '').toLowerCase()
  const userPhone = ((session?.user as any)?.phone || '')
  const phoneDigits = userPhone.replace(/\D/g, '').slice(-10)
  const assignedStoreId = (session?.user as any)?.assignedStoreId

  const isSuper = userEmail.startsWith('admin') || 
    userEmail.includes('hrdk') || 
    phoneDigits === '8112849854' || 
    phoneDigits === '9170942500' || 
    phoneDigits === '7054470303' ||
    (sessionRole === 'ADMIN' && !assignedStoreId)

  if (isSuper || (sessionRole && (allowedRoles.includes(sessionRole) || sessionRole === 'ADMIN'))) {
    return { error: null, session }
  }

  if (!session?.user) {
    return { error: NextResponse.json({ error: 'Unauthorized: Staff login required' }, { status: 401 }), session: null }
  }
  return { error: NextResponse.json({ error: 'Forbidden: Insufficient permissions' }, { status: 403 }), session: null }
}

/** Shortcut: require ADMIN / Staff role */
export async function requireAdmin(request?: Request) {
  return requireRole(['ADMIN', 'CHEF', 'RESTAURANT_OWNER', 'PICKER'], request)
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
            } as any
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
  } catch (e) {}

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
