import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { Role } from '@prisma/client'

export async function POST(req: NextRequest) {
  try {
    const session = await auth()
    const { orderId } = await req.json()

    if (!orderId || typeof orderId !== 'string') {
      return NextResponse.json({ error: 'orderId is required' }, { status: 400 })
    }

    const cleanId = orderId.trim()
    const targetOrder = await prisma.order.findFirst({
      where: {
        OR: [
          { id: cleanId },
          { readableId: cleanId },
        ],
      },
      include: { user: true, address: true },
    })

    if (!targetOrder) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    // Verify session user ownership or admin
    if (session?.user?.id && targetOrder.userId && targetOrder.userId !== session.user.id && session.user.role !== 'ADMIN') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 403 })
    }

    // If already paid, return early
    if (targetOrder.paymentStatus === 'PAID') {
      return NextResponse.json({
        success: true,
        paymentStatus: 'PAID',
        status: targetOrder.status,
        updated: false,
      })
    }

    const keyId = process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID || 'rzp_live_TRvyzlqHiRGWbr'
    const keySecret = process.env.RAZORPAY_KEY_SECRET || '4C54O0N5q841qdmQ8N1MTTiU'
    const authHeader = 'Basic ' + Buffer.from(`${keyId}:${keySecret}`).toString('base64')

    // Fetch recent captured payments from Razorpay API
    let matchedPayment: any = null
    try {
      const rzpRes = await fetch('https://api.razorpay.com/v1/payments?count=50', {
        headers: { Authorization: authHeader },
        cache: 'no-store',
      })
      if (rzpRes.ok) {
        const rzpData = await rzpRes.json()
        const items = rzpData.items || []
        const orderTotalPaise = Math.round(Number(targetOrder.total) * 100)
        const targetReadableId = String(targetOrder.readableId || '')

        matchedPayment = items.find((p: any) => {
          if (p.status !== 'captured' && p.status !== 'authorized') return false
          if (p.notes?.orderId === targetOrder.id) return true
          if (targetReadableId && p.notes?.readableId === targetReadableId) return true
          if (targetReadableId && p.description && p.description.includes(targetReadableId)) return true
          // Match amount if created within same 24 hour window
          if (p.amount === orderTotalPaise) {
            const pTime = p.created_at * 1000
            const oTime = new Date(targetOrder.createdAt).getTime()
            if (Math.abs(pTime - oTime) < 24 * 60 * 60 * 1000) return true
          }
          return false
        })
      }
    } catch (rzpErr) {
      console.warn('Razorpay check error:', rzpErr)
    }

    if (!matchedPayment) {
      return NextResponse.json({
        success: true,
        paymentStatus: targetOrder.paymentStatus,
        status: targetOrder.status,
        updated: false,
        message: 'No captured online payment detected on Razorpay yet.',
      })
    }

    // Payment captured! Update to PAID and CONFIRMED
    if (targetOrder.combinedId) {
      await prisma.$executeRaw`
        UPDATE orders 
        SET "paymentStatus" = 'PAID'::"PaymentStatus",
            "paymentMethod" = 'UPI'::"PaymentMethod",
            status = CASE WHEN status IN ('PENDING', 'CANCELLED') THEN 'CONFIRMED'::"OrderStatus" ELSE status END,
            "updatedAt" = NOW()
        WHERE "combinedId" = ${targetOrder.combinedId}
      `
    } else {
      const nextStatus = (targetOrder.status === 'PENDING' || targetOrder.status === 'CANCELLED') ? 'CONFIRMED' : targetOrder.status
      await prisma.$executeRaw`
        UPDATE orders 
        SET "paymentStatus" = 'PAID'::"PaymentStatus",
            "paymentMethod" = 'UPI'::"PaymentMethod",
            status = ${nextStatus}::"OrderStatus",
            "updatedAt" = NOW()
        WHERE id = ${targetOrder.id}
      `
    }

    const freshSynced: any[] = await prisma.$queryRaw`
      SELECT id, status::text as status, total,
             "paymentStatus"::text as "paymentStatus",
             "paymentMethod"::text as "paymentMethod",
             "readableId", "createdAt"
      FROM orders WHERE id = ${targetOrder.id} LIMIT 1
    `
    const updatedOrder = freshSynced[0] || targetOrder
    const displayId = updatedOrder.readableId || updatedOrder.id.slice(-6).toUpperCase()

    // Trigger Notifications
    try {
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
        title: '💳 Razorpay Payment Verified!',
        body: `Order #${displayId} of ₹${updatedOrder.total} marked as PAID ✅`,
        tag: `order-${updatedOrder.id}`,
        data: { orderId: updatedOrder.id },
      }).catch((err: any) => console.error('Push notification error:', err))

      const adminPhones = ['7054470303', '8112849854']
      const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://fast-kirana-gtm.vercel.app'
      const cleanAppUrl = appUrl.replace('https://', '').replace('http://', '')
      const customerName = targetOrder.user?.name || 'Customer'
      const customerPhone = targetOrder.address?.phone || targetOrder.user?.phone || 'N/A'

      const adminText = `💳 *Online Payment Auto-Synced* Order #${displayId} of ₹${updatedOrder.total} from ${customerName} (${customerPhone}). Razorpay ID: ${matchedPayment.id}. Manage: ${cleanAppUrl}/admin`

      for (const adminPhone of adminPhones) {
        sendWhatsAppOrderAlert(adminPhone, adminText).catch((err: any) =>
          console.error(`WhatsApp alert error to ${adminPhone}:`, err)
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

      // Revalidate storefront
      try {
        const { revalidateStorefront } = await import('@/lib/revalidate')
        revalidateStorefront()
      } catch (e) {
        console.warn('Revalidation notice:', e)
      }
    } catch (notifErr) {
      console.error('Notification error in sync-order route:', notifErr)
    }

    return NextResponse.json({
      success: true,
      updated: true,
      paymentStatus: 'PAID',
      status: updatedOrder.status,
      paymentId: matchedPayment.id,
      message: `Order #${displayId} verified as PAID via Razorpay!`,
    })
  } catch (error: any) {
    console.error('Error in sync-order endpoint:', error)
    return NextResponse.json({ error: error.message || 'Internal server error' }, { status: 500 })
  }
}
