import { sseEmitter } from '@/lib/sse-emitter'

export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  const responseHeaders = new Headers({
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-transform',
    'Connection': 'keep-alive',
  })

  const stream = new ReadableStream({
    start(controller) {
      // Send initial connection event
      controller.enqueue('data: {"type":"connected"}\n\n')

      const handleOrderUpdate = (data: any) => {
        try {
          controller.enqueue(`data: ${JSON.stringify(data)}\n\n`)
        } catch (err) {
          console.error('SSE enqueue error:', err)
        }
      }

      // Subscribe to events
      sseEmitter.on('order', handleOrderUpdate)

      // Send a heartbeat event every 15 seconds to prevent timeout
      const heartbeatInterval = setInterval(() => {
        try {
          controller.enqueue('data: {"type":"heartbeat"}\n\n')
        } catch (err) {
          clearInterval(heartbeatInterval)
        }
      }, 15000)

      // Clean up when client disconnects
      request.signal.addEventListener('abort', () => {
        clearInterval(heartbeatInterval)
        sseEmitter.off('order', handleOrderUpdate)
      })
    },
  })

  return new Response(stream, { headers: responseHeaders })
}
