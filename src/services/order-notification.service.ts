import { prisma } from '@/lib/prisma'
import { Role, OrderStatus } from '@prisma/client'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles, sendPushNotificationToRestaurant } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { buildOrderFcmPayload, sendTopicWithRetry } from '@/lib/fcm-utils'
import { getLast10Digits } from '@/lib/phone'

export interface OrderNotificationContext {
  createdOrders: any[]
  isOnlinePaid: boolean
  customerName: string
  customerPhone: string
  addressText?: string
  cleanAppUrl?: string
  settingsMap?: Record<string, string>
}

export async function dispatchOrderNotifications(ctx: OrderNotificationContext): Promise<void> {
  const { createdOrders, isOnlinePaid, customerName, customerPhone, addressText = '', cleanAppUrl = 'fastkirana.in' } = ctx

  if (!createdOrders || createdOrders.length === 0) return

  try {
    // 1. Fetch WhatsApp & alert settings
    let settingsMap = ctx.settingsMap
    if (!settingsMap) {
      const settings = await prisma.storeSetting.findMany({
        where: {
          key: {
            in: [
              'whatsapp_notify_7054470303',
              'whatsapp_notify_8112849854',
              'order_alert_phone',
              'contact_phone'
            ]
          }
        }
      })
      settingsMap = {}
      for (const s of settings) {
        settingsMap[s.key] = s.value
      }
    }

    const notifyPhone1 = settingsMap['whatsapp_notify_7054470303'] !== 'false'
    const notifyPhone2 = settingsMap['whatsapp_notify_8112849854'] !== 'false'
    const adminPhones: string[] = []

    if (notifyPhone1) adminPhones.push('7054470303')
    if (notifyPhone2) adminPhones.push('8112849854')

    if (settingsMap['order_alert_phone']) {
      const clean = settingsMap['order_alert_phone'].replace(/\D/g, '').slice(-10)
      if (clean && !adminPhones.includes(clean)) adminPhones.push(clean)
    }
    if (settingsMap['contact_phone']) {
      const clean = settingsMap['contact_phone'].replace(/\D/g, '').slice(-10)
      if (clean && !adminPhones.includes(clean)) adminPhones.push(clean)
    }

    const notifiedWebRoles = new Set<string>()

    for (const order of createdOrders) {
      const displayId = order.readableId || order.id.slice(-6).toUpperCase()
      const isRestaurant = !!order.restaurantId
      const notificationTitle = isRestaurant ? `New Order for ${order.shopName} 🍲` : 'New Grocery Order 📦'

      // 1. SSE Real-time Emit for Admin Console
      sseEmitter.emit('order', {
        type: 'new-order',
        orderId: order.id,
        readableId: order.readableId,
        shopName: order.shopName,
        status: order.status,
        total: order.total,
        paymentStatus: order.paymentStatus,
        paymentMethod: order.paymentMethod,
        createdAt: order.createdAt,
        restaurantId: order.restaurantId,
      })

      // 2. Web Push Notifications
      if (isRestaurant) {
        const rolesToNotify = [Role.ADMIN, Role.DELIVERY].filter(r => !notifiedWebRoles.has(r))
        if (rolesToNotify.length > 0) {
          rolesToNotify.forEach(r => notifiedWebRoles.add(r))
          sendPushNotificationToRoles(rolesToNotify, {
            title: isOnlinePaid ? '💳 Online Payment Order Confirmed!' : notificationTitle,
            body: isOnlinePaid ? `Order #${displayId} of ₹${order.total} — PAID Online ✅` : `Order #${displayId} of ₹${order.total} has been placed.`,
            tag: `order-${order.id}`,
            data: { orderId: order.id }
          }).catch((err: any) => console.error('Error sending push notification to admins:', err))
        }

        // Restaurant kitchen push (Only if order is valid and not cancelled)
        if (order.status !== OrderStatus.CANCELLED) {
          sendPushNotificationToRestaurant(order.restaurantId, {
            title: `👨‍🍳 New Food Order #${displayId}!`,
            body: `New order #${displayId} received for ${order.shopName || 'Kitchen'}. Tap to prepare dishes.`,
            tag: `restaurant-order-${order.id}`,
            data: { orderId: order.id, restaurantId: order.restaurantId }
          }).catch((err: any) => console.error('Error sending push notification to restaurant:', err))
        }
      } else {
        const rolesToNotify = [Role.ADMIN, Role.PICKER, Role.DELIVERY].filter(r => !notifiedWebRoles.has(r))
        if (rolesToNotify.length > 0) {
          rolesToNotify.forEach(r => notifiedWebRoles.add(r))
          sendPushNotificationToRoles(rolesToNotify, {
            title: isOnlinePaid ? '💳 Online Payment Order Confirmed!' : notificationTitle,
            body: isOnlinePaid ? `Order #${displayId} of ₹${order.total} — PAID Online ✅` : `Order #${displayId} of ₹${order.total} has been placed.`,
            tag: `order-${order.id}`,
            data: { orderId: order.id }
          }).catch((err: any) => console.error('Error sending push notification to grocery staff:', err))
        }
      }

      // 3. FCM Mobile Push Notifications
      try {
        const { fcmMessaging } = await import('@/lib/firebase-admin')
        if (fcmMessaging) {
          const staffPayload = buildOrderFcmPayload(
            isOnlinePaid ? '💳 New PAID Order Received!' : '🛎️ New Order Received!',
            `New order #${displayId} of ₹${order.total} has been placed.`,
            {
              title: isOnlinePaid ? '💳 New PAID Order Received!' : '🛎️ New Order Received!',
              body: `New order #${displayId} of ₹${order.total} has been placed.`,
              orderId: order.id,
              readableId: displayId,
              status: order.status,
              screen: 'admin-orders',
              timestamp: Date.now().toString(),
            }
          )

          if (order.storeId) {
            sendTopicWithRetry(fcmMessaging, { topic: `admin_orders_${order.storeId}`, ...staffPayload }).catch(() => {})
            if (!isRestaurant) {
              sendTopicWithRetry(fcmMessaging, { topic: `staff_orders_${order.storeId}`, ...staffPayload }).catch(() => {})
            }
          } else {
            sendTopicWithRetry(fcmMessaging, { topic: 'admin_orders', ...staffPayload }).catch(() => {})
            if (!isRestaurant) {
              sendTopicWithRetry(fcmMessaging, { topic: 'staff_orders', ...staffPayload }).catch(() => {})
            }
          }
          sendTopicWithRetry(fcmMessaging, { topic: 'admin_orders_all', ...staffPayload }).catch(() => {})

          // Push strictly to kitchen device
          if (isRestaurant && order.restaurantId && order.status !== OrderStatus.CANCELLED) {
            const restInfo = await prisma.restaurant.findUnique({
              where: { id: order.restaurantId },
              select: { ownerPhone: true }
            })
            const cleanRestPhone = restInfo?.ownerPhone ? getLast10Digits(restInfo.ownerPhone) : ''

            const restaurantPayload = buildOrderFcmPayload(
              `👨‍🍳 New Order for ${order.shopName || 'Kitchen'}!`,
              `Order #${displayId} received! Open kitchen console to prepare dishes.`,
              {
                title: `👨‍🍳 New Order for ${order.shopName || 'Kitchen'}!`,
                body: `Order #${displayId} received! Open kitchen console to prepare dishes.`,
                orderId: order.id,
                readableId: displayId,
                restaurantId: order.restaurantId,
                status: order.status,
                screen: 'restaurant-console',
                timestamp: Date.now().toString(),
              }
            )

            const restTokens = await prisma.fcmToken.findMany({
              where: {
                user: {
                  OR: [
                    { assignedRestaurantId: order.restaurantId },
                    ...(cleanRestPhone ? [{ phone: { contains: cleanRestPhone } }] : []),
                  ]
                }
              },
              select: { token: true }
            })

            for (const t of restTokens) {
              fcmMessaging.send({ token: t.token, ...restaurantPayload }).catch(() => {})
            }
          }
        }
      } catch (fcmErr) {
        console.warn('FCM dispatch note:', fcmErr)
      }

      // 4. WhatsApp Order Alert to Store Admin
      try {
        const adminText = isOnlinePaid
          ? `💳 *NEW PAID ONLINE ORDER* #${displayId} for [${order.shopName || 'Store'}] of ₹${order.total} from ${customerName} (${customerPhone}). Address: ${addressText}. Manage: ${cleanAppUrl}/admin`
          : `🛎️ *NEW ORDER* #${displayId} for [${order.shopName || 'Store'}] of ₹${order.total} (${order.paymentMethod}) from ${customerName} (${customerPhone}). Address: ${addressText}. Manage: ${cleanAppUrl}/admin`

        for (const phone of adminPhones) {
          sendWhatsAppOrderAlert(phone, adminText).catch(() => {})
        }
      } catch (waErr) {
        console.warn('WhatsApp alert dispatch note:', waErr)
      }
    }
  } catch (err) {
    console.error('dispatchOrderNotifications error:', err)
  }
}
