import webpush from 'web-push'
import { prisma } from './prisma'

const publicKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY || 'BPxeEdEbKwG5gG_jE6jT6ReXk516Pi1iszzLJSW3OHrpIg9UloqpDOlrfZISFl97PpBYMQHOoesTKtPAruF4QEw'
const privateKey = process.env.VAPID_PRIVATE_KEY || '02VzQDrVNvZo88wiRVPtDu3r_Gfp0McW3nW4UoyhI7Q'
const subject = process.env.VAPID_SUBJECT || 'mailto:admin@fastkirana.com'

if (publicKey && privateKey) {
  webpush.setVapidDetails(subject, publicKey, privateKey)
} else {
  console.warn('Web Push VAPID keys are missing from environment variables.')
}

interface PushPayload {
  title: string
  body: string
  icon?: string
  badge?: string
  tag?: string
  renotify?: boolean
  data?: Record<string, any>
}

/**
 * Send a push notification to all subscriptions of a specific user.
 * Automatically handles expired/invalid subscriptions by removing them.
 */
export async function sendPushNotification(userId: string, payload: PushPayload) {
  if (!publicKey || !privateKey) {
    console.error('Cannot send push notification: VAPID keys not configured.')
    return
  }

  try {
    // Find all subscriptions for the user
    const subscriptions = await prisma.pushSubscription.findMany({
      where: { userId },
    })

    if (subscriptions.length === 0) {
      console.log(`No active push subscriptions found for user: ${userId}`)
      return
    }

    const payloadString = JSON.stringify(payload)

    const promises = subscriptions.map(async (sub) => {
      try {
        if (sub.endpoint.startsWith('ExponentPushToken')) {
          const expoRes = await fetch('https://exp.host/--/api/v2/push/send', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: JSON.stringify({
              to: sub.endpoint,
              sound: 'default',
              title: payload.title,
              body: payload.body,
              data: payload.data,
            }),
          })
          if (!expoRes.ok) {
            const errText = await expoRes.text()
            throw new Error(`Expo API returned status ${expoRes.status}: ${errText}`)
          }
          console.log(`Push notification sent successfully via Expo to: ${sub.endpoint}`)
        } else {
          const pushSubscription = {
            endpoint: sub.endpoint,
            keys: {
              p256dh: sub.p256dh,
              auth: sub.auth,
            },
          }

          await webpush.sendNotification(pushSubscription, payloadString)
          console.log(`Push notification sent successfully to endpoint: ${sub.endpoint.slice(0, 30)}...`)
        }
      } catch (err: any) {
        // Handle expired or invalid subscription (status 410 or 404)
        if (err.statusCode === 410 || err.statusCode === 404) {
          console.log(`Removing expired subscription: ${sub.id} / ${sub.endpoint.slice(0, 30)}...`)
          await prisma.pushSubscription.delete({
            where: { id: sub.id },
          }).catch((dbErr) => {
            console.error('Failed to delete expired subscription from DB:', dbErr)
          })
        } else {
          console.error(`Failed to send push notification to endpoint: ${sub.endpoint.slice(0, 30)}...`, err)
        }
      }
    })

    await Promise.all(promises)
  } catch (error) {
    console.error(`Error sending push notification to user ${userId}:`, error)
  }
}

/**
 * Broadcast a push notification to all subscribed endpoints.
 * Returns success and failure counts.
 */
export async function broadcastPushNotification(payload: PushPayload) {
  if (!publicKey || !privateKey) {
    console.error('Cannot broadcast push notification: VAPID keys not configured.')
    return { successCount: 0, failureCount: 0, error: 'VAPID keys not configured' }
  }

  try {
    const subscriptions = await prisma.pushSubscription.findMany()

    if (subscriptions.length === 0) {
      console.log('No active push subscriptions found in database.')
      return { successCount: 0, failureCount: 0 }
    }

    const payloadString = JSON.stringify(payload)
    let successCount = 0
    let failureCount = 0

    // Send notifications to all subscribers concurrently
    const promises = subscriptions.map(async (sub) => {
      try {
        if (sub.endpoint.startsWith('ExponentPushToken')) {
          const expoRes = await fetch('https://exp.host/--/api/v2/push/send', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: JSON.stringify({
              to: sub.endpoint,
              sound: 'default',
              title: payload.title,
              body: payload.body,
              data: payload.data,
            }),
          })
          if (!expoRes.ok) {
            const errText = await expoRes.text()
            throw new Error(`Expo API returned status ${expoRes.status}: ${errText}`)
          }
          successCount++
          console.log(`Push notification sent successfully via Expo to: ${sub.endpoint}`)
        } else {
          const pushSubscription = {
            endpoint: sub.endpoint,
            keys: {
              p256dh: sub.p256dh,
              auth: sub.auth,
            },
          }

          await webpush.sendNotification(pushSubscription, payloadString)
          successCount++
          console.log(`Push notification sent successfully to endpoint: ${sub.endpoint.slice(0, 30)}...`)
        }
      } catch (err: any) {
        failureCount++
        if (err.statusCode === 410 || err.statusCode === 404) {
          console.log(`Removing expired subscription: ${sub.id} / ${sub.endpoint.slice(0, 30)}...`)
          await prisma.pushSubscription.delete({
            where: { id: sub.id },
          }).catch((dbErr) => {
            console.error('Failed to delete expired subscription from DB:', dbErr)
          })
        } else {
          console.error(`Failed to send push notification to endpoint: ${sub.endpoint.slice(0, 30)}...`, err)
        }
      }
    })

    await Promise.all(promises)
    return { successCount, failureCount }
  } catch (error) {
    console.error('Error broadcasting push notification:', error)
    return { successCount: 0, failureCount: 0, error: String(error) }
  }
}

