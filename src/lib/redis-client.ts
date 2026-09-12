import { Redis } from '@upstash/redis'

interface MemoryCacheEntry {
  value: any
  expiresAt: number
}

const memoryStore = new Map<string, MemoryCacheEntry>()

if (typeof setInterval !== 'undefined') {
  const cleanupTimer = setInterval(() => {
    const now = Date.now()
    for (const [key, entry] of memoryStore.entries()) {
      if (entry.expiresAt <= now) {
        memoryStore.delete(key)
      }
    }
  }, 60000)
  if (cleanupTimer.unref) cleanupTimer.unref()
}

let _upstashRedis: Redis | null = null
let _hasLoggedWarning = false

function initUpstash(): Redis | null {
  if (_upstashRedis) return _upstashRedis

  const url = process.env.UPSTASH_REDIS_REST_URL
  const token = process.env.UPSTASH_REDIS_REST_TOKEN

  if (!url || !token) {
    if (!_hasLoggedWarning && process.env.NODE_ENV !== 'production') {
      console.info('ℹ️ Upstash Redis credentials not set. Using high-speed in-memory cache fallback.')
      _hasLoggedWarning = true
    }
    return null
  }

  try {
    _upstashRedis = new Redis({ url, token })
    return _upstashRedis
  } catch (err) {
    console.warn('⚠️ Failed to initialize Upstash Redis. Falling back to in-memory cache:', err)
    return null
  }
}

/**
 * Resilient Cache Interface
 * Supports both Upstash Redis and In-Memory fallback seamlessly.
 */
export const cache = {
  async get<T>(key: string): Promise<T | null> {
    const upstash = initUpstash()
    if (upstash) {
      try {
        const data = await upstash.get<T>(key)
        if (data !== null && data !== undefined) return data
      } catch (err) {
        console.warn(`Redis get failed for key "${key}", falling back to memory:`, err)
      }
    }

    const entry = memoryStore.get(key)
    if (!entry) return null
    if (entry.expiresAt <= Date.now()) {
      memoryStore.delete(key)
      return null
    }
    return entry.value as T
  },

  async set(key: string, value: any, opts?: { ex?: number }): Promise<void> {
    const ttlSeconds = opts?.ex || 300
    const upstash = initUpstash()
    if (upstash) {
      try {
        await upstash.set(key, value, { ex: ttlSeconds })
      } catch (err) {
        console.warn(`Redis set failed for key "${key}", writing to memory fallback:`, err)
      }
    }

    memoryStore.set(key, {
      value,
      expiresAt: Date.now() + ttlSeconds * 1000,
    })
  },

  async del(...keys: string[]): Promise<void> {
    if (!keys || keys.length === 0) return
    const upstash = initUpstash()
    if (upstash) {
      try {
        await upstash.del(...keys)
      } catch (err) {
        console.warn(`Redis del failed:`, err)
      }
    }

    for (const key of keys) {
      memoryStore.delete(key)
    }
  },

  async delByPrefix(prefix: string): Promise<void> {
    const upstash = initUpstash()
    if (upstash) {
      try {
        const keys = await upstash.keys(`${prefix}*`)
        if (keys && keys.length > 0) {
          await upstash.del(...keys)
        }
      } catch (err) {
        console.warn(`Redis delByPrefix failed for "${prefix}":`, err)
      }
    }

    for (const key of memoryStore.keys()) {
      if (key.startsWith(prefix)) {
        memoryStore.delete(key)
      }
    }
  }
}

/**
 * Drop-in backward compatibility for existing code calling getRedis()
 */
export function getRedis(): typeof cache {
  return cache
}

export const CACHE_KEYS = {
  SETTINGS: 'cache:settings',
  CATEGORIES: 'cache:categories',
  RESTAURANTS: 'cache:restaurants',
  PRODUCTS: 'cache:products',
} as const

export const DEFAULT_TTL = {
  SETTINGS: 30,
  CATEGORIES: 3600,
  RESTAURANTS: 600,
  PRODUCTS: 300,
} as const
