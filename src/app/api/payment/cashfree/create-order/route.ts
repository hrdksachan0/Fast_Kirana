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
    if (cleanPhone.length > 10) {
      cleanPhone = cleanPhone.slice(-10)
    }
    if (cleanPhone.length !== 10) {
      cleanPhone = '9999999999'
    }

    // Email is optional for Cashfree PG; only pass if valid email format exists
    let cleanEmail: string | undefined = undefined
    if (resolvedEmail && typeof resolvedEmail === 'string') {
      const trimmed = resolvedEmail.trim().toLowerCase()
      if (trimmed.includes('@') && trimmed.includes('.')) {
        cleanEmail = trimmed
      }
    }

    const cleanName = String(resolvedName || 'FastKirana Customer').trim() || 'FastKirana Customer'

    const rawAppUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://www.fastkirana.in'
    const appUrl = (rawAppUrl.includes('fastkirana.in') && !rawAppUrl.includes('www.') && !rawAppUrl.includes('api.'))
      ? rawAppUrl.replace('fastkirana.in', 'www.fastkirana.in')
      : rawAppUrl
    const webhookUrl = (process.env.WEBHOOK_BASE_URL || appUrl).replace(/\/+$/, '')

    const cfOrder = await createCashfreeOrder({
      orderId: resolvedOrderId,
      amount: totalAmount,
      customerId,
      customerName: cleanName,
      customerPhone: cleanPhone,
      customerEmail: cleanEmail,
      returnUrl: `${appUrl}/checkout/verify?order_id=${resolvedOrderId}&cf_order_id={order_id}`,
      notifyUrl: `${webhookUrl}/api/payment/cashfree/webhook`,
      note: `FastKirana Order #${readableId || resolvedOrderId}`
    })

    // 🛡️ PERMANENT FIX: Save draft order payload in Redis cache with 24-hr TTL
    // If user's browser/app drops or disconnects while in UPI app, the webhook
    // retrieves this draft and auto-creates the exact order in database!
    const draftPayload = body.orderPayload || {
      items: body.items,
      addressId: body.addressId,
      customerAddress: body.customerAddress,
      userId: customerId !== 'guest_customer' ? customerId : (body.userId || undefined),
      deliveryMethod: body.deliveryMethod || 'DELIVERY',
      notes: body.note || body.notes,
      couponCode: body.couponCode,
      packagingOption: body.packagingOption,
      packagingFee: body.packagingFee,
      phone: cleanPhone,
      userName: cleanName,
      customerPhone: cleanPhone,
      customerName: cleanName,
      customerEmail: cleanEmail,
    }

    if (draftPayload && (draftPayload.items?.length || body.items?.length || body.orderPayload)) {
      try {
        const { cache } = await import('@/lib/redis-client')
        const cachePayload = JSON.stringify({
          ...draftPayload,
          amount: cfOrder.order_amount,
          cfOrderId: cfOrder.order_id,
          createdAt: new Date().toISOString(),
        })
        await cache.set(`draft_cf_order:${cfOrder.order_id}`, cachePayload, { ex: 86400 })
        await cache.set(`cf_pending:${cfOrder.order_id}`, cachePayload, { ex: 86400 })
      } catch (cacheErr) {
        console.warn('Draft order caching note:', cacheErr)
      }
    }

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
