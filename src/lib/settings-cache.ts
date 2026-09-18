import { cache, CACHE_KEYS } from './redis-client'

export async function clearSettingsCache(): Promise<void> {
  try {
    await Promise.all([
      cache.del(CACHE_KEYS.SETTINGS),
      cache.delByPrefix(`${CACHE_KEYS.SETTINGS}:`),
      cache.del('cache:settings'),
      cache.delByPrefix('cache:settings:'),
      cache.del('store:status'),
      cache.del('store:status:global'),
      cache.delByPrefix('store:status:'),
    ])
  } catch (_err) {
    // Gracefully ignore if Redis is not configured or throws
  }
}
