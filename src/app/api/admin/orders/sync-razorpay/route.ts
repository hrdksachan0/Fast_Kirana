import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth-guard'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { Role } from '@prisma/client'

export async function POST(req: Request) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error

  try {
    const { paymentId, orderId } = await req.json()

    if (!paymentId && !orderId) {
      return NextResponse.json({ error: 'Either paymentId or orderId is required' }, { status: 400 })
    }

    const keyId = process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID || 'rzp_live_TRvyzlqHiRGWbr'
    const keySecret = process.env.RAZORPAY_KEY_SECRET || '4C54O0N5q841qdmQ8N1MTTiU'
    const authHeader = 'Basic ' + Buffer.from(`${keyId}:${keySecret}`).toString('base64')

    let targetOrder: any = null

    if (orderId) {
      targetOrder = await prisma.order.findUnique({
        where: { id: orderId },
        include: { user: true, address: true },
      })
    }

    if (paymentId) {
      // Fetch details from Razorpay API
      const rzpRes = await fetch(`https://api.razorpay.com/v1/payments/${paymentId}`, {
        headers: { Authorization: authHeader },
      })
      const rzpPayment = await rzpRes.json()

      if (!rzpRes.ok) {
        return NextResponse.json({ error: rzpPayment.error?.description || 'Failed to fetch payment from Razorpay' }, { status: 400 })
      }

      if (rzpPayment.status !== 'captured' && rzpPayment.status !== 'authorized') {
        return NextResponse.json({
          error: `Razorpay payment ${paymentId} status is '${rzpPayment.status}'. Order cannot be marked PAID.`,
          rzpStatus: rzpPayment.status,
        }, { status: 400 })
      }

      // Find order by notes or matching orderId
      const dbOrderId = rzpPayment.notes?.orderId || rzpPayment.notes?.receipt
      if (dbOrderId && !targetOrder) {
        targetOrder = await prisma.order.findUnique({
          where: { id: dbOrderId },
          include: { user: true, address: true },
        })
      }

      // Fallback: match by amount
      if (!targetOrder) {
        const amountInRupees = Number(rzpPayment.amount) / 100
        targetOrder = await prisma.order.findFirst({
          where: {
            total: amountInRupees,
            paymentStatus: 'PENDING',
          },
          orderBy: { createdAt: 'desc' },
          include: { user: true, address: true },
        })
      }
    }

    if (!targetOrder) {
      return NextResponse.json({ error: 'No matching order found to sync with Razorpay payment.' }, { status: 404 })
    }

    // Update order status to PAID & CONFIRMED
    const nextStatus = targetOrder.status === 'PENDING' ? 'CONFIRMED' : targetOrder.status
    const updatedOrder = await prisma.order.update({
      where: { id: targetOrder.id },
      data: {
        paymentStatus: 'PAID',
        paymentMethod: 'UPI',
        status: nextStatus,
      },
    })

    // Trigger Notifications
    try {
      const displayId = (updatedOrder as any).readableId || updatedOrder.id.slice(-6).toUpperCase()

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

      sendPushNotificationToRoles([Role.ADMIN, Role.CHEF, Role.DELIVERY, Role.PICKER], {
        title: '💳 Admin Synced Razorpay Payment!',
        body: `Order #${displayId} of ₹${updatedOrder.total} marked as PAID ✅`,
        tag: `order-${updatedOrder.id}`,
        data: { orderId: updatedOrder.id },
      }).catch((err: any) => console.error('Push notification error:', err))

      const adminPhones = ['7054470303', '8112849854']
      const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://fast-kirana-gtm.vercel.app'
      const cleanAppUrl = appUrl.replace('https://', '').replace('http://', '')
      const customerName = targetOrder.user?.name || 'Customer'
      const customerPhone = targetOrder.address?.phone || targetOrder.user?.phone || 'N/A'

      const adminText = `💳 *Manual Sync PAID* Order #${displayId} of ₹${updatedOrder.total} from ${customerName} (${customerPhone}). Razorpay ID: ${paymentId || 'Verified'}. Manage: ${cleanAppUrl}/admin`

      for (const adminPhone of adminPhones) {
        sendWhatsAppOrderAlert(adminPhone, adminText).catch((err: any) =>
          console.error(`WhatsApp alert error to ${adminPhone}:`, err)
        )
      }
    } catch (notifErr) {
      console.error('Notification error in sync route:', notifErr)
    }

    return NextResponse.json({
      success: true,
      message: `Order #${updatedOrder.readableId || updatedOrder.id} successfully synced to PAID & CONFIRMED!`,
      orderId: updatedOrder.id,
      paymentStatus: updatedOrder.paymentStatus,
      status: updatedOrder.status,
    })
  } catch (error: any) {
    console.error('Error in sync-razorpay endpoint:', error)
    return NextResponse.json({ error: error.message || 'Internal server error' }, { status: 500 })
  }
}
