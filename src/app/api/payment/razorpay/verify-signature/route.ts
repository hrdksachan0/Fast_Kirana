import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import crypto from 'crypto'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles, sendPushNotificationToRestaurant } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { Role } from '@prisma/client'

export async function POST(req: Request) {
  try {
    const { orderId, razorpay_order_id, razorpay_payment_id, razorpay_signature } = await req.json()

    if (!orderId || !razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return NextResponse.json({ error: 'Missing required signature parameters' }, { status: 400 })
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
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const order = orders[0]

    const keySecret = process.env.RAZORPAY_KEY_SECRET || '4C54O0N5q841qdmQ8N1MTTiU'

    const generatedSignature = crypto
      .createHmac('sha256', keySecret)
      .update(`${razorpay_order_id}|${razorpay_payment_id}`)
      .digest('hex')

    if (generatedSignature !== razorpay_signature) {
      return NextResponse.json({ error: 'Invalid Razorpay payment signature' }, { status: 400 })
    }

    // Update ALL sub-orders in the combined group (or just this one if standalone)
    // Mark paymentStatus = PAID and paymentMethod = UPI, while keeping order status (e.g. PENDING) for admin confirmation
    if (order.combinedId) {
      await prisma.$executeRaw`
        UPDATE orders 
        SET "paymentStatus" = 'PAID'::"PaymentStatus",
            "paymentMethod" = 'UPI'::"PaymentMethod",
            "updatedAt" = NOW()
        WHERE "combinedId" = ${order.combinedId}
      `
    } else {
      await prisma.$executeRaw`
        UPDATE orders 
        SET "paymentStatus" = 'PAID'::"PaymentStatus",
            "paymentMethod" = 'UPI'::"PaymentMethod",
            "updatedAt" = NOW()
        WHERE id = ${order.id}
      `
    }

    // Re-fetch to get fresh state using the confirmed order.id
    const freshOrders: any[] = await prisma.$queryRaw`
      SELECT id, status::text as status, total,
             "paymentStatus"::text as "paymentStatus",
             "paymentMethod"::text as "paymentMethod",
             "readableId", "createdAt"
      FROM orders WHERE id = ${order.id} LIMIT 1
    `
    const updatedOrder = freshOrders[0] || { ...order, paymentStatus: 'PAID', paymentMethod: 'UPI' }

    // Fire notifications — payment is confirmed!
    try {
      const displayId = updatedOrder.readableId
        ? String(updatedOrder.readableId).replace(/-[GR\d]+$/i, '')
        : updatedOrder.id.slice(-6).toUpperCase()

      // Calculate combined total for notification
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

      // Push notification to staff
      const isRestaurantOrder = !!order.restaurantId
      const outletName = order.shopName || (order.restaurantId ? 'Restaurant' : 'FastKirana Grocery')
      const customerName = order.userName || 'Customer'
      const customerPhone = order.userPhone || 'N/A'

      if (isRestaurantOrder) {
        sendPushNotificationToRoles([Role.ADMIN, Role.DELIVERY], {
          title: '💳 Online Payment Order Confirmed!',
          body: `Order #${displayId} of ₹${notifyTotal} — PAID via Razorpay ✅`,
          tag: `order-${updatedOrder.id}`,
          data: { orderId: updatedOrder.id }
        }).catch((err: any) => console.error('Error sending push notification to admin:', err))

        sendPushNotificationToRestaurant(order.restaurantId, {
          title: `👨‍🍳 New Food Order #${displayId}!`,
          body: `Order #${displayId} for ${outletName} is confirmed and paid. Start preparing dishes!`,
          tag: `restaurant-order-${updatedOrder.id}`,
          data: { orderId: updatedOrder.id, restaurantId: order.restaurantId }
        }).catch((err: any) => console.error('Error sending push notification to restaurant:', err))
      } else {
        // Grocery order: only Admin, Picker, Delivery
        sendPushNotificationToRoles([Role.ADMIN, Role.PICKER, Role.DELIVERY], {
          title: '💳 Online Payment Order Confirmed!',
          body: `Order #${displayId} of ₹${notifyTotal} — PAID via Razorpay ✅`,
          tag: `order-${updatedOrder.id}`,
          data: { orderId: updatedOrder.id }
        }).catch((err: any) => console.error('Error sending push notification to grocery staff:', err))
      }

      // WhatsApp Order Alert to Admin Phones
      const settings = await prisma.storeSetting.findMany({
        where: {
          key: { in: ['whatsapp_notify_7054470303', 'whatsapp_notify_8112849854'] }
        }
      })
      const settingsMap: Record<string, string> = {}
      for (const s of settings) {
        settingsMap[s.key] = s.value
      }

      const adminPhones: string[] = []
      if (settingsMap['whatsapp_notify_7054470303'] !== 'false') adminPhones.push('7054470303')
      if (settingsMap['whatsapp_notify_8112849854'] !== 'false') adminPhones.push('8112849854')

      const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://fast-kirana-gtm.vercel.app'
      const cleanAppUrl = appUrl.replace('https://', '').replace('http://', '')
      
      const adminText = `💳 *PAID Online Order* #${displayId} for [${outletName}] of ₹${notifyTotal} from ${customerName} (${customerPhone}). Payment: Razorpay PAID ✅. Manage: ${cleanAppUrl}/admin`

      for (const adminPhone of adminPhones) {
        sendWhatsAppOrderAlert(adminPhone, adminText)
          .catch((err: any) => console.error(`Failed to send WhatsApp alert to ${adminPhone}:`, err))
      }

      // Broadcast live event to Supabase channel for admin & kitchen consoles
      try {
        const { supabase } = await import('@/lib/supabase-client')
        const channel = supabase.channel('admin-orders-live')
        channel.subscribe((status) => {
          if (status === 'SUBSCRIBED') {
            channel.send({
              type: 'broadcast',
              event: 'order-payment-updated',
              payload: {
                orderId: updatedOrder.id,
                readableId: displayId,
                paymentStatus: 'PAID',
                status: updatedOrder.status
              }
            }).finally(() => {
              supabase.removeChannel(channel)
            })
          }
        })
      } catch (sbErr) {
        console.warn('Supabase broadcast notice:', sbErr)
      }

      // Revalidate storefront cache
      try {
        const { revalidateStorefront } = await import('@/lib/revalidate')
        revalidateStorefront()
      } catch (e) {
        console.warn('Revalidation notice:', e)
      }

    } catch (notifErr) {
      console.error('Notification error after payment verification:', notifErr)
    }

    return NextResponse.json({
      success: true,
      message: 'Payment verified successfully!',
      orderId: updatedOrder.id,
      readableId: updatedOrder.readableId,
      status: updatedOrder.status,
      paymentStatus: 'PAID',
    })
  } catch (error: any) {
    console.error('Error verifying Razorpay signature:', error)
    return NextResponse.json(
      { error: error.message || 'Internal server error' },
      { status: 500 }
    )
  }
}
