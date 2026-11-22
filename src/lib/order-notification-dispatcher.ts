import { prisma } from '@/lib/prisma'
import { sendPushNotification, sendPushNotificationToRoles, sendPushNotificationToRestaurant } from '@/lib/push-notification'
import { sendTopicWithRetry, buildOrderFcmPayload } from '@/lib/fcm-utils'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { getLast10Digits } from '@/lib/phone'
import { sendGiftRecipientNotification } from '@/lib/gift-notification'
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

  if (!createdOrders || createdOrders.length === 0) return

  const hasAdminPending = createdOrders.some((o) => o.status === OrderStatus.ADMIN_PENDING)
  const isCombined = createdOrders.length > 1
  const primaryOrder = createdOrders.find((o) => !o.restaurantId) || createdOrders[0]
  const baseDisplayId = (primaryOrder.readableId || primaryOrder.id).replace(/-[GR]\d*$/i, '')
  const combinedTotal = createdOrders.reduce((sum, o) => sum + (Number(o.total) || 0), 0)
  const outletNames = [...new Set(createdOrders.map(o => (o.shopName || (o.restaurantId ? 'Restaurant' : 'FastMinute Grocery')).replace(/FastKirana/g, 'FastMinute')))].join(' + ')
  const storeId = primaryOrder.storeId || ''

  // ─── 1. CONSOLIDATED ADMIN NOTIFICATION (Exactly 1 Buzzer Alert per Checkout) ───────────
  // Prevents multiple notifications for multi-outlet / combined orders (Grocery + Restaurant).
  const adminTitle = hasAdminPending
    ? (isCombined ? '🚨 New Combined Order Awaiting Approval!' : '🚨 New Order Awaiting Approval!')
    : (isCombined ? `🔔 New Combined Order #${baseDisplayId}!` : `🔔 New Live Order #${baseDisplayId}!`)

  const adminBody = hasAdminPending
    ? (isCombined
        ? `Order #${baseDisplayId} Combined (${outletNames}, ₹${combinedTotal.toFixed(2)}) needs admin approval. Tap to review.`
        : `Order #${baseDisplayId} (${outletNames}, ₹${combinedTotal.toFixed(2)}) needs admin approval. Tap to review.`)
    : (isCombined
        ? `Order #${baseDisplayId} Combined (${outletNames}, ₹${combinedTotal.toFixed(2)}) received. Tap to manage.`
        : `Order #${baseDisplayId} of ₹${combinedTotal.toFixed(2)} received (${outletNames}). Tap to manage.`)

  // A. Exactly 1 Web Push Notification to Store Admin (for ALL incoming orders)
  try {
    let targetAdmins = await prisma.user.findMany({
      where: {
        role: Role.ADMIN,
        ...(storeId ? { assignedStoreId: storeId } : {}),
      },
      select: { id: true },
    })

    if (targetAdmins.length === 0) {
      targetAdmins = await prisma.user.findMany({
        where: { role: Role.ADMIN, assignedStoreId: null },
        select: { id: true },
      })
    }

    for (const adminUser of targetAdmins) {
      sendPushNotification(adminUser.id, {
        title: adminTitle,
        body: adminBody,
        tag: `admin-order-${baseDisplayId}`,
        data: { orderId: primaryOrder.id, storeId },
      }).catch((err: any) => console.error('Error sending push to admin:', err))
    }
  } catch (adminPushErr) {
    console.error('Error querying hub admins for web push:', adminPushErr)
  }

  // B. Exactly 1 FCM Push Alert to Admin (Hub Topic Broadcast with Collapse Key)
  try {
    const { fcmMessaging } = await import('@/lib/firebase-admin')
    if (fcmMessaging) {
      const staffPayload = buildOrderFcmPayload(
        adminTitle,
        adminBody,
        {
          title: adminTitle,
          body: adminBody,
          orderId: primaryOrder.id,
          readableId: baseDisplayId,
          storeId,
          status: primaryOrder.status,
          screen: 'admin-orders',
          type: 'NEW_ORDER',
          role: 'ADMIN',
          timestamp: Date.now().toString(),
        }
      )

      if (staffPayload.android) {
        staffPayload.android.collapseKey = `admin_order_${baseDisplayId}`
        if (staffPayload.android.notification) {
          staffPayload.android.notification.tag = `admin_order_${baseDisplayId}`
        }
      }

      // Hub-scoped admin topic (strictly hub-isolated, exactly 1 canonical topic per hub)
      const targetStoreId = storeId || 'hub-209206'
      const fcmDispatchPromises: Promise<any>[] = []

      let canonicalAdminTopic = `admin_orders_${targetStoreId}`
      if (targetStoreId.includes('209206')) {
        canonicalAdminTopic = 'admin_orders_ghatampur'
      } else if (targetStoreId.includes('816101')) {
        canonicalAdminTopic = 'admin_orders_barharwa'
      } else if (targetStoreId.includes('224122')) {
        canonicalAdminTopic = 'admin_orders_akbarpur'
      }

      fcmDispatchPromises.push(
        sendTopicWithRetry(fcmMessaging, { topic: canonicalAdminTopic, ...staffPayload }).catch(() => {})
      )

      // Super Admin HQ (9170942500) Direct Alert ONLY (if not on local hub topic)
      try {
        const hqTokens = await prisma.fcmToken.findMany({
          where: {
            user: {
              role: Role.ADMIN,
              phone: { contains: '9170942500' },
            },
          },
          select: { token: true },
        })

        for (const t of hqTokens) {
          if (!sentFcmTokensThisCheckout.has(t.token)) {
            sentFcmTokensThisCheckout.add(t.token)
            fcmDispatchPromises.push(
              fcmMessaging.send({ token: t.token, ...staffPayload }).catch((err: any) =>
                console.error('Direct Super Admin HQ FCM send failed:', err)
              )
            )
          }
        }
      } catch (directFcmErr) {
        console.error('Error fetching admin FCM tokens:', directFcmErr)
      }

      // STRICT AWAIT: Guarantees FCM packets reach Google before serverless runtime freezes
      await Promise.allSettled(fcmDispatchPromises)
    }
  } catch (fcmErr) {
    console.error('Unified admin FCM error:', fcmErr)
  }

  // ─── 2. EXACTLY 1 CONSOLIDATED CUSTOMER NOTIFICATION (No 2x duplicates for combined orders) ───
  const primaryCustOrder = createdOrders.find((o) => !o.restaurantId) || createdOrders[0]
  const totalCombinedAmount = createdOrders.reduce((sum, o) => sum + Number(o.total || 0), 0)
  const isAnyAdminPending = createdOrders.some((o) => o.status === OrderStatus.ADMIN_PENDING)
  const outletSummary = Array.from(new Set(createdOrders.map((o) => (o.shopName || '').replace(/FastKirana/g, 'FastMinute')).filter(Boolean))).join(' + ') || 'FastMinute Store'

  sendPushNotification(primaryCustOrder.userId, {
    title: isAnyAdminPending
      ? '⏳ Order Placed — Waiting for Store Approval'
      : isOnlinePaid
      ? '💳 Order Confirmed & Paid!'
      : notificationTitle,
    body: isAnyAdminPending
      ? `Your order #${baseDisplayId} (${outletSummary}, ₹${totalCombinedAmount.toFixed(0)}) is received and awaiting store confirmation.`
      : isOnlinePaid
      ? `Order #${baseDisplayId} (${outletSummary}, ₹${totalCombinedAmount.toFixed(0)}) has been placed and paid online.`
      : `Your order #${baseDisplayId} (${outletSummary}, ₹${totalCombinedAmount.toFixed(0)}) has been placed.`,
    icon: `${origin}/icons/icon-192.png`,
    badge: `${origin}/icons/icon-192.png`,
    tag: `order-${baseDisplayId}`,
    renotify: true,
    data: { orderId: primaryCustOrder.id, readableId: baseDisplayId },
  }).catch((err: any) => console.error('Error sending customer web push:', err))

  // ─── 3. PER-OUTLET STAFF & KITCHEN NOTIFICATIONS (Strictly Separate per outlet, ONLY after Admin Approval) ──────
  // If ANY order in this checkout requires admin approval, DO NOT notify pickers, riders, or restaurants yet!
  // Outlets are notified strictly AFTER Admin Approval via dispatchAdminApprovedNotifications.
  if (!isAnyAdminPending) {
    for (const order of createdOrders) {
      const isRestaurant = Boolean(order.orderType === 'RESTAURANT' || order.restaurantId)
      const displayId = order.readableId ? String(order.readableId) : order.id.slice(-6).toUpperCase()
      const safeShopName = (order.shopName || '').replace(/FastKirana/g, 'FastMinute')

      // Auto-approved Restaurant order: Notify Restaurant Owner / Kitchen ONLY
      if (isRestaurant && order.restaurantId) {
        if (order.status !== OrderStatus.CANCELLED) {
          sendPushNotificationToRestaurant(order.restaurantId, {
            title: `👨‍🍳 New Food Order #${displayId}!`,
            body: `New order #${displayId} received for ${safeShopName || 'Kitchen'}. Tap to prepare dishes.`,
            tag: `restaurant-order-${order.id}`,
            data: { orderId: order.id, restaurantId: order.restaurantId },
          }).catch((err: any) => console.error('Error sending push notification to restaurant:', err))
        }
      } else {
        // Auto-approved Grocery order: Notify Dark Store Pickers ONLY
        const rolesToNotify = [Role.PICKER].filter((r) => !notifiedWebRoles.has(r))
        if (rolesToNotify.length > 0) {
          rolesToNotify.forEach((r) => notifiedWebRoles.add(r))
          sendPushNotificationToRoles(rolesToNotify, {
            title: isOnlinePaid ? '💳 Online Payment Order Confirmed!' : notificationTitle,
            body: isOnlinePaid
              ? `Order #${displayId} of ₹${order.total} — PAID Online ✅`
              : `Order #${displayId} of ₹${order.total} has been placed. Tap to pack.`,
            tag: `order-${order.id}`,
            data: { orderId: order.id, storeId: order.storeId || '' },
          }).catch((err: any) => console.error('Error sending push notification to grocery pickers:', err))
        }
      }

      // FCM Push Notification to Staff & Kitchens (Auto-approved only)
      try {
        const { fcmMessaging } = await import('@/lib/firebase-admin')
        if (fcmMessaging) {
          // Direct FCM push to Picker staff for grocery orders ONLY
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

            const pickerTopic = order.storeId ? `picker_orders_${order.storeId}` : 'picker_orders'
            sendTopicWithRetry(fcmMessaging, { topic: pickerTopic, ...pickerPayload }).catch(() => {})
          }

          // Restaurant kitchen FCM notification ONLY (Isolated to this restaurant)
          if (isRestaurant && order.restaurantId && order.status !== OrderStatus.CANCELLED) {
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

            sendTopicWithRetry(fcmMessaging, { topic: `restaurant_${order.restaurantId}`, ...restaurantPayload }).catch(() => {})
          }
        }
      } catch (fcmErr) {
        console.error('Customer order placement FCM error:', fcmErr)
      }
    }
  }

  // 4. Exactly 1 Consolidated WhatsApp Alert to Hub Admin (Single alert even for multi-outlet combined orders)
  try {
    const primaryOrder = createdOrders.find((o) => !o.restaurantId) || createdOrders[0]
    const orderAlertPhones = new Set<string>()

    const storePrefix = primaryOrder.storeId ? `store:${primaryOrder.storeId}:` : ''
    const settingsMap = ctx.settingsMap || {}

    const getVal = (k: string): string | undefined => {
      if (storePrefix && settingsMap[`${storePrefix}${k}`] !== undefined && settingsMap[`${storePrefix}${k}`] !== '') {
        return settingsMap[`${storePrefix}${k}`]
      }
      return settingsMap[k]
    }

    // 1. Master Admin 7054470303
    if (getVal('whatsapp_notify_7054470303') === 'true') {
      orderAlertPhones.add('7054470303')
    }

    // 2. Ops Admin 9450358388
    if (getVal('whatsapp_notify_9450358388') === 'true') {
      orderAlertPhones.add('9450358388')
    }

    // 3. Store Contact Phone
    if (getVal('whatsapp_notify_store_phone') === 'true') {
      const storeContact = getVal('contact_phone') || getVal('store_phone')
      if (storeContact) {
        const clean = storeContact.replace(/\D/g, '').slice(-10)
        if (clean.length === 10) orderAlertPhones.add(clean)
      }
    }

    // 4. Additional store alert numbers
    const addl = getVal('store_alert_phones') || getVal('order_alert_phone')
    if (addl) {
      const matches = addl.match(/\b\d{10}\b/g)
      if (matches) matches.forEach((m: string) => orderAlertPhones.add(m))
    }
    if (orderAlertPhones.size > 0) {
      const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://fastminute.in'
      const cleanAppUrl = appUrl.replace('https://', '').replace('http://', '')
      const customerName = primaryOrder.user?.name || 'Customer'
      const customerPhone = primaryOrder.address?.phone || primaryOrder.user?.phone || userPhone || 'N/A'

      let adminText: string
      if (createdOrders.length > 1) {
        const baseDisplayId = (primaryOrder.readableId || primaryOrder.id).replace(/-[GR]\d*$/i, '')
        const combinedTotal = createdOrders.reduce((sum, o) => sum + Number(o.total || 0), 0)
        const outlets = Array.from(new Set(createdOrders.map((o) => o.shopName || (o.restaurantId ? 'Restaurant' : 'FastMinute Dark Store')))).join(' + ')
        adminText = `#${baseDisplayId} [${outlets}, Rs.${combinedTotal.toFixed(0)}, ${customerName}: ${customerPhone}]`
      } else {
        const order = createdOrders[0]
        const displayId = order.readableId ? String(order.readableId) : order.id.slice(-6).toUpperCase()
        const outletName = order.shopName || (order.restaurantId ? 'Restaurant' : 'Dark Store')
        adminText = `#${displayId} [${outletName}, Rs.${Number(order.total).toFixed(0)}, ${customerName}: ${customerPhone}]`
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
        ? '🎉 Order Placed & Paid!'
        : '🎉 Order Placed!'
      const notifBody = isCombined
        ? `Order #${baseDisplayId} (₹${combinedTotal.toFixed(0)}) is confirmed & packing.`
        : `Order #${primaryOrder.readableId || primaryOrder.id} is confirmed & packing.`

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

  // 6. Gift Order Recipient Alert with Live Tracking Link
  try {
    const primaryOrder = createdOrders.find((o) => !o.restaurantId) || createdOrders[0]
    const notesStr = primaryOrder?.notes || ''
    const trackingLinkMatch = notesStr.match(/\[SEND LIVE TRACKING LINK TO:\s*([0-9+ ]+)\]/i)
    if (trackingLinkMatch && trackingLinkMatch[1]) {
      const recipientPhone = trackingLinkMatch[1].replace(/\D/g, '').slice(-10)
      if (recipientPhone.length === 10) {
        const giftNoteMatch = notesStr.match(/💌 Gift Note:\s*(.*?)(?:\||$)/)
        const recipientNameMatch = notesStr.match(/🎁 Order for:\s*(.*?)(?:\(|$)/)

        const appUrl = (process.env.NEXT_PUBLIC_APP_URL || origin || 'https://fastminute.in').replace(/\/+$/, '')
        const trackingUrl = `${appUrl}/order/${primaryOrder.id}/track`

        const recipientName = recipientNameMatch ? recipientNameMatch[1].trim() : undefined
        const senderName = primaryOrder.user?.name || undefined
        const giftNote = giftNoteMatch ? giftNoteMatch[1].trim() : undefined
        const baseDisplayId = (primaryOrder.readableId || primaryOrder.id).replace(/-[GR]\d*$/i, '')

        sendGiftRecipientNotification({
          orderId: primaryOrder.id,
          readableId: baseDisplayId,
          recipientPhone,
          recipientName,
          senderName,
          giftNote,
          trackingUrl,
        }).catch((err) => console.error('[GiftRecipientNotification] Failed:', err))
      }
    }
  } catch (giftAlertErr) {
    console.error('Gift recipient tracking alert error:', giftAlertErr)
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
    const baseRid = primaryOrder.readableId ? primaryOrder.readableId.replace(/-[GR]\d*$/i, '') : ''
    let allTargetOrders = primaryOrder.combinedId
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

    if (allTargetOrders.length <= 1 && baseRid) {
      const siblingOrders = await prisma.order.findMany({
        where: { readableId: { startsWith: baseRid } },
        include: {
          user: true,
          address: true,
          restaurant: true,
          items: true,
        },
      })
      if (siblingOrders.length > 0) {
        allTargetOrders = siblingOrders
      }
    }

    const { fcmMessaging } = await import('@/lib/firebase-admin')
    const { createClient } = await import('@supabase/supabase-js')

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://bberzasmxwioxjynbuaf.supabase.co'
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''
    const supabase = (supabaseUrl && supabaseKey)
      ? createClient(supabaseUrl, supabaseKey, { auth: { persistSession: false } })
      : null

    // ─── 1. EXACTLY 1 CONSOLIDATED CUSTOMER APPROVAL NOTIFICATION ─────────────────────
    const primaryTargetOrder = allTargetOrders.find((o) => !o.restaurantId) || allTargetOrders[0]
    const baseDisplayId = baseRid || (primaryTargetOrder.readableId ? String(primaryTargetOrder.readableId) : primaryTargetOrder.id.slice(-6).toUpperCase())
    const totalApprovedAmount = allTargetOrders.reduce((sum, o) => sum + Number(o.total || 0), 0)
    const outletsCombined = Array.from(new Set(allTargetOrders.map((o) => (o.shopName || '').replace(/FastKirana/g, 'FastMinute')).filter(Boolean))).join(' + ') || 'FastMinute Store'

    // Customer Web Push (Single consolidated notification)
    sendPushNotification(primaryTargetOrder.userId, {
      title: '✅ Order Approved & Confirmed!',
      body: `Your order #${baseDisplayId} (${outletsCombined}, ₹${totalApprovedAmount.toFixed(0)}) has been approved and is now being prepared!`,
      icon: `${baseOrigin}/icons/icon-192.png`,
      badge: `${baseOrigin}/icons/icon-192.png`,
      tag: `order-${baseDisplayId}`,
      renotify: true,
      data: { orderId: primaryTargetOrder.id, readableId: baseDisplayId },
    }).catch((err: any) => console.error('Error sending customer approval web push:', err))

    // Customer Phone FCM (Single consolidated notification)
    const customerPhone = primaryTargetOrder.address?.phone || primaryTargetOrder.user?.phone || ''
    const cleanPhone = getLast10Digits(customerPhone)
    if (fcmMessaging && cleanPhone && cleanPhone.length === 10) {
      const custApprovalPayload = buildOrderFcmPayload(
        '✅ Order Approved & Confirmed!',
        `Your order #${baseDisplayId} (${outletsCombined}, ₹${totalApprovedAmount.toFixed(0)}) has been approved and is now being prepared!`,
        {
          title: '✅ Order Approved & Confirmed!',
          body: `Your order #${baseDisplayId} (${outletsCombined}, ₹${totalApprovedAmount.toFixed(0)}) has been approved and is now being prepared!`,
          orderId: primaryTargetOrder.id,
          readableId: baseDisplayId,
          status: 'CONFIRMED',
          screen: 'order-tracking',
          timestamp: Date.now().toString(),
        }
      )
      sendTopicWithRetry(fcmMessaging, { topic: `phone_${cleanPhone}`, ...custApprovalPayload }).catch(() => {})
    }

    // ─── 2. RIDER ASSIGNMENT BUZZER (Triggered ONLY if a designated rider is assigned) ──
    const assignedRiderId = primaryTargetOrder.deliveryUserId || allTargetOrders.find((o) => o.deliveryUserId)?.deliveryUserId
    if (assignedRiderId && String(assignedRiderId).trim().toUpperCase() !== 'UNASSIGNED' && String(assignedRiderId).trim().toUpperCase() !== 'STORE_ADMIN_SELF') {
      const cleanRiderId = String(assignedRiderId).trim()
      const riderPayload = buildOrderFcmPayload(
        `🛵 Order #${baseDisplayId} Assigned to You!`,
        `Order #${baseDisplayId} (${outletsCombined}, ₹${totalApprovedAmount.toFixed(0)}) has been assigned to you. Tap to deliver.`,
        {
          title: `🛵 Order #${baseDisplayId} Assigned to You!`,
          body: `Order #${baseDisplayId} (${outletsCombined}, ₹${totalApprovedAmount.toFixed(0)}) has been assigned to you. Tap to deliver.`,
          orderId: primaryTargetOrder.id,
          readableId: baseDisplayId,
          status: 'CONFIRMED',
          screen: 'delivery',
          url: '/delivery',
          role: 'DELIVERY',
          type: 'ORDER_ASSIGNED',
          timestamp: Date.now().toString(),
        }
      )
      if (fcmMessaging) {
        sendTopicWithRetry(fcmMessaging, { topic: `user_${cleanRiderId}`, ...riderPayload }).catch(() => {})
      }
    }

    // ─── 3. PER-OUTLET SEPARATE NOTIFICATIONS (Kitchen & Dark Store Pickers) ───────────
    for (const order of allTargetOrders) {
      const displayId = order.readableId ? String(order.readableId) : order.id.slice(-6).toUpperCase()
      const isRestaurant = Boolean(order.orderType === 'RESTAURANT' || order.restaurantId)
      const outletName = order.shopName || (isRestaurant ? 'Restaurant' : 'FastMinute Dark Store')

      // Staff Web & FCM Notifications
      if (isRestaurant && order.restaurantId) {
        // Instant Realtime Supabase Broadcast for Kitchen Console Chime & Refresh
        if (supabase) {
          try {
            const restBroadcastPayload = {
              orderId: order.id,
              readableId: displayId,
              restaurantId: order.restaurantId,
              restaurantName: order.restaurant?.name || order.shopName,
              shopName: order.shopName,
              status: order.status || 'PENDING',
            }

            // Broadcast to both outlet-specific and global restaurant channels
            const chSpecific = supabase.channel(`restaurant-orders-live-${order.restaurantId}`)
            chSpecific.subscribe((status) => {
              if (status === 'SUBSCRIBED') {
                chSpecific.send({
                  type: 'broadcast',
                  event: 'new_order',
                  payload: restBroadcastPayload,
                }).then(() => supabase.removeChannel(chSpecific)).catch(() => {})
              }
            })

            const chGlobal = supabase.channel('restaurant-orders-live')
            chGlobal.subscribe((status) => {
              if (status === 'SUBSCRIBED') {
                chGlobal.send({
                  type: 'broadcast',
                  event: 'new_order',
                  payload: restBroadcastPayload,
                }).then(() => supabase.removeChannel(chGlobal)).catch(() => {})
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

        // FCM to Restaurant & Kitchen Staff
        if (fcmMessaging) {
          const restPayload = buildOrderFcmPayload(
            `👨‍🍳 New Food Order #${displayId}!`,
            `Order #${displayId} (${outletName}) is APPROVED by Admin. Start cooking!`,
            {
              title: `👨‍🍳 New Food Order #${displayId}!`,
              body: `Order #${displayId} (${outletName}) is APPROVED by Admin. Start cooking!`,
              orderId: order.id,
              readableId: displayId,
              restaurantId: order.restaurantId,
              status: order.status || 'PENDING',
              screen: 'restaurant-console',
              type: 'NEW_ORDER',
              timestamp: Date.now().toString(),
            }
          )

          // 1. Topic broadcast to canonical restaurant topic
          sendTopicWithRetry(fcmMessaging, { topic: `restaurant_${order.restaurantId}`, ...restPayload }).catch(() => {})

          // 2. Direct FCM tokens for users assigned to this restaurant
          prisma.fcmToken.findMany({
            where: {
              user: {
                OR: [
                  { assignedRestaurantId: order.restaurantId },
                  { role: { in: [Role.CHEF, Role.RESTAURANT_OWNER] } },
                ],
              },
            },
            select: { token: true },
          }).then((restTokens) => {
            for (const rToken of restTokens) {
              fcmMessaging.send({
                token: rToken.token,
                ...restPayload,
                android: {
                  priority: 'high',
                  notification: {
                    sound: 'order_chime',
                    channelId: 'fastminute_order_alarm_v3',
                  },
                },
              }).catch(() => {})
            }
          }).catch((err: any) => console.error('Error fetching restaurant FCM tokens:', err))
        }
      } else {
        // Pure Grocery Dark Store Order: Alert Pickers
        const pickerRoles = [Role.PICKER]
        sendPushNotificationToRoles(pickerRoles, {
          title: `📦 Order #${displayId} Approved!`,
          body: `Order #${displayId} of ₹${order.total} has been approved. Ready for packing!`,
          tag: `order-${order.id}`,
          data: { orderId: order.id, storeId: order.storeId || '' },
        }).catch((err: any) => console.error('Error sending push to pickers:', err))

        if (fcmMessaging) {
          const staffPayload = buildOrderFcmPayload(
            '📦 New Approved Order to Pick!',
            `Order #${displayId} of ₹${order.total} is approved. Ready for packing!`,
            {
              title: '📦 New Approved Order to Pick!',
              body: `Order #${displayId} of ₹${order.total} is approved. Ready for packing!`,
              orderId: order.id,
              readableId: displayId,
              storeId: order.storeId || '',
              status: order.status || 'PENDING',
              screen: 'picker',
              role: 'PICKER',
              type: 'NEW_ORDER',
              timestamp: Date.now().toString(),
            }
          )

          const pickerTopic = order.storeId ? `picker_orders_${order.storeId}` : 'picker_orders'
          sendTopicWithRetry(fcmMessaging, { topic: pickerTopic, ...staffPayload }).catch(() => {})
        }
      }
    }

    // Unified Order Event Engine broadcast on admin approval
    try {
      const { OrderEventEngine } = await import('@/lib/order-event-engine')
      await OrderEventEngine.emit({
        orderId: primaryOrder.id,
        tag: 'ORDER_ADMIN_APPROVED',
        newStatus: primaryOrder.status || 'CONFIRMED',
        previousStatus: 'ADMIN_PENDING',
        origin: baseOrigin,
      })
    } catch (engineErr) {
      console.error('dispatchAdminApprovedNotifications OrderEventEngine error:', engineErr)
    }
  } catch (err) {
    console.error('dispatchAdminApprovedNotifications error:', err)
  }
}

