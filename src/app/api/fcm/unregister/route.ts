import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

/**
 * Unregister an FCM token (and matching push subscription) on logout.
 * Ensures a device logged out from Admin/Staff/Restaurant never keeps receiving staff alerts.
 */
export async function POST(request: NextRequest) {
  try {
    const session = await auth().catch(() => null)
    const body = await request.json().catch(() => ({}))
    const token = typeof body?.token === 'string' ? body.token.trim() : ''
    const userId = session?.user?.id || (typeof body?.userId === 'string' ? body.userId.trim() : '')

    if (!token && !userId) {
      return NextResponse.json({ error: 'FCM token is required' }, { status: 400 })
    }

    if (token) {
      await prisma.fcmToken.deleteMany({
        where: { token },
      })
      await prisma.pushSubscription.deleteMany({
        where: { endpoint: token },
      })
    }

    return NextResponse.json({
      success: true,
      message: 'FCM token unregistered successfully',
    })
  } catch (error: any) {
    console.error('FCM unregister error:', error)
    return NextResponse.json(
      { error: 'Internal server error: ' + (error?.message || String(error)) },
      { status: 500 }
    )
  }
}
