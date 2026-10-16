import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/auth-guard'
import { sendPushNotification } from '@/lib/push-notification'
import { prisma } from '@/lib/prisma'
import { fcmMessaging } from '@/lib/firebase-admin'

export async function POST(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error

  try {
    const body = await request.json().catch(() => ({}))
    const { userId, title, body: contentBody, phone: rawPhone } = body

    if (!userId || !title || !contentBody) {
      return NextResponse.json({ error: 'Missing required fields: userId, title, body' }, { status: 400 })
    }

    // 1. Look up user in database by ID or phone
    let user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, phone: true, name: true, email: true },
    })

    // Resolve phone number
    const potentialPhones = [rawPhone, user?.phone, String(userId)].filter(Boolean)
    let cleanPhone = ''
    for (const p of potentialPhones) {
      const digits = String(p).replace(/\D/g, '').slice(-10)
      if (digits.length === 10) {
        cleanPhone = digits
        break
      }
    }

    if (!user && cleanPhone.length === 10) {
      user = await prisma.user.findFirst({
        where: { phone: { contains: cleanPhone } },
        select: { id: true, phone: true, name: true, email: true },
      })
    }

    let fcmTokensCount = 0
    let fcmTopicsCount = 0
    let webPushCount = 0

    // Collect all related user IDs (original userId, resolved user.id, and any user matching cleanPhone)
    const targetUserIds = new Set<string>([userId])
    if (user?.id) targetUserIds.add(user.id)

    if (cleanPhone.length === 10) {
      const phoneUsers = await prisma.user.findMany({
        where: { phone: { contains: cleanPhone } },
        select: { id: true },
      })
      phoneUsers.forEach((u) => targetUserIds.add(u.id))
    }

    const allUserIds = Array.from(targetUserIds)

    // 2. Send Firebase FCM Push Notification to Flutter mobile app
    if (fcmMessaging) {
      try {
        const collapseTag = `cart_${cleanPhone || userId}`
        const fcmPayload = {
          notification: {
            title,
            body: contentBody,
          },
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

        // Direct delivery to all active device FCM tokens
        const fcmRecords = await prisma.fcmToken.findMany({
          where: { userId: { in: allUserIds } },
          select: { token: true },
          orderBy: { createdAt: 'desc' },
          take: 10,
        })

        for (const rec of fcmRecords) {
          try {
            await fcmMessaging.send({
              token: rec.token,
              ...fcmPayload,
            })
            fcmTokensCount++
          } catch (tokErr) {
            console.warn('[FCM] Token dispatch warning:', tokErr)
          }
        }

        // Broadcast to mobile topic channels for instant fallback receipt
        if (cleanPhone.length === 10) {
          try {
            await fcmMessaging.send({
              topic: `phone_${cleanPhone}`,
              ...fcmPayload,
            })
            fcmTopicsCount++
          } catch (_) {}
        }

        for (const uid of allUserIds) {
          try {
            await fcmMessaging.send({
              topic: `user_${uid}`,
              ...fcmPayload,
            })
            fcmTopicsCount++
          } catch (_) {}
        }
      } catch (fcmErr) {
        console.error('FCM cart dispatch error:', fcmErr)
      }
    }

    // 3. Send WebPush Notification (for Web PWA / Browser users)
    const webPushOptions = {
      title,
      body: contentBody,
      icon: '/icons/icon-192.png',
      badge: '/icons/badge.png',
      tag: `cart_alert_${cleanPhone || userId}`,
      data: {
        url: '/cart',
      },
    }

    for (const uid of allUserIds) {
      try {
        await sendPushNotification(uid, webPushOptions)
        webPushCount++
      } catch (wpErr) {
        console.warn(`[WebPush] Dispatch error for user ${uid}:`, wpErr)
      }
    }

    console.log(
      `[LiveCartsNotify] Dispatched alert for user ${userId} (phone: ${cleanPhone || 'N/A'}): ` +
        `FCM tokens=${fcmTokensCount}, FCM topics=${fcmTopicsCount}, WebPush targets=${webPushCount}`
    )

    return NextResponse.json({
      success: true,
      delivered: {
        fcmTokens: fcmTokensCount,
        fcmTopics: fcmTopicsCount,
        webPushUsers: webPushCount,
      },
      message: 'Notification alert sent successfully to customer mobile app & web!',
    })
  } catch (error: any) {
    console.error('Failed to send live cart push notification:', error)
    return NextResponse.json({ error: 'Internal server error: ' + error.message }, { status: 500 })
  }
}
