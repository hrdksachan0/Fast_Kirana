import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'
import { apiReadLimiter, apiWriteLimiter } from '@/lib/rate-limit'
import { ApiResponder } from '@/lib/api-response'
import { revalidateStorefront } from '@/lib/revalidate'
import { getCachedSearch, setCachedSearch } from '@/lib/search-cache'
import { OUTLET_AS_RESTAURANT_ID, OUTLET_WEDSON_ID } from '@/lib/constants'
import { getSemanticAiScore } from '@/lib/vector-search'

const SYNONYM_DICTIONARY: Record<string, string[]> = {
  'aalu': ['potato', 'aloo'],
  'aloo': ['potato', 'aalu'],
  'pyaz': ['onion', 'pyaj'],
  'pyaj': ['onion', 'pyaz'],
  'doodh': ['milk', 'dudh'],
  'dudh': ['milk', 'doodh'],
  'dahi': ['curd', 'yogurt'],
  'anda': ['egg', 'eggs'],
  'tamatar': ['tomato', 'tomatoes'],
  'makhan': ['butter'],
  'nimbu': ['lemon', 'lime'],
  'chai': ['tea'],
  'patti': ['tea'],
  'pani': ['water'],
  'chawal': ['rice'],
  'chini': ['sugar'],
  'namak': ['salt']
}

