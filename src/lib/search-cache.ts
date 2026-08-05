import { LRUCache } from 'lru-cache'

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

const searchCache = new LRUCache<string, SearchResult>({
  max: 200,
  ttl: 5 * 60 * 1000,
})

export function getCachedSearch(key: string): SearchResult | null {
  return searchCache.get(key) ?? null
}

export function setCachedSearch(key: string, data: SearchResult) {
  searchCache.set(key, data)
}
