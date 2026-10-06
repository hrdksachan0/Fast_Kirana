import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { verifyCashfreeWebhookSignature } from '@/lib/cashfree'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles, sendPushNotificationToRestaurant } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { Role } from '@prisma/client'
import { cache } from '@/lib/redis-client'

export async function GET() {
  return NextResponse.json({ status: 'active', message: 'Cashfree Webhook Endpoint Active' }, { status: 200 })
}

export async function POST(req: NextRequest) {
  try {
    const rawBody = await req.text()
    if (!rawBody || rawBody.trim() === '' || rawBody === '{}') {
      return NextResponse.json({ received: true, status: 'ok' })
    }

    const signature = req.headers.get('x-webhook-signature') || ''
    const timestamp = req.headers.get('x-webhook-timestamp') || ''

    // Verify signature if configured
    if (signature && timestamp) {
      const isValid = verifyCashfreeWebhookSignature(rawBody, timestamp, signature)
      if (!isValid) {
        console.warn('Cashfree webhook signature mismatch')
        return NextResponse.json({ error: 'Invalid signature' }, { status: 400 })
      }
    }

    let event: any = {}
    try {
      event = JSON.parse(rawBody)
    } catch {
      return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 })
    }

    const eventType = event.type
    const orderData = event.data?.order
    const paymentData = event.data?.payment

    if (eventType === 'PAYMENT_SUCCESS_WEBHOOK' || paymentData?.payment_status === 'SUCCESS') {
      const orderId = orderData?.order_id
      if (orderId) {
        const rawId = String(orderId).trim()
        const cleanId = rawId.replace(/_r\d+$/, '')
        const lockKey = `lock:webhook:cf:${cleanId}`
        const acquired = await cache.acquireLock(lockKey, 30)
        if (!acquired) {
          console.log(`[CashfreeWebhook] Duplicate/concurrent webhook ignored for order #${cleanId}`)
          return NextResponse.json({ received: true, status: 'already_processing' })
        }

        // Cache payment success so if client creates the order slightly later, it's immediately recognized as PAID
        try {
          await cache.set(`cf_paid:${cleanId}`, 'true', { ex: 3600 })
          if (rawId && rawId !== cleanId) {
            await cache.set(`cf_paid:${rawId}`, 'true', { ex: 3600 })
          }
        } catch (_) {}

        const orders: any[] = await prisma.$queryRaw`
          SELECT o.id, o."combinedId", o."readableId", o.status::text as status,
                 o.total, o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."restaurantId", o."shopName",
                 u.name as "userName", u.phone as "userPhone"
          FROM orders o
          LEFT JOIN users u ON o."userId" = u.id
          WHERE o.id = ${cleanId} OR o."readableId" = ${cleanId} OR o.id = ${rawId}
             OR (o.notes IS NOT NULL AND o.notes ILIKE ${'%' + cleanId + '%'})
          LIMIT 1
        `

        if (orders.length > 0) {
          const order = orders[0]
          const wasCod = (order.paymentMethod || '').toUpperCase() === 'COD'

          // Build Cashfree audit note with real payment reference
          const cfPayId = paymentData?.cf_payment_id || paymentData?.payment_id || ''
          const cfPayMode = paymentData?.payment_group || paymentData?.payment_method?.upi?.channel || 'UPI'
          const cfNote = cfPayId
            ? `Cashfree Auto-Paid (Webhook CF_${cfPayId}, ${cfPayMode})`
            : 'Cashfree Auto-Paid (Webhook)'

          if (order.paymentStatus !== 'PAID') {
            if (order.combinedId) {
              await prisma.$executeRaw`
                UPDATE orders 
                SET "paymentStatus" = 'PAID'::"PaymentStatus",
                    "paymentMethod" = 'UPI'::"PaymentMethod",
                    "status" = CASE WHEN status IN ('PENDING', 'ADMIN_PENDING') THEN 'CONFIRMED'::"OrderStatus" ELSE status END,
                    "confirmedAt" = COALESCE("confirmedAt", NOW()),
                    notes = CASE 
                      WHEN notes IS NULL OR notes = '' THEN ${cfNote}
                      WHEN notes LIKE '%Cashfree%' THEN notes
                      ELSE notes || ' | ' || ${cfNote}
                    END,
                    "updatedAt" = NOW()
                WHERE "combinedId" = ${order.combinedId}
              `
            } else {
              await prisma.$executeRaw`
                UPDATE orders 
                SET "paymentStatus" = 'PAID'::"PaymentStatus",
                    "paymentMethod" = 'UPI'::"PaymentMethod",
                    "status" = CASE WHEN status IN ('PENDING', 'ADMIN_PENDING') THEN 'CONFIRMED'::"OrderStatus" ELSE status END,
                    "confirmedAt" = COALESCE("confirmedAt", NOW()),
                    notes = CASE 
                      WHEN notes IS NULL OR notes = '' THEN ${cfNote}
                      WHEN notes LIKE '%Cashfree%' THEN notes
                      ELSE notes || ' | ' || ${cfNote}
                    END,
                    "updatedAt" = NOW()
                WHERE id = ${order.id}
              `
            }

            console.log(`✅ Cashfree webhook: Order #${order.readableId || order.id} marked PAID! (wasCod: ${wasCod})`)

            // Fire full notification suite
            try {
              const displayId = order.readableId
                ? String(order.readableId).replace(/-[GR\d]+$/i, '')
                : order.id.slice(-6).toUpperCase()

              let notifyTotal = Number(order.total || 0)
              if (order.combinedId) {
                const combinedTotals: any[] = await prisma.$queryRaw`
                  SELECT SUM(total) as "combinedTotal" FROM orders WHERE "combinedId" = ${order.combinedId}
                `
                if (combinedTotals[0]?.combinedTotal) {
                  notifyTotal = Number(combinedTotals[0].combinedTotal)
                }
              }

              // 1. SSE Event for Admin Dashboard
              sseEmitter.emit('order', {
                type: 'new-order',
                orderId: order.id,
                readableId: displayId,
                status: 'CONFIRMED',
                total: notifyTotal,
                paymentStatus: 'PAID',
                paymentMethod: 'UPI',
                createdAt: new Date().toISOString(),
              })

              // 2. Push Notifications
              const isRestaurantOrder = !!order.restaurantId
              const outletName = order.shopName || (order.restaurantId ? 'Restaurant' : 'FastKirana Grocery')
              const customerName = order.userName || 'Customer'
              const customerPhone = order.userPhone || 'N/A'

              if (isRestaurantOrder) {
                sendPushNotificationToRoles([Role.ADMIN, Role.DELIVERY], {
                  title: '💳 Online Payment Order Confirmed!',
                  body: `Order #${displayId} of ₹${notifyTotal} — PAID via Cashfree ✅`,
                  tag: `order-${order.id}`,
                  data: { orderId: order.id }
                }).catch((err: any) => console.error('Push admin error:', err))

                if (order.status !== 'ADMIN_PENDING') {
                  sendPushNotificationToRestaurant(order.restaurantId, {
                    title: `👨‍🍳 New Food Order #${displayId}!`,
                    body: `Order #${displayId} for ${outletName} is confirmed and paid. Start preparing dishes!`,
                    tag: `restaurant-order-${order.id}`,
                    data: { orderId: order.id, restaurantId: order.restaurantId }
                  }).catch((err: any) => console.error('Push restaurant error:', err))
                }
              } else {
                sendPushNotificationToRoles([Role.ADMIN, Role.PICKER, Role.DELIVERY], {
                  title: '💳 Online Payment Order Confirmed!',
                  body: `Order #${displayId} of ₹${notifyTotal} — PAID via Cashfree ✅`,
                  tag: `order-${order.id}`,
                  data: { orderId: order.id }
                }).catch((err: any) => console.error('Push grocery error:', err))
              }

              // Special Late Payment / Webhook Reconciliation Alert:
              // If order was previously converted or placed as COD, notify Delivery partner not to collect cash
              if (wasCod) {
                sendPushNotificationToRoles([Role.DELIVERY, Role.ADMIN], {
                  title: '⚠️ CASH MAT LENA! Order Paid Online',
                  body: `Order #${displayId} (₹${notifyTotal}) customer ne online pay kar diya hai. Delivery ke waqt CASH NA LEIN!`,
                  tag: `cod-reconciled-${order.id}`,
                  data: { orderId: order.id, paidOnline: 'true' }
                }).catch((err: any) => console.error('Push delivery late payment error:', err))
              }

              // 3. WhatsApp Alert to Admin
              const settings = await prisma.storeSetting.findMany({
                where: { key: { in: ['whatsapp_notify_7054470303', 'whatsapp_notify_8112849854'] } }
              })
              const settingsMap: Record<string, string> = {}
              for (const s of settings) {
                settingsMap[s.key] = s.value
              }

              const adminPhones: string[] = []
              if (settingsMap['whatsapp_notify_7054470303'] !== 'false') adminPhones.push('7054470303')
              if (settingsMap['whatsapp_notify_8112849854'] !== 'false') adminPhones.push('8112849854')

              const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://fastkirana.in'
              const cleanAppUrl = appUrl.replace('https://', '').replace('http://', '')
              const adminText = wasCod
                ? `⚠️ *LATE PAYMENT RECONCILED* #${displayId} for [${outletName}] of ₹${notifyTotal} from ${customerName} (${customerPhone}). Previously COD, now PAID online via Cashfree ✅. DO NOT COLLECT CASH! Manage: ${cleanAppUrl}/admin`
                : `💳 *PAID Online Order* #${displayId} for [${outletName}] of ₹${notifyTotal} from ${customerName} (${customerPhone}). Payment: Cashfree PAID ✅. Manage: ${cleanAppUrl}/admin`

              for (const adminPhone of adminPhones) {
                sendWhatsAppOrderAlert(adminPhone, adminText).catch(() => {})
              }

              // 4. Supabase realtime broadcast
              try {
                const { supabase } = await import('@/lib/supabase-client')
                const channel = supabase.channel('admin-orders-live')
                channel.subscribe((status) => {
                  if (status === 'SUBSCRIBED') {
                    channel.send({
                      type: 'broadcast',
                      event: 'order-payment-updated',
                      payload: {
                        orderId: order.id,
                        readableId: displayId,
                        paymentStatus: 'PAID',
                        status: 'CONFIRMED',
                        wasCod: wasCod,
                      }
                    }).finally(() => {
                      supabase.removeChannel(channel)
                    })
                  }
                })
              } catch (sbErr) {
                console.warn('Supabase broadcast notice:', sbErr)
              }
            } catch (notifErr) {
              console.warn('Cashfree webhook notification notice:', notifErr)
            }
          }
        } else {
          // ⚠️ ORPHAN PAYMENT SAFETY NET — Order not found in DB but payment was successful!
          // This is the scenario that caused missed orders (e.g. Ankita Sachan's Khajoor order).
          // Save the payment details so it's never silently lost.
          const cfPayId = paymentData?.cf_payment_id || paymentData?.payment_id || ''
          const paymentAmount = Number(orderData?.order_amount || paymentData?.payment_amount || 0)
          const customerPhone = orderData?.customer_details?.customer_phone || paymentData?.customer_phone || null
          const customerName = orderData?.customer_details?.customer_name || null
          const customerEmail = orderData?.customer_details?.customer_email || null

          console.error(`🚨 ORPHAN PAYMENT DETECTED! Cashfree payment SUCCESS for order ${cleanId} (₹${paymentAmount}) but NO matching order in DB! Customer: ${customerName || 'Unknown'} (${customerPhone || 'N/A'})`)

          // Save to orphan_payments table
          try {
            await prisma.orphanPayment.upsert({
              where: { cfOrderId: cleanId },
              update: {
                cfPaymentId: cfPayId ? String(cfPayId) : null,
                amount: paymentAmount,
                customerPhone,
                customerName,
                customerEmail,
                rawPayload: event,
                notes: `Webhook received at ${new Date().toISOString()}. Order ID from Cashfree: ${rawId}`,
              },
              create: {
                cfOrderId: cleanId,
                cfPaymentId: cfPayId ? String(cfPayId) : null,
                amount: paymentAmount,
                customerPhone,
                customerName,
                customerEmail,
                rawPayload: event,
                status: 'UNRESOLVED',
                notes: `Webhook received at ${new Date().toISOString()}. Order ID from Cashfree: ${rawId}`,
              },
            })
          } catch (orphanErr) {
            console.error('Failed to save orphan payment record:', orphanErr)
          }

          // 🚨 Send URGENT admin alerts — WhatsApp + Push
          try {
            const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://fastkirana.in'
            const cleanAppUrl = appUrl.replace('https://', '').replace('http://', '')

            const urgentMsg = `🚨 *ORPHAN PAYMENT ALERT!*\n\nPayment of ₹${paymentAmount} received via Cashfree but NO ORDER FOUND in system!\n\nCashfree Order: ${rawId}\nCF Payment ID: ${cfPayId || 'N/A'}\nCustomer: ${customerName || 'Unknown'}\nPhone: ${customerPhone || 'N/A'}\n\n⚡ *Action Required:* Create manual order for this customer in Admin → Orders → Create On Behalf.\n\nManage: ${cleanAppUrl}/admin`

            const adminPhones = ['7054470303', '8112849854']
            for (const phone of adminPhones) {
              sendWhatsAppOrderAlert(phone, urgentMsg).catch(() => {})
            }

            sendPushNotificationToRoles([Role.ADMIN], {
              title: '🚨 ORPHAN PAYMENT! Order Missing!',
              body: `₹${paymentAmount} received from ${customerName || customerPhone || 'Unknown'} but NO order found! Create order manually ASAP.`,
              tag: `orphan-payment-${cleanId}`,
              data: { type: 'orphan-payment', cfOrderId: cleanId, amount: String(paymentAmount) }
            }).catch(() => {})
          } catch (alertErr) {
            console.error('Failed to send orphan payment alert:', alertErr)
          }
        }
      }
    } else if (
      eventType === 'PAYMENT_FAILED_WEBHOOK' ||
      eventType === 'PAYMENT_USER_DROPPED_WEBHOOK' ||
      paymentData?.payment_status === 'FAILED' ||
      paymentData?.payment_status === 'USER_DROPPED'
    ) {
      const orderId = orderData?.order_id
      if (orderId) {
        const rawId = String(orderId).trim()
        const cleanId = rawId.replace(/_r\d+$/, '')
        console.warn(`⚠️ Cashfree webhook: Payment failed/dropped for order ${cleanId}: ${paymentData?.payment_message || eventType}`)
        await prisma.$executeRaw`
          UPDATE orders
          SET "paymentStatus" = 'FAILED'::"PaymentStatus",
              "updatedAt" = NOW()
          WHERE (id = ${cleanId} OR "readableId" = ${cleanId} OR id = ${rawId} OR (notes IS NOT NULL AND notes ILIKE ${'%' + cleanId + '%'}))
            AND "paymentStatus" != 'PAID'::"PaymentStatus"
            AND "paymentMethod" != 'COD'::"PaymentMethod"
        `.catch((err: any) => console.error('Error updating failed payment status:', err))
      }
    }

    return NextResponse.json({ received: true })
  } catch (err: any) {
    console.error('Error handling Cashfree webhook:', err)
    return NextResponse.json({ error: 'Webhook processing error' }, { status: 500 })
  }
}
