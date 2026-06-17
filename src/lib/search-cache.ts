type SearchResult = {
  products: any[]
  pagination: {
    total: number
    page: number
    limit: number
    totalPages: number
  }
}

const cache = new Map<string, { data: SearchResult; expiresAt: number }>()

export function getCachedSearch(key: string): SearchResult | null {
  const cached = cache.get(key)
  if (!cached) return null
  if (Date.now() > cached.expiresAt) {
    cache.delete(key)
    return null
  }
  return cached.data
}

export function setCachedSearch(key: string, data: SearchResult, ttlMs = 300000) {
  cache.set(key, {
    data,
    expiresAt: Date.now() + ttlMs
  })

  // Prevent memory leaks: Evict stale entries when size exceeds limit
  if (cache.size > 200) {
    const now = Date.now()
    for (const [k, v] of cache.entries()) {
      if (now > v.expiresAt) {
        cache.delete(k)
      }
    }
    // If still too large, delete oldest entries (FIFO eviction fallback)
    if (cache.size > 200) {
      const keys = Array.from(cache.keys())
      const toDelete = keys.slice(0, 50)
      toDelete.forEach((k) => cache.delete(k))
    }
  }
}
