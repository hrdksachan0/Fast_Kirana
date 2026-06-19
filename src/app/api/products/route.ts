import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { auth } from '@/auth'
import { apiReadLimiter, apiWriteLimiter } from '@/lib/rate-limit'
import { revalidateStorefront } from '@/lib/revalidate'
import { getCachedSearch, setCachedSearch } from '@/lib/search-cache'

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
    const skip = (page - 1) * limit
    const includeUnavailable = searchParams.get('admin') === 'true'
    const trending = searchParams.get('trending') === 'true'

    let isAdmin = false
    if (includeUnavailable) {
      const session = await auth()
      isAdmin = session?.user?.role === 'ADMIN'
    }

    // Cache check for typo-tolerant searches
    const cacheKey = `search:${search || ''}:${category || ''}:${sort || ''}:${page}:${limit}:${isAdmin}`
    if (search) {
      const cached = getCachedSearch(cacheKey)
      if (cached) {
        return NextResponse.json(cached)
      }
    }

    const where: Prisma.ProductWhereInput = {}

    // Only filter available products for regular users
    if (!isAdmin) {
      where.isAvailable = true
    }

    if (category) {
      where.category = {
        slug: category,
      }
    }

    let orderBy: Prisma.ProductOrderByWithRelationInput = { createdAt: 'desc' }

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
      createdAt: true,
      updatedAt: true,
      category: {
        select: {
          id: true,
          name: true,
          slug: true,
          imageUrl: true,
          parentId: true,
          sortOrder: true,
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

    if (search) {
      // 1. Try to fetch matching products from database first (broad indexed filter)
      const queryOptions: any = {
        where: {
          category: where.category,
          isAvailable: where.isAvailable,
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { description: { contains: search, mode: 'insensitive' } },
          ],
        }
      }
      if (isAdmin) {
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
          take: 1000,
        }
        if (isAdmin) {
          fallbackOptions.include = { category: true }
        } else {
          fallbackOptions.select = productSelect
        }
        matchedProducts = await prisma.product.findMany(fallbackOptions)
      }

      // 2. Score each product using the fuzzy text matcher
      const scoredProducts = matchedProducts.map((p) => {
        const nameScore = getFuzzyScore(search, p.name)
        const tagScore = p.tags.some((t: string) => getFuzzyScore(search, t) > 60) ? 85 : 0
        const descScore = p.description ? getFuzzyScore(search, p.description) * 0.5 : 0
        const score = Math.max(nameScore, tagScore, descScore)
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
      products = matches.slice(skip, skip + limit).map((m) => m.product)
    } else {
      // Standard database query for normal non-search listings
      const queryOptions: any = {
        where,
        orderBy,
        skip,
        take: limit,
      }
      if (isAdmin) {
        queryOptions.include = { category: true }
      } else {
        queryOptions.select = productSelect
      }

      const [dbProducts, dbTotal] = await Promise.all([
        prisma.product.findMany(queryOptions),
        prisma.product.count({ where }),
      ])
      products = dbProducts
      total = dbTotal
    }

    const responseData = {
      products,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    }

    if (search) {
      setCachedSearch(cacheKey, responseData)
    }

    return NextResponse.json(responseData)
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

  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const body = await request.json()
    const { name, description, imageUrl, categoryId, mrp, price, unit, stock, isAvailable, tags, minStock, expiryDate, costPrice, variants, location, isFlashDeal, isTopPick, isBestSeller } = body

    if (!name || !categoryId || mrp === undefined || price === undefined) {
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

    const calculatedDiscount = mrp > price 
      ? Math.max(0, Math.round(((mrp - price) / mrp) * 100))
      : 0

    const product = await prisma.product.create({
      data: {
        name,
        slug: finalSlug,
        description,
        imageUrl: imageUrl || '📦',
        categoryId,
        mrp: parseFloat(mrp),
        price: parseFloat(price),
        discount: calculatedDiscount,
        unit: finalUnit,
        stock: parseInt(stock) || 0,
        isAvailable: isAvailable !== undefined ? !!isAvailable : true,
        tags: Array.isArray(tags) ? tags : [],
        variants: variants || null,
        minStock: minStock !== undefined ? parseInt(minStock) : 10,
        expiryDate: expiryDate ? new Date(expiryDate) : null,
        costPrice: costPrice !== undefined ? parseFloat(costPrice) : 0,
        location: location || null,
        isFlashDeal: isFlashDeal !== undefined ? !!isFlashDeal : false,
        isTopPick: isTopPick !== undefined ? !!isTopPick : false,
        isBestSeller: isBestSeller !== undefined ? !!isBestSeller : false,
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
