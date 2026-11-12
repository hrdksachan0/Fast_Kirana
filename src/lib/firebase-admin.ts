import admin from 'firebase-admin'

export function getFcmMessaging(): admin.messaging.Messaging | null {
  try {
    if (admin.apps.length === 0) {
      const projectId = process.env.FIREBASE_PROJECT_ID || 'fastkirana-98a68'
      const clientEmail = process.env.FIREBASE_CLIENT_EMAIL
      let privateKey = (process.env.FIREBASE_PRIVATE_KEY || '')?.trim()

      if (!clientEmail || !privateKey) {
        console.warn('[Firebase Admin] Skipping initialization: FIREBASE_CLIENT_EMAIL or FIREBASE_PRIVATE_KEY not configured.')
        return null
      }

      if (privateKey.startsWith('"') && privateKey.endsWith('"')) {
        privateKey = privateKey.substring(1, privateKey.length - 1)
      }
      if (privateKey.startsWith("'") && privateKey.endsWith("'")) {
        privateKey = privateKey.substring(1, privateKey.length - 1)
      }
      // Handle all possible \n escape formats: literal \\n, escaped \\\\n, etc.
      privateKey = privateKey.replace(/\\\\n/g, '\n')
      privateKey = privateKey.replace(/\\n/g, '\n')

      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey,
        }),
      })
      console.log('[Firebase Admin] Successfully initialized!')
    }
    return admin.messaging()
  } catch (e: any) {
    console.error('Firebase Admin getFcmMessaging error:', e?.message || e)
    return null
  }
}

export const fcmMessaging = {
  send: async (msg: any) => {
    const fcm = getFcmMessaging()
    if (!fcm) {
      console.warn('FCM instance unavailable for send')
      return null
    }
    return fcm.send(msg)
  },
  sendEachForMulticast: async (msg: any) => {
    const fcm = getFcmMessaging()
    if (!fcm) {
      console.warn('FCM instance unavailable for sendEachForMulticast')
      return { responses: [], successCount: 0, failureCount: 0 }
    }
    return fcm.sendEachForMulticast(msg)
  },
}

// Pre-warm Firebase Admin at module load so cold Vercel instances
// don't pay the gRPC handshake cost inside a request handler.
try { getFcmMessaging() } catch (_) { /* lazy re-try on next call */ }

export interface OptimizedFcmPayloadOptions {
  title: string
  body: string
  imageUrl?: string | null
  linkUrl?: string | null
  orderId?: string | null
  readableId?: string | null
  status?: string | null
  category?: 'order' | 'offer' | 'delivery'
  collapseKey?: string
  ttlSeconds?: number
}

/**
 * Builds an enterprise-grade FCM payload with Android Doze bypass, collapseKey, and iOS Time-Sensitive flags.
 */
export function buildOptimizedFcmPayload(opts: OptimizedFcmPayloadOptions): any {
  const channelId = 'fastkirana_alerts'
  const ttl = opts.ttlSeconds ?? 86400 // default 24 hours

  return {
    notification: {
      title: opts.title,
      body: opts.body,
      ...(opts.imageUrl ? { imageUrl: opts.imageUrl } : {}),
    },
    data: {
      title: opts.title,
      body: opts.body,
      ...(opts.orderId ? { orderId: opts.orderId } : {}),
      ...(opts.readableId ? { readableId: opts.readableId } : {}),
      ...(opts.status ? { status: opts.status } : {}),
      category: opts.category || 'order',
      url: opts.linkUrl || (opts.orderId ? `/orders/${opts.orderId}` : '/'),
      screen: opts.orderId ? 'order-tracking' : 'home',
      timestamp: Date.now().toString(),
    },
    android: {
      priority: 'high' as const,
      ttl: ttl * 1000,
      ...(opts.collapseKey ? { collapseKey: opts.collapseKey } : {}),
      notification: {
        channelId,
        sound: 'default',
        defaultSound: true,
        defaultVibrateTimings: true,
        visibility: 'PUBLIC' as const,
        priority: 'HIGH' as const,
        tag: opts.collapseKey || 'fastminute_broadcast',
        ...(opts.imageUrl ? { imageUrl: opts.imageUrl } : {}),
      },
    },
    apns: {
      headers: {
        'apns-priority': '10',
        'apns-push-type': 'alert',
        ...(opts.collapseKey ? { 'apns-collapse-id': opts.collapseKey } : {}),
      },
      payload: {
        aps: {
          alert: {
            title: opts.title,
            body: opts.body,
          },
          sound: 'default',
          badge: 1,
          contentAvailable: true,
          'interruption-level': 'time-sensitive',
          'thread-id': opts.orderId ? `order-${opts.orderId}` : 'fastkirana-marketing',
        },
      },
    },
  }
}

/**
 * Sends to a topic with automatic retry (up to 2 attempts).
 */
export async function sendTopicWithRetry(topic: string, payload: any, maxRetries = 2): Promise<boolean> {
  const fcm = getFcmMessaging()
  if (!fcm) return false

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      await fcm.send({
        topic,
        ...payload,
      })
      return true
    } catch (err: any) {
      if (attempt === maxRetries) {
        console.warn(`[FCM] Topic send failed for ${topic} after ${maxRetries} attempts:`, err?.message || err)
        return false
      }
      await new Promise((r) => setTimeout(r, 200 * attempt))
    }
  }
  return false
}



