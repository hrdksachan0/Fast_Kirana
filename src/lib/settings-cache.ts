import { getRedis, CACHE_KEYS } from './redis-client'

export async function clearSettingsCache(): Promise<void> {
  try {
    const redis = getRedis()
    await redis.del(CACHE_KEYS.SETTINGS)
  } catch (_err) {
    // Gracefully ignore if Redis is not configured or throws
  }
}
