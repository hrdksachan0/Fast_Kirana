import { prisma } from '@/lib/prisma'
import { sendPushNotification, sendPushNotificationToRoles, sendPushNotificationToRestaurant } from '@/lib/push-notification'
import { sendTopicWithRetry, buildOrderFcmPayload } from '@/lib/fcm-utils'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { getLast10Digits } from '@/lib/phone'
import { Role, OrderStatus } from '@prisma/client'

export interface OrderNotificationContext {
  createdOrders: any[]
  isOnlinePaid: boolean
  notificationTitle: string
  adminPhones: string[]
  origin: string
  userPhone?: string
}

/**
 * Dispatches multi-channel notifications for placed orders:
 * 1. Web push (customer, staff, and restaurant owners)
 * 2. Mobile FCM push (superadmins, darkstore pickers, riders, and kitchen consoles)
 * 3. WhatsApp order alerts to administrator phones
 * 4. Deduplicated customer push for combined or single orders
 */
export async function dispatchOrderNotifications(ctx: OrderNotificationContext): Promise<void> {
  const { createdOrders, isOnlinePaid, notificationTitle, adminPhones, origin, userPhone } = ctx
  const notifiedWebRoles = new Set<Role>()
  const sentFcmTokensThisCheckout = new Set<string>()

  for (const order of createdOrders) {
    const isRestaurant = Boolean(order.orderType === 'RESTAURANT' || order.restaurantId)
    const displayId = order.readableId ? String(order.readableId) : order.id.slice(-6).toUpperCase()

    // 1. Web Push Notification to Customer
    sendPushNotification(order.userId, {
      title: isOnlinePaid ? '💳 Order Confirmed & Paid!' : notificationTitle,
      body: isOnlinePaid
        ? `Order #${displayId} of ₹${order.total} has been placed and paid online.`
        : `Your order #${displayId} of ₹${order.total} has been placed.`,
      icon: `${origin}/icons/icon-192.png`,
      badge: `${origin}/icons/icon-192.png`,
      tag: `order-${order.id}`,
      renotify: true,
      data: { orderId: order.id },
    }).catch((err: any) => console.error('Error sending customer web push:', err))

    // 2. Web Push Notification to Staff
    if (isRestaurant && order.restaurantId) {
      // Restaurant order: Only Admin and Delivery roles
      const rolesToNotify = [Role.ADMIN, Role.DELIVERY].filter((r) => !notifiedWebRoles.has(r))
      if (rolesToNotify.length > 0) {
        rolesToNotify.forEach((r) => notifiedWebRoles.add(r))
        sendPushNotificationToRoles(rolesToNotify, {
          title: isOnlinePaid ? '💳 Online Payment Food Order!' : '🍽️ New Food Order!',
          body: isOnlinePaid
            ? `Order #${displayId} for ${order.shopName || 'Restaurant'} (₹${order.total}) — PAID Online ✅`
            : `Order #${displayId} for ${order.shopName || 'Restaurant'} (₹${order.total}) received.`,
          tag: `order-${order.id}`,
          data: { orderId: order.id },
        }).catch((err: any) => console.error('Error sending push to admin/delivery:', err))
      }

      // Notify Restaurant Owner (only if auto-approved / not ADMIN_PENDING)
      if (order.status !== OrderStatus.CANCELLED && order.status !== OrderStatus.ADMIN_PENDING) {
        sendPushNotificationToRestaurant(order.restaurantId, {
          title: `👨‍🍳 New Food Order #${displayId}!`,
          body: `New order #${displayId} received for ${order.shopName || 'Kitchen'}. Tap to prepare dishes.`,
          tag: `restaurant-order-${order.id}`,
          data: { orderId: order.id, restaurantId: order.restaurantId },
        }).catch((err: any) => console.error('Error sending push notification to restaurant:', err))
      }
    } else {
      // Pure Grocery order: Admin, Picker, Delivery
      const rolesToNotify = [Role.ADMIN, Role.PICKER, Role.DELIVERY].filter((r) => !notifiedWebRoles.has(r))
      if (rolesToNotify.length > 0) {
        rolesToNotify.forEach((r) => notifiedWebRoles.add(r))
        sendPushNotificationToRoles(rolesToNotify, {
          title: isOnlinePaid ? '💳 Online Payment Order Confirmed!' : notificationTitle,
          body: isOnlinePaid
            ? `Order #${displayId} of ₹${order.total} — PAID Online ✅`
            : `Order #${displayId} of ₹${order.total} has been placed.`,
          tag: `order-${order.id}`,
          data: { orderId: order.id },
        }).catch((err: any) => console.error('Error sending push notification to grocery staff:', err))
      }
    }

    // 3. FCM Push Notification to Staff & Kitchens
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
        // Super admin / HQ global listener
        sendTopicWithRetry(fcmMessaging, { topic: 'admin_orders_all', ...staffPayload }).catch(() => {})

        // Direct FCM push to all registered Admin device tokens
        const adminTokens = await prisma.fcmToken.findMany({
          where: {
            user: { role: Role.ADMIN },
          },
          select: { token: true },
        })
        for (const aToken of adminTokens) {
          fcmMessaging.send({ token: aToken.token, ...staffPayload }).catch(() => {})
        }

        // Direct FCM push to Delivery & Picker staff for grocery orders
        if (!isRestaurant) {
          const riderPayload = buildOrderFcmPayload(
            isOnlinePaid ? '💳 New PAID Order!' : '🛵 New Order to Deliver / Pick!',
            `New order #${displayId} of ₹${order.total} is ready for processing.`,
            {
              title: isOnlinePaid ? '💳 New PAID Order!' : '🛵 New Order to Deliver / Pick!',
              body: `New order #${displayId} of ₹${order.total} is ready for processing.`,
              orderId: order.id,
              readableId: displayId,
              status: order.status,
              screen: 'delivery',
              timestamp: Date.now().toString(),
            }
          )
          const staffTokens = await prisma.fcmToken.findMany({
            where: {
              user: { role: { in: [Role.DELIVERY, Role.PICKER] } },
            },
            select: { token: true },
          })
          for (const sToken of staffTokens) {
            fcmMessaging.send({ token: sToken.token, ...riderPayload }).catch(() => {})
          }
        }

        // Restaurant owner direct push (only when not in ADMIN_PENDING)
        if (isRestaurant && order.restaurantId && order.status !== OrderStatus.CANCELLED && order.status !== OrderStatus.ADMIN_PENDING) {
          const restInfo = await prisma.restaurant.findUnique({
            where: { id: order.restaurantId },
            select: { ownerPhone: true },
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
                  { role: { in: [Role.RESTAURANT_OWNER, Role.CHEF] } },
                  ...(cleanRestPhone ? [{ phone: { contains: cleanRestPhone } }] : []),
                ],
              },
            },
            select: { token: true },
          })

          const uniqueRestTokens = Array.from(new Set(restTokens.map((t) => t.token)))
          for (const rToken of uniqueRestTokens) {
            fcmMessaging.send({ token: rToken, ...restaurantPayload }).catch((err) =>
              console.error(`Error sending direct restaurant FCM to token ${rToken}:`, err)
            )
          }

          sendTopicWithRetry(fcmMessaging, { topic: `restaurant_orders_${order.restaurantId}`, ...restaurantPayload }).catch(() => {})
          sendTopicWithRetry(fcmMessaging, { topic: `restaurant_${order.restaurantId}`, ...restaurantPayload }).catch(() => {})
          sendTopicWithRetry(fcmMessaging, { topic: `kitchen_${order.restaurantId}`, ...restaurantPayload }).catch(() => {})
        }
      }
    } catch (fcmErr) {
      console.error('Customer order placement FCM error:', fcmErr)
    }

    // 4. WhatsApp Order Alert to Admin Phones
    if (adminPhones.length > 0) {
      const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://fast-kirana-gtm.vercel.app'
      const cleanAppUrl = appUrl.replace('https://', '').replace('http://', '')
      const outletName = order.shopName || (isRestaurant ? 'Restaurant' : 'FastKirana Dark Store')
      const customerName = order.user?.name || 'Customer'
      const customerPhone = order.address?.phone || order.user?.phone || 'N/A'
      const adminText = isOnlinePaid
        ? `💳 *PAID Online Order* #${displayId} for [${outletName}] of ₹${order.total} from ${customerName} (${customerPhone}). Payment: Online PAID ✅. Manage: ${cleanAppUrl}/admin`
        : `New Order #${displayId} for [${outletName}] of ₹${order.total} from ${customerName} (${customerPhone}). Manage: ${cleanAppUrl}/admin`

      const whatsappPromises = adminPhones.map((phone) =>
        sendWhatsAppOrderAlert(phone, adminText).catch((err: any) =>
          console.error(`Failed to send admin (${phone}) WhatsApp order alert:`, err)
        )
      )
      await Promise.allSettled(whatsappPromises)
    }
  }

  // 5. Exactly 1 Consolidated Customer Notification for Entire Checkout
  try {
    const primaryOrder = createdOrders.find((o) => !o.restaurantId) || createdOrders[0]
    const isCombined = createdOrders.length > 1
    const baseDisplayId = (primaryOrder.readableId || primaryOrder.id).replace(/-[GR]\d*$/i, '')
    const combinedTotal = createdOrders.reduce((sum, o) => sum + Number(o.total || 0), 0)
    const customerPhone = primaryOrder.address?.phone || primaryOrder.user?.phone || userPhone || ''
    const cleanPhone = getLast10Digits(customerPhone)

    const { fcmMessaging } = await import('@/lib/firebase-admin')
    if (fcmMessaging) {
      const notifTitle = isOnlinePaid
        ? (isCombined ? '💳 Combined Order Confirmed & Paid!' : '💳 Order Confirmed & Paid!')
        : (isCombined ? '📦 Combined Order Placed Successfully!' : '📦 Order Placed Successfully!')
      const notifBody = isCombined
        ? `Your FastKirana combined order #${baseDisplayId} (₹${combinedTotal.toFixed(0)}) is confirmed and being prepared.`
        : `Your FastKirana order #${primaryOrder.readableId || primaryOrder.id} (₹${Number(primaryOrder.total).toFixed(0)}) is confirmed and being prepared.`

      const dataPayload: Record<string, string> = {
        title: notifTitle,
        body: notifBody,
        orderId: primaryOrder.id,
        readableId: baseDisplayId,
        status: primaryOrder.status,
        screen: 'order-tracking',
        url: `/orders/${primaryOrder.id}`,
        timestamp: Date.now().toString(),
      }

      const custPayload = buildOrderFcmPayload(notifTitle, notifBody, dataPayload)

      const customerTokens = await prisma.fcmToken.findMany({
        where: {
          OR: [
            ...(primaryOrder.userId ? [{ userId: primaryOrder.userId }] : []),
            ...(cleanPhone ? [{ user: { phone: { contains: cleanPhone } } }] : []),
          ],
        },
        select: { token: true },
        orderBy: { createdAt: 'desc' },
        take: 1,
      })

      if (customerTokens.length > 0) {
        const custToken = customerTokens[0].token
        if (!sentFcmTokensThisCheckout.has(custToken)) {
          sentFcmTokensThisCheckout.add(custToken)
          fcmMessaging.send({ token: custToken, ...custPayload }).catch((e) =>
            console.error('Error sending customer FCM:', e)
          )
        }
      } else if (cleanPhone && cleanPhone.length === 10) {
        await sendTopicWithRetry(fcmMessaging, { topic: `phone_${cleanPhone}`, ...custPayload }).catch((e) =>
          console.error('Error sending customer topic FCM:', e)
        )
      }
    }
  } catch (custNotifErr) {
    console.error('Unified customer order FCM notification error:', custNotifErr)
  }
}
