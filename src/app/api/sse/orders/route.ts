import { sseEmitter } from '@/lib/sse-emitter'
import { auth } from '@/auth'

export const dynamic = 'force-dynamic'
export const maxDuration = 25

const HEARTBEAT_MS = 25_000

export async function GET(request: Request) {
  // Require authentication for SSE — prevents anonymous connection storms.
  const session = await auth()
  if (!session?.user) {
    return new Response('Unauthorized', { status: 401 })
  }

  const responseHeaders = new Headers({
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-transform',
    'Connection': 'keep-alive',
    // Discourage proxies/NGINX from buffering, which breaks SSE.
    'X-Accel-Buffering': 'no',
  })

  const stream = new ReadableStream({
    start(controller) {
      const safeEnqueue = (chunk: string) => {
        try {
          controller.enqueue(chunk)
        } catch {
          // Controller already closed (client disconnected) — tear down below.
        }
      }

      safeEnqueue('data: {"type":"connected"}\n\n')

      const handleOrderUpdate = (data: any) => {
        safeEnqueue(`data: ${JSON.stringify(data)}\n\n`)
      }

      sseEmitter.on('order', handleOrderUpdate)

      // Comment-line heartbeat — keeps the socket alive through proxies without
      // triggering EventSource message handlers on the client.
      const heartbeatInterval = setInterval(() => {
        safeEnqueue(`: heartbeat ${Date.now()}\n\n`)
      }, HEARTBEAT_MS)

      const cleanup = () => {
        clearInterval(heartbeatInterval)
        sseEmitter.off('order', handleOrderUpdate)
      }

      request.signal.addEventListener('abort', cleanup)
    },
    cancel() {
      // ReadableStream cancelled — abort handler above will also fire.
    },
  })

  return new Response(stream, { headers: responseHeaders })
}
