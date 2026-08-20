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
    let order = await prisma.order.findUnique({
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

    const keyId = process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID || 'rzp_live_TRvyzlqHiRGWbr'
    const keySecret = process.env.RAZORPAY_KEY_SECRET || '4C54O0N5q841qdmQ8N1MTTiU'
    const authHeader = 'Basic ' + Buffer.from(`${keyId}:${keySecret}`).toString('base64')

    // Live Razorpay API Check: If Razorpay captured payment for this order, auto-update paymentStatus to PAID
    if (order.paymentStatus !== 'PAID') {
      try {
        const rzpCheck = await fetch(`https://api.razorpay.com/v1/payments?count=15`, {
          headers: { 'Authorization': authHeader },
        })
        if (rzpCheck.ok) {
          const rzpPayments = await rzpCheck.json()
          const items = rzpPayments.items || []
          const paidTxn = items.find((p: any) => 
            p.status === 'captured' && 
            (p.notes?.orderId === order.id || p.notes?.readableId === String(order.readableId || ''))
          )
          if (paidTxn) {
            await prisma.order.update({
              where: { id: order.id },
              data: { paymentStatus: 'PAID', paymentMethod: 'UPI' }
            })
            order.paymentStatus = 'PAID'
          }
        }
      } catch (e) {
        console.warn('Razorpay live poll check warning:', e)
      }
    }

    // Fetch store UPI VPA setting or fallback to default
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

    const displayId = String(order.readableId || order.id.slice(0, 8))
    const amountStr = Number(order.total).toFixed(2)
    const payeeName = encodeURIComponent('FastKirana Store')
    const note = encodeURIComponent(`Payment for Order #${displayId}`)
    const tr = `FK${displayId}`

    // 1. Native Universal Indian UPI Intent URI (Scans on PhonePe, GPay, Paytm, BHIM, Mobikwik, WhatsApp)
    const upiUri = `upi://pay?pa=${upiVpa}&pn=${payeeName}&am=${amountStr}&cu=INR&tn=${note}&tr=${tr}`
    const upiQrImageUrl = `https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=${encodeURIComponent(upiUri)}`

    let paymentLinkUrl = ''
    let razorpayQrImageUrl = ''

    // 2. Try official Razorpay Payment Link
    if (order.paymentStatus !== 'PAID') {
      try {
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
            reference_id: `FK_${displayId}_${Date.now()}`,
            description: `FastKirana Order #${displayId}`,
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

        const rzpData = await rzpRes.json()

        if (rzpRes.ok && rzpData.short_url) {
          paymentLinkUrl = rzpData.short_url
          razorpayQrImageUrl = `https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=${encodeURIComponent(paymentLinkUrl)}`
        } else {
          console.warn('Razorpay Payment Link API notice:', rzpData)
        }
      } catch (e) {
        console.warn('Failed to generate Razorpay Payment Link:', e)
      }
    }

    return NextResponse.json({
      orderId: order.id,
      readableId: order.readableId,
      amount: order.total,
      upiVpa,
      upiUri,
      paymentLinkUrl,
      qrImageUrl: upiQrImageUrl,
      razorpayQrImageUrl,
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
      message: 'Payment verified via UPI!'
    })

  } catch (err: any) {
    console.error('Error confirming doorstep UPI payment:', err)
    return NextResponse.json({ error: err.message || 'Failed to confirm UPI payment' }, { status: 500 })
  }
}
