import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { SYNONYM_DICTIONARY, normalizeSearchQuery } from '@/lib/synonyms'
import { getSemanticAiScore } from '@/lib/vector-search'
import { sortProductsByStock } from '@/lib/utils'

export interface SearchOptions {
  query?: string | null
  storeId?: string | null
  restaurantId?: string | null
  restaurantSlug?: string | null
  categoryId?: string | null
  category?: string | null
  sort?: string | null
  page?: number
  limit?: number
  includeUnavailable?: boolean
  isWorker?: boolean
  excludeRestaurant?: boolean
  includeRestaurants?: boolean
}

const STOP_WORDS = new Set([
  'ke', 'ka', 'ki', 'ko', 'se', 'me', 'mein', 'par', 'pe', 'aur', 'and', 'the', 'of', 'in', 'for', 'with', 'from'
])

export class ProductSearchService {
  /**
   * Execute optimized hybrid search:
   * 1. PostgreSQL tsvector + GIN index for exact & stemmed full-text search with ranking
   * 2. Trigram GIN index for typo tolerance (word_similarity)
   * 3. Hindi script transliteration & Hinglish synonym expansion
   * 4. Multi-store inventory stock override
   * 5. Zepto-style in-stock first ordering
   */
  static async search(options: SearchOptions) {
    const {
      query: rawQuery,
      storeId,
      restaurantId,
      restaurantSlug,
      categoryId,
      category,
      sort,
      page = 1,
      limit = 40,
      includeUnavailable = false,
      isWorker = false,
      excludeRestaurant = false,
      includeRestaurants = false,
    } = options

    const normalizedQuery = rawQuery ? normalizeSearchQuery(rawQuery) : ''
    let products: any[] = []
    let restaurants: any[] = []
    let total = 0

    const activeStoreId = storeId || 'hub-209206'

    if (normalizedQuery) {
      // 1. Tokenize query & filter stop words
      const rawTokens = normalizedQuery.split(/\s+/).filter(Boolean)
      const filteredTokens = rawTokens.filter(t => !STOP_WORDS.has(t))
      const searchTokens = filteredTokens.length > 0 ? filteredTokens : rawTokens

      // 2. Build PostgreSQL tsquery string with synonyms and prefix matching
      const tokenGroups = searchTokens.map(t => {
        const clean = t.replace(/[^a-z0-9]/g, '')
        if (!clean) return ''
        const syns = (SYNONYM_DICTIONARY[clean] || [])
          .map(s => s.replace(/[^a-z0-9]/g, ''))
          .filter(s => s.length > 1)
          .slice(0, 4)
        
        const allVariants = [clean, ...syns]
        return `(${allVariants.map(v => `${v}:*`).join(' | ')})`
      }).filter(Boolean)

      const tsquery = tokenGroups.join(' & ')

      // 3. Find candidate product IDs using PostgreSQL Full Text Search
      let candidateIds: string[] = []
      let rankMap = new Map<string, number>()

      if (tsquery) {
        try {
          const ftsRows: any[] = await prisma.$queryRaw`
            SELECT p.id, ts_rank(p.search_vector, to_tsquery('english', ${tsquery})) as rank
            FROM products p
            WHERE ${includeUnavailable ? Prisma.sql`TRUE` : Prisma.sql`p."isAvailable" = TRUE`}
              AND p.search_vector @@ to_tsquery('english', ${tsquery})
            ORDER BY rank DESC
            LIMIT 100;
          `
          ftsRows.forEach(r => {
            candidateIds.push(r.id)
            rankMap.set(r.id, Number(r.rank) || 0)
          })
        } catch (err) {
          console.warn('[ProductSearchService] tsquery execution fallback:', err)
        }
      }

      // 4. Typo tolerance: If few results found, use pg_trgm word_similarity
      if (candidateIds.length < 5) {
        try {
          const firstWord = searchTokens[0].replace(/[^a-z0-9]/g, '')
          if (firstWord.length >= 3) {
            const trgmRows: any[] = await prisma.$queryRaw`
              SELECT p.id, word_similarity(${firstWord}, p.name) as wsim
              FROM products p
              WHERE ${includeUnavailable ? Prisma.sql`TRUE` : Prisma.sql`p."isAvailable" = TRUE`}
                AND word_similarity(${firstWord}, p.name) > 0.28
              ORDER BY wsim DESC
              LIMIT 40;
            `
            trgmRows.forEach(r => {
              if (!candidateIds.includes(r.id)) {
                candidateIds.push(r.id)
                rankMap.set(r.id, (Number(r.wsim) || 0) * 0.5) // weighted trigram rank
              }
            })
          }
        } catch (err) {
          console.warn('[ProductSearchService] Trigram execution fallback:', err)
        }
      }

      // 5. Query matching restaurants in parallel for outlets section
      try {
        const restaurantMatches = await prisma.restaurant.findMany({
          where: {
            isActive: true,
            OR: [
              { name: { contains: normalizedQuery, mode: 'insensitive' } },
              { slug: { contains: normalizedQuery, mode: 'insensitive' } },
              { cuisineTags: { hasSome: searchTokens } },
            ]
          },
          take: 6,
        })
        restaurants = restaurantMatches || []
      } catch (err) {
        console.warn('[ProductSearchService] Restaurant search failed:', err)
      }

      // 6. Fetch full candidate product entities from Prisma with relations
      if (candidateIds.length > 0) {
        const whereClause: Prisma.ProductWhereInput = {
          id: { in: candidateIds },
          ...(!includeUnavailable && !isWorker ? { isAvailable: true } : {}),
        }

        if (restaurantId) {
          whereClause.restaurantId = restaurantId
        } else if (restaurantSlug) {
          whereClause.restaurant = { slug: restaurantSlug }
        } else if (excludeRestaurant) {
          whereClause.restaurantId = null
        }

        if (categoryId) {
          whereClause.categoryId = categoryId
        }

        const rawProducts = await prisma.product.findMany({
          where: whereClause,
          include: {
            category: true,
            restaurant: true,
          },
        })

        // 7. Calculate hybrid relevance scores combining ts_rank + semantic intent
        const scored = rawProducts.map(p => {
          const ftsRank = (rankMap.get(p.id) || 0) * 100
          const semanticScore = getSemanticAiScore(normalizedQuery, p)
          const pNameLower = (p.name || '').toLowerCase()
          
          // Specific noodles boosting
          let noodleBoost = 0
          const isNoodleQuery = ['maggi', 'maggie', 'magi', 'megi', 'noodle'].some(k => normalizedQuery.includes(k))
          if (isNoodleQuery) {
            if (pNameLower.includes('ketchup') || pNameLower.includes('sauce')) {
              noodleBoost = -40
            } else if (pNameLower.includes('instant noodles') || pNameLower.includes('maggi') || pNameLower.includes('noodle')) {
              noodleBoost = 50
            }
          }

          const finalScore = Math.max(ftsRank, semanticScore) + noodleBoost
          return { product: p, score: finalScore }
        })

        // Sort by final score
        scored.sort((a, b) => b.score - a.score)
        products = scored.map(s => s.product)
      }

      // Fallback: If still 0 products, try standard Prisma contains on tokens
      if (products.length === 0) {
        const fallbackWhere: Prisma.ProductWhereInput = {
          ...(!includeUnavailable && !isWorker ? { isAvailable: true } : {}),
          OR: searchTokens.map(w => ({
            OR: [
              { name: { contains: w, mode: 'insensitive' } },
              { tags: { has: w } },
              { category: { name: { contains: w, mode: 'insensitive' } } },
              { restaurant: { name: { contains: w, mode: 'insensitive' } } },
            ]
          }))
        }

        if (excludeRestaurant) {
          fallbackWhere.restaurantId = null
        }

        products = await prisma.product.findMany({
          where: fallbackWhere,
          include: {
            category: true,
            restaurant: true,
          },
          take: limit,
        }).catch(() => [])
      }

      total = products.length

      // Apply sort overrides
      if (sort === 'price-asc') {
        products.sort((a, b) => (a.price || 0) - (b.price || 0))
      } else if (sort === 'price-desc') {
        products.sort((a, b) => (b.price || 0) - (a.price || 0))
      } else if (sort === 'discount-desc') {
        products.sort((a, b) => (b.discount || 0) - (a.discount || 0))
      } else if (sort === 'name') {
        products.sort((a, b) => (a.name || '').localeCompare(b.name || ''))
      }

      // Memory pagination
      const skip = (page - 1) * limit
      products = products.slice(skip, skip + limit)
    } else {
      // Browsing without search query: standard database query
      const where: Prisma.ProductWhereInput = {
        ...(!includeUnavailable && !isWorker ? { isAvailable: true } : {}),
      }

      if (restaurantId) {
        where.restaurantId = restaurantId
      } else if (restaurantSlug) {
        where.restaurant = { slug: restaurantSlug }
      } else if (excludeRestaurant || (!includeRestaurants && !category && !categoryId)) {
        where.restaurantId = null
      }

      if (categoryId) {
        where.categoryId = categoryId
      }

      const [dbProducts, count] = await Promise.all([
        prisma.product.findMany({
          where,
          include: {
            category: true,
            restaurant: true,
          },
          orderBy: [
            { sortOrder: 'desc' },
            { createdAt: 'desc' }
          ],
          skip: (page - 1) * limit,
          take: limit,
        }),
        prisma.product.count({ where }),
      ])

      products = dbProducts
      total = count
    }

    // 8. Override stock & availability with localized dark store inventory
    if (activeStoreId && products.length > 0) {
      try {
        const inventories = await prisma.storeInventory.findMany({
          where: {
            storeId: activeStoreId,
            productId: { in: products.map(p => p.id) }
          }
        })
        const inventoryMap = new Map(inventories.map(inv => [inv.productId, inv.stock]))
        products = products.map(p => {
          const isRest = !!p.restaurantId
          const localStock = isRest ? p.stock : (inventoryMap.has(p.id) ? inventoryMap.get(p.id)! : p.stock)
          return {
            ...p,
            stock: localStock,
            isAvailable: isRest ? p.isAvailable : (p.isAvailable && localStock > 0)
          }
        })
      } catch (err) {
        console.warn('[ProductSearchService] Inventory override failed:', err)
      }
    }

    // 9. Zepto/Blinkit architecture: in-stock items sink first, out of stock items sink to bottom
    if (!isWorker && !includeUnavailable && products.length > 0) {
      products = sortProductsByStock(products)
    }

    return {
      products,
      restaurants,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit) || 1,
      }
    }
  }
}
