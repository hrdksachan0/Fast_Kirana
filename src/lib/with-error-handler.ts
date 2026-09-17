import { NextRequest, NextResponse } from 'next/server'
import { ApiResponder, ApiErrorCode } from './api-response'
import crypto from 'crypto'

export type RouteHandler = (
  req: NextRequest,
  context?: { params?: Promise<Record<string, string | string[]>> | Record<string, string | string[]> }
) => Promise<NextResponse | Response>

/**
 * Higher-order error handling wrapper for Next.js App Router route handlers.
 * Guarantees that uncaught errors never crash the node runtime and always return
 * a structured JSON envelope with an x-request-id correlation header.
 */
export function withErrorHandler(handler: RouteHandler): RouteHandler {
  return async (req: NextRequest, context) => {
    const requestId = req.headers.get('x-request-id') || crypto.randomUUID()
    const startTime = Date.now()

    try {
      const response = await handler(req, context)

      // Ensure the x-request-id header is attached if returning a NextResponse
      if (response instanceof NextResponse && !response.headers.has('x-request-id')) {
        response.headers.set('x-request-id', requestId)
      }

      return response
    } catch (error: any) {
      const duration = Date.now() - startTime
      console.error(
        `[API ERROR] [${requestId}] ${req.method} ${req.nextUrl.pathname} (${duration}ms):`,
        error?.stack || error?.message || error
      )

      const status = typeof error?.status === 'number' ? error.status : 500
      let code: ApiErrorCode = 'INTERNAL_ERROR'
      if (status === 400) code = 'BAD_REQUEST'
      if (status === 401) code = 'UNAUTHORIZED'
      if (status === 403) code = 'FORBIDDEN'
      if (status === 404) code = 'NOT_FOUND'
      if (status === 409) code = 'CONFLICT'

      return ApiResponder.error(
        error?.message || 'An unexpected error occurred while processing your request',
        status,
        code,
        error?.stack,
        requestId
      )
    }
  }
}
