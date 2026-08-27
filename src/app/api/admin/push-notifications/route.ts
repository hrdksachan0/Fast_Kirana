import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { broadcastPushNotification } from '@/lib/push-notification'
import { apiWriteLimiter } from '@/lib/rate-limit'
import { requireAdmin } from '@/lib/auth-guard'

export async function GET(request: NextRequest) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const notifications = await prisma.pushNotification.findMany({
      orderBy: { sentAt: 'desc' },
    })

    const subscriptionCount = await prisma.pushSubscription.count()

    return NextResponse.json({ notifications, subscriptionCount })
  } catch (error) {
    console.error('Failed to fetch notifications:', error)
    return NextResponse.json({ error: 'Failed to fetch notifications' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  const limitResponse = await apiWriteLimiter.check(request)
  if (limitResponse) return limitResponse

  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const body = await request.json()
    const { title, body: contentBody, imageUrl, linkUrl } = body

    if (!title || !contentBody) {
      return NextResponse.json({ error: 'Title and body are required' }, { status: 400 })
    }

    // Build the payload matching Web Push standards
    const payload = {
      title,
      body: contentBody,
      icon: imageUrl || '/favicon.ico',
      badge: '/favicon.ico',
      data: {
        url: linkUrl || '/',
      },
    }

    // Broadcast message to all active Web Push subscriptions
    const stats = await broadcastPushNotification(payload)

    // Broadcast message to all Mobile App users via Firebase FCM
    try {
      const { fcmMessaging } = await import('@/lib/firebase-admin')
      if (fcmMessaging) {
        const fcmPayload: any = {
          notification: {
            title,
            body: contentBody,
            ...(imageUrl ? { imageUrl } : {}),
          },
          data: {
            title,
            body: contentBody,
            url: linkUrl || '/',
            category: 'offer',
            timestamp: Date.now().toString(),
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'fastkirana_alerts',
              sound: 'default',
              defaultSound: true,
              defaultVibrateTimings: true,
              visibility: 'PUBLIC',
              priority: 'HIGH',
              clickAction: 'FLUTTER_NOTIFICATION_CLICK',
              ...(imageUrl ? { imageUrl } : {}),
            },
          },
          apns: {
            headers: { 'apns-priority': '10' },
            payload: {
              aps: {
                alert: { title, body: contentBody },
                sound: 'default',
                badge: 1,
                contentAvailable: true,
              },
            },
          },
        }

        // 1. Broadcast to all_users topic
        await fcmMessaging.send({
          topic: 'all_users',
          ...fcmPayload,
        }).catch((err) => console.error('FCM broadcast to all_users failed:', err))

        // 2. Broadcast to ghatampur_alerts topic
        await fcmMessaging.send({
          topic: 'ghatampur_alerts',
          ...fcmPayload,
        }).catch((err) => console.error('FCM broadcast to ghatampur_alerts failed:', err))

        // 3. Multicast to all stored FCM device tokens
        const allTokens = await prisma.fcmToken.findMany({ select: { token: true } })
        if (allTokens.length > 0) {
          const tokens = allTokens.map((t) => t.token)
          // Send in chunks of 500
          for (let i = 0; i < tokens.length; i += 500) {
            const chunk = tokens.slice(i, i + 500)
            await fcmMessaging.sendEachForMulticast({
              tokens: chunk,
              notification: fcmPayload.notification,
              data: fcmPayload.data as Record<string, string>,
              android: fcmPayload.android,
              apns: fcmPayload.apns,
            }).catch(() => {})
          }
        }
      }
    } catch (fcmErr) {
      console.error('Failed to broadcast mobile FCM notifications:', fcmErr)
    }

    // Save notification log in database
    const notification = await prisma.pushNotification.create({
      data: {
        title,
        body: contentBody,
        imageUrl: imageUrl || null,
        linkUrl: linkUrl || null,
        successCount: stats.successCount,
        failureCount: stats.failureCount,
      },
    })

    return NextResponse.json(notification, { status: 201 })
  } catch (error) {
    console.error('Failed to broadcast push notification:', error)
    return NextResponse.json({ error: 'Failed to send push notification' }, { status: 500 })
  }
}
