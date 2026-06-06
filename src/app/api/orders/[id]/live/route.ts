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

  // Verify order exists
  const order = await prisma.order.findUnique({
    where: { id },
  })

  if (!order) {
    return new Response('Order not found', { status: 404 })
  }

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

      const sendEvent = (data: any) => {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(data)}\n\n`))
      }

      // Initial push
      sendEvent({
        status: lastStatus,
        deliveryLat: lastLat,
        deliveryLng: lastLng,
      })

      // Interval to poll DB and push changes
      const interval = setInterval(async () => {
        try {
          const freshOrder = await prisma.order.findUnique({
            where: { id },
            select: { status: true, deliveryLat: true, deliveryLng: true },
          })

          if (freshOrder) {
            const hasStatusChanged = freshOrder.status !== lastStatus
            const hasCoordinatesChanged =
              freshOrder.deliveryLat !== lastLat || freshOrder.deliveryLng !== lastLng

            if (hasStatusChanged || hasCoordinatesChanged) {
              lastStatus = freshOrder.status
              lastLat = freshOrder.deliveryLat
              lastLng = freshOrder.deliveryLng

              sendEvent({
                status: freshOrder.status,
                deliveryLat: freshOrder.deliveryLat,
                deliveryLng: freshOrder.deliveryLng,
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
