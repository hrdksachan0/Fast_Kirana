import webpush from 'web-push'
import { prisma } from './prisma'

const publicKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY
const privateKey = process.env.VAPID_PRIVATE_KEY
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
        const pushSubscription = {
          endpoint: sub.endpoint,
          keys: {
            p256dh: sub.p256dh,
            auth: sub.auth,
          },
        }

        await webpush.sendNotification(pushSubscription, payloadString)
        console.log(`Push notification sent successfully to endpoint: ${sub.endpoint.slice(0, 30)}...`)
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
