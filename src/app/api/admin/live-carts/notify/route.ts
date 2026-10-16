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

    // Collect related user IDs
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
    // STRICT ANTI-DUPLICATION: Send via Device Token OR Topic Fallback (NEVER BOTH!)
    if (fcmMessaging) {
      try {
        const collapseTag = `cart_alert`
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

        // Check for active device tokens first
        const fcmRecords = await prisma.fcmToken.findMany({
          where: { userId: { in: allUserIds } },
          select: { token: true },
          orderBy: { createdAt: 'desc' },
          take: 5,
        })

        const uniqueTokens = Array.from(new Set(fcmRecords.map((r) => r.token).filter(Boolean)))

        if (uniqueTokens.length > 0) {
          // Direct delivery: send ONLY to active device tokens (prevents 2x/3x topic duplicates!)
          for (const tok of uniqueTokens) {
            try {
              await fcmMessaging.send({
                token: tok,
                ...fcmPayload,
              })
              fcmTokensCount++
            } catch (tokErr) {
              console.warn('[FCM] Token dispatch warning:', tokErr)
            }
          }
        } else {
          // Fallback ONLY when user has no registered device token in database
          if (cleanPhone.length === 10) {
            try {
              await fcmMessaging.send({
                topic: `phone_${cleanPhone}`,
                ...fcmPayload,
              })
              fcmTopicsCount++
            } catch (_) {}
          } else {
            try {
              await fcmMessaging.send({
                topic: `user_${userId}`,
                ...fcmPayload,
              })
              fcmTopicsCount++
            } catch (_) {}
          }
        }
      } catch (fcmErr) {
        console.error('FCM cart dispatch error:', fcmErr)
      }
    }

    // 3. Send WebPush Notification (for Web PWA / Browser users)
    // Send to primary userId only to avoid duplicate WebPush across alias IDs
    const webPushOptions = {
      title,
      body: contentBody,
      icon: '/icons/icon-192.png',
      badge: '/icons/badge.png',
      tag: `cart_alert`,
      data: {
        url: '/cart',
      },
    }

    for (const uid of allUserIds) {
      try {
        await sendPushNotification(uid, webPushOptions)
        webPushCount++
        break // Stop after first matched user ID so the browser only receives 1 notification
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
