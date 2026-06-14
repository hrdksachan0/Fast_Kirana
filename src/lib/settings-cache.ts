let cachedSettings: any = null
let lastFetched: number = 0
const CACHE_TTL = 10000 // 10 seconds

export function getCachedSettings() {
  const now = Date.now()
  if (cachedSettings && (now - lastFetched < CACHE_TTL)) {
    return cachedSettings
  }
  return null
}

export function setCachedSettings(settings: any) {
  cachedSettings = settings
  lastFetched = Date.now()
}

export function clearSettingsCache() {
  cachedSettings = null
  lastFetched = 0
}
