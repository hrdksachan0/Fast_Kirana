/**
 * Gemini Semantic Query Embedding Service
 * Uses Google Gemini embedding API (models/gemini-embedding-001) with outputDimensionality: 768.
 * Features an in-memory LRU cache to make repeat queries instant (0ms).
 */

const queryEmbeddingCache = new Map<string, number[]>()
const MAX_CACHE_SIZE = 500

export async function getGeminiQueryEmbedding(rawQuery: string): Promise<number[] | null> {
  const query = (rawQuery || '').trim().toLowerCase()
  if (!query || query.length < 2) return null

  // 1. Check in-memory cache
  if (queryEmbeddingCache.has(query)) {
    return queryEmbeddingCache.get(query)!
  }

  const apiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY
  if (!apiKey) {
    console.warn('[GeminiEmbedding] GEMINI_API_KEY not found in environment.')
    return null
  }

  try {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${apiKey}`
    const payload = {
      model: 'models/gemini-embedding-001',
      content: {
        parts: [{ text: query }]
      },
      outputDimensionality: 768
    }

    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 2000) // 2s timeout max

    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      signal: controller.signal
    })
    clearTimeout(timeoutId)

    if (!res.ok) {
      console.warn(`[GeminiEmbedding] API returned ${res.status}: ${res.statusText}`)
      return null
    }

    const data = await res.json()
    const embedding = data?.embedding?.values as number[]
    if (Array.isArray(embedding) && embedding.length === 768) {
      // Store in LRU cache
      if (queryEmbeddingCache.size >= MAX_CACHE_SIZE) {
        const firstKey = queryEmbeddingCache.keys().next().value
        if (firstKey) queryEmbeddingCache.delete(firstKey)
      }
      queryEmbeddingCache.set(query, embedding)
      return embedding
    }
    return null
  } catch (err: any) {
    if (err.name !== 'AbortError') {
      console.warn('[GeminiEmbedding] Embedding query failed:', err.message || err)
    }
    return null
  }
}
