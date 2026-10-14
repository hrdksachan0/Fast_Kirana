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

        // Fetch stored mobile device tokens
        const allTokens = await prisma.fcmToken.findMany({ select: { token: true } })
        const uniqueTokens = Array.from(new Set(allTokens.map((t) => t.token)))

        if (uniqueTokens.length > 0) {
          for (let i = 0; i < uniqueTokens.length; i += 500) {
            const chunk = uniqueTokens.slice(i, i + 500)
            const resp = await fcmMessaging.sendEachForMulticast({
              tokens: chunk,
              notification: fcmPayload.notification,
              data: fcmPayload.data,
              android: fcmPayload.android,
              apns: fcmPayload.apns,
            })
            if (resp) {
              fcmSuccessCount += resp.successCount || 0
              fcmFailureCount += resp.failureCount || 0
              if (resp.responses && resp.responses.length > 0) {
                await cleanupInvalidTokens(chunk, resp.responses).catch(() => {})
              }
            }
          }
        }

        // Broadcast to broadcast topics so all app installations (including guest users) receive it
        const topicPromises = ['all_users', 'ghatampur_alerts'].map((topic) =>
          fcmMessaging.send({
            topic,
            ...fcmPayload,
          })
        )

        const topicResults = await Promise.allSettled(topicPromises)
        topicResults.forEach((res, idx) => {
          const topicName = idx === 0 ? 'all_users' : 'ghatampur_alerts'
          if (res.status === 'fulfilled') {
            console.log(`[FCM Broadcast] Successfully dispatched to topic: ${topicName}`)
          } else {
            console.warn(`[FCM Broadcast] Topic dispatch failed for ${topicName}:`, res.reason)
          }
        })
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
