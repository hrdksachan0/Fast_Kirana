import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export const dynamic = 'force-dynamic'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { id } = await params
    const order = await prisma.order.findUnique({
      where: { id },
      select: {
        id: true,
        readableId: true,
        total: true,
        paymentMethod: true,
        paymentStatus: true,
        status: true,
        shopName: true
      }
    })

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    // Default fallback UPI ID
    const upiVpaSetting = await prisma.storeSetting.findUnique({
      where: { key: 'store_upi_vpa' }
    })
    const fallbackUpiVpa = upiVpaSetting?.value || '7054470303@paytm'

    let paymentLinkUrl = ''
    let qrImageUrl = ''

    // If order is still unpaid, generate dynamic Razorpay Payment Link for automatic tracking
    if (order.paymentStatus !== 'PAID') {
      try {
        const keyId = process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID || 'rzp_live_TRvyzlqHiRGWbr'
        const keySecret = process.env.RAZORPAY_KEY_SECRET || '4C54O0N5q841qdmQ8N1MTTiU'
        const authHeader = 'Basic ' + Buffer.from(`${keyId}:${keySecret}`).toString('base64')
        const displayId = order.readableId || order.id.slice(0, 8)

        const rzpRes = await fetch('https://api.razorpay.com/v1/payment_links', {
          method: 'POST',
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            amount: Math.round(Number(order.total) * 100),
            currency: 'INR',
            accept_partial: false,
            reference_id: `FK_${displayId}_${Date.now().toString(36)}`,
            description: `Doorstep Payment for FastKirana Order #${displayId}`,
            notify: {
              sms: false,
              email: false,
            },
            reminder_enable: false,
            notes: {
              orderId: order.id,
              readableId: displayId,
            },
          }),
        })

        if (rzpRes.ok) {
          const rzpData = await rzpRes.json()
          paymentLinkUrl = rzpData.short_url
        }
      } catch (e) {
        console.warn('Failed to generate Razorpay Payment Link, falling back to static UPI QR:', e)
      }
    }

    if (paymentLinkUrl) {
      qrImageUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(paymentLinkUrl)}`
    } else {
      // NPCI UPI Intent fallback
      const payeeName = encodeURIComponent('FastKirana Store')
      const note = encodeURIComponent(`Payment for Order #${order.readableId || order.id.slice(0, 8)}`)
      const amount = order.total.toFixed(2)
      const tr = `FK${order.readableId || order.id.slice(0, 8)}`
      const upiUri = `upi://pay?pa=${fallbackUpiVpa}&pn=${payeeName}&am=${amount}&cu=INR&tn=${note}&tr=${tr}`
      qrImageUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(upiUri)}`
    }

    return NextResponse.json({
      orderId: order.id,
      readableId: order.readableId,
      amount: order.total,
      upiVpa: fallbackUpiVpa,
      paymentLinkUrl,
      qrImageUrl,
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
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { id } = await params
    const { referenceId } = await request.json()

    const order = await prisma.order.findUnique({
      where: { id }
    })

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    // Convert payment method to UPI and mark paymentStatus as PAID
    const updatedOrder = await prisma.order.update({
      where: { id },
      data: {
        paymentMethod: 'UPI',
        paymentStatus: 'PAID',
        notes: order.notes 
          ? `${order.notes} | Doorstep UPI Paid (Ref: ${referenceId || 'QR Scan'})`
          : `Doorstep UPI Paid (Ref: ${referenceId || 'QR Scan'})`
      }
    })

    return NextResponse.json({
      success: true,
      order: updatedOrder,
      message: 'Payment converted to UPI successfully!'
    })

  } catch (err: any) {
    console.error('Error converting doorstep QR payment:', err)
    return NextResponse.json({ error: err.message || 'Failed to confirm UPI payment' }, { status: 500 })
  }
}
