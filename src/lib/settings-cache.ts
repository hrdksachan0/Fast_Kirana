import { cache, CACHE_KEYS } from './redis-client'

export async function clearSettingsCache(): Promise<void> {
  try {
    await Promise.all([
      cache.del(CACHE_KEYS.SETTINGS),
      cache.delByPrefix(`${CACHE_KEYS.SETTINGS}:`),
      cache.del('store:status'),
      cache.delByPrefix('store:status:'),
    ])
  } catch (_err) {
    // Gracefully ignore if Redis is not configured or throws
  }
}
