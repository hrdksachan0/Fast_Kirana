import { sseEmitter } from '@/lib/sse-emitter'

export const dynamic = 'force-dynamic'

export async function GET() {
  const stream = new ReadableStream({
    start(controller) {
      const sendEvent = (data: any) => {
        try {
          const chunk = `data: ${JSON.stringify(data)}\n\n`
          controller.enqueue(new TextEncoder().encode(chunk))
        } catch (err) {
          console.error('SSE send error:', err)
        }
      }

      // Initial ping event
      sendEvent({ type: 'connected', timestamp: Date.now() })

      const onOrderEvent = (eventData: any) => {
        sendEvent(eventData)
      }

      sseEmitter.on('order', onOrderEvent)

      // Send keep-alive heartbeats every 15 seconds to prevent proxy timeouts
      const heartbeatInterval = setInterval(() => {
        sendEvent({ type: 'ping', timestamp: Date.now() })
      }, 15000)

      return () => {
        sseEmitter.off('order', onOrderEvent)
        clearInterval(heartbeatInterval)
      }
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
