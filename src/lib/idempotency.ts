import crypto from 'crypto'
import { Redis } from '@upstash/redis'

interface MemoryIdempotencyEntry {
  status: 'PROCESSING' | 'COMPLETED'
  response?: any
  expiresAt: number
}

const localMemoryLocks = new Map<string, MemoryIdempotencyEntry>()

// Periodic cleanup of stale in-memory locks every 60s
if (typeof setInterval !== 'undefined') {
  const cleanupTimer = setInterval(() => {
    const now = Date.now()
    for (const [key, entry] of localMemoryLocks.entries()) {
      if (entry.expiresAt <= now) {
        localMemoryLocks.delete(key)
      }
    }
  }, 60000)
  if (cleanupTimer.unref) cleanupTimer.unref()
}

let _redisInstance: Redis | null = null

function getRedis(): Redis | null {
  if (_redisInstance) return _redisInstance
  const url = process.env.UPSTASH_REDIS_REST_URL
  const token = process.env.UPSTASH_REDIS_REST_TOKEN
  if (!url || !token || url === 'placeholder' || token === 'placeholder') return null

  try {
    _redisInstance = new Redis({ url, token })
    return _redisInstance
  } catch {
    return null
  }
}

/**
 * Generate a deterministic cart signature for order idempotency.
 * Combines buyer identifier, sorted cart items, delivery address, and payment method.
 */
export function generateOrderCartSignature(
  buyerId: string,
  items: Array<{ id?: string; productId?: string; quantity?: number; variantId?: string; product?: { id?: string } }>,
  addressId?: string | null,
  paymentMethod?: string | null
): string {
  const normalizedItems = (items || [])
    .map((it) => {
      const pId = it.product?.id || it.productId || it.id || ''
      const qty = it.quantity || 1
      const vId = it.variantId || ''
      return `${pId}:${vId}:${qty}`
    })
    .sort()
    .join('|')

  const raw = `${buyerId.trim()}#${normalizedItems}#${addressId || 'STORE_PICKUP'}#${paymentMethod || 'COD'}`
  return crypto.createHash('sha256').update(raw).digest('hex').slice(0, 32)
}

export interface IdempotencyResult {
  isDuplicate: boolean
  isProcessing?: boolean
  cachedResponse?: any
}

/**
 * Attempt to acquire an atomic lock for order creation.
 * Returns isDuplicate: true if a concurrent or previous identical request was made within ttlSeconds.
 */
export async function acquireIdempotencyLock(
  key: string,
  ttlSeconds = 60
): Promise<IdempotencyResult> {
  const fullKey = `idempotency:order:${key}`
  const now = Date.now()
  const redis = getRedis()

  if (redis) {
    try {
      // 1. Check if key already exists
      const existing = await redis.get<string | { status: string; response: any }>(fullKey)
      if (existing) {
        if (typeof existing === 'string' && existing === 'PROCESSING') {
          return { isDuplicate: true, isProcessing: true }
        }
        if (typeof existing === 'object' && existing.status === 'COMPLETED') {
          return { isDuplicate: true, isProcessing: false, cachedResponse: existing.response }
        }
        return { isDuplicate: true, isProcessing: true }
      }

      // 2. Atomic SET NX with TTL
      const acquired = await redis.set(fullKey, 'PROCESSING', { ex: ttlSeconds, nx: true })
      if (!acquired) {
        return { isDuplicate: true, isProcessing: true }
      }

      return { isDuplicate: false }
    } catch (err) {
      console.warn('Redis idempotency check failed, falling back to in-memory store:', err)
    }
  }

  // Fallback to local memory lock
  const local = localMemoryLocks.get(fullKey)
  if (local && local.expiresAt > now) {
    if (local.status === 'PROCESSING') {
      return { isDuplicate: true, isProcessing: true }
    }
    return { isDuplicate: true, isProcessing: false, cachedResponse: local.response }
  }

  localMemoryLocks.set(fullKey, {
    status: 'PROCESSING',
    expiresAt: now + ttlSeconds * 1000,
  })

  return { isDuplicate: false }
}

/**
 * Cache the successful order creation response for subsequent replay attempts.
 */
export async function saveIdempotencyResponse(
  key: string,
  response: any,
  ttlSeconds = 120
): Promise<void> {
  const fullKey = `idempotency:order:${key}`
  const now = Date.now()
  const payload = { status: 'COMPLETED', response }
  const redis = getRedis()

  if (redis) {
    try {
      await redis.set(fullKey, payload, { ex: ttlSeconds })
    } catch (err) {
      console.warn('Redis saveIdempotencyResponse failed:', err)
    }
  }

  localMemoryLocks.set(fullKey, {
    status: 'COMPLETED',
    response,
    expiresAt: now + ttlSeconds * 1000,
  })
}

/**
 * Release an idempotency lock early (e.g. if order validation failed before database commit).
 */
export async function releaseIdempotencyLock(key: string): Promise<void> {
  const fullKey = `idempotency:order:${key}`
  const redis = getRedis()

  if (redis) {
    try {
      await redis.del(fullKey)
    } catch (err) {
      console.warn('Redis releaseIdempotencyLock failed:', err)
    }
  }

  localMemoryLocks.delete(fullKey)
}
