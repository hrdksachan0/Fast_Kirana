import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import crypto from 'crypto'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles } from '@/lib/push-notification'
import { Role } from '@prisma/client'

export async function POST(req: Request) {
  try {
    const { orderId, razorpay_order_id, razorpay_payment_id, razorpay_signature } = await req.json()

    if (!orderId || !razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return NextResponse.json({ error: 'Missing required signature parameters' }, { status: 400 })
    }

    const order = await prisma.order.findUnique({
      where: { id: orderId },
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

    // Update order status to PAID and CONFIRMED
    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        paymentStatus: 'PAID',
        status: 'CONFIRMED',
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
        createdAt: updatedOrder.createdAt,
      })

      // Push notification to all staff
      sendPushNotificationToRoles([Role.ADMIN, Role.CHEF, Role.DELIVERY, Role.PICKER], {
        title: '💳 Online Payment Order Confirmed!',
        body: `Order #${displayId} of ₹${updatedOrder.total} — PAID via Razorpay ✅`,
        tag: `order-${updatedOrder.id}`,
        data: { orderId: updatedOrder.id }
      }).catch((err: any) => console.error('Error sending push notification:', err))
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
