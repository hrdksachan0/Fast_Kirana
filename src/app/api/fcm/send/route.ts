import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { fcmMessaging } from '@/lib/firebase-admin'

/**
 * Send an FCM push notification.
 * Admin-only: broadcasts to all devices or targets a specific user/token.
 */
export async function POST(request: NextRequest) {
  const session = await auth()
  if (!session?.user || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized — Admin only' }, { status: 401 })
  }

  try {
    const body = await request.json()
    const { target, fcmToken, userId, title, body: notificationBody, data } = body

    if (!title || !notificationBody) {
      return NextResponse.json({ error: 'Title and body are required' }, { status: 400 })
    }

    const payload: admin.messaging.Message = {
      notification: { title, body: notificationBody },
      data: {
        ...data,
        title,
        body: notificationBody,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'fastkirana_alerts',
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    }

    let tokens: string[] = []
    let successCount = 0
    let failureCount = 0

    if (target === 'token' && fcmToken) {
      // Send to a single token
      tokens = [fcmToken]
      payload.token = fcmToken
    } else if (target === 'userId' && userId) {
      // Send to all tokens of a specific user
      const fcmRecords = await prisma.fcmToken.findMany({
        where: { userId },
        select: { token: true },
      })
      tokens = fcmRecords.map((r) => r.token)
      payload.tokens = tokens
    } else if (target === 'all') {
      // Broadcast to all FCM tokens
      const allTokens = await prisma.fcmToken.findMany({
        select: { token: true },
      })
      tokens = allTokens.map((r) => r.token)
      payload.tokens = tokens
    } else {
      return NextResponse.json(
        { error: 'Invalid target. Use "all", "userId", or "token"' },
        { status: 400 }
      )
    }

    if (tokens.length === 0) {
      return NextResponse.json({ success: true, successCount: 0, failureCount: 0, message: 'No tokens found' })
    }

    // Firebase Admin SDK v12 uses sendAll() for multicasting
    const response = await fcmMessaging.sendEachForMulticast({
      tokens,
      notification: payload.notification as admin.messaging.Notification,
      data: payload.data as Record<string, string>,
      android: payload.android as admin.messaging.AndroidConfig,
      apns: payload.apns as admin.messaging.ApnsConfig,
    })

    successCount = response.successCount
    failureCount = response.failureCount

    // Clean up invalid tokens
    const invalidTokens: string[] = []
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const error = resp.error
        if (error?.code === 'messaging/registration-token-not-registered' || error?.code === 'messaging/invalid-argument') {
          invalidTokens.push(tokens[idx])
        }
      }
    })

    if (invalidTokens.length > 0) {
      await prisma.fcmToken.deleteMany({
        where: { token: { in: invalidTokens } },
      })
    }

    return NextResponse.json({ success: true, successCount, failureCount, totalTargeted: tokens.length })
  } catch (error: any) {
    console.error('FCM send error:', error)
    return NextResponse.json({ error: 'Failed to send notification: ' + error.message }, { status: 500 })
  }
}
