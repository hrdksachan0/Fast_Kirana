import crypto from 'crypto'
import { Redis } from '@upstash/redis'

interface MemoryIdempotencyEntry {
  status: 'PROCESSING' | 'COMPLETED'
  userId?: string | null
  requestHash?: string | null
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

export function computeRequestFingerprint(
  userId: string | null | undefined,
  items: Array<any>,
  addressId?: string | null,
  paymentMethod?: string | null,
  couponCode?: string | null,
  tipAmount?: number | null
): string {
  const normalizedItems = (items || [])
    .map((it) => {
      const p = it.product || {}
      const pid = String(p.id || it.productId || it.id || '')
      const varName = it.selectedVariant || (pid.includes('_') ? pid.split('_')[1] : '')
      const qty = Number(it.quantity || 1)
      const price = Number(it.price || p.price || 0)
      return `${pid}:${varName}:${qty}:${price.toFixed(2)}`
    })
    .sort()
    .join('|')

  const normCoupon = (couponCode || '').trim().toUpperCase()
  const normTip = Number(tipAmount || 0).toFixed(2)
  const normMethod = (paymentMethod || 'COD').trim().toUpperCase()
  const normAddr = (addressId || '').trim()
  const normUser = (userId || '').trim()

  const raw = `${normUser}#${normAddr}#${normMethod}#${normCoupon}#${normTip}#${normalizedItems}`
  return crypto.createHash('sha256').update(raw).digest('hex')
}

export function getScopedIdempotencyKey(key: string, userId?: string | null, operation = 'checkout'): string {
  const cleanKey = (key || '').trim()
  const cleanUser = (userId || 'anon').trim()
  return `${cleanUser}:${operation}:${cleanKey}`
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
  status?: number
  error?: string
}

/**
 * Attempt to acquire an atomic lock for order creation.
 * Returns isDuplicate: true if a concurrent or previous identical request was made within ttlSeconds.
 * Scoped by verified buyer and operation, enforces request payload fingerprint matching.
 */
export async function acquireIdempotencyLock(
  key: string,
  ttlSeconds = 60,
  prismaClient: any = null,
  userId?: string,
  requestHash?: string,
  operation = 'checkout'
): Promise<IdempotencyResult> {
  const scopedKey = getScopedIdempotencyKey(key, userId, operation)
  const fullKey = `idempotency:order:${scopedKey}`
  const now = Date.now()
  const redis = getRedis()

  if (redis) {
    try {
      // 1. Check if key already exists
      const existing = await redis.get<string | { status: string; response?: any; userId?: string; requestHash?: string; expiresAt?: number }>(fullKey)
      if (existing) {
        if (typeof existing === 'object') {
          // Check ownership
          if (existing.userId && userId && existing.userId !== userId) {
            return { isDuplicate: true, status: 403, error: 'Forbidden: Idempotency key belongs to another user' }
          }
          // Check payload fingerprint
          if (existing.requestHash && requestHash && existing.requestHash !== requestHash) {
            return { isDuplicate: true, status: 409, error: 'Idempotency key already used with different request payload' }
          }
          if (existing.status === 'COMPLETED') {
            return { isDuplicate: true, isProcessing: false, cachedResponse: existing.response }
          }
          if (existing.status === 'PROCESSING') {
            return { isDuplicate: true, isProcessing: true }
          }
        } else if (typeof existing === 'string') {
          if (existing === 'PROCESSING') {
            return { isDuplicate: true, isProcessing: true }
          }
        }
      }

      // 2. Atomic SET NX with TTL
      const procVal = JSON.stringify({
        status: 'PROCESSING',
        userId: userId || null,
        requestHash: requestHash || null,
        expiresAt: now + ttlSeconds * 1000,
      })
      const acquired = await redis.set(fullKey, procVal, { ex: ttlSeconds, nx: true })
      if (!acquired) {
        return { isDuplicate: true, isProcessing: true }
      }

      localMemoryLocks.set(scopedKey, {
        status: 'PROCESSING',
        userId: userId || null,
        requestHash: requestHash || null,
        expiresAt: now + ttlSeconds * 1000,
      })

      return { isDuplicate: false }
    } catch (err) {
      console.warn('Redis idempotency check failed, falling back to durable store:', err)
    }
  }

  // ── DURABLE DATABASE LOCKING (Independent of Redis) ──
  if (prismaClient?.idempotencyRecord) {
    try {
      const record = await prismaClient.idempotencyRecord.findUnique({
        where: { key: scopedKey }
      })

      const nowDt = new Date()
      if (record) {
        // Ownership check
        if (record.userId && userId && record.userId !== userId) {
          return { isDuplicate: true, status: 403, error: 'Forbidden: Idempotency key belongs to another user' }
        }
        // Fingerprint check
        if (record.requestHash && requestHash && record.requestHash !== requestHash) {
          return { isDuplicate: true, status: 409, error: 'Idempotency key already used with different request payload' }
        }

        if (record.status === 'COMPLETED') {
          return { isDuplicate: true, isProcessing: false, cachedResponse: record.response }
        }
        if (record.status === 'PROCESSING') {
          if (record.expiresAt > nowDt) {
            return { isDuplicate: true, isProcessing: true }
          }
          // Expired lock, reclaim
          await prismaClient.idempotencyRecord.update({
            where: { key: scopedKey },
            data: {
              status: 'PROCESSING',
              userId: userId || record.userId,
              requestHash: requestHash || record.requestHash,
              expiresAt: new Date(Date.now() + ttlSeconds * 1000)
            }
          })
          return { isDuplicate: false }
        }
      } else {
        try {
          await prismaClient.idempotencyRecord.create({
            data: {
              key: scopedKey,
              userId: userId || null,
              requestHash: requestHash || null,
              status: 'PROCESSING',
              expiresAt: new Date(Date.now() + ttlSeconds * 1000)
            }
          })
          return { isDuplicate: false }
        } catch (dbErr: any) {
          if (dbErr.code === 'P2002') {
            const fresh = await prismaClient.idempotencyRecord.findUnique({ where: { key: scopedKey } })
            if (fresh?.userId && userId && fresh.userId !== userId) {
              return { isDuplicate: true, status: 403, error: 'Forbidden: Idempotency key belongs to another user' }
            }
            if (fresh?.requestHash && requestHash && fresh.requestHash !== requestHash) {
              return { isDuplicate: true, status: 409, error: 'Idempotency key already used with different request payload' }
            }
            if (fresh?.status === 'COMPLETED') {
              return { isDuplicate: true, isProcessing: false, cachedResponse: fresh.response }
            }
            return { isDuplicate: true, isProcessing: true }
          }
        }
      }
    } catch (err) {
      console.warn('Database idempotency check error, falling back to memory store:', err)
    }
  }

  // Fallback to local memory lock
  const local = localMemoryLocks.get(scopedKey)
  if (local && local.expiresAt > now) {
    if (local.userId && userId && local.userId !== userId) {
      return { isDuplicate: true, status: 403, error: 'Forbidden: Idempotency key belongs to another user' }
    }
    if (local.requestHash && requestHash && local.requestHash !== requestHash) {
      return { isDuplicate: true, status: 409, error: 'Idempotency key already used with different request payload' }
    }
    if (local.status === 'PROCESSING') {
      return { isDuplicate: true, isProcessing: true }
    }
    return { isDuplicate: true, isProcessing: false, cachedResponse: local.response }
  }

  localMemoryLocks.set(scopedKey, {
    status: 'PROCESSING',
    userId: userId || null,
    requestHash: requestHash || null,
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
  ttlSeconds = 86400,
  prismaClient: any = null,
  userId?: string,
  requestHash?: string,
  operation = 'checkout'
): Promise<void> {
  const scopedKey = getScopedIdempotencyKey(key, userId, operation)
  const fullKey = `idempotency:order:${scopedKey}`
  const now = Date.now()
  const payload = {
    status: 'COMPLETED',
    response,
    userId: userId || null,
    requestHash: requestHash || null,
    expiresAt: now + ttlSeconds * 1000,
  }
  const redis = getRedis()

  if (redis) {
    try {
      await redis.set(fullKey, JSON.stringify(payload), { ex: ttlSeconds })
    } catch (err) {
      console.warn('Redis saveIdempotencyResponse failed:', err)
    }
  }

  if (prismaClient?.idempotencyRecord) {
    try {
      const orderId = response?.id || response?.order?.id || null
      await prismaClient.idempotencyRecord.upsert({
        where: { key: scopedKey },
        create: {
          key: scopedKey,
          userId: userId || null,
          requestHash: requestHash || null,
          status: 'COMPLETED',
          response,
          orderId,
          expiresAt: new Date(Date.now() + ttlSeconds * 1000)
        },
        update: {
          status: 'COMPLETED',
          userId: userId || undefined,
          requestHash: requestHash || undefined,
          response,
          orderId,
          expiresAt: new Date(Date.now() + ttlSeconds * 1000)
        }
      })
    } catch (err) {
      console.warn('Database saveIdempotencyResponse failed:', err)
    }
  }

  localMemoryLocks.set(scopedKey, {
    status: 'COMPLETED',
    userId: userId || null,
    requestHash: requestHash || null,
    response,
    expiresAt: now + ttlSeconds * 1000,
  })
}

/**
 * Release an idempotency lock early (e.g. if order validation failed before database commit).
 */
export async function releaseIdempotencyLock(
  key: string,
  prismaClient: any = null,
  userId?: string,
  operation = 'checkout'
): Promise<void> {
  const scopedKey = getScopedIdempotencyKey(key, userId, operation)
  const fullKey = `idempotency:order:${scopedKey}`
  const redis = getRedis()

  if (redis) {
    try {
      await redis.del(fullKey)
    } catch (err) {
      console.warn('Redis releaseIdempotencyLock failed:', err)
    }
  }

  if (prismaClient?.idempotencyRecord) {
    try {
      await prismaClient.idempotencyRecord.deleteMany({
        where: { key: scopedKey, status: 'PROCESSING' }
      })
    } catch (err) {
      console.warn('Database releaseIdempotencyLock failed:', err)
    }
  }

  localMemoryLocks.delete(scopedKey)
}
