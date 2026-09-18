import { NextRequest, NextResponse } from 'next/server'
import { apiWriteLimiter } from '@/lib/rate-limit'

export const dynamic = 'force-dynamic'

interface ErrorReportBody {
  message: string
  stack?: string
  route?: string
  severity?: 'INFO' | 'WARN' | 'ERROR' | 'CRITICAL'
  metadata?: Record<string, any>
  timestamp?: string
  userAgent?: string
  screenWidth?: number
  screenHeight?: number
}

export async function POST(request: NextRequest) {
  // 1. Rate-limit to prevent DOS / error log flooding
  const rateLimitResponse = await apiWriteLimiter.check(request)
  if (rateLimitResponse) return rateLimitResponse

  try {
    let body: ErrorReportBody
    const contentType = request.headers.get('content-type') || ''

    if (contentType.includes('application/json')) {
      body = await request.json()
    } else {
      const text = await request.text()
      body = JSON.parse(text)
    }

    const {
      message = 'Unknown client error',
      stack,
      route = 'unknown',
      severity = 'ERROR',
      metadata,
      timestamp = new Date().toISOString(),
      userAgent,
      screenWidth,
      screenHeight,
    } = body

    // 2. Structured log format for production log aggregators (Vercel / Datadog)
    const logPrefix = severity === 'CRITICAL' ? '🚨 [TELEMETRY_CRITICAL]' : '⚠️ [TELEMETRY_CLIENT_ERROR]'
    
    console.error(`${logPrefix} [${route}] ${message}`, {
      severity,
      route,
      timestamp,
      stack: stack ? stack.split('\n').slice(0, 5).join('\n') : undefined,
      metadata,
      client: {
        userAgent: userAgent?.slice(0, 150),
        viewport: screenWidth && screenHeight ? `${screenWidth}x${screenHeight}` : undefined,
      },
    })

    return NextResponse.json({ success: true, received: true }, { status: 200 })
  } catch (_err) {
    // Return 200/400 gracefully
    return NextResponse.json({ success: false, error: 'Invalid payload' }, { status: 400 })
  }
}
