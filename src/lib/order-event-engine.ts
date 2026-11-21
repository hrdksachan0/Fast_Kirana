// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FastMinute Unified Order Event Engine (Server Core)
// Single Centralized Funnel for All Order Lifecycle Notifications, Realtime
// WebSockets, FCM Push, WhatsApp Alerts, and SSE Events.
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import { prisma } from '@/lib/prisma'
import {
  OrderEventTag,
  OrderEventEnvelope,
  resolveAlertMatrix,
} from './order-event-types'
import { getLast10Digits } from '@/lib/phone'
import { buildOrderFcmPayload, sendTopicWithRetry } from '@/lib/fcm-utils'
import { sseEmitter } from '@/lib/sse-emitter'
import { Role } from '@prisma/client'

export interface EmitOrderEventParams {
  orderId: string
  tag: OrderEventTag
  newStatus?: string
  previousStatus?: string
  actorId?: string
  actorRole?: string
  payload?: Record<string, any>
  origin?: string
  settingsMap?: Record<string, string>
}

export class OrderEventEngine {
  /**
   * Primary entry point for every order event in FastMinute.
   * Call this from any API route whenever an order is created, updated, or assigned.
   */
  static async emit(params: EmitOrderEventParams): Promise<OrderEventEnvelope | null> {
    const { orderId, tag, newStatus: inputNewStatus, previousStatus: inputPrevStatus, actorId, actorRole, payload = {}, origin } = params

    try {
      const cleanId = orderId.replace(/^#/, '').trim()
      const strippedFkId = cleanId.replace(/^FK-/, '').trim()

      // 1. Fetch primary order
      const primaryOrder = await prisma.order.findFirst({
        where: {
          OR: [
            { id: cleanId },
            { id: strippedFkId },
            { readableId: cleanId },
            { readableId: strippedFkId },
            { readableId: { startsWith: strippedFkId } },
            { combinedId: cleanId },
          ],
        },
        include: {
          user: { select: { id: true, name: true, phone: true } },
          address: true,
          restaurant: { select: { id: true, name: true } },
          items: true,
        },
      })

      if (!primaryOrder) {
        console.warn(`[OrderEventEngine] Order not found for id=${orderId}`);
        return null
      }

      // 2. Resolve sibling orders if part of a combined multi-outlet checkout
      const baseDisplayId = (primaryOrder.readableId || primaryOrder.id).replace(/-[GR]\d*$/i, '')
      let allOrders = [primaryOrder]
      if (primaryOrder.combinedId) {
        allOrders = await prisma.order.findMany({
          where: { combinedId: primaryOrder.combinedId },
          include: {
            user: { select: { id: true, name: true, phone: true } },
            address: true,
            restaurant: { select: { id: true, name: true } },
            items: true,
          },
        })
      } else if (baseDisplayId) {
        const siblings = await prisma.order.findMany({
          where: { readableId: { startsWith: baseDisplayId } },
          include: {
            user: { select: { id: true, name: true, phone: true } },
            address: true,
            restaurant: { select: { id: true, name: true } },
            items: true,
          },
        })
        if (siblings.length > 0) allOrders = siblings
      }

      // 3. Compute consolidated order metrics
      const isCombined = allOrders.length > 1
      const effectiveNewStatus = inputNewStatus || primaryOrder.status
      const effectivePrevStatus = inputPrevStatus || ''
      const totalAmount = allOrders.reduce((sum, o) => sum + (Number(o.total) || 0), 0)
      const outletNames = Array.from(
        new Set(
          allOrders.map((o) =>
            (o.shopName || (o.restaurantId ? 'Restaurant Kitchen' : 'FastMinute Grocery')).replace(/FastKirana/g, 'FastMinute')
          )
        )
      )
      const outletSummary = outletNames.join(' + ')
      const storeId = primaryOrder.storeId || allOrders.find((o) => o.storeId)?.storeId || null
      const restaurantOrder = allOrders.find((o) => o.restaurantId || o.orderType === 'RESTAURANT')
      const restaurantId = restaurantOrder?.restaurantId || null
      const isOnlinePaid = primaryOrder.paymentStatus === 'PAID' || primaryOrder.paymentMethod === 'UPI'

      // 4. Resolve declarative alert rules matrix
      const { targets, alert } = resolveAlertMatrix({
        tag,
        newStatus: effectiveNewStatus,
        previousStatus: effectivePrevStatus,
        displayId: baseDisplayId,
        outletSummary,
        totalAmount,
        isCombined,
        isOnlinePaid,
        riderName: payload.riderName || (primaryOrder as any).deliveryBoyName,
        riderPhone: payload.riderPhone || (primaryOrder as any).deliveryBoyPhone,
      })

      // 5. Construct standard immutable envelope
      const envelope: OrderEventEnvelope = {
        tag,
        orderId: primaryOrder.id,
        readableId: primaryOrder.readableId || primaryOrder.id,
        displayId: baseDisplayId,
        combinedId: primaryOrder.combinedId || (isCombined ? baseDisplayId : null),
        storeId,
        restaurantId,
        orderType: isCombined ? 'COMBINED' : (restaurantId ? 'RESTAURANT' : 'GROCERY'),
        status: effectiveNewStatus,
        previousStatus: effectivePrevStatus,
        paymentStatus: primaryOrder.paymentStatus,
        paymentMethod: primaryOrder.paymentMethod,
        actorId,
        actorRole,
        targets,
        alert,
        payload: {
          ...payload,
          total: totalAmount,
          itemsCount: allOrders.reduce((sum, o) => sum + (o.items?.length || 0), 0),
          customerPhone: primaryOrder.address?.phone || primaryOrder.user?.phone || '',
          customerName: (primaryOrder.address as any)?.name || primaryOrder.user?.name || 'Customer',
        },
        version: Date.now(),
        timestamp: Date.now(),
      }

      // 6. Execute Parallel Multi-Channel Dispatch (Non-blocking Promise.allSettled)
      await Promise.allSettled([
        this.dispatchSupabaseRealtime(envelope, allOrders),
        this.dispatchFCM(envelope, primaryOrder, allOrders),
        this.dispatchSSE(envelope, primaryOrder),
        this.dispatchWhatsApp(envelope, primaryOrder, allOrders, params.settingsMap),
      ])

      return envelope
    } catch (err) {
      console.error('[OrderEventEngine] Unexpected dispatch error:', err)
      return null
    }
  }

  /**
   * Channel 1: Supabase Realtime Broadcast (sub-100ms ultra-low latency WebSocket)
   */
  private static async dispatchSupabaseRealtime(
    envelope: OrderEventEnvelope,
    allOrders: any[]
  ): Promise<void> {
    try {
      const { supabase } = await import('@/lib/supabase-client')
      if (!supabase) return

      const payload = {
        orderId: envelope.orderId,
        readableId: envelope.readableId,
        displayId: envelope.displayId,
        combinedId: envelope.combinedId,
        status: envelope.status,
        previousStatus: envelope.previousStatus,
        storeId: envelope.storeId,
        restaurantId: envelope.restaurantId,
        version: envelope.version,
        timestamp: envelope.timestamp,
        envelope,
      }

      // Fan-out to all possible channel aliases so client listeners on ANY key always receive the event
      const channelKeys = new Set<string>()
      channelKeys.add(`order-live-tracking-${envelope.orderId}`)
      channelKeys.add(`order-live-tracking-${envelope.readableId}`)
      channelKeys.add(`order-live-tracking-${envelope.displayId}`)

      if (envelope.combinedId) {
        channelKeys.add(`order-live-tracking-${envelope.combinedId}`)
      }

      for (const ord of allOrders) {
        if (ord.id) channelKeys.add(`order-live-tracking-${ord.id}`)
        if (ord.readableId) channelKeys.add(`order-live-tracking-${ord.readableId}`)
      }

      // Store-level hub channel for Admin & Pickers
      if (envelope.storeId) {
        channelKeys.add(`store-orders-${envelope.storeId}`)
      }
      channelKeys.add('admin-global-orders-websocket')

      // Restaurant-specific console channel
      if (envelope.restaurantId) {
        channelKeys.add(`restaurant-orders-live-${envelope.restaurantId}`)
        channelKeys.add('restaurant-orders-live')
      }

      const broadcastPromises = Array.from(channelKeys).map(async (key) => {
        try {
          const ch = supabase.channel(key)
          await ch.send({
            type: 'broadcast',
            event: 'status_update',
            payload,
          })
          await ch.send({
            type: 'broadcast',
            event: 'order_event',
            payload: envelope,
          })
        } catch (_) {}
      })

      await Promise.allSettled(broadcastPromises)
    } catch (err) {
      console.warn('[OrderEventEngine] Supabase broadcast warning:', err)
    }
  }

  /**
   * Channel 2: Firebase Cloud Messaging (FCM Push for Background & Killed State)
   */
  private static async dispatchFCM(
    envelope: OrderEventEnvelope,
    primaryOrder: any,
    allOrders: any[]
  ): Promise<void> {
    try {
      const { fcmMessaging } = await import('@/lib/firebase-admin')
      if (!fcmMessaging) return

      const fcmPromises: Promise<any>[] = []
      const sentTokens = new Set<string>()

      // ────────────────── A. ADMIN NOTIFICATION ──────────────────
      if (envelope.targets.includes('ADMIN') && envelope.alert.admin) {
        const adminAlert = envelope.alert.admin
        const isCritical = adminAlert.urgency === 'CRITICAL'

        const adminPayload = buildOrderFcmPayload(
          adminAlert.title,
          adminAlert.body,
          {
            title: adminAlert.title,
            body: adminAlert.body,
            orderId: envelope.orderId,
            readableId: envelope.displayId,
            storeId: envelope.storeId || '',
            status: envelope.status,
            screen: 'admin-orders',
            type: envelope.tag,
            role: 'ADMIN',
            urgency: adminAlert.urgency,
            version: String(envelope.version),
            timestamp: String(envelope.timestamp),
          }
        )

        // Custom Android alarm settings for continuous siren
        if (isCritical && adminPayload.android) {
          adminPayload.android.priority = 'high'
          if (adminPayload.android.notification) {
            adminPayload.android.notification.channelId = 'fastminute_order_alarm_v3'
            adminPayload.android.notification.sound = 'order_chime'
            adminPayload.android.notification.tag = `admin_order_${envelope.displayId}`
          }
        }

        // 1. Topic: store-scoped admin topic + global
        const adminTopic = envelope.storeId ? `admin_orders_${envelope.storeId}` : 'admin_orders'
        fcmPromises.push(sendTopicWithRetry(fcmMessaging, { topic: adminTopic, ...adminPayload }).catch(() => {}))
        if (envelope.storeId) {
          fcmPromises.push(sendTopicWithRetry(fcmMessaging, { topic: 'admin_orders', ...adminPayload }).catch(() => {}))
        }

        // 2. Direct device tokens for Admin role & master phone
        try {
          const adminTokens = await prisma.fcmToken.findMany({
            where: {
              OR: [
                { user: { role: Role.ADMIN } },
                { user: { phone: { contains: '7054470303' } } },
              ],
            },
            select: { token: true },
          })
          for (const t of adminTokens) {
            if (!sentTokens.has(t.token)) {
              sentTokens.add(t.token)
              fcmPromises.push(fcmMessaging.send({ token: t.token, ...adminPayload }).catch(() => {}))
            }
          }
        } catch (_) {}
      }

      // ────────────────── B. CUSTOMER NOTIFICATION ──────────────────
      if (envelope.targets.includes('CUSTOMER') && envelope.alert.customer && envelope.alert.customer.urgency !== 'SILENT') {
        const custAlert = envelope.alert.customer
        const custPayload = buildOrderFcmPayload(
          custAlert.title,
          custAlert.body,
          {
            title: custAlert.title,
            body: custAlert.body,
            orderId: envelope.orderId,
            readableId: envelope.displayId,
            status: envelope.status,
            screen: 'order-tracking',
            urgency: custAlert.urgency,
            version: String(envelope.version),
            timestamp: String(envelope.timestamp),
          }
        )

        const custPhone = getLast10Digits(primaryOrder.address?.phone || primaryOrder.user?.phone || '')
        const custUserIds = Array.from(new Set(allOrders.map((o) => o.userId).filter(Boolean)))

        try {
          const customerTokens = await prisma.fcmToken.findMany({
            where: {
              OR: [
                ...(custUserIds.length > 0 ? [{ userId: { in: custUserIds } }] : []),
                ...(custPhone ? [{ user: { phone: { contains: custPhone } } }] : []),
              ],
            },
            select: { token: true },
            orderBy: { createdAt: 'desc' },
            take: 2,
          })

          if (customerTokens.length > 0) {
            for (const t of customerTokens) {
              if (!sentTokens.has(t.token)) {
                sentTokens.add(t.token)
                fcmPromises.push(fcmMessaging.send({ token: t.token, ...custPayload }).catch(() => {}))
              }
            }
          } else if (custPhone && custPhone.length === 10) {
            fcmPromises.push(sendTopicWithRetry(fcmMessaging, { topic: `phone_${custPhone}`, ...custPayload }).catch(() => {}))
          }
        } catch (_) {}
      }

      // ────────────────── C. PICKER NOTIFICATION ──────────────────
      if (envelope.targets.includes('PICKER') && envelope.alert.picker) {
        const pickerAlert = envelope.alert.picker
        const pickerPayload = buildOrderFcmPayload(
          pickerAlert.title,
          pickerAlert.body,
          {
            title: pickerAlert.title,
            body: pickerAlert.body,
            orderId: envelope.orderId,
            readableId: envelope.displayId,
            storeId: envelope.storeId || '',
            status: envelope.status,
            screen: 'picker',
            role: 'PICKER',
            urgency: pickerAlert.urgency,
            version: String(envelope.version),
            timestamp: String(envelope.timestamp),
          }
        )
        const pickerTopic = envelope.storeId ? `picker_orders_${envelope.storeId}` : 'picker_orders'
        fcmPromises.push(sendTopicWithRetry(fcmMessaging, { topic: pickerTopic, ...pickerPayload }).catch(() => {}))
      }

      // ────────────────── D. KITCHEN NOTIFICATION ──────────────────
      if (envelope.targets.includes('KITCHEN') && envelope.alert.kitchen && envelope.restaurantId) {
        const kitchenAlert = envelope.alert.kitchen
        const kitchenPayload = buildOrderFcmPayload(
          kitchenAlert.title,
          kitchenAlert.body,
          {
            title: kitchenAlert.title,
            body: kitchenAlert.body,
            orderId: envelope.orderId,
            readableId: envelope.displayId,
            restaurantId: envelope.restaurantId,
            status: envelope.status,
            screen: 'restaurant-console',
            role: 'CHEF',
            urgency: kitchenAlert.urgency,
            version: String(envelope.version),
            timestamp: String(envelope.timestamp),
          }
        )
        if (kitchenPayload.android?.notification) {
          kitchenPayload.android.notification.channelId = 'fastminute_order_alarm_v3'
          kitchenPayload.android.notification.sound = 'kitchen_order_bell'
        }
        fcmPromises.push(sendTopicWithRetry(fcmMessaging, { topic: `restaurant_${envelope.restaurantId}`, ...kitchenPayload }).catch(() => {}))
      }

      // ────────────────── E. RIDER NOTIFICATION ──────────────────
      if (envelope.targets.includes('RIDER') && envelope.alert.rider) {
        const riderAlert = envelope.alert.rider
        const assignedRiderId = primaryOrder.deliveryUserId || envelope.payload.riderId
        const riderPayload = buildOrderFcmPayload(
          riderAlert.title,
          riderAlert.body,
          {
            title: riderAlert.title,
            body: riderAlert.body,
            orderId: envelope.orderId,
            readableId: envelope.displayId,
            status: envelope.status,
            screen: 'delivery',
            role: 'DELIVERY',
            type: envelope.tag,
            urgency: riderAlert.urgency,
            version: String(envelope.version),
            timestamp: String(envelope.timestamp),
          }
        )

        if (assignedRiderId && assignedRiderId !== 'UNASSIGNED') {
          fcmPromises.push(sendTopicWithRetry(fcmMessaging, { topic: `user_${assignedRiderId}`, ...riderPayload }).catch(() => {}))
        } else {
          fcmPromises.push(sendTopicWithRetry(fcmMessaging, { topic: 'delivery_orders', ...riderPayload }).catch(() => {}))
        }
      }

      await Promise.allSettled(fcmPromises)
    } catch (err) {
      console.warn('[OrderEventEngine] FCM dispatch warning:', err)
    }
  }

  /**
   * Channel 3: Server-Sent Events (SSE) for Web Admin Console
   */
  private static async dispatchSSE(
    envelope: OrderEventEnvelope,
    primaryOrder: any
  ): Promise<void> {
    try {
      sseEmitter.emit('order', {
        type: 'status-change',
        orderId: envelope.orderId,
        status: envelope.status,
        order: {
          id: envelope.orderId,
          readableId: envelope.readableId,
          status: envelope.status,
          total: envelope.payload.total,
          storeId: envelope.storeId,
          restaurantId: envelope.restaurantId,
        },
      })
      sseEmitter.emit('order:update', {
        id: envelope.orderId,
        storeId: envelope.storeId,
        status: envelope.status,
        combinedId: envelope.combinedId,
      })
    } catch (_) {}
  }

  /**
   * Channel 4: WhatsApp Notification (Only for order placement / approval alerts)
   */
  private static async dispatchWhatsApp(
    envelope: OrderEventEnvelope,
    primaryOrder: any,
    allOrders: any[],
    settingsMap?: Record<string, string>
  ): Promise<void> {
    if (envelope.tag !== 'ORDER_CREATED' && envelope.tag !== 'ORDER_ADMIN_APPROVED') return

    try {
      const { sendWhatsAppOrderAlert } = await import('@/lib/whatsapp')
      const alertPhones = new Set<string>()

      const storePrefix = envelope.storeId ? `store:${envelope.storeId}:` : ''
      const sm = settingsMap || {}
      const getVal = (k: string) => (storePrefix && sm[`${storePrefix}${k}`]) || sm[k]

      if (getVal('whatsapp_notify_7054470303') === 'true' || !settingsMap) {
        alertPhones.add('7054470303')
      }
      if (getVal('whatsapp_notify_9450358388') === 'true') {
        alertPhones.add('9450358388')
      }

      if (alertPhones.size > 0) {
        const outletNames = Array.from(new Set(allOrders.map((o) => o.shopName || (o.restaurantId ? 'Restaurant' : 'Grocery')))).join(' + ')
        const text = `#${envelope.displayId} [${outletNames}, Rs.${envelope.payload.total.toFixed(0)}, ${envelope.payload.customerName}: ${envelope.payload.customerPhone}]`

        const waPromises = Array.from(alertPhones).map((phone) =>
          sendWhatsAppOrderAlert(phone, text).catch(() => {})
        )
        await Promise.allSettled(waPromises)
      }
    } catch (_) {}
  }
}
