import { Redis } from '@upstash/redis'

let _redis: Redis | undefined

export function getRedis(): Redis {
  if (_redis) return _redis

  const url = process.env.UPSTASH_REDIS_REST_URL
  const token = process.env.UPSTASH_REDIS_REST_TOKEN

  if (!url || !token) {
    throw new Error('UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN are required')
  }

  _redis = new Redis({ url, token })
  return _redis
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
