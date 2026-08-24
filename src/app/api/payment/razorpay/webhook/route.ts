import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import crypto from 'crypto'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { Role } from '@prisma/client'

export async function POST(req: Request) {
  try {
    const rawBody = await req.text()
    const signature = req.headers.get('x-razorpay-signature')

    const webhookSecret =
      process.env.RAZORPAY_WEBHOOK_SECRET || process.env.RAZORPAY_KEY_SECRET || '4C54O0N5q841qdmQ8N1MTTiU'

    if (signature) {
      const expectedSignature = crypto
        .createHmac('sha256', webhookSecret)
        .update(rawBody)
        .digest('hex')

      if (expectedSignature !== signature) {
        console.error('Razorpay Webhook: Invalid signature')
        return NextResponse.json({ error: 'Invalid webhook signature' }, { status: 400 })
      }
    }

    const payload = JSON.parse(rawBody)
    const event = payload.event

    console.log(`Razorpay Webhook received event: ${event}`)

    if (event === 'payment.captured' || event === 'order.paid') {
      const paymentEntity = payload.payload?.payment?.entity || {}
      const orderEntity = payload.payload?.order?.entity || {}

      const razorpayOrderId = paymentEntity.order_id || orderEntity.id
      const razorpayPaymentId = paymentEntity.id
      const paymentMethod = (paymentEntity.method || 'ONLINE').toUpperCase()

      // Try finding orderId from notes or receipt
      const targetOrderId =
        paymentEntity.notes?.orderId ||
        orderEntity.receipt ||
        paymentEntity.notes?.receipt

      let order: any = null

      if (targetOrderId) {
        order = await prisma.order.findUnique({
          where: { id: targetOrderId },
          include: { user: true, address: true },
        })
      }

      if (!order && razorpayOrderId) {
        // Fallback: lookup by notes or search recent pending orders matching total amount
        const amountInRupees = (paymentEntity.amount || orderEntity.amount || 0) / 100
        if (amountInRupees > 0) {
          order = await prisma.order.findFirst({
            where: {
              paymentStatus: 'PENDING',
              total: amountInRupees,
            },
            orderBy: { createdAt: 'desc' },
            include: { user: true, address: true },
          })
        }
      }

      if (!order) {
        console.warn(`Razorpay Webhook: No matching order found for payment ${razorpayPaymentId}`)
        return NextResponse.json({ message: 'No matching order found' }, { status: 200 })
      }

      // If order is already marked PAID, return early
      if (order.paymentStatus === 'PAID') {
        console.log(`Order ${order.id} is already marked as PAID`)
        return NextResponse.json({ success: true, message: 'Order already paid' }, { status: 200 })
      }

      // Update order and any companion sub-orders (combinedId) payment status to PAID and paymentMethod
      const nextStatus = order.status === 'PENDING' ? 'CONFIRMED' : order.status
      const mappedPaymentMethod = paymentMethod === 'CARD' ? 'CARD' : (paymentMethod === 'WALLET' ? 'WALLET' : 'UPI')

      const updateFilter = order.combinedId
        ? { combinedId: order.combinedId }
        : { id: order.id }

      await prisma.order.updateMany({
        where: updateFilter,
        data: {
          paymentStatus: 'PAID',
          paymentMethod: mappedPaymentMethod as any,
          status: nextStatus as any,
        },
      })

      const updatedOrder = (await prisma.order.findUnique({
        where: { id: order.id },
      })) || order

      console.log(`✅ Order ${updatedOrder.id} updated to PAID & CONFIRMED via Razorpay Webhook`)

      // Fire notifications now that payment is confirmed!
      try {
        const displayId = (updatedOrder as any).readableId || updatedOrder.id.slice(-6).toUpperCase()

        // SSE event for admin dashboard audio & live update
        sseEmitter.emit('order', {
          type: 'new-order',
          orderId: updatedOrder.id,
          readableId: (updatedOrder as any).readableId,
          status: updatedOrder.status,
          total: updatedOrder.total,
          paymentStatus: updatedOrder.paymentStatus,
          paymentMethod: updatedOrder.paymentMethod,
          createdAt: updatedOrder.createdAt,
        })

        // Push notification to staff roles
        sendPushNotificationToRoles([Role.ADMIN, Role.CHEF, Role.DELIVERY, Role.PICKER], {
          title: '💳 Online Payment Order Confirmed!',
          body: `Order #${displayId} of ₹${updatedOrder.total} — PAID via Razorpay ✅`,
          tag: `order-${updatedOrder.id}`,
          data: { orderId: updatedOrder.id },
        }).catch((err: any) => console.error('Error sending push notification:', err))

        // WhatsApp Order Alert to Admin Phones
        const settings = await prisma.storeSetting.findMany({
          where: {
            key: { in: ['whatsapp_notify_7054470303', 'whatsapp_notify_8112849854'] },
          },
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
        const outletName =
          (order as any).shopName || ((order as any).restaurantId ? 'Restaurant' : 'FastKirana Grocery')
        const customerName = order.user?.name || 'Customer'
        const customerPhone = order.address?.phone || order.user?.phone || 'N/A'

        const adminText = `💳 *PAID Online Order* #${displayId} for [${outletName}] of ₹${updatedOrder.total} from ${customerName} (${customerPhone}). Payment: Razorpay PAID ✅. Manage: ${cleanAppUrl}/admin`

        for (const adminPhone of adminPhones) {
          sendWhatsAppOrderAlert(adminPhone, adminText).catch((err: any) =>
            console.error(`Failed to send WhatsApp alert to ${adminPhone}:`, err)
          )
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
                payload: { orderId: updatedOrder.id, paymentStatus: 'PAID', status: updatedOrder.status }
              }).finally(() => {
                supabase.removeChannel(channel)
              })
            }
          })
        } catch (sbErr) {
          console.warn('Supabase broadcast notice:', sbErr)
        }

        // Revalidate storefront and admin orders cache
        try {
          const { revalidateStorefront } = await import('@/lib/revalidate')
          revalidateStorefront()
        } catch (e) {
          console.warn('Revalidation notice:', e)
        }
      } catch (notifErr) {
        console.error('Webhook notification error:', notifErr)
      }

      return NextResponse.json({
        success: true,
        message: 'Order status updated to PAID via webhook',
        orderId: updatedOrder.id,
      })
    }

    return NextResponse.json({ success: true, message: 'Event ignored' })
  } catch (error: any) {
    console.error('Error in Razorpay Webhook:', error)
    return NextResponse.json({ error: error.message || 'Webhook processing failed' }, { status: 500 })
  }
}
