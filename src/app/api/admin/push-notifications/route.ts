import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { broadcastPushNotification } from '@/lib/push-notification'
import { apiWriteLimiter } from '@/lib/rate-limit'
import { requireAdmin } from '@/lib/auth-guard'
import { cleanupInvalidTokens } from '@/lib/fcm-utils'
import { fcmMessaging, buildOptimizedFcmPayload } from '@/lib/firebase-admin'

export async function GET(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error

  try {
    const notifications = await prisma.pushNotification.findMany({
      orderBy: { sentAt: 'desc' },
      take: 50,
    })

    const [webSubscriptionCount, mobileDeviceCount] = await Promise.all([
      prisma.pushSubscription.count(),
      prisma.fcmToken.count(),
    ])

    const totalSubscribers = webSubscriptionCount + mobileDeviceCount

    return NextResponse.json({
      notifications,
      subscriptionCount: totalSubscribers,
      webSubscriptionCount,
      mobileDeviceCount,
    })
  } catch (error) {
    console.error('Failed to fetch notifications:', error)
    return NextResponse.json({ error: 'Failed to fetch notifications' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  const limitResponse = await apiWriteLimiter.check(request)
  if (limitResponse) return limitResponse

  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error

  try {
    const body = await request.json()
    const { title, body: contentBody, imageUrl, linkUrl } = body

    if (!title || !contentBody) {
      return NextResponse.json({ error: 'Title and body are required' }, { status: 400 })
    }

    // 1. Build & broadcast to Web Push subscriptions (Browsers)
    const webPayload = {
      title,
      body: contentBody,
      icon: imageUrl || '/favicon.ico',
      badge: '/favicon.ico',
      data: {
        url: linkUrl || '/',
      },
    }

    const webStats = await broadcastPushNotification(webPayload)

    // 2. Broadcast to Mobile App devices (Flutter / FCM)
    let fcmSuccessCount = 0
    let fcmFailureCount = 0

    try {
      if (fcmMessaging) {
        // High-priority enterprise payload with 24h TTL and Doze wake-up
        const fcmPayload = buildOptimizedFcmPayload({
          title,
          body: contentBody,
          imageUrl: imageUrl || null,
          linkUrl: linkUrl || '/',
          category: 'offer',
          ttlSeconds: 86400, // 24 hours
        })

        // Count stored mobile devices for audit stats
        const allTokens = await prisma.fcmToken.findMany({ select: { token: true } })
        const uniqueTokens = Array.from(new Set(allTokens.map((t) => t.token)))

        // Broadcast ONCE to the universal 'all_users' topic.
        // Every installed Flutter app automatically subscribes to 'all_users' upon launch.
        // Sending strictly to 'all_users' guarantees that each device receives EXACTLY ONE notification,
        // eliminating the 3x duplication caused by sending to individual tokens + all_users + ghatampur_alerts.
        const topicResp = await fcmMessaging.send({
          topic: 'all_users',
          ...fcmPayload,
        })

        if (topicResp) {
          fcmSuccessCount = Math.max(1, uniqueTokens.length)
          console.log(`[FCM Broadcast] Successfully dispatched to universal topic 'all_users':`, topicResp)
        } else {
          fcmFailureCount = 1
        }
      }
    } catch (fcmErr) {
      console.error('Failed to broadcast mobile FCM notifications:', fcmErr)
    }

    // Combined delivery statistics
    const totalSuccess = webStats.successCount + fcmSuccessCount
    const totalFailure = webStats.failureCount + fcmFailureCount

    // Save notification log in database
    const notification = await prisma.pushNotification.create({
      data: {
        title,
        body: contentBody,
        imageUrl: imageUrl || null,
        linkUrl: linkUrl || null,
        successCount: totalSuccess,
        failureCount: totalFailure,
      },
    })

    return NextResponse.json(
      {
        ...notification,
        webSuccessCount: webStats.successCount,
        fcmSuccessCount,
      },
      { status: 201 }
    )
  } catch (error) {
    console.error('Failed to broadcast push notification:', error)
    return NextResponse.json({ error: 'Failed to send push notification' }, { status: 500 })
  }
}

export async function DELETE(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error

  try {
    const { searchParams } = new URL(request.url)
    const id = searchParams.get('id')
    const deleteAll = searchParams.get('all') === 'true'

    if (deleteAll) {
      const deleted = await prisma.pushNotification.deleteMany({})
      return NextResponse.json({
        success: true,
        message: 'All campaign history cleared successfully',
        count: deleted.count,
      })
    }

    if (!id) {
      return NextResponse.json(
        { error: 'Notification ID or all=true query parameter is required' },
        { status: 400 }
      )
    }

    await prisma.pushNotification.delete({
      where: { id },
    })

    return NextResponse.json({
      success: true,
      message: 'Campaign deleted successfully',
    })
  } catch (error) {
    console.error('Failed to delete push notification:', error)
    return NextResponse.json({ error: 'Failed to delete push notification' }, { status: 500 })
  }
}

