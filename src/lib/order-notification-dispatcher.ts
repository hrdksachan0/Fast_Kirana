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
  settingsMap?: Record<string, string>
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

    const isAdminPending = order.status === OrderStatus.ADMIN_PENDING

    // 1. Web Push Notification to Customer
    sendPushNotification(order.userId, {
      title: isAdminPending
        ? '⏳ Order Placed — Waiting for Store Approval'
        : isOnlinePaid
        ? '💳 Order Confirmed & Paid!'
        : notificationTitle,
      body: isAdminPending
        ? `Your order #${displayId} of ₹${order.total} is received and awaiting store confirmation.`
        : isOnlinePaid
        ? `Order #${displayId} of ₹${order.total} has been placed and paid online.`
        : `Your order #${displayId} of ₹${order.total} has been placed.`,
      icon: `${origin}/icons/icon-192.png`,
      badge: `${origin}/icons/icon-192.png`,
      tag: `order-${order.id}`,
      renotify: true,
      data: { orderId: order.id },
    }).catch((err: any) => console.error('Error sending customer web push:', err))

    // 2. Web Push Notification to Staff
    if (isAdminPending) {
      // Manual approval mode: ONLY Super Admins receive alerts
      const rolesToNotify = [Role.ADMIN].filter((r) => !notifiedWebRoles.has(r))
      if (rolesToNotify.length > 0) {
        rolesToNotify.forEach((r) => notifiedWebRoles.add(r))
        sendPushNotificationToRoles(rolesToNotify, {
          title: '🚨 New Order Awaiting Admin Approval!',
          body: `Order #${displayId} (${order.shopName || 'Store'}, ₹${order.total}) requires your approval. Tap to review.`,
          tag: `order-approval-${order.id}`,
          data: { orderId: order.id },
        }).catch((err: any) => console.error('Error sending push to admin:', err))
      }
    } else if (isRestaurant && order.restaurantId) {
      // Auto-approved Restaurant order: Admin, Delivery, and Restaurant Owner
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

      // Notify Restaurant Owner
      if (order.status !== OrderStatus.CANCELLED) {
        sendPushNotificationToRestaurant(order.restaurantId, {
          title: `👨‍🍳 New Food Order #${displayId}!`,
          body: `New order #${displayId} received for ${order.shopName || 'Kitchen'}. Tap to prepare dishes.`,
          tag: `restaurant-order-${order.id}`,
          data: { orderId: order.id, restaurantId: order.restaurantId },
        }).catch((err: any) => console.error('Error sending push notification to restaurant:', err))
      }
    } else {
      // Auto-approved Pure Grocery order: Admin, Picker, Delivery
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
          isAdminPending
            ? '🚨 New Order Awaiting Approval!'
            : isOnlinePaid
            ? '💳 New PAID Order Received!'
            : '🛎️ New Order Received!',
          isAdminPending
            ? `Order #${displayId} of ₹${order.total} needs admin approval. Tap to review.`
            : `New order #${displayId} of ₹${order.total} has been placed.`,
          {
            title: isAdminPending
              ? '🚨 New Order Awaiting Approval!'
              : isOnlinePaid
              ? '💳 New PAID Order Received!'
              : '🛎️ New Order Received!',
            body: isAdminPending
              ? `Order #${displayId} of ₹${order.total} needs admin approval. Tap to review.`
              : `New order #${displayId} of ₹${order.total} has been placed.`,
            orderId: order.id,
            readableId: displayId,
            status: order.status,
            screen: 'admin-orders',
            timestamp: Date.now().toString(),
          }
        )

        // Broadcast to Admin Topics
        if (order.storeId) {
          sendTopicWithRetry(fcmMessaging, { topic: `admin_orders_${order.storeId}`, ...staffPayload }).catch(() => {})
          if (!isAdminPending && !isRestaurant) {
            sendTopicWithRetry(fcmMessaging, { topic: `staff_orders_${order.storeId}`, ...staffPayload }).catch(() => {})
          }
        } else {
          sendTopicWithRetry(fcmMessaging, { topic: 'admin_orders', ...staffPayload }).catch(() => {})
          if (!isAdminPending && !isRestaurant) {
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

        // Only notify Pickers/Riders and Kitchens if NOT awaiting admin approval
        if (!isAdminPending) {
          // Direct FCM push to Delivery & Picker staff for grocery orders
          if (!isRestaurant) {
            const pickerPayload = buildOrderFcmPayload(
              isOnlinePaid ? '💳 New PAID Order to Pick!' : '📦 New Grocery Order to Pick!',
              `New order #${displayId} of ₹${order.total} (${order.items?.length || 1} items). Tap to pack.`,
              {
                title: isOnlinePaid ? '💳 New PAID Order to Pick!' : '📦 New Grocery Order to Pick!',
                body: `New order #${displayId} of ₹${order.total} (${order.items?.length || 1} items). Tap to pack.`,
                orderId: order.id,
                readableId: displayId,
                status: order.status,
                screen: 'picker',
                type: 'NEW_ORDER',
                role: 'PICKER',
                timestamp: Date.now().toString(),
              }
            )

            const riderPayload = buildOrderFcmPayload(
              isOnlinePaid ? '💳 New PAID Order!' : '🛵 New Order to Deliver!',
              `New order #${displayId} of ₹${order.total} is ready for processing.`,
              {
                title: isOnlinePaid ? '💳 New PAID Order!' : '🛵 New Order to Deliver!',
                body: `New order #${displayId} of ₹${order.total} is ready for processing.`,
                orderId: order.id,
                readableId: displayId,
                status: order.status,
                screen: 'delivery',
                type: 'NEW_ORDER',
                role: 'DELIVERY',
                timestamp: Date.now().toString(),
              }
            )

            // Direct tokens to Pickers
            const pickerTokens = await prisma.fcmToken.findMany({
              where: {
                user: { role: Role.PICKER },
              },
              select: { token: true },
            })
            for (const pToken of pickerTokens) {
              fcmMessaging.send({ token: pToken.token, ...pickerPayload }).catch(() => {})
            }

            // Direct tokens to Delivery Riders
            const riderTokens = await prisma.fcmToken.findMany({
              where: {
                user: { role: Role.DELIVERY },
              },
              select: { token: true },
            })
            for (const rToken of riderTokens) {
              fcmMessaging.send({ token: rToken.token, ...riderPayload }).catch(() => {})
            }

            // Broadcast to Picker Topics
            if (order.storeId) {
              sendTopicWithRetry(fcmMessaging, { topic: `picker_orders_${order.storeId}`, ...pickerPayload }).catch(() => {})
            }
            sendTopicWithRetry(fcmMessaging, { topic: 'picker_orders', ...pickerPayload }).catch(() => {})
          }

          // Restaurant owner direct push
          if (isRestaurant && order.restaurantId && order.status !== OrderStatus.CANCELLED) {
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
      }
    } catch (fcmErr) {
      console.error('Customer order placement FCM error:', fcmErr)
    }


  }

  // 4. Exactly 1 Consolidated WhatsApp Alert to Hub Admin (Single alert even for multi-outlet combined orders)
  try {
    const primaryOrder = createdOrders.find((o) => !o.restaurantId) || createdOrders[0]
    const orderAlertPhones = new Set<string>()

    if (primaryOrder.storeId && ctx.settingsMap) {
      const storePrefix = `store:${primaryOrder.storeId}:`
      const storeContact = ctx.settingsMap[`${storePrefix}contact_phone`] || ctx.settingsMap[`${storePrefix}store_phone`]
      const notifyStore = ctx.settingsMap[`${storePrefix}whatsapp_notify_store_phone`] !== 'false'
      if (notifyStore && storeContact) {
        const clean = storeContact.replace(/\D/g, '').slice(-10)
        if (clean.length === 10) orderAlertPhones.add(clean)
      }
      const addl = ctx.settingsMap[`${storePrefix}store_alert_phones`] || ctx.settingsMap[`${storePrefix}order_alert_phone`]
      if (addl) {
        const matches = addl.match(/\b\d{10}\b/g)
        if (matches) matches.forEach((m: string) => orderAlertPhones.add(m))
      }
      if (ctx.settingsMap[`${storePrefix}whatsapp_notify_7054470303`] !== 'false') {
        orderAlertPhones.add('7054470303')
      }
      if (ctx.settingsMap[`${storePrefix}whatsapp_notify_8112849854`] !== 'false') {
        orderAlertPhones.add('8112849854')
      }
    }

    if (orderAlertPhones.size === 0) {
      adminPhones.forEach((p) => orderAlertPhones.add(p))
    }

    if (orderAlertPhones.size > 0) {
      const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://fastkirana.in'
      const cleanAppUrl = appUrl.replace('https://', '').replace('http://', '')
      const customerName = primaryOrder.user?.name || 'Customer'
      const customerPhone = primaryOrder.address?.phone || primaryOrder.user?.phone || userPhone || 'N/A'

      let adminText: string
      if (createdOrders.length > 1) {
        const baseDisplayId = (primaryOrder.readableId || primaryOrder.id).replace(/-[GR]\d*$/i, '')
        const combinedTotal = createdOrders.reduce((sum, o) => sum + Number(o.total || 0), 0)
        const outlets = Array.from(new Set(createdOrders.map((o) => o.shopName || (o.restaurantId ? 'Restaurant' : 'FastKirana Dark Store')))).join(' + ')
        adminText = `New 🛒 Combined Order #${baseDisplayId} [${outlets}] of ₹${combinedTotal.toFixed(0)} from ${customerName} (${customerPhone}). Manage: ${cleanAppUrl}/admin`
      } else {
        const order = createdOrders[0]
        const displayId = order.readableId ? String(order.readableId) : order.id.slice(-6).toUpperCase()
        const outletName = order.shopName || (order.restaurantId ? 'Restaurant' : 'FastKirana Dark Store')
        const orderTypeStr = order.restaurantId ? '🍽️ Restaurant Order' : '📦 Order'
        adminText = `New ${orderTypeStr} #${displayId} for [${outletName}] of ₹${Number(order.total).toFixed(0)} from ${customerName} (${customerPhone}). Manage: ${cleanAppUrl}/admin`
      }

      const whatsappPromises = Array.from(orderAlertPhones).map((phone) =>
        sendWhatsAppOrderAlert(phone, adminText).catch((err: any) =>
          console.error(`Failed to send WhatsApp order alert (${phone}):`, err)
        )
      )
      await Promise.allSettled(whatsappPromises)
    }
  } catch (waErr) {
    console.error('Consolidated WhatsApp admin alert error:', waErr)
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

/**
 * Dispatches targeted multi-channel notifications when an Admin approves
 * an order from ADMIN_PENDING to PENDING / CONFIRMED.
 */
export async function dispatchAdminApprovedNotifications(orderId: string, origin?: string): Promise<void> {
  try {
    const baseOrigin = origin || process.env.NEXT_PUBLIC_APP_URL || 'https://fast-kirana-gtm.vercel.app'
    const primaryOrder = await prisma.order.findUnique({
      where: { id: orderId },
      include: {
        user: true,
        address: true,
        restaurant: true,
        items: true,
      },
    })

    if (!primaryOrder) return

    // If part of a combined order, fetch all sibling sub-orders so both Restaurant and Grocery outlets are notified
    const allTargetOrders = primaryOrder.combinedId
      ? await prisma.order.findMany({
          where: { combinedId: primaryOrder.combinedId },
          include: {
            user: true,
            address: true,
            restaurant: true,
            items: true,
          },
        })
      : [primaryOrder]

    const { fcmMessaging } = await import('@/lib/firebase-admin')
    const { createClient } = await import('@supabase/supabase-js')

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://bberzasmxwioxjynbuaf.supabase.co'
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''
    const supabase = (supabaseUrl && supabaseKey)
      ? createClient(supabaseUrl, supabaseKey, { auth: { persistSession: false } })
      : null

    for (const order of allTargetOrders) {
      const displayId = order.readableId ? String(order.readableId) : order.id.slice(-6).toUpperCase()
      const isRestaurant = Boolean(order.orderType === 'RESTAURANT' || order.restaurantId)
      const outletName = order.shopName || (isRestaurant ? 'Restaurant' : 'FastKirana Dark Store')

      // 1. Notify Customer (Web Push + FCM)
      sendPushNotification(order.userId, {
        title: '✅ Order Approved & Confirmed!',
        body: `Your order #${displayId} of ₹${order.total} has been approved by ${outletName} and is now being prepared.`,
        icon: `${baseOrigin}/icons/icon-192.png`,
        badge: `${baseOrigin}/icons/icon-192.png`,
        tag: `order-${order.id}`,
        renotify: true,
        data: { orderId: order.id },
      }).catch((err: any) => console.error('Error sending customer approval web push:', err))

      // 2. Staff Web & FCM Notifications
      if (isRestaurant && order.restaurantId) {
        // Instant Realtime Supabase Broadcast for Kitchen Console Chime & Refresh
        if (supabase) {
          try {
            const ch = supabase.channel('restaurant-orders-live')
            ch.subscribe((status) => {
              if (status === 'SUBSCRIBED') {
                ch.send({
                  type: 'broadcast',
                  event: 'new_order',
                  payload: {
                    orderId: order.id,
                    readableId: displayId,
                    restaurantId: order.restaurantId,
                    restaurantName: order.restaurant?.name || order.shopName,
                    shopName: order.shopName,
                    status: order.status || 'PENDING',
                  },
                }).then(() => supabase.removeChannel(ch)).catch(() => {})
              }
            })
          } catch (_) {}
        }

        // Web push to Restaurant Owner
        sendPushNotificationToRestaurant(order.restaurantId, {
          title: `👨‍🍳 New Food Order #${displayId}!`,
          body: `Order #${displayId} for ${outletName} is APPROVED by Admin. Open Kitchen Console to start cooking!`,
          tag: `restaurant-order-${order.id}`,
          data: { orderId: order.id, restaurantId: order.restaurantId },
        }).catch((err: any) => console.error('Error sending restaurant approval web push:', err))

        // FCM to Restaurant & Kitchen
        if (fcmMessaging) {
          const restPayload = buildOrderFcmPayload(
            `👨‍🍳 New Food Order #${displayId}!`,
            `Order #${displayId} for ${outletName} is APPROVED by Admin. Start cooking!`,
            {
              title: `👨‍🍳 New Food Order #${displayId}!`,
              body: `Order #${displayId} for ${outletName} is APPROVED by Admin. Start cooking!`,
              orderId: order.id,
              readableId: displayId,
              restaurantId: order.restaurantId,
              status: order.status || 'PENDING',
              screen: 'restaurant-console',
              timestamp: Date.now().toString(),
            }
          )

          // Topic broadcasts
          sendTopicWithRetry(fcmMessaging, { topic: `restaurant_orders_${order.restaurantId}`, ...restPayload }).catch(() => {})
          sendTopicWithRetry(fcmMessaging, { topic: `restaurant_${order.restaurantId}`, ...restPayload }).catch(() => {})
          sendTopicWithRetry(fcmMessaging, { topic: `kitchen_${order.restaurantId}`, ...restPayload }).catch(() => {})

          // Direct FCM tokens to chefs & owners
          prisma.restaurant.findUnique({
            where: { id: order.restaurantId },
            select: { ownerPhone: true },
          }).then(async (restInfo) => {
            const cleanRestPhone = restInfo?.ownerPhone ? getLast10Digits(restInfo.ownerPhone) : ''
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
            const uniqueTokens = Array.from(new Set(restTokens.map((t) => t.token)))
            for (const token of uniqueTokens) {
              fcmMessaging.send({ token, ...restPayload }).catch(() => {})
            }
          }).catch(() => {})
        }
      } else {
        // Pure Grocery Order -> Pickers & Riders
        sendPushNotificationToRoles([Role.PICKER, Role.DELIVERY], {
          title: '📦 New Approved Order to Pick & Deliver!',
          body: `Order #${displayId} of ₹${order.total} has been approved. Ready for packing!`,
          tag: `order-${order.id}`,
          data: { orderId: order.id },
        }).catch((err: any) => console.error('Error sending push to pickers/riders:', err))

        if (fcmMessaging) {
          const staffPayload = buildOrderFcmPayload(
            '📦 New Approved Order to Pick & Deliver!',
            `Order #${displayId} of ₹${order.total} is approved. Ready for packing!`,
            {
              title: '📦 New Approved Order to Pick & Deliver!',
              body: `Order #${displayId} of ₹${order.total} is approved. Ready for packing!`,
              orderId: order.id,
              readableId: displayId,
              status: order.status || 'PENDING',
              screen: 'delivery',
              timestamp: Date.now().toString(),
            }
          )

          if (order.storeId) {
            sendTopicWithRetry(fcmMessaging, { topic: `staff_orders_${order.storeId}`, ...staffPayload }).catch(() => {})
          } else {
            sendTopicWithRetry(fcmMessaging, { topic: 'staff_orders', ...staffPayload }).catch(() => {})
          }

          prisma.fcmToken.findMany({
            where: {
              user: { role: { in: [Role.DELIVERY, Role.PICKER] } },
            },
            select: { token: true },
          }).then((staffTokens) => {
            for (const sToken of staffTokens) {
              fcmMessaging.send({ token: sToken.token, ...staffPayload }).catch(() => {})
            }
          }).catch(() => {})
        }
      }

      // 3. Direct Customer Phone Broadcast
      const customerPhone = order.address?.phone || order.user?.phone || ''
      const cleanPhone = getLast10Digits(customerPhone)
      if (fcmMessaging && cleanPhone && cleanPhone.length === 10) {
        const custApprovalPayload = buildOrderFcmPayload(
          '✅ Order Approved & Confirmed!',
          `Your order #${displayId} has been approved and is now being prepared.`,
          {
            title: '✅ Order Approved & Confirmed!',
            body: `Your order #${displayId} has been approved and is now being prepared.`,
            orderId: order.id,
            readableId: displayId,
            status: order.status || 'PENDING',
            screen: 'order-tracking',
            timestamp: Date.now().toString(),
          }
        )
        sendTopicWithRetry(fcmMessaging, { topic: `phone_${cleanPhone}`, ...custApprovalPayload }).catch(() => {})
      }
    }
  } catch (err) {
    console.error('dispatchAdminApprovedNotifications error:', err)
  }
}

