import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function POST(req: Request) {
  try {
    const { orderId, amount } = await req.json()

    let totalAmount = 0
    let receiptId = `rcpt_${Date.now()}`
    let readableId = ''
    let resolvedOrderId = orderId || ''

    if (orderId) {
      // Use raw SQL to avoid PrismaPg enum deserialization issues
      const orders: any[] = await prisma.$queryRaw`
        SELECT id, total, "readableId", "combinedId"
        FROM orders WHERE id = ${orderId} LIMIT 1
      `

      if (!orders || orders.length === 0) {
        return NextResponse.json({ error: 'Order not found' }, { status: 404 })
      }

      const order = orders[0]

      // If this is part of a combined order, calculate the FULL combined total
      if (order.combinedId) {
        const combinedOrders: any[] = await prisma.$queryRaw`
          SELECT id, total, "readableId"
          FROM orders WHERE "combinedId" = ${order.combinedId}
        `
        totalAmount = combinedOrders.reduce((sum: number, o: any) => sum + Number(o.total || 0), 0)
        readableId = String((order.readableId || '').replace(/-[GR\d]+$/i, '') || order.readableId || '')
      } else {
        totalAmount = Number(order.total)
        readableId = String(order.readableId || '')
      }

      receiptId = order.id
    } else if (amount) {
      totalAmount = Number(amount)
    } else {
      return NextResponse.json({ error: 'orderId or amount is required' }, { status: 400 })
    }

    // If client explicitly passed a higher amount (combined total from UI), use that
    if (amount && Number(amount) > totalAmount) {
      totalAmount = Number(amount)
    }

    const keyId = process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID || 'rzp_live_TRvyzlqHiRGWbr'
    const keySecret = process.env.RAZORPAY_KEY_SECRET || '4C54O0N5q841qdmQ8N1MTTiU'

    const amountInPaise = Math.round(totalAmount * 100)

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
        receipt: (receiptId || `rcpt_${Date.now()}`).slice(0, 40),
        notes: {
          orderId: resolvedOrderId,
          readableId: String(readableId || ''),
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
      orderId: resolvedOrderId || null,
    })
  } catch (error: any) {
    console.error('Error creating Razorpay order:', error)
    return NextResponse.json(
      { detail: error.message || 'Internal server error' },
      { status: 500 }
    )
  }
}
