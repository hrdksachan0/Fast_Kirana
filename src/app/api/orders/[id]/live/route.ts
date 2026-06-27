import { NextRequest } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { OrderStatus } from '@prisma/client'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session) {
    return new Response('Unauthorized', { status: 401 })
  }

  const { id } = await params

  // Verify order exists using raw SQL to avoid the enum deserialization bug
  const orders: any[] = await prisma.$queryRaw`
    SELECT id, "userId", status::text as status, "deliveryLat", "deliveryLng", "deliveryUserId" FROM orders WHERE id = ${id} LIMIT 1
  `

  if (orders.length === 0) {
    return new Response('Order not found', { status: 404 })
  }

  const order = orders[0]

  // Verify access authorization
  if (
    order.userId !== session.user.id &&
    session.user.role !== 'ADMIN' &&
    session.user.role !== 'DELIVERY'
  ) {
    return new Response('Unauthorized', { status: 401 })
  }

  const encoder = new TextEncoder()

  const stream = new ReadableStream({
    async start(controller) {
      let lastStatus = order.status
      let lastLat = order.deliveryLat
      let lastLng = order.deliveryLng
      let lastUserId = order.deliveryUserId

      const sendEvent = (data: any) => {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(data)}\n\n`))
      }

      // Fetch initial rider details
      let deliveryUser = null
      if (lastUserId) {
        const riders: any[] = await prisma.$queryRaw`
          SELECT name, phone FROM users WHERE id = ${lastUserId} LIMIT 1
        `
        if (riders.length > 0) {
          deliveryUser = {
            name: riders[0].name,
            phone: riders[0].phone
          }
        }
      }

      // Initial push
      sendEvent({
        status: lastStatus,
        deliveryLat: lastLat,
        deliveryLng: lastLng,
        deliveryUser,
      })

      // Interval to poll DB and push changes
      const interval = setInterval(async () => {
        try {
          const freshOrders: any[] = await prisma.$queryRaw`
            SELECT status::text as status, "deliveryLat", "deliveryLng", "deliveryUserId" FROM orders WHERE id = ${id} LIMIT 1
          `

          if (freshOrders.length > 0) {
            const freshOrder = freshOrders[0]
            const hasStatusChanged = freshOrder.status !== lastStatus
            const hasCoordinatesChanged =
              freshOrder.deliveryLat !== lastLat || freshOrder.deliveryLng !== lastLng
            const hasRiderChanged = freshOrder.deliveryUserId !== lastUserId

            if (hasStatusChanged || hasCoordinatesChanged || hasRiderChanged) {
              lastStatus = freshOrder.status
              lastLat = freshOrder.deliveryLat
              lastLng = freshOrder.deliveryLng
              lastUserId = freshOrder.deliveryUserId

              let freshDeliveryUser = null
              if (lastUserId) {
                const riders: any[] = await prisma.$queryRaw`
                  SELECT name, phone FROM users WHERE id = ${lastUserId} LIMIT 1
                `
                if (riders.length > 0) {
                  freshDeliveryUser = {
                    name: riders[0].name,
                    phone: riders[0].phone
                  }
                }
              }

              sendEvent({
                status: freshOrder.status,
                deliveryLat: freshOrder.deliveryLat,
                deliveryLng: freshOrder.deliveryLng,
                deliveryUser: freshDeliveryUser,
              })
            }
          }
        } catch (err) {
          console.error('SSE interval polling error:', err)
        }
      }, 3000)

      // Clean up when request aborts
      request.signal.addEventListener('abort', () => {
        clearInterval(interval)
        controller.close()
      })
    },
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      'Connection': 'keep-alive',
    },
  })
}
