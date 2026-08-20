import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function POST(req: Request) {
  try {
    const { orderId } = await req.json()

    if (!orderId) {
      return NextResponse.json({ error: 'orderId is required' }, { status: 400 })
    }

    const order = await prisma.order.findUnique({
      where: { id: orderId },
    })

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const keyId = process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID || 'rzp_live_TRvyzlqHiRGWbr'
    const keySecret = process.env.RAZORPAY_KEY_SECRET || '4C54O0N5q841qdmQ8N1MTTiU'

    const amountInPaise = Math.round(Number(order.total) * 100)

    if (amountInPaise < 100) {
      return NextResponse.json({ error: 'Minimum order amount for online payment is ₹1.00' }, { status: 400 })
    }

    const authHeader = 'Basic ' + Buffer.from(`${keyId}:${keySecret}`).toString('base64')

    const rzpRes = await fetch('https://api.razorpay.com/v1/orders', {
      method: 'POST',
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        amount: amountInPaise,
        currency: 'INR',
        receipt: order.id,
        notes: {
          readableId: String(order.readableId || ''),
        },
      }),
    })

    const rzpData = await rzpRes.json()

    if (!rzpRes.ok) {
      console.error('Razorpay API error:', rzpData)
      return NextResponse.json(
        { detail: rzpData.error?.description || 'Razorpay order creation failed' },
        { status: rzpRes.status }
      )
    }

    return NextResponse.json({
      success: true,
      razorpayOrderId: rzpData.id,
      keyId,
      amount: rzpData.amount,
      currency: rzpData.currency,
      orderId: order.id,
    })
  } catch (error: any) {
    console.error('Error creating Razorpay order:', error)
    return NextResponse.json(
      { detail: error.message || 'Internal server error' },
      { status: 500 }
    )
  }
}
