import { LRUCache } from 'lru-cache'
import { Redis } from '@upstash/redis'

type SearchResult = {
  products: any[]
  pagination: {
    total: number | null
    page: number
    limit: number
    totalPages: number | null
    nextCursor?: string | null
  }
}

// In-Memory Fallback LRU Cache
const localCache = new LRUCache<string, any>({
  max: 1000,
  ttl: 60 * 1000, // 60 seconds default TTL
})

let upstashRedis: Redis | null = null

try {
  const url = process.env.UPSTASH_REDIS_REST_URL
  const token = process.env.UPSTASH_REDIS_REST_TOKEN
  if (url && token && url.startsWith('http')) {
    upstashRedis = new Redis({
      url,
      token,
    })
  }
} catch (err) {
  console.warn('[RedisCache] Upstash Redis initialization bypassed, using in-memory LRU cache.', err)
}

/**
 * Retrieve cached data by key.
 */
export async function getCache<T>(key: string): Promise<T | null> {
  // First check fast local memory
  const localVal = localCache.get(key)
  if (localVal !== undefined) {
    return localVal as T
  }

  if (upstashRedis) {
    try {
      const data = await upstashRedis.get<T>(key)
      if (data !== null && data !== undefined) {
        // Populate local cache for sub-millisecond future hits
        localCache.set(key, data)
        return data
      }
    } catch (err) {
      console.warn(`[RedisCache] Redis GET failed for key "${key}", using LRU:`, err)
    }
  }

  return null
}

/**
 * Set cached data with TTL in seconds.
 */
export async function setCache<T>(key: string, value: T, ttlSeconds: number = 60): Promise<void> {
  localCache.set(key, value, { ttl: ttlSeconds * 1000 })

  if (upstashRedis) {
    try {
      await upstashRedis.set(key, value, { ex: ttlSeconds })
    } catch (err) {
      console.warn(`[RedisCache] Redis SET failed for key "${key}":`, err)
    }
  }
}

/**
 * Delete a specific key from cache.
 */
export async function deleteCache(key: string): Promise<void> {
  localCache.delete(key)
  if (upstashRedis) {
    try {
      await upstashRedis.del(key)
    } catch (err) {
      console.warn(`[RedisCache] Redis DEL failed for key "${key}":`, err)
    }
  }
}

/**
 * Invalidate all product & search cache entries.
 * Call this when a product is created, updated, or deleted.
 */
export async function invalidateProductCache(): Promise<void> {
  localCache.clear()

  if (upstashRedis) {
    try {
      const keys = await upstashRedis.keys('products:*')
      if (keys && keys.length > 0) {
        await Promise.all(keys.map((k) => upstashRedis!.del(k)))
      }
      const searchKeys = await upstashRedis.keys('search:*')
      if (searchKeys && searchKeys.length > 0) {
        await Promise.all(searchKeys.map((k) => upstashRedis!.del(k)))
      }
    } catch (err) {
      console.warn('[RedisCache] Redis product cache invalidation error:', err)
    }
  }
}

// Backward compatibility helpers
export function getCachedSearch(key: string): SearchResult | null {
  return localCache.get(key) ?? null
}

export function setCachedSearch(key: string, data: SearchResult) {
  localCache.set(key, data, { ttl: 60 * 1000 })
  if (upstashRedis) {
    upstashRedis.set(key, data, { ex: 60 }).catch(() => {})
  }
}
