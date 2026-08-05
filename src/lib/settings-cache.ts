import { LRUCache } from 'lru-cache'

const settingsCache = new LRUCache<string, any>({
  max: 50,
  ttl: 3 * 60 * 1000,
})

const KEY = 'settings'

export function getCachedSettings(): any {
  return settingsCache.get(KEY) ?? null
}

export function setCachedSettings(settings: any) {
  settingsCache.set(KEY, settings)
}

export function clearSettingsCache() {
  settingsCache.delete(KEY)
}