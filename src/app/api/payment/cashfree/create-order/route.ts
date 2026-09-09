import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { orderLimiter } from '@/lib/rate-limit'
import { createCashfreeOrder } from '@/lib/cashfree'

export async function POST(request: NextRequest) {
  const limited = await orderLimiter.check(request)
  if (limited) return limited

  try {
    const body = await request.json()
    const { orderId, amount, customerPhone, customerEmail, customerName } = body

    let totalAmount = 0
    let readableId = ''
    let resolvedOrderId = orderId || `cf_${Date.now()}`
    let customerId = 'guest_customer'
    let resolvedPhone = customerPhone || '9999999999'
    let resolvedEmail = customerEmail || 'customer@fastkirana.in'
    let resolvedName = customerName || 'FastKirana Customer'

    if (orderId) {
      const cleanOrderId = String(orderId).trim()
      const order = await prisma.order.findFirst({
        where: {
          OR: [
            { id: cleanOrderId },
            { readableId: cleanOrderId }
          ]
        },
        include: {
          user: { select: { id: true, name: true, email: true, phone: true } },
          address: { select: { phone: true } }
        }
      })

      if (!order) {
        return NextResponse.json({ error: 'Order not found' }, { status: 404 })
      }

      if (order.combinedId) {
        const combinedOrders = await prisma.order.findMany({
          where: { combinedId: order.combinedId },
          select: { total: true, readableId: true }
        })
        totalAmount = combinedOrders.reduce((sum, o) => sum + Number(o.total || 0), 0)
        readableId = String(order.readableId || '').replace(/-[GR\d]+$/i, '')
      } else {
        totalAmount = Number(order.total)
        readableId = String(order.readableId || '')
      }

      customerId = order.userId || order.user?.id || order.id
      resolvedPhone = order.address?.phone || order.user?.phone || customerPhone || resolvedPhone
      resolvedEmail = order.user?.email || customerEmail || resolvedEmail
      resolvedName = order.user?.name || customerName || resolvedName
      resolvedOrderId = order.id
    } else if (amount) {
      totalAmount = Number(amount)
    } else {
      return NextResponse.json({ error: 'orderId or amount is required' }, { status: 400 })
    }

    if (amount && Number(amount) > totalAmount) {
      totalAmount = Number(amount)
    }

    if (totalAmount < 1) {
      return NextResponse.json({ error: 'Minimum order amount for online payment is ₹1.00' }, { status: 400 })
    }

    // Sanitize phone to strictly 10 digits as required by Cashfree API
    let cleanPhone = String(resolvedPhone || '').replace(/[^\d]/g, '')
    if (cleanPhone.startsWith('91') && cleanPhone.length > 10) {
      cleanPhone = cleanPhone.slice(2)
    }
    if (cleanPhone.length !== 10) {
      cleanPhone = '9999999999'
    }

    // Sanitize email
    let cleanEmail = String(resolvedEmail || '').trim().toLowerCase()
    if (!cleanEmail.includes('@') || !cleanEmail.includes('.')) {
      cleanEmail = 'customer@fastkirana.in'
    }

    const cleanName = String(resolvedName || 'FastKirana Customer').trim() || 'FastKirana Customer'

    const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://fastkirana.in'

    const cfOrder = await createCashfreeOrder({
      orderId: resolvedOrderId,
      amount: totalAmount,
      customerId,
      customerName: cleanName,
      customerPhone: cleanPhone,
      customerEmail: cleanEmail,
      returnUrl: `${appUrl}/checkout/verify?order_id=${resolvedOrderId}&cf_order_id={order_id}`,
      notifyUrl: `${appUrl}/api/payment/cashfree/webhook`,
      note: `FastKirana Order #${readableId || resolvedOrderId}`
    })

    return NextResponse.json({
      success: true,
      paymentSessionId: cfOrder.payment_session_id,
      orderId: cfOrder.order_id,
      cfOrderId: cfOrder.cf_order_id,
      amount: cfOrder.order_amount,
    })
  } catch (err: any) {
    console.error('Error creating Cashfree order:', err)
    return NextResponse.json(
      { error: err.message || 'Failed to initialize Cashfree payment session' },
      { status: 500 }
    )
  }
}
