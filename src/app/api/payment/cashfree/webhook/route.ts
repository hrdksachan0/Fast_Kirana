import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { verifyCashfreeWebhookSignature } from '@/lib/cashfree'
import { sseEmitter } from '@/lib/sse-emitter'
import { sendPushNotificationToRoles, sendPushNotificationToRestaurant } from '@/lib/push-notification'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { Role } from '@prisma/client'

export async function GET() {
  return NextResponse.json({ status: 'active', message: 'Cashfree Webhook Endpoint Active' }, { status: 200 })
}

export async function POST(req: NextRequest) {
  try {
    const rawBody = await req.text()
    if (!rawBody || rawBody.trim() === '' || rawBody === '{}') {
      return NextResponse.json({ received: true, status: 'ok' })
    }

    const signature = req.headers.get('x-webhook-signature') || ''
    const timestamp = req.headers.get('x-webhook-timestamp') || ''

    // Verify signature if configured
    if (signature && timestamp) {
      const isValid = verifyCashfreeWebhookSignature(rawBody, timestamp, signature)
      if (!isValid) {
        console.warn('Cashfree webhook signature mismatch')
        return NextResponse.json({ error: 'Invalid signature' }, { status: 400 })
      }
    }

    let event: any = {}
    try {
      event = JSON.parse(rawBody)
    } catch {
      return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 })
    }

    const eventType = event.type
    const orderData = event.data?.order
    const paymentData = event.data?.payment

    if (eventType === 'PAYMENT_SUCCESS_WEBHOOK' || paymentData?.payment_status === 'SUCCESS') {
      const orderId = orderData?.order_id
      if (orderId) {
        const cleanId = String(orderId).trim()

        const orders: any[] = await prisma.$queryRaw`
          SELECT id, "combinedId", "readableId", status::text as status,
                 total, "paymentStatus"::text as "paymentStatus", "restaurantId", "shopName"
          FROM orders
          WHERE id = ${cleanId} OR "readableId" = ${cleanId} LIMIT 1
        `

        if (orders.length > 0) {
          const order = orders[0]

          if (order.paymentStatus !== 'PAID') {
            if (order.combinedId) {
              await prisma.$executeRaw`
                UPDATE orders 
                SET "paymentStatus" = 'PAID'::"PaymentStatus",
                    "paymentMethod" = 'UPI'::"PaymentMethod",
                    "status" = CASE WHEN status = 'PENDING' THEN 'CONFIRMED'::"OrderStatus" ELSE status END,
                    "updatedAt" = NOW()
                WHERE "combinedId" = ${order.combinedId}
              `
            } else {
              await prisma.$executeRaw`
                UPDATE orders 
                SET "paymentStatus" = 'PAID'::"PaymentStatus",
                    "paymentMethod" = 'UPI'::"PaymentMethod",
                    "status" = CASE WHEN status = 'PENDING' THEN 'CONFIRMED'::"OrderStatus" ELSE status END,
                    "updatedAt" = NOW()
                WHERE id = ${order.id}
              `
            }

            console.log(`✅ Cashfree webhook: Order #${order.readableId || order.id} marked PAID!`)
          }
        }
      }
    }

    return NextResponse.json({ received: true })
  } catch (err: any) {
    console.error('Error handling Cashfree webhook:', err)
    return NextResponse.json({ error: 'Webhook processing error' }, { status: 500 })
  }
}
