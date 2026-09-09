import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { verifyCashfreeWebhookSignature } from '@/lib/cashfree'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles, sendPushNotificationToRestaurant } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { Role } from '@prisma/client'

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
        const cleanId = String(orderId).trim()

        const orders: any[] = await prisma.$queryRaw`
          SELECT o.id, o."combinedId", o."readableId", o.status::text as status,
                 o.total, o."paymentStatus"::text as "paymentStatus", o."restaurantId", o."shopName",
                 u.name as "userName", u.phone as "userPhone"
          FROM orders o
          LEFT JOIN users u ON o."userId" = u.id
          WHERE o.id = ${cleanId} OR o."readableId" = ${cleanId} LIMIT 1
        `

        if (orders.length > 0) {
          const order = orders[0]

          if (order.paymentStatus !== 'PAID') {
            if (order.combinedId) {
              await prisma.$executeRaw`
                UPDATE orders 
                SET "paymentStatus" = 'PAID'::"PaymentStatus",
                    "paymentMethod" = 'UPI'::"PaymentMethod",
                    "status" = CASE WHEN status = 'PENDING' THEN 'CONFIRMED'::"OrderStatus" ELSE status END,
                    "updatedAt" = NOW()
                WHERE "combinedId" = ${order.combinedId}
              `
            } else {
              await prisma.$executeRaw`
                UPDATE orders 
                SET "paymentStatus" = 'PAID'::"PaymentStatus",
                    "paymentMethod" = 'UPI'::"PaymentMethod",
                    "status" = CASE WHEN status = 'PENDING' THEN 'CONFIRMED'::"OrderStatus" ELSE status END,
                    "updatedAt" = NOW()
                WHERE id = ${order.id}
              `
            }

            console.log(`✅ Cashfree webhook: Order #${order.readableId || order.id} marked PAID!`)

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

                sendPushNotificationToRestaurant(order.restaurantId, {
                  title: `👨‍🍳 New Food Order #${displayId}!`,
                  body: `Order #${displayId} for ${outletName} is confirmed and paid. Start preparing dishes!`,
                  tag: `restaurant-order-${order.id}`,
                  data: { orderId: order.id, restaurantId: order.restaurantId }
                }).catch((err: any) => console.error('Push restaurant error:', err))
              } else {
                sendPushNotificationToRoles([Role.ADMIN, Role.PICKER, Role.DELIVERY], {
                  title: '💳 Online Payment Order Confirmed!',
                  body: `Order #${displayId} of ₹${notifyTotal} — PAID via Cashfree ✅`,
                  tag: `order-${order.id}`,
                  data: { orderId: order.id }
                }).catch((err: any) => console.error('Push grocery error:', err))
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
              const adminText = `💳 *PAID Online Order* #${displayId} for [${outletName}] of ₹${notifyTotal} from ${customerName} (${customerPhone}). Payment: Cashfree PAID ✅. Manage: ${cleanAppUrl}/admin`

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
                        status: 'CONFIRMED'
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
        }
      }
    }

    return NextResponse.json({ received: true })
  } catch (err: any) {
    console.error('Error handling Cashfree webhook:', err)
    return NextResponse.json({ error: 'Webhook processing error' }, { status: 500 })
  }
}
