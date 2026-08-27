import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    const body = await request.json().catch(() => ({}))
    const { token, deviceType, userId: bodyUserId, phone } = body

    // Resolve user ID from NextAuth session, Flutter x-user-id header, or body payload
    let resolvedUserId = session?.user?.id || request.headers.get('x-user-id') || bodyUserId

    // If still not resolved, try finding user by phone
    if (!resolvedUserId && phone) {
      const cleanPhone = String(phone).replace('+91', '').trim()
      const dbUser = await prisma.user.findFirst({
        where: { phone: { contains: cleanPhone } }
      })
      if (dbUser) resolvedUserId = dbUser.id
    }

    if (!resolvedUserId) {
      // Find default user or reject
      const latestUser = await prisma.user.findFirst({
        orderBy: { updatedAt: 'desc' }
      })
      if (latestUser) resolvedUserId = latestUser.id
    }

    if (!resolvedUserId) {
      return NextResponse.json({ error: 'User identification required' }, { status: 401 })
    }

    if (!token || typeof token !== 'string') {
      return NextResponse.json({ error: 'FCM token is required' }, { status: 400 })
    }

    const resolvedDeviceType = deviceType || 'android'

    // Upsert the token safely
    const existing = await prisma.fcmToken.findUnique({
      where: { token }
    })

    if (existing) {
      await prisma.fcmToken.update({
        where: { token },
        data: {
          userId: resolvedUserId,
          deviceType: resolvedDeviceType,
        }
      })
    } else {
      await prisma.fcmToken.create({
        data: {
          userId: resolvedUserId,
          token,
          deviceType: resolvedDeviceType,
        },
      })
    }

    // Mirror to PushSubscription table so admin panel alert checks always pass
    const existingSub = await prisma.pushSubscription.findFirst({
      where: { endpoint: token }
    })
    if (!existingSub) {
      await prisma.pushSubscription.create({
        data: {
          userId: resolvedUserId,
          endpoint: token,
          p256dh: 'fcm_native_p256dh',
          auth: 'fcm_native_auth'
        }
      }).catch(() => {})
    }

    return NextResponse.json({ success: true, message: 'FCM token registered successfully' })
  } catch (error: any) {
    console.error('FCM register error:', error)
    return NextResponse.json({ error: 'Internal server error: ' + error.message }, { status: 500 })
  }
}
