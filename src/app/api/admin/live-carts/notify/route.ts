import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { sendPushNotification } from '@/lib/push-notification'
import { prisma } from '@/lib/prisma'
import { fcmMessaging } from '@/lib/firebase-admin'

export async function POST(request: NextRequest) {
  const session = await auth()
  if (!session || (session.user as any).role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const body = await request.json()
    const { userId, title, body: contentBody } = body

    if (!userId || !title || !contentBody) {
      return NextResponse.json({ error: 'Missing required fields: userId, title, body' }, { status: 400 })
    }

    // Verify user exists in database (by id or phone)
    let user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, phone: true, name: true }
    })

    if (!user) {
      const cleanInput = String(userId).replace(/\D/g, '').slice(-10)
      if (cleanInput.length === 10) {
        user = await prisma.user.findFirst({
          where: { phone: { contains: cleanInput } },
          select: { id: true, phone: true, name: true }
        })
      }
    }

    const cleanPhone = (user?.phone || String(userId)).replace(/\D/g, '').slice(-10)

    let fcmDispatched = false

    // 1. Send Firebase FCM Push Notification to Flutter mobile app
    if (fcmMessaging) {
      try {
        const collapseTag = `cart_${cleanPhone || userId}`
        const fcmPayload = {
          notification: { title, body: contentBody },
          data: {
            title,
            body: contentBody,
            type: 'CART_ALERT',
            url: '/cart',
            timestamp: Date.now().toString(),
          },
          android: {
            priority: 'high' as const,
            collapseKey: collapseTag,
            notification: {
              channelId: 'fastkirana_alerts',
              sound: 'default',
              clickAction: 'FLUTTER_NOTIFICATION_CLICK',
              tag: collapseTag,
            },
          },
          apns: {
            headers: {
              'apns-collapse-id': collapseTag,
            },
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        }

        // Find user's latest active FCM token
        let userIds = [userId]
        if (cleanPhone.length === 10) {
          const matchingUsers = await prisma.user.findMany({
            where: { phone: { contains: cleanPhone } },
            select: { id: true },
          })
          userIds = Array.from(new Set([...userIds, ...matchingUsers.map(u => u.id)]))
        }

        const fcmRecords = await prisma.fcmToken.findMany({
          where: { userId: { in: userIds } },
          select: { token: true },
          orderBy: { createdAt: 'desc' },
          take: 1,
        })

        if (fcmRecords.length > 0) {
          // Direct 1-push delivery to active device
          await fcmMessaging.send({
            token: fcmRecords[0].token,
            ...fcmPayload
          })
          fcmDispatched = true
        } else if (cleanPhone.length === 10) {
          // Fallback to topic only if no registered token in DB
          await fcmMessaging.send({
            topic: `phone_${cleanPhone}`,
            ...fcmPayload
          }).catch(() => {})
          fcmDispatched = true
        }
      } catch (fcmErr) {
        console.error('FCM cart dispatch error:', fcmErr)
      }
    }

    // 2. Send WebPush Notification (for Web PWA users)
    try {
      await sendPushNotification(userId, {
        title,
        body: contentBody,
        icon: '/favicon.ico',
        badge: '/favicon.ico',
        data: {
          url: '/cart'
        }
      })
    } catch (_) {}

    return NextResponse.json({ 
      success: true, 
      message: 'Push notification sent successfully to customer mobile app!' 
    })
  } catch (error: any) {
    console.error('Failed to send live cart push notification:', error)
    return NextResponse.json({ error: 'Internal server error: ' + error.message }, { status: 500 })
  }
}
