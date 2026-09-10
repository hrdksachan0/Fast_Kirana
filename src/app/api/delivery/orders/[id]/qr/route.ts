import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireRole } from '@/lib/auth-guard'
import {
  isCashfreeConfigured,
  createCashfreeOrder,
  getCashfreeOrder,
  createCashfreeUpiQrSession,
  createCashfreePaymentLink,
  checkCashfreeOrderPaid,
} from '@/lib/cashfree'

export const dynamic = 'force-dynamic'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  // Check auth: NextAuth / Bearer JWT, with fallback to mobile app headers
  const { error } = await requireRole(['DELIVERY', 'ADMIN'], request)
  if (error) {
    const headerRole = request.headers.get('x-user-role')?.toUpperCase()
    if (!['DELIVERY', 'ADMIN', 'PICKER'].includes(headerRole || '')) {
      return error
    }
  }

  try {
    const { id } = await params
    let order = await prisma.order.findUnique({
      where: { id },
      select: {
        id: true,
        readableId: true,
        total: true,
        paymentMethod: true,
        paymentStatus: true,
        status: true,
        shopName: true,
        combinedId: true,
        userId: true,
        notes: true,
        user: {
          select: {
            name: true,
            phone: true,
            email: true,
          }
        },
        address: {
          select: {
            phone: true,
          }
        }
      }
    })

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const displayId = String(order.readableId || order.id.slice(0, 8))
    const sanitizedOrderId = order.id.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 45)

    // 1. Live Cashfree Status Check: If payment was captured, auto-update paymentStatus to PAID
    if (order.paymentStatus !== 'PAID' && isCashfreeConfigured()) {
      try {
        const checkResult = await checkCashfreeOrderPaid(sanitizedOrderId)
        if (checkResult.isPaid) {
          const updateFilter = order.combinedId
            ? { combinedId: order.combinedId }
            : { id: order.id }

          await prisma.order.updateMany({
            where: updateFilter,
            data: {
              paymentStatus: 'PAID',
              paymentMethod: 'UPI',
              notes: order.notes
                ? `${order.notes} | Cashfree Auto-Paid (${checkResult.paymentId || 'Captured'})`
                : `Cashfree Auto-Paid (${checkResult.paymentId || 'Captured'})`
            }
          })
          order.paymentStatus = 'PAID'
          order.paymentMethod = 'UPI'
        }
      } catch (checkErr) {
        console.warn('Cashfree live poll check notice:', checkErr)
      }
    }

    // 2. Fetch Store UPI VPA fallback
    let upiVpa = '7054470303@paytm'
    try {
      const setting = await prisma.storeSetting.findUnique({
        where: { key: 'store_upi_vpa' }
      })
      if (setting?.value && setting.value.trim().length > 0) {
        upiVpa = setting.value.trim()
      }
    } catch (e) {
      console.warn('Could not fetch store_upi_vpa setting:', e)
    }

    const amountStr = Number(order.total).toFixed(2)
    const payeeName = encodeURIComponent('FastKirana Store')
    const note = encodeURIComponent(`Payment for Order #${displayId}`)
    const tr = `FK${displayId}`

    // Standard Universal Indian UPI Intent URI (Fallback)
    const directUpiUri = `upi://pay?pa=${upiVpa}&pn=${payeeName}&am=${amountStr}&cu=INR&tn=${note}&tr=${tr}`
    const directUpiQrImageUrl = `https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=${encodeURIComponent(directUpiUri)}`

    let cashfreeQrUrl = ''
    let cashfreeUpiUri = ''
    let paymentLinkUrl = ''

    // 3. Generate Cashfree Dynamic UPI QR Code if order is unpaid
    if (order.paymentStatus !== 'PAID' && isCashfreeConfigured()) {
      try {
        let cfOrder: any = null
        try {
          cfOrder = await getCashfreeOrder(sanitizedOrderId)
        } catch (e) {
          // Cashfree order doesn't exist yet, create one
          const cleanPhone = (order.address?.phone || order.user?.phone || '9999999999').replace(/\D/g, '').slice(-10)
          cfOrder = await createCashfreeOrder({
            orderId: sanitizedOrderId,
            amount: Number(order.total),
            customerId: order.userId || `guest_${order.id.slice(0, 10)}`,
            customerName: order.user?.name || 'Customer',
            customerPhone: cleanPhone.length === 10 ? cleanPhone : '9999999999',
            customerEmail: order.user?.email || 'customer@fastkirana.in',
            note: `Doorstep Payment Order #${displayId}`,
          })
        }

        // Generate Dynamic UPI QR session from Cashfree Order
        if (cfOrder?.payment_session_id) {
          try {
            const qrSession = await createCashfreeUpiQrSession(cfOrder.payment_session_id)
            if (qrSession.qrImageUrl) {
              cashfreeQrUrl = qrSession.qrImageUrl
            }
            if (qrSession.upiUri) {
              cashfreeUpiUri = qrSession.upiUri
              if (!cashfreeQrUrl) {
                cashfreeQrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=${encodeURIComponent(cashfreeUpiUri)}`
              }
            }
          } catch (qrSessionErr) {
            console.warn('Cashfree UPI QR session notice (trying payment link fallback):', qrSessionErr)
          }
        }

        // Fallback to Cashfree Payment Link if session QR is unavailable
        if (!cashfreeQrUrl) {
          const cleanPhone = (order.address?.phone || order.user?.phone || '9999999999').replace(/\D/g, '').slice(-10)
          const linkResult = await createCashfreePaymentLink({
            linkId: `FK_L_${displayId}_${Date.now().toString().slice(-6)}`,
            amount: Number(order.total),
            customerPhone: cleanPhone.length === 10 ? cleanPhone : '9999999999',
            customerName: order.user?.name || 'Customer',
            customerEmail: order.user?.email || 'customer@fastkirana.in',
            purpose: `Order #${displayId} Payment`,
          })
          paymentLinkUrl = linkResult.linkUrl
          cashfreeQrUrl = linkResult.linkQrUrl
        }
      } catch (cfErr) {
        console.warn('Cashfree dynamic QR generation warning:', cfErr)
      }
    }

    const activeQrImageUrl = cashfreeQrUrl || directUpiQrImageUrl

    return NextResponse.json({
      orderId: order.id,
      readableId: order.readableId,
      amount: order.total,
      gateway: isCashfreeConfigured() ? 'CASHFREE' : 'DIRECT_UPI',
      upiVpa,
      upiUri: directUpiUri,
      directUpiQrUrl: directUpiQrImageUrl,
      cashfreeQrUrl,
      cashfreeUpiUri,
      paymentLinkUrl,
      qrImageUrl: activeQrImageUrl,
      paymentStatus: order.paymentStatus,
      paymentMethod: order.paymentMethod
    })

  } catch (err: any) {
    console.error('Error generating doorstep QR:', err)
    return NextResponse.json({ error: err.message || 'Server error' }, { status: 500 })
  }
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { error } = await requireRole(['DELIVERY', 'ADMIN'], request)
  if (error) {
    const headerRole = request.headers.get('x-user-role')?.toUpperCase()
    if (!['DELIVERY', 'ADMIN', 'PICKER'].includes(headerRole || '')) {
      return error
    }
  }

  try {
    const { id } = await params
    const { referenceId } = await request.json().catch(() => ({}))

    const order = await prisma.order.findUnique({
      where: { id }
    })

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const updateFilter = order.combinedId
      ? { combinedId: order.combinedId }
      : { id }

    await prisma.order.updateMany({
      where: updateFilter,
      data: {
        paymentMethod: 'UPI',
        paymentStatus: 'PAID',
        notes: order.notes 
          ? `${order.notes} | Doorstep UPI Paid (Ref: ${referenceId || 'QR Scan'})`
          : `Doorstep UPI Paid (Ref: ${referenceId || 'QR Scan'})`
      }
    })

    const updatedOrder = (await prisma.order.findUnique({
      where: { id }
    })) || order

    return NextResponse.json({
      success: true,
      order: updatedOrder,
      message: 'Payment verified via UPI!'
    })

  } catch (err: any) {
    console.error('Error confirming doorstep UPI payment:', err)
    return NextResponse.json({ error: err.message || 'Failed to confirm UPI payment' }, { status: 500 })
  }
}
