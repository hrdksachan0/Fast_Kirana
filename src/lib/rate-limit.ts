/**
 * Simple in-memory rate limiter for API routes.
 * 
 * Usage in any API route:
 *   import { rateLimit } from '@/lib/rate-limit'
 *   const limiter = rateLimit({ interval: 60_000, limit: 20 })
 *   
 *   export async function POST(request: NextRequest) {
 *     const limited = limiter.check(request)
 *     if (limited) return limited  // returns 429 response
 *     // ... your logic
 *   }
 */

import { NextRequest, NextResponse } from 'next/server'

interface RateLimitOptions {
  /** Time window in milliseconds (default: 60_000 = 1 minute) */
  interval?: number
  /** Max requests per window per IP (default: 30) */
  limit?: number
}

interface TokenEntry {
  count: number
  resetAt: number
}

const tokenBuckets = new Map<string, Map<string, TokenEntry>>()

// Auto-cleanup stale entries every 5 minutes
if (typeof globalThis !== 'undefined') {
  const CLEANUP_INTERVAL = 5 * 60 * 1000
  setInterval(() => {
    const now = Date.now()
    for (const [bucketId, bucket] of tokenBuckets) {
      for (const [key, entry] of bucket) {
        if (now > entry.resetAt) {
          bucket.delete(key)
        }
      }
      if (bucket.size === 0) {
        tokenBuckets.delete(bucketId)
      }
    }
  }, CLEANUP_INTERVAL).unref?.()
}

function getClientIp(request: NextRequest): string {
  return (
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
    request.headers.get('x-real-ip') ||
    request.headers.get('cf-connecting-ip') ||
    'unknown'
  )
}

export function rateLimit(options: RateLimitOptions = {}) {
  const { interval = 60_000, limit = 30 } = options
  const bucketId = `${interval}-${limit}-${Math.random().toString(36).slice(2, 6)}`
  const bucket = new Map<string, TokenEntry>()
  tokenBuckets.set(bucketId, bucket)

  return {
    /**
     * Check if the request is rate-limited.
     * Returns null if allowed, or a 429 NextResponse if limited.
     */
    check(request: NextRequest): NextResponse | null {
      const ip = getClientIp(request)
      const now = Date.now()

      const existing = bucket.get(ip)

      if (!existing || now > existing.resetAt) {
        // New window
        bucket.set(ip, { count: 1, resetAt: now + interval })
        return null
      }

      if (existing.count >= limit) {
        const retryAfter = Math.ceil((existing.resetAt - now) / 1000)
        return NextResponse.json(
          {
            error: 'Too many requests. Please try again later.',
            retryAfter,
          },
          {
            status: 429,
            headers: {
              'Retry-After': String(retryAfter),
              'X-RateLimit-Limit': String(limit),
              'X-RateLimit-Remaining': '0',
              'X-RateLimit-Reset': String(existing.resetAt),
            },
          }
        )
      }

      // Increment
      existing.count++
      return null
    },
  }
}

// ── Pre-configured limiters for different route types ──

/** For auth routes (login, OTP, signup): 10 requests per minute */
export const authLimiter = rateLimit({ interval: 60_000, limit: 10 })

/** For OTP send: 3 requests per minute (prevent spam) */
export const otpLimiter = rateLimit({ interval: 60_000, limit: 3 })

/** For general API reads: 60 requests per minute */
export const apiReadLimiter = rateLimit({ interval: 60_000, limit: 60 })

/** For mutations (create/update/delete): 20 requests per minute */
export const apiWriteLimiter = rateLimit({ interval: 60_000, limit: 20 })
