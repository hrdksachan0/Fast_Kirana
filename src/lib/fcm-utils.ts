import { prisma } from './prisma'

/**
 * Retry wrapper for FCM sends. Retries on network/server errors only.
 * Does NOT retry on permanent errors (unregistered token, invalid argument).
 */
export async function sendTopicWithRetry(
  fcm: any,
  msg: any,
  retries = 2,
): Promise<any> {
  const permanentCodes = [
    'messaging/registration-token-not-registered',
    'messaging/invalid-argument',
    'messaging/mismatched-credential',
    'messaging/invalid-apns-credentials',
  ]

  for (let i = 0; i <= retries; i++) {
    try {
      return await fcm.send(msg)
    } catch (e: any) {
      const code = e?.code || e?.errorInfo?.code
      if (permanentCodes.includes(code) || i === retries) {
        throw e
      }
      await new Promise((r) => setTimeout(r, 400 * (i + 1)))
    }
  }
}

/**
 * Inspect multicast responses and delete revoked/invalid tokens from the DB.
 * Call this after every sendEachForMulticast.
 */
export async function cleanupInvalidTokens(
  tokens: string[],
  responses: any[],
): Promise<string[]> {
  const invalid: string[] = []
  responses.forEach((resp, idx) => {
    if (!resp.success) {
      const code = resp.error?.code
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-argument'
      ) {
        invalid.push(tokens[idx])
      }
    }
  })
  if (invalid.length > 0) {
    await prisma.fcmToken.deleteMany({ where: { token: { in: invalid } } })
  }
  return invalid
}

/**
 * Build the standard FCM payload used across all order-status and broadcast routes.
 */
export function buildOrderFcmPayload(
  title: string,
  body: string,
  data: Record<string, string>,
  ttlSeconds = 600,
) {
  const collapseId = data.orderId ? `order_${data.orderId}` : undefined

  const isOrderAlert =
    data.screen === 'restaurant-console' ||
    data.screen === 'admin-orders' ||
    data.screen === 'delivery' ||
    data.screen === 'picker' ||
    Boolean(data.restaurantId) ||
    data.type === 'NEW_ORDER' ||
    title.includes('Order') ||
    title.includes('🛎️') ||
    title.includes('💳') ||
    title.includes('👨‍🍳')

  return {
    notification: { title, body },
    data,
    android: {
      priority: 'high' as const,
      ttl: ttlSeconds,
      ...(collapseId ? { collapseKey: collapseId } : {}),
      notification: {
        channelId: isOrderAlert ? 'fastkirana_kitchen_alerts' : 'fastkirana_alerts',
        sound: isOrderAlert ? 'order_chime' : 'default',
        defaultSound: !isOrderAlert,
        defaultVibrateTimings: !isOrderAlert,
        ...(isOrderAlert ? { vibrateTimingsMillis: [0, 1000, 500, 1000, 500, 1000, 500, 1000] } : {}),
        visibility: 'PUBLIC' as const,
        priority: isOrderAlert ? ('MAX' as const) : ('HIGH' as const),
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        ...(collapseId ? { tag: collapseId } : {}),
      },
    },
    apns: {
      headers: {
        'apns-priority': '10',
        'apns-expiration': String(Math.floor(Date.now() / 1000) + ttlSeconds),
        ...(collapseId ? { 'apns-collapse-id': collapseId } : {}),
      },
      payload: {
        aps: {
          alert: { title, body },
          sound: 'default',
          badge: 1,
          'content-available': 1,
          'interruption-level': 'time-sensitive',
          'thread-id': data.readableId || data.orderId || 'fastkirana',
        },
      },
    },
  }
}
