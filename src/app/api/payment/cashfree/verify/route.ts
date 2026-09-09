import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getCashfreeOrder, getCashfreeOrderPayments } from '@/lib/cashfree'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles, sendPushNotificationToRestaurant } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { Role } from '@prisma/client'
import { apiWriteLimiter } from '@/lib/rate-limit'

export async function POST(req: NextRequest) {
  const limited = await apiWriteLimiter.check(req)
  if (limited) return limited

  try {
    const { orderId } = await req.json()

    if (!orderId) {
      return NextResponse.json({ error: 'orderId is required' }, { status: 400 })
    }

    const cleanId = String(orderId).trim()

    const orders: any[] = await prisma.$queryRaw`
      SELECT o.id, o."userId", o."combinedId", o."readableId",
             o.status::text as status,
             o.total, o."paymentStatus"::text as "paymentStatus",
             o."paymentMethod"::text as "paymentMethod",
             o."shopName", o."restaurantId",
             o."createdAt",
             u.name as "userName", u.phone as "userPhone", u.email as "userEmail"
      FROM orders o
      LEFT JOIN users u ON o."userId" = u.id
      WHERE o.id = ${cleanId} OR o."readableId" = ${cleanId} LIMIT 1
    `

    if (!orders || orders.length === 0) {
      // Check if this is a preflight Cashfree order before DB record creation (e.g. Flutter mobile checkout)
      try {
        const cfOrder = await getCashfreeOrder(cleanId)
        if (cfOrder && cfOrder.order_status === 'PAID') {
          return NextResponse.json({
            success: true,
            orderId: cleanId,
            paymentStatus: 'PAID',
            isPaid: true,
            orderAmount: cfOrder.order_amount,
          })
        }
        const payments = await getCashfreeOrderPayments(cleanId)
        const successfulPayment = payments.find(p => p.payment_status === 'SUCCESS')
        if (successfulPayment) {
          return NextResponse.json({
            success: true,
            orderId: cleanId,
            paymentStatus: 'PAID',
            isPaid: true,
            cfPaymentId: String(successfulPayment.cf_payment_id || ''),
          })
        }
      } catch (cfErr) {
        console.warn('Preflight Cashfree order check note:', cfErr)
      }
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const order = orders[0]

    // Verify status with Cashfree Server directly
    let isPaid = false
    let cfPaymentId = ''
    let paymentMode = 'UPI'

    try {
      const cfOrder = await getCashfreeOrder(order.id)
      if (cfOrder && cfOrder.order_status === 'PAID') {
        isPaid = true
      }
    } catch (cfErr) {
      console.warn('Direct order status check note:', cfErr)
    }

    if (!isPaid) {
      try {
        const payments = await getCashfreeOrderPayments(order.id)
        const successfulPayment = payments.find(p => p.payment_status === 'SUCCESS')
        if (successfulPayment) {
          isPaid = true
          cfPaymentId = String(successfulPayment.cf_payment_id || '')
          if (successfulPayment.payment_method) {
            paymentMode = 'UPI'
          }
        }
      } catch (payErr) {
        console.warn('Payments check note:', payErr)
      }
    }

    if (!isPaid) {
      return NextResponse.json({
        success: false,
        paymentStatus: 'PENDING',
        message: 'Payment has not been completed or is still processing.'
      }, { status: 400 })
    }

    // Update ALL sub-orders in the combined group (or standalone order)
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

    const freshOrders: any[] = await prisma.$queryRaw`
      SELECT id, status::text as status, total,
             "paymentStatus"::text as "paymentStatus",
             "paymentMethod"::text as "paymentMethod",
             "readableId", "createdAt"
      FROM orders WHERE id = ${order.id} LIMIT 1
    `
    const updatedOrder = freshOrders[0] || { ...order, paymentStatus: 'PAID', paymentMethod: 'UPI' }

    // Fire notifications
    try {
      const displayId = updatedOrder.readableId
        ? String(updatedOrder.readableId).replace(/-[GR\d]+$/i, '')
        : updatedOrder.id.slice(-6).toUpperCase()

      let notifyTotal = Number(updatedOrder.total || 0)
      if (order.combinedId) {
        const combinedTotals: any[] = await prisma.$queryRaw`
          SELECT SUM(total) as "combinedTotal" FROM orders WHERE "combinedId" = ${order.combinedId}
        `
        if (combinedTotals[0]?.combinedTotal) {
          notifyTotal = Number(combinedTotals[0].combinedTotal)
        }
      }

      // SSE event for admin dashboard
      sseEmitter.emit('order', {
        type: 'new-order',
        orderId: updatedOrder.id,
        readableId: displayId,
        status: updatedOrder.status,
        total: notifyTotal,
        paymentStatus: 'PAID',
        paymentMethod: 'UPI',
        createdAt: updatedOrder.createdAt,
      })

      // Push notification
      const isRestaurantOrder = !!order.restaurantId
      const outletName = order.shopName || (order.restaurantId ? 'Restaurant' : 'FastKirana Grocery')
      const customerName = order.userName || 'Customer'
      const customerPhone = order.userPhone || 'N/A'

      if (isRestaurantOrder) {
        sendPushNotificationToRoles([Role.ADMIN, Role.DELIVERY], {
          title: '💳 Online Payment Order Confirmed!',
          body: `Order #${displayId} of ₹${notifyTotal} — PAID via Cashfree ✅`,
          tag: `order-${updatedOrder.id}`,
          data: { orderId: updatedOrder.id }
        }).catch((err: any) => console.error('Push admin error:', err))

        sendPushNotificationToRestaurant(order.restaurantId, {
          title: `👨‍🍳 New Food Order #${displayId}!`,
          body: `Order #${displayId} for ${outletName} is confirmed and paid. Start preparing dishes!`,
          tag: `restaurant-order-${updatedOrder.id}`,
          data: { orderId: updatedOrder.id, restaurantId: order.restaurantId }
        }).catch((err: any) => console.error('Push restaurant error:', err))
      } else {
        sendPushNotificationToRoles([Role.ADMIN, Role.PICKER, Role.DELIVERY], {
          title: '💳 Online Payment Order Confirmed!',
          body: `Order #${displayId} of ₹${notifyTotal} — PAID via Cashfree ✅`,
          tag: `order-${updatedOrder.id}`,
          data: { orderId: updatedOrder.id }
        }).catch((err: any) => console.error('Push grocery error:', err))
      }

      // WhatsApp Alert
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
    } catch (notifErr) {
      console.warn('Notification non-fatal error:', notifErr)
    }

    return NextResponse.json({
      success: true,
      orderId: updatedOrder.id,
      paymentStatus: 'PAID',
      cfPaymentId,
    })
  } catch (err: any) {
    console.error('Error verifying Cashfree payment:', err)
    return NextResponse.json({ error: err.message || 'Payment verification failed' }, { status: 500 })
  }
}
