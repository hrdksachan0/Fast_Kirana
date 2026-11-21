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

export function getUniversalOrderCollapseId(readableId?: string | null, orderId?: string | null): string {
  for (const target of [readableId, orderId]) {
    if (target) {
      const s = String(target).trim()
      if (!s.startsWith('cmq') && !s.startsWith('cl') && s.length < 16) {
        const m = s.match(/(\d{3,6})/)
        if (m) return `order_${m[1]}`
      }
    }
  }
  const raw = String(orderId || readableId || '').trim()
  const clean = raw.replace(/[^a-zA-Z0-9_-]/g, '').toLowerCase()
  return clean ? `order_${clean}` : 'order_general'
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
  const isCustomerTracking =
    !isOrderAlert &&
    (data.role === 'CUSTOMER' ||
      data.screen === 'order-tracking' ||
      data.isLiveTracking === 'true' ||
      Boolean(data.readableId || data.orderId))

  // Blinkit/Zepto standard: Unified live tracking tag prevents stacking multiple cards
  const collapseId = isCustomerTracking
    ? 'fastminute_live_tracking'
    : getUniversalOrderCollapseId(data.readableId, data.orderId)

  const channelId = isOrderAlert
    ? 'fastminute_order_alarm_v3'
    : isCustomerTracking
      ? 'fastkirana_live_tracking_v1'
      : 'fastkirana_alerts'

  return {
    notification: { title, body },
    data,
    android: {
      priority: 'high' as const,
      ttl: ttlSeconds,
      ...(collapseId ? { collapseKey: collapseId } : {}),
      notification: {
        channelId,
        sound: isOrderAlert ? 'order_chime' : undefined,
        defaultSound: !isOrderAlert && !isCustomerTracking,
        defaultVibrateTimings: !isOrderAlert && !isCustomerTracking,
        ...(isOrderAlert ? { vibrateTimingsMillis: [0, 1000, 500, 1000, 500, 1000, 500, 1000] } : {}),
        visibility: 'PUBLIC' as const,
        priority: isOrderAlert ? ('MAX' as const) : ('HIGH' as const),
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