export async function GET(request: NextRequest) {
  const limited = await apiReadLimiter.check(request)
  if (limited) return limited

  try {
    const { searchParams } = new URL(request.url)
    const category = searchParams.get('category')
    const search = searchParams.get('search')
    const sort = searchParams.get('sort')
    const page = parseInt(searchParams.get('page') || '1')
    const limit = parseInt(searchParams.get('limit') || '100') // default to larger limit for admin viewing
    // Cursor-based pagination: client passes the last row's createdAt:id as "cursor" instead of a page number.
    // Falls back to standard offset on page 1 for backwards compatibility.
    const cursor = searchParams.get('cursor') as string | null
    const isNextPage = cursor !== null
    const page1 = !isNextPage && page <= 1

    const [cursorCreatedAt, cursorId] = cursor ? cursor.split(':') : [null, null]

    const hasCursor = Boolean(cursorCreatedAt && cursorId)
    const trending = searchParams.get('trending') === 'true'
    const storeId = searchParams.get('storeId')
    const restaurantId = searchParams.get('restaurantId')
    const restaurantSlug = searchParams.get('restaurantSlug')

    const session = await auth()
    const role = session?.user?.role
    const isWorker = role === 'ADMIN' || role === 'CHEF'

    // Normalize the search query so "Maggi", " maggi ", and "MAGGI" share the
    // same cache entry (and same Levenshtein comparison). Trim + lowercase +
    // collapse internal whitespace.
    const normalizedSearch = search ? search.trim().toLowerCase().replace(/\s+/g, ' ') : ''

    // Cache check for typo-tolerant searches
    const cacheKey = `search:${normalizedSearch}:${category || ''}:${sort || ''}:${page}:${limit}:${isWorker}:${restaurantId || ''}:${restaurantSlug || ''}`
    if (normalizedSearch) {
      const cached = getCachedSearch(cacheKey)
      if (cached) {
        return NextResponse.json(cached)
      }
    }

    const where: Prisma.ProductWhereInput = {}

    // Only filter available products for regular users unless includeUnavailable is requested
    const includeUnavailable = searchParams.get('admin') === 'true' || searchParams.get('includeUnavailable') === 'true'
    if (!isWorker && !includeUnavailable) {
      where.isAvailable = true
    }

    // Filter by restaurant — or exclude restaurant items for grocery context
    const excludeRestaurant = searchParams.get('excludeRestaurant') === 'true'
    if (restaurantId) {
      if (restaurantId === OUTLET_AS_RESTAURANT_ID || restaurantId === 'as-restaurant' || restaurantId === 'as-cafe') {
        where.OR = [
          { restaurantId: restaurantId },
          { restaurant: { slug: { in: ['as-restaurant', 'as-cafe'] } } },
          { tags: { hasSome: ['as-restaurant', 'as-cafe', 'as_restaurant', 'a.s restaurant', 'a.s. restaurant'] } }
        ]
      } else if (restaurantId === OUTLET_WEDSON_ID || restaurantId === 'wedson') {
        where.OR = [
          { restaurantId: restaurantId },
          { restaurant: { slug: { in: ['wedson', 'restaurant-kitchen'] } } },
          { tags: { hasSome: ['wedson', 'wedson-restaurant'] } }
        ]
      } else {
        where.restaurantId = restaurantId
      }
    } else if (restaurantSlug) {
      if (restaurantSlug === 'as-restaurant' || restaurantSlug === 'as-cafe') {
        where.OR = [
          { restaurant: { slug: { in: ['as-restaurant', 'as-cafe'] } } },
          { restaurantId: OUTLET_AS_RESTAURANT_ID },
          { tags: { hasSome: ['as-restaurant', 'as-cafe', 'as_restaurant', 'a.s restaurant', 'a.s. restaurant'] } }
        ]
      } else if (restaurantSlug === 'wedson' || restaurantSlug === 'restaurant-kitchen') {
        where.OR = [
          { restaurant: { slug: { in: ['wedson', 'restaurant-kitchen'] } } },
          { restaurantId: OUTLET_WEDSON_ID },
          { tags: { hasSome: ['wedson', 'wedson-restaurant'] } }
        ]
      } else {
        where.restaurant = { slug: restaurantSlug }
      }
    } else if (excludeRestaurant || (!isWorker && !includeUnavailable && !category)) {
      // In grocery context (no restaurant specified, no category override), exclude restaurant products
      // This prevents restaurant items from appearing in grocery search, home page, etc.
      where.restaurantId = null
    }

    if (category) {
      const slugs = category.split(',')
      const isCafeQuery = slugs.some(s => s === 'cafe' || s === 'fastkirana-cafe')
      const isRestaurantQuery = slugs.some(s => s === 'restaurant' || s === 'wedson-restaurant')

      if (isCafeQuery) {
        where.OR = [
          { category: { slug: { in: ['cafe', 'fastkirana-cafe', 'hot-beverages', 'cold-beverages', 'drinks', 'shakes', 'mocktails', 'sandwiches', 'burgers', 'pizza', 'rolls', 'chinese', 'pasta', 'snacks', 'desserts', 'bakery', 'south-indian', 'fast-food', 'quick-bites', 'coffee', 'tea'] } } },
          { tags: { hasSome: ['cafe', 'fastkirana-cafe', 'hot-beverage', 'hot-bite', 'sandwiches', 'frankie-rolls', 'chinese', 'italian-pasta', 'bombay-bites', 'rice-dishes', 'shakes', 'mocktails', 'cold-coffee', 'south-indian', 'chilled', 'bakery', 'pizza', 'burgers', 'garlic-bread', 'desserts', 'tea', 'coffee', 'food'] } },
        ]
      } else if (isRestaurantQuery) {
        where.OR = [
          { restaurantId: { not: null } },
          { category: { slug: { in: ['restaurant', 'wedson-restaurant', 'thali', 'biryani', 'north-indian', 'main-course', 'roti-naan', 'chinese', 'combos', 'curry'] } } },
          { tags: { hasSome: ['restaurant', 'wedson-restaurant', 'thali', 'biryani', 'north-indian', 'south-indian', 'chinese', 'main-course', 'combos', 'roti-naan-kulcha', 'biryani-rice'] } },
        ]
      } else {
        where.category = {
          slug: {
            in: slugs,
          },
        }
        if (!restaurantId && !restaurantSlug) {
          where.restaurantId = null
          where.NOT = [
            { tags: { hasSome: ['restaurant', 'as-restaurant', 'as_restaurant', 'wedson'] } }
          ]
        }
      }
    }

    let orderBy: any = [
      { sortOrder: 'desc' },
      { createdAt: 'desc' }
    ]

    // Check database for category-specific auto-sorting rule
    if (category && !category.includes(',')) {
      try {
        const sortSetting = await prisma.storeSetting.findUnique({
          where: { key: `category_sort_${category}` }
        })
        if (sortSetting && sortSetting.value !== 'manual') {
          const rule = sortSetting.value
          if (rule === 'best-seller') {
            orderBy = [
              { isBestSeller: 'desc' },
              { sortOrder: 'desc' },
              { createdAt: 'desc' }
            ]
          } else if (rule === 'stock-desc') {
            orderBy = [
              { stock: 'desc' },
              { sortOrder: 'desc' },
              { createdAt: 'desc' }
            ]
          } else if (rule === 'price-asc') {
            orderBy = [
              { price: 'asc' },
              { sortOrder: 'desc' }
            ]
          } else if (rule === 'price-desc') {
            orderBy = [
              { price: 'desc' },
              { sortOrder: 'desc' }
            ]
          } else if (rule === 'newest') {
            orderBy = [
              { createdAt: 'desc' }
            ]
          }
        }
      } catch (err) {
        console.warn('Failed to fetch category sort rule settings:', err)
      }
    }

    if (sort === 'price-asc') {
      orderBy = { price: 'asc' }
    } else if (sort === 'price-desc') {
      orderBy = { price: 'desc' }
    } else if (sort === 'discount-desc') {
      orderBy = { discount: 'desc' }
    }

    const productSelect = {
      id: true,
      name: true,
      slug: true,
      description: true,
      imageUrl: true,
      categoryId: true,
      mrp: true,
      price: true,
      discount: true,
      unit: true,
      stock: true,
      isAvailable: true,
      tags: true,
      variants: true,
      minStock: true,
      expiryDate: true,
      isFlashDeal: true,
      isTopPick: true,
      isBestSeller: true,
      sortOrder: true,
      createdAt: true,
      updatedAt: true,
      restaurantId: true,
      category: {
        select: {
          id: true,
          name: true,
          slug: true,
          imageUrl: true,
          parentId: true,
          sortOrder: true,
        }
      },
      restaurant: {
        select: {
          id: true,
          name: true,
          slug: true,
          logoUrl: true,
          bannerUrl: true,
          rating: true,
          deliveryTime: true,
          isOpen: true,
        }
      }
    }

    if (trending) {
      let trendingOrderItems: any[] = []
      try {
        trendingOrderItems = await (prisma.orderItem.groupBy as any)({
          by: ['productId'],
          _sum: {
            quantity: true,
          },
          orderBy: {
            _sum: {
              quantity: 'desc',
            },
          },
          take: 12,
        })
      } catch (err) {
        console.warn('Failed to fetch trending order items in API:', err)
      }

      const trendingProductIds = trendingOrderItems
        .map((item) => item.productId)
        .filter((id): id is string => id !== null)

      const whereClause: Prisma.ProductWhereInput = {
        isAvailable: true,
        NOT: [
          { tags: { has: 'cafe' } },
          { category: { slug: 'cafe' } }
        ]
      }

      const featuredProducts = await prisma.product.findMany({
        where: {
          ...whereClause,
          OR: [
            { isTopPick: true },
            { isBestSeller: true },
            { id: { in: trendingProductIds } }
          ]
        },
        select: productSelect,
        take: 12
      })

      let finalProducts = [...featuredProducts]

      if (finalProducts.length < 8) {
        const existingIds = finalProducts.map(p => p.id)
        const popularProducts = await prisma.product.findMany({
          where: {
            ...whereClause,
            tags: { has: 'popular' },
            id: { notIn: existingIds }
          },
          select: productSelect,
          take: 8 - finalProducts.length
        })
        finalProducts = [...finalProducts, ...popularProducts]
      }

      if (finalProducts.length < 8) {
        const existingIds = finalProducts.map(p => p.id)
        const anyProducts = await prisma.product.findMany({
          where: {
            ...whereClause,
            id: { notIn: existingIds }
          },
          select: productSelect,
          take: 8 - finalProducts.length
        })
        finalProducts = [...finalProducts, ...anyProducts]
      }

      return NextResponse.json({
        products: finalProducts.slice(0, 8),
        pagination: {
          total: finalProducts.length,
          page: 1,
          limit: 8,
          totalPages: 1
        }
      })
    }

    let products: any[] = []
    let total = 0
    let nextCursor: string | null = null
    if (normalizedSearch) {
      // 1. Split query into tokens, expand with synonyms, and build an intersection query
      const searchWords = normalizedSearch.split(/\s+/)
      const wordClauses = searchWords.map(w => {
        const syns = SYNONYM_DICTIONARY[w] || []
        const wordOptions = [w, ...syns]
        
        return {
          OR: wordOptions.flatMap(opt => [
            { name: { contains: opt, mode: 'insensitive' } },
            { description: { contains: opt, mode: 'insensitive' } },
            { tags: { has: opt } }
          ])
        }
      })

      const queryOptions: any = {
        where: {
          category: where.category,
          isAvailable: where.isAvailable,
          AND: wordClauses
        }
      }
      if (isWorker) {
        queryOptions.include = { category: true }
      } else {
        queryOptions.select = productSelect
      }

      let matchedProducts = await prisma.product.findMany(queryOptions)

      // If no direct database matches are found, fallback to fetching all products to perform typo-tolerant fuzzy search
      if (matchedProducts.length === 0) {
        const fallbackOptions: any = {
          where: {
            category: where.category,
            isAvailable: where.isAvailable,
          },
          take: 500,
        }
        if (isWorker) {
          fallbackOptions.include = { category: true }
        } else {
          fallbackOptions.select = productSelect
        }
        matchedProducts = await prisma.product.findMany(fallbackOptions)
      }

      // 2. Score each product using the fuzzy text matcher & Supabase Semantic AI engine
      const scoredProducts = matchedProducts.map((p) => {
        const nameScore = getFuzzyScore(normalizedSearch, p.name)
        const tagScore = p.tags.some((t: string) => getFuzzyScore(normalizedSearch, t) > 60) ? 85 : 0
        const descScore = p.description ? getFuzzyScore(normalizedSearch, p.description) * 0.5 : 0
        const semanticAiScore = getSemanticAiScore(normalizedSearch, p)
        const score = Math.max(nameScore, tagScore, descScore, semanticAiScore)
        return { product: p, score }
      })

      // 3. Filter products with acceptable match similarity (> 35) and sort by score
      const matches = scoredProducts
        .filter((item) => item.score > 35)
        .sort((a, b) => b.score - a.score)

      total = matches.length

      // Apply sort overrides if requested
      if (sort === 'price-asc') {
        matches.sort((a, b) => a.product.price - b.product.price)
      } else if (sort === 'price-desc') {
        matches.sort((a, b) => b.product.price - a.product.price)
      } else if (sort === 'discount-desc') {
        matches.sort((a, b) => b.product.discount - a.product.discount)
      }

      // 4. Paginate in memory
      const memorySkip = (page - 1) * limit
      products = matches.slice(memorySkip, memorySkip + limit).map((m) => m.product)
    } else {
      // Standard database query for normal non-search listings.
      // For page 1, we still skip/limit for client compatibility; deeper pages
      // should pass `cursor=createdAt:id` of the last row, which keeps the query
      // O(limit) regardless of dataset size.
      const stableOrderBy = Array.isArray(orderBy)
        ? [...orderBy, { createdAt: 'desc' }, { id: 'desc' }]
        : [orderBy, { createdAt: 'desc' }, { id: 'desc' }]

      const queryOptions: any = {
        where,
        orderBy: stableOrderBy,
        take: limit + 1,
      }

      // Cursor pagination takes precedence over skip when supplied.
      if (hasCursor) {
        queryOptions.cursor = { id: cursorId }
        queryOptions.skip = 1 // skip the cursor row itself
        queryOptions.where = {
          ...where,
          OR: [
            { createdAt: { lt: new Date(cursorCreatedAt!) } },
            {
              createdAt: new Date(cursorCreatedAt!),
              id: { lt: cursorId! },
            },
          ],
        }
      } else if (page1) {
        queryOptions.skip = 0
      } else {
        // Backwards-compat: legacy callers passing ?page=N keep offset behavior.
        queryOptions.skip = (page - 1) * limit
      }

      if (isWorker) {
        queryOptions.include = { category: true }
      } else {
        queryOptions.select = productSelect
      }

      const dbProducts = await prisma.product.findMany(queryOptions)
      const hasMore = dbProducts.length > limit
      products = hasMore ? dbProducts.slice(0, limit) : dbProducts
      // Cursor mode avoids a count(*) over the full table.
      total = hasCursor ? -1 : await prisma.product.count({ where })
      if (hasCursor && hasMore) {
        const last = products[products.length - 1]
        nextCursor = `${(last as any).createdAt.toISOString()}:${last.id}`
      }
    }

    // Override stock and availability with localized dark store inventory
    if (storeId && products.length > 0) {
      const inventories = await prisma.storeInventory.findMany({
        where: {
          storeId,
          productId: { in: products.map(p => p.id) }
        }
      })
      const inventoryMap = new Map(inventories.map(inv => [inv.productId, inv.stock]))
      products = products.map(p => {
        const localStock = inventoryMap.get(p.id) ?? 0
        return {
          ...p,
          stock: localStock,
          isAvailable: p.isAvailable && localStock > 0
        }
      })
    }

    const responseData = {
      products,
      pagination: {
        total: total === -1 ? null : total,
        page,
        limit,
        totalPages: total === -1 ? null : Math.ceil(total / limit),
        nextCursor,
      },
    }

    if (normalizedSearch && !isWorker && !includeUnavailable) {
      setCachedSearch(cacheKey, responseData)
    }

    const isCacheable = !isWorker && !includeUnavailable
    return NextResponse.json(responseData, {
      headers: {
        'Cache-Control': isCacheable
          ? 'public, s-maxage=15, stale-while-revalidate=30'
          : 'no-store, max-age=0, must-revalidate',
      }
    })
  } catch (error: any) {
    console.error('Products API Error:', error)
    return NextResponse.json({ error: 'Failed to fetch products' }, { status: 500 })
  }
}

