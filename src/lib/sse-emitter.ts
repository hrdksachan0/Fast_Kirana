import { EventEmitter } from 'events'

class SSEEmitter extends EventEmitter {}

// Global object to persist across hot reloads in Next.js dev server
const globalForEmitter = global as unknown as {
  sseEmitter: SSEEmitter | undefined
}

export const sseEmitter = globalForEmitter.sseEmitter ?? new SSEEmitter()

if (process.env.NODE_ENV !== 'production') {
  globalForEmitter.sseEmitter = sseEmitter
}
