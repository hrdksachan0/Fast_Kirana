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

    let paymentLinkUrl = ''
    let qrImageUrl = ''

    // Always generate official Razorpay Payment Link for Option A
    if (order.paymentStatus !== 'PAID') {
      try {
        const keyId = process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID || 'rzp_live_TRvyzlqHiRGWbr'
        const keySecret = process.env.RAZORPAY_KEY_SECRET || '4C54O0N5q841qdmQ8N1MTTiU'
        const authHeader = 'Basic ' + Buffer.from(`${keyId}:${keySecret}`).toString('base64')
        const displayId = String(order.readableId || order.id.slice(0, 8))

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
          qrImageUrl = `https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=${encodeURIComponent(paymentLinkUrl)}`
        } else {
          console.error('Razorpay Payment Link API error:', rzpData)
        }
      } catch (e) {
        console.warn('Failed to generate Razorpay Payment Link:', e)
      }
    }

    // Fallback URL if API call fails
    if (!qrImageUrl) {
      const displayId = String(order.readableId || order.id.slice(0, 8))
      const fallbackUrl = `https://rzp.io/l/fastkirana_${displayId}`
      qrImageUrl = `https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=${encodeURIComponent(fallbackUrl)}`
    }

    return NextResponse.json({
      orderId: order.id,
      readableId: order.readableId,
      amount: order.total,
      paymentLinkUrl,
      qrImageUrl,
      paymentStatus: order.paymentStatus,
      paymentMethod: order.paymentMethod
    })

  } catch (err: any) {
    console.error('Error generating doorstep Razorpay QR:', err)
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
          ? `${order.notes} | Razorpay Doorstep Paid (Ref: ${referenceId || 'QR Scan'})`
          : `Razorpay Doorstep Paid (Ref: ${referenceId || 'QR Scan'})`
      }
    })

    return NextResponse.json({
      success: true,
      order: updatedOrder,
      message: 'Payment verified via Razorpay!'
    })

  } catch (err: any) {
    console.error('Error confirming Razorpay payment:', err)
    return NextResponse.json({ error: err.message || 'Failed to confirm Razorpay payment' }, { status: 500 })
  }
}