// Levenshtein distance string matching algorithm
function getLevenshteinDistance(a: string, b: string): number {
  const tmp: number[][] = []
  let i: number, j: number
  for (i = 0; i <= a.length; i++) {
    tmp.push([i])
  }
  for (j = 1; j <= b.length; j++) {
    tmp[0].push(j)
  }
  for (i = 1; i <= a.length; i++) {
    for (j = 1; j <= b.length; j++) {
      tmp[i][j] = Math.min(
        tmp[i - 1][j] + 1,
        tmp[i][j - 1] + 1,
        tmp[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1)
      )
    }
  }
  return tmp[a.length][b.length]
}

// Fuzzy matching text similarity score utility (0 to 100)
function getFuzzyScore(query: string, target: string): number {
  const q = query.toLowerCase().trim()
  const t = target.toLowerCase().trim()

  if (t.includes(q)) return 100 // exact substring matches get highest priority

  const qWords = q.split(/\s+/)
  const tWords = t.split(/\s+/)

  let totalScore = 0
  for (const qw of qWords) {
    let bestWordScore = 0
    for (const tw of tWords) {
      if (tw === qw) {
        bestWordScore = Math.max(bestWordScore, 90)
      } else if (tw.includes(qw) || qw.includes(tw)) {
        bestWordScore = Math.max(bestWordScore, 70)
      } else {
        const dist = getLevenshteinDistance(qw, tw)
        const maxLen = Math.max(qw.length, tw.length)
        if (maxLen > 0) {
          const sim = 1 - dist / maxLen
          if (sim > 0.5) {
            bestWordScore = Math.max(bestWordScore, Math.round(sim * 80))
          }
        }
      }
    }
    totalScore += bestWordScore
  }

  return totalScore / qWords.length
}

