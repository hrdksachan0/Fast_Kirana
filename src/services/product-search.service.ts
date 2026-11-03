import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { SYNONYM_DICTIONARY, normalizeSearchQuery } from '@/lib/synonyms'
import { getSemanticAiScore } from '@/lib/vector-search'
import { sortProductsByStock } from '@/lib/utils'
import { getGeminiQueryEmbedding } from '@/lib/gemini-embedding'
import { shouldParseIntent, parseQueryIntentWithGemini, ParsedSearchIntent } from '@/lib/gemini-intent'

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

      // 1.1 Gemini AI Conversational Intent & Mood Parser (Superpowers 1, 3, 4)
      let parsedIntent: ParsedSearchIntent | null = null
      if (shouldParseIntent(normalizedQuery)) {
        try {
          parsedIntent = await parseQueryIntentWithGemini(normalizedQuery)
          if (parsedIntent && parsedIntent.search_terms && parsedIntent.search_terms.length > 0) {
            for (const term of parsedIntent.search_terms) {
              for (const tw of term.toLowerCase().split(/\s+/)) {
                if (tw.length >= 2 && !STOP_WORDS.has(tw) && !searchTokens.includes(tw)) {
                  searchTokens.push(tw)
                }
              }
            }
          }
        } catch (intentErr) {
          console.warn('[ProductSearchService] Intent parser fallback:', intentErr)
        }
      }

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

      // Restaurant search detection
      const isAsQuery = normalizedQuery === 'as' || normalizedQuery.startsWith('as ') || normalizedQuery.includes('as restaurant') || normalizedQuery.includes('a.s')
      const matchedRestIds = new Set<string>()
      if (isAsQuery) matchedRestIds.add('REST-101')
      // Only match distinctive restaurant brand names (never trigger on generic substrings like "hot", "hotel", "bal")
      if (normalizedQuery.includes('wedson')) {
        matchedRestIds.add('REST-102')
      }
      if (normalizedQuery.includes('bal udyan') || (searchTokens.includes('bal') && searchTokens.includes('udyan'))) {
        matchedRestIds.add('REST-103')
      }
      if (normalizedQuery.includes('hot pizza') || (searchTokens.includes('pizza') && searchTokens.includes('lovers'))) {
        matchedRestIds.add('REST-104')
      }
      if (normalizedQuery.includes('zayka')) {
        matchedRestIds.add('REST-105')
      }
      const isRestaurantSearch = matchedRestIds.size > 0 || searchTokens.some(w => ['restaurant', 'cafe', 'dhaba', 'kitchen', 'hotel'].includes(w))

      // 2.5 Supabase PgVector Semantic AI Search (Option 1 + 3)
      let candidateIds: string[] = []
      let rankMap = new Map<string, number>()
      let vectorMap = new Map<string, number>()

      // If restaurant explicitly searched, pull its entire menu
      if (matchedRestIds.size > 0) {
        try {
          const restRows: any[] = await prisma.$queryRawUnsafe(`
            SELECT p.id
            FROM products p
            WHERE ${includeUnavailable ? 'TRUE' : 'p."isAvailable" = TRUE'}
              AND p."restaurantId" = ANY($1::text[])
            LIMIT 100;
          `, Array.from(matchedRestIds))
          restRows.forEach(r => candidateIds.push(r.id))
        } catch (rErr) {
          console.warn('[ProductSearchService] Restaurant candidate fetch error:', rErr)
        }
      }

      if (normalizedQuery.length >= 2) {
        try {
          const queryEmbedding = await getGeminiQueryEmbedding(normalizedQuery)
          if (queryEmbedding && queryEmbedding.length === 768) {
            const embStr = `[${queryEmbedding.map(v => v.toFixed(6)).join(',')}]`
            const vectorRows: any[] = await prisma.$queryRawUnsafe(`
              SELECT p.id, (1 - (p.embedding <=> $1::vector)) as sim
              FROM products p
              WHERE ${includeUnavailable ? 'TRUE' : 'p."isAvailable" = TRUE'}
                AND p.embedding IS NOT NULL
                AND (1 - (p.embedding <=> $1::vector)) > 0.38
              ORDER BY sim DESC
              LIMIT 60;
            `, embStr)

            if (vectorRows && vectorRows.length > 0) {
              vectorRows.forEach(r => {
                const sim = Number(r.sim) || 0
                candidateIds.push(r.id)
                vectorMap.set(r.id, sim)
              })
            }
          }
        } catch (vecErr) {
          console.warn('[ProductSearchService] PgVector search fallback:', vecErr)
        }
      }

      // 3. Find candidate product IDs using PostgreSQL Full Text Search (Fallback & Multi-word Token Search)

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

          // Also pull broader OR candidates for multi-word queries so similar dishes (e.g. other Biryanis) rank right below exact match
          if (tokenGroups.length > 1) {
            const orTsquery = tokenGroups.join(' | ')
            const orRows: any[] = await prisma.$queryRaw`
              SELECT p.id, ts_rank(p.search_vector, to_tsquery('english', ${orTsquery})) as rank
              FROM products p
              WHERE ${includeUnavailable ? Prisma.sql`TRUE` : Prisma.sql`p."isAvailable" = TRUE`}
                AND p.search_vector @@ to_tsquery('english', ${orTsquery})
              ORDER BY rank DESC
              LIMIT 60;
            `
            orRows.forEach(r => {
              if (!rankMap.has(r.id)) {
                candidateIds.push(r.id)
                rankMap.set(r.id, (Number(r.rank) || 0) * 0.5)
              }
            })
          }
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

        // 7. Calculate universal hybrid relevance scores combining ts_rank + semantic intent
        const COOKED_MEAL_KEYWORDS = new Set([
          'biryani', 'chicken', 'paneer', 'mutton', 'dal', 'curry', 'gravy',
          'pasta', 'chole', 'rajma', 'sabzi', 'kadhai', 'handi', 'fish', 'egg'
        ])
        const isMealSearch = searchTokens.some(w => COOKED_MEAL_KEYWORDS.has(w))

        const scored = rawProducts.map(p => {
          const vectorSim = vectorMap.get(p.id) || 0
          const ftsRank = (rankMap.get(p.id) || 0) * 100
          const semanticScore = getSemanticAiScore(normalizedQuery, p)
          const pNameLower = (p.name || '').toLowerCase().trim()
          const pWords = new Set(pNameLower.split(/\s+/).filter(Boolean))
          const pTags = (p.tags || []).map((t: string) => t.toLowerCase().trim())
          const catSlug = (p.category?.slug || '').toLowerCase().trim()
          const pDesc = (p.description || '').toLowerCase().trim()
          const isFromTargetRestaurant = Boolean(p.restaurantId && matchedRestIds.has(p.restaurantId))

          // Short tokens (<= 2 chars, e.g. "as") MUST be whole-word matches to prevent polluting words like "Namaste" or "Masala".
          // Tokens length >= 3 match exact word OR words starting with token (e.g. "hal" -> "Haldiram", "Haldi", "Haldwani")
          const matchingTitleWords = searchTokens.filter(w => {
            if (w.length <= 2) return pWords.has(w)
            return pWords.has(w) || Array.from(pWords).some(pw => pw.startsWith(w))
          })
          const matchingTagWords = searchTokens.filter(w => {
            if (w.length <= 2) return pTags.includes(w)
            return pTags.some((t: string) => t === w || t.startsWith(w))
          })
          const matchingDesc = searchTokens.some(w => w.length > 3 && pDesc.includes(w))

          // Superpower 4: Strict Veg vs Non-Veg AI Filter
          if (parsedIntent) {
            const isNonVeg = ['chicken', 'mutton', 'egg', 'fish', 'meat', 'non-veg', 'nonveg'].some(k => pNameLower.includes(k) || pTags.some(t => t.includes(k)))
            if (parsedIntent.dietary === 'veg' && isNonVeg) {
              return { product: p, score: 0 } // Strictly discard non-veg on veg intent!
            }
          }

          // ── UNIVERSAL EXCLUSION GUARD (Applied to EVERY product in the store) ──
          // If user specifically searched for a restaurant brand, discard products from other outlets/retail
          if (isRestaurantSearch && matchedRestIds.size > 0 && !isFromTargetRestaurant && pNameLower !== normalizedQuery) {
            return { product: p, score: 0 }
          }

          // Cleanliness Guard: If candidate has no token match in title, tags, or description,
          // only retain it if it has very high semantic similarity (>= 0.60) or parsed conversational intent.
          // Never allow weak vector matches (0.38 - 0.55) to pollute keyword searches!
          const hasTextMatch = matchingTitleWords.length > 0 || matchingTagWords.length > 0 || matchingDesc
          if (!isFromTargetRestaurant && !hasTextMatch && vectorSim < 0.60 && !parsedIntent) {
            return { product: p, score: 0 }
          }

          let tierScore = 0
          const hasAllWordsInTitle = searchTokens.length > 1 && searchTokens.every(w => pWords.has(w) || pNameLower.includes(w))

          // Strict Dish Exclusion Guard (e.g. "momos", "burger", "pizza", "roll", "sandwich", "dosa", "chowmein", "pavbhaji")
          const DISH_EXCLUSIVE_KEYWORDS = ['momo', 'momos', 'burger', 'burgers', 'pizza', 'pizzas', 'sandwich', 'sandwiches', 'roll', 'rolls', 'dosa', 'dosas', 'chowmein', 'pavbhaji', 'pav bhaji']
          const searchedDishKeyword = searchTokens.find(w => DISH_EXCLUSIVE_KEYWORDS.some(dk => w === dk || w.startsWith(dk)))
          if (searchedDishKeyword) {
            const rootWord = searchedDishKeyword.slice(0, 4)
            if (!pNameLower.includes(rootWord) && !pTags.some((t: string) => t.includes(rootWord))) {
              return { product: p, score: 0 } // Completely discard items like Spring Roll / Fries when Momos is searched!
            }
          }

          // ── TIER 1: EXACT & DIRECT TITLE MATCH (10,000+) ──
          if (pNameLower === normalizedQuery) {
            tierScore = 20000 // Absolute #1 exact match (e.g. "Chilli Paneer")
          } else if (hasAllWordsInTitle) {
            tierScore = 15000 // Contains all multi-words in title (e.g. "Chilli Paneer Dry")
          } else if (pNameLower.startsWith(normalizedQuery + ' ') || pNameLower.startsWith(normalizedQuery)) {
            tierScore = 12000
          } else if (pNameLower.includes(' ' + normalizedQuery + ' ') || pNameLower.endsWith(' ' + normalizedQuery) || Array.from(pWords).some(pw => pw.startsWith(normalizedQuery))) {
            tierScore = 9000
          } else if (isFromTargetRestaurant) {
            tierScore = 7000 // Restaurant menu boost when restaurant was explicitly queried
          } else if (vectorSim >= 0.65) {
            // TIER 2: HIGH AI SEMANTIC MATCH
            tierScore = Math.round(vectorSim * 4000)
          } else if (matchingTitleWords.length > 0) {
            tierScore = matchingTitleWords.length * 1500
          } else if (vectorSim >= 0.60) {
            tierScore = Math.round(vectorSim * 2000)
          } else if (matchingTagWords.length > 0) {
            tierScore = 300
          } else if (matchingDesc) {
            tierScore = 150
          }

          // ── TIER 3: CONTEXT-AWARE DEMOTIONS & COOKED DISH BOOST ──
          // 1. Prepared Meal vs Raw Spice Packets & Raw Grocery (e.g. searching "Chicken Biryani" shouldn't rank Everest Masala on top; "Chilli Paneer" shouldn't rank raw dairy paneer block on top)
          if (isMealSearch) {
            if (catSlug.includes('spices') || catSlug.includes('masala') || pNameLower.includes('masala') || catSlug.includes('milk') || catSlug.includes('dairy')) {
              if (!normalizedQuery.includes('masala') && !normalizedQuery.includes('milk') && !normalizedQuery.includes('doodh') && !normalizedQuery.includes('dairy')) {
                tierScore = Math.min(tierScore, 400) // Demote raw spices/dairy below cooked meals!
              }
            } else if (p.restaurantId) {
              tierScore += 2500 // Prepared cooked dishes rank above raw groceries!
            }
          }

          // 2. Noodles vs Ketchup/Sauce (e.g. searching "Maggi" shouldn't rank Maggi Sauce above Maggi Noodles)
          if (searchTokens.some(w => ['maggi', 'maggie', 'noodle', 'noodles'].includes(w))) {
            if (catSlug.includes('sauce') || pNameLower.includes('ketchup') || pNameLower.includes('sauce')) {
              tierScore = Math.min(tierScore, 300)
            }
          }

          const finalScore = tierScore + Math.round(vectorSim * 1000) + Math.max(ftsRank, semanticScore) + (p.stock > 0 ? 50 : 0)
          return { product: p, score: finalScore }
        }).filter(item => item.score > 0)

        // Sort by final score descending
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
