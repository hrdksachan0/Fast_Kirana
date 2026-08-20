import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import crypto from 'crypto'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { Role } from '@prisma/client'

export async function POST(req: Request) {
  try {
    const { orderId, razorpay_order_id, razorpay_payment_id, razorpay_signature } = await req.json()

    if (!orderId || !razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return NextResponse.json({ error: 'Missing required signature parameters' }, { status: 400 })
    }

    const order = await prisma.order.findUnique({
      where: { id: orderId },
      include: {
        user: true,
        address: true,
      }
    })

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const keySecret = process.env.RAZORPAY_KEY_SECRET || '4C54O0N5q841qdmQ8N1MTTiU'

    const generatedSignature = crypto
      .createHmac('sha256', keySecret)
      .update(`${razorpay_order_id}|${razorpay_payment_id}`)
      .digest('hex')

    if (generatedSignature !== razorpay_signature) {
      return NextResponse.json({ error: 'Invalid Razorpay payment signature' }, { status: 400 })
    }

    // Update order payment status to PAID and paymentMethod to ONLINE
    // Advance status to CONFIRMED only if it was PENDING, else preserve (PACKED, SHIPPED, etc.)
    const nextStatus = order.status === 'PENDING' ? 'CONFIRMED' : order.status

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        paymentStatus: 'PAID',
        paymentMethod: 'UPI',
        status: nextStatus,
      },
    })

    // NOW fire notifications — payment is confirmed!
    try {
      const displayId = (updatedOrder as any).readableId || updatedOrder.id.slice(-6).toUpperCase()

      // SSE event for admin dashboard
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

      // Push notification to all staff
      sendPushNotificationToRoles([Role.ADMIN, Role.CHEF, Role.DELIVERY, Role.PICKER], {
        title: '💳 Online Payment Order Confirmed!',
        body: `Order #${displayId} of ₹${updatedOrder.total} — PAID via Razorpay ✅`,
        tag: `order-${updatedOrder.id}`,
        data: { orderId: updatedOrder.id }
      }).catch((err: any) => console.error('Error sending push notification:', err))

      // WhatsApp Order Alert to Admin Phones (Strictly based on Admin Settings selection)
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
      const outletName = (order as any).shopName || ((order as any).restaurantId ? 'Restaurant' : 'FastKirana Grocery')
      const customerName = order.user?.name || 'Customer'
      const customerPhone = order.address?.phone || order.user?.phone || 'N/A'
      
      const adminText = `💳 *PAID Online Order* #${displayId} for [${outletName}] of ₹${updatedOrder.total} from ${customerName} (${customerPhone}). Payment: Razorpay PAID ✅. Manage: ${cleanAppUrl}/admin`

      for (const adminPhone of adminPhones) {
        sendWhatsAppOrderAlert(adminPhone, adminText)
          .catch((err: any) => console.error(`Failed to send WhatsApp alert to ${adminPhone}:`, err))
      }

    } catch (notifErr) {
      console.error('Notification error after payment verification:', notifErr)
    }

    return NextResponse.json({
      success: true,
      message: 'Payment verified successfully!',
      orderId: updatedOrder.id,
      status: updatedOrder.status,
      paymentStatus: updatedOrder.paymentStatus,
    })
  } catch (error: any) {
    console.error('Error verifying Razorpay signature:', error)
    return NextResponse.json(
      { error: error.message || 'Internal server error' },
      { status: 500 }
    )
  }
}
