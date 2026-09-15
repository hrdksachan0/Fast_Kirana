import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles, sendPushNotificationToRestaurant } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { Role } from '@prisma/client'
import { apiWriteLimiter } from '@/lib/rate-limit'

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const limited = await apiWriteLimiter.check(request)
  if (limited) return limited

  try {
    const { id } = await params
    if (!id) {
      return NextResponse.json({ error: 'Order ID is required' }, { status: 400 })
    }

    const session = await auth()
    const userId = session?.user?.id
    const userRole = session?.user?.role

    const cleanId = String(id).trim()

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
      WHERE o.id = ${cleanId} OR o."readableId" = ${cleanId}
      LIMIT 1
    `

    if (!orders || orders.length === 0) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const order = orders[0]

    // Authorization: User must own the order or be staff/admin
    const isOwner = userId && order.userId === userId
    const isAdmin = userRole === 'ADMIN'
    if (!isOwner && !isAdmin && userId) {
      return NextResponse.json({ error: 'Unauthorized to modify this order' }, { status: 403 })
    }

    // Guard: Do not convert if already paid online
    if (order.paymentStatus === 'PAID') {
      return NextResponse.json({
        error: 'Order has already been paid online',
        paymentStatus: 'PAID'
      }, { status: 400 })
    }

    // Guard: Do not convert if already cancelled
    if (order.status === 'CANCELLED') {
      return NextResponse.json({
        error: 'Order has been cancelled and cannot be converted',
        status: 'CANCELLED'
      }, { status: 400 })
    }

    // Atomically convert all companion sub-orders in the combined group (or single order) to COD
    if (order.combinedId) {
      await prisma.$executeRaw`
        UPDATE orders
        SET "paymentMethod" = 'COD'::"PaymentMethod",
            "paymentStatus" = 'PENDING'::"PaymentStatus",
            "status" = 'CONFIRMED'::"OrderStatus",
            "confirmedAt" = NOW(),
            "updatedAt" = NOW()
        WHERE "combinedId" = ${order.combinedId}
      `
    } else {
      await prisma.$executeRaw`
        UPDATE orders
        SET "paymentMethod" = 'COD'::"PaymentMethod",
            "paymentStatus" = 'PENDING'::"PaymentStatus",
            "status" = 'CONFIRMED'::"OrderStatus",
            "confirmedAt" = NOW(),
            "updatedAt" = NOW()
        WHERE id = ${order.id}
      `
    }

    // Fetch refreshed orders for notification
    const refreshedOrders: any[] = order.combinedId
      ? await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total,
                 o."restaurantId", o."shopName", o."createdAt"
          FROM orders o
          WHERE o."combinedId" = ${order.combinedId}
        `
      : await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total,
                 o."restaurantId", o."shopName", o."createdAt"
          FROM orders o
          WHERE o.id = ${order.id}
        `

    const displayId = order.readableId
      ? String(order.readableId).replace(/-[GR\d]+$/i, '')
      : order.id.slice(-6).toUpperCase()

    let totalAmount = Number(order.total || 0)
    if (order.combinedId && refreshedOrders.length > 0) {
      totalAmount = refreshedOrders.reduce((sum, o) => sum + Number(o.total || 0), 0)
    }

    // 1. Emit real-time SSE event for admin & staff
    sseEmitter.emit('order', {
      type: 'new-order',
      orderId: order.id,
      readableId: displayId,
      status: 'CONFIRMED',
      total: totalAmount,
      paymentStatus: 'PENDING',
      paymentMethod: 'COD',
      createdAt: order.createdAt,
    })

    // 2. Dispatch push notifications to kitchen, pickers, riders
    try {
      for (const ro of refreshedOrders) {
        const isRestaurant = !!ro.restaurantId
        const outletName = ro.shopName || (ro.restaurantId ? 'Restaurant' : 'FastKirana Grocery')

        if (isRestaurant) {
          sendPushNotificationToRestaurant(ro.restaurantId, {
            title: `🍲 New Kitchen Order #${ro.readableId || displayId} (COD)`,
            body: `Order of ₹${ro.total} placed via Cash on Delivery for ${outletName}.`,
            data: { orderId: ro.id, role: 'CHEF', type: 'new-order' }
          }).catch(() => {})

          sendPushNotificationToRoles([Role.ADMIN, Role.DELIVERY], {
            title: `🍲 New Kitchen Order #${displayId} (COD)`,
            body: `Order of ₹${totalAmount} for ${outletName} is ready for processing.`,
            data: { orderId: ro.id, role: 'DELIVERY', type: 'new-order' }
          }).catch(() => {})
        } else {
          sendPushNotificationToRoles([Role.ADMIN, Role.PICKER, Role.DELIVERY], {
            title: `📦 New Grocery Order #${displayId} (COD)`,
            body: `Order of ₹${totalAmount} placed via Cash on Delivery. Ready for packing!`,
            data: { orderId: ro.id, role: 'PICKER', type: 'new-order' }
          }).catch(() => {})
        }
      }
    } catch (pushErr) {
      console.error('Error sending push notifications on COD conversion:', pushErr)
    }

    // 3. Send WhatsApp confirmation alert
    try {
      const customerPhone = order.userPhone?.replace(/\D/g, '')
      if (customerPhone && customerPhone.length >= 10) {
        const alertMsg = `📦 FastKirana Order #${displayId} confirmed! Total: ₹${totalAmount}. Payment: Cash on Delivery.`
        sendWhatsAppOrderAlert(customerPhone.slice(-10), alertMsg).catch(() => {})
      }
    } catch (waErr) {
      console.error('Error sending WhatsApp alert on COD conversion:', waErr)
    }

    return NextResponse.json({
      success: true,
      message: 'Order successfully converted to Cash on Delivery (COD)!',
      orderId: order.id,
      readableId: displayId,
      paymentMethod: 'COD',
      status: 'CONFIRMED'
    })
  } catch (error: any) {
    console.error('Error converting order to COD:', error)
    return NextResponse.json(
      { error: error.message || 'Failed to convert order to COD' },
      { status: 500 }
    )
  }
}