export async function POST(request: NextRequest) {
  const limited = await apiWriteLimiter.check(request)
  if (limited) return limited

  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const body = await request.json()
    const { name, description, imageUrl, categoryId, restaurantId, mrp, price, unit, stock, isAvailable, tags, minStock, expiryDate, costPrice, variants, location, isFlashDeal, isTopPick, isBestSeller, sortOrder, barcode } = body

    let finalCategoryId = categoryId
    let tagsList = Array.isArray(tags) 
      ? tags.map((t: any) => String(t).trim()).filter((t: string) => t.length > 0)
      : (typeof tags === 'string' ? tags.split(',').map((t: string) => t.trim()).filter((t: string) => t.length > 0) : [])

    // ── Restaurant product hardening ──
    // When restaurantId is present, ALWAYS force restaurant category, tags, and unlimited stock
    if (restaurantId) {
      let restCat = await prisma.category.findFirst({ where: { slug: 'restaurant' } })
      if (!restCat) {
        restCat = await prisma.category.create({
          data: { name: 'FastKirana Restaurant', slug: 'restaurant', imageUrl: '🍽️', sortOrder: 10 }
        })
      }
      finalCategoryId = restCat.id

      // Ensure 'restaurant' tag is present
      if (!tagsList.map(t => t.toLowerCase()).includes('restaurant')) {
        tagsList.push('restaurant')
      }
      // Remove 'cafe' tag to prevent cross-contamination
      tagsList = tagsList.filter(t => t.toLowerCase() !== 'cafe')
    } else if (!finalCategoryId || finalCategoryId === '') {
      const lowerTags = tagsList.map(t => t.toLowerCase())
      if (lowerTags.includes('restaurant')) {
        let restCat = await prisma.category.findFirst({ where: { slug: 'restaurant' } })
        if (!restCat) {
          restCat = await prisma.category.create({
            data: { name: 'FastKirana Restaurant', slug: 'restaurant', imageUrl: '🍽️', sortOrder: 10 }
          })
        }
        finalCategoryId = restCat.id
      } else if (lowerTags.includes('cafe')) {
        let cafeCat = await prisma.category.findFirst({ where: { slug: { in: ['cafe', 'fastkirana-cafe'] } } })
        if (!cafeCat) {
          cafeCat = await prisma.category.create({
            data: { name: 'FastKirana Cafe', slug: 'cafe', imageUrl: '☕', sortOrder: 11 }
          })
        }
        finalCategoryId = cafeCat.id
      }
    }

    if (!name || !finalCategoryId || mrp === undefined || price === undefined) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    const finalUnit = (unit && typeof unit === 'string') ? unit.trim() : ''

    // Generate slug from name
    const slug = name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)+/g, '')

    // Check slug uniqueness
    const existing = await prisma.product.findUnique({
      where: { slug }
    })

    let finalSlug = slug
    if (existing) {
      finalSlug = `${slug}-${Date.now().toString().slice(-4)}`
    }

    let finalMrp = parseFloat(mrp)
    let finalPrice = parseFloat(price)
    let sortedVariants = variants

    if (variants && Array.isArray(variants) && variants.length > 0) {
      sortedVariants = [...variants].sort((a: any, b: any) => (parseFloat(a.price) || 0) - (parseFloat(b.price) || 0))
      finalPrice = parseFloat(sortedVariants[0].price) || 0
      finalMrp = parseFloat(sortedVariants[0].mrp) || finalPrice
    }

    const calculatedDiscount = finalMrp > finalPrice 
      ? Math.max(0, Math.round(((finalMrp - finalPrice) / finalMrp) * 100))
      : 0

    // Find highest readableId to increment
    const lastProduct = await prisma.product.findFirst({
      orderBy: { readableId: 'desc' },
      select: { readableId: true }
    })
    const nextReadableId = lastProduct && lastProduct.readableId 
      ? lastProduct.readableId + 1 
      : 200001

    const product = await prisma.product.create({
      data: {
        name,
        readableId: nextReadableId,
        slug: finalSlug,
        description,
        imageUrl: imageUrl || '📦',
        categoryId: finalCategoryId,
        restaurantId: restaurantId || null,
        mrp: finalMrp,
        price: finalPrice,
        discount: calculatedDiscount,
        unit: finalUnit,
        stock: restaurantId ? 999 : (parseInt(stock) || 0),
        isAvailable: isAvailable !== undefined ? !!isAvailable : true,
        tags: tagsList,
        variants: sortedVariants || null,
        minStock: minStock !== undefined ? parseInt(minStock) : 10,
        expiryDate: expiryDate ? new Date(expiryDate) : null,
        costPrice: costPrice !== undefined ? parseFloat(costPrice) : 0,
        location: location || null,
        isFlashDeal: isFlashDeal !== undefined ? !!isFlashDeal : false,
        isTopPick: isTopPick !== undefined ? !!isTopPick : false,
        isBestSeller: isBestSeller !== undefined ? !!isBestSeller : false,
        sortOrder: sortOrder !== undefined ? parseInt(sortOrder) || 0 : 0,
        barcode: barcode && typeof barcode === 'string' ? barcode.trim() : null,
      },
      include: {
        category: true,
      }
    })

    // Invalidate storefront caches on-demand
    revalidateStorefront(product.category?.slug)

    return NextResponse.json(product, { status: 201 })
  } catch (error: any) {
    console.error('Failed to create product:', error)
    return NextResponse.json({ error: 'Failed to create product' }, { status: 500 })
  }
}
