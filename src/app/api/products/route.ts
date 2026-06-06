import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { auth } from '@/auth'

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const category = searchParams.get('category')
    const search = searchParams.get('search')
    const sort = searchParams.get('sort')
    const page = parseInt(searchParams.get('page') || '1')
    const limit = parseInt(searchParams.get('limit') || '100') // default to larger limit for admin viewing
    const skip = (page - 1) * limit
    const includeUnavailable = searchParams.get('admin') === 'true'

    const where: Prisma.ProductWhereInput = {}

    // Only filter available products for regular users
    if (!includeUnavailable) {
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

    let products: any[] = []
    let total = 0

    if (search) {
      // 1. Fetch all products matching basic filters to perform fuzzy search in memory
      const allProducts = await prisma.product.findMany({
        where: {
          category: where.category,
          isAvailable: where.isAvailable,
        },
        include: {
          category: true,
        },
      })

      // 2. Score each product using the fuzzy text matcher
      const scoredProducts = allProducts.map((p) => {
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
      const [dbProducts, dbTotal] = await Promise.all([
        prisma.product.findMany({
          where,
          orderBy,
          skip,
          take: limit,
          include: {
            category: true,
          },
        }),
        prisma.product.count({ where }),
      ])
      products = dbProducts
      total = dbTotal
    }

    return NextResponse.json({
      products,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
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

export async function POST(request: Request) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const body = await request.json()
    const { name, description, imageUrl, categoryId, mrp, price, unit, stock, isAvailable, tags, minStock, expiryDate, costPrice } = body

    if (!name || !categoryId || mrp === undefined || price === undefined || !unit) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

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
        unit,
        stock: parseInt(stock) || 0,
        isAvailable: isAvailable !== undefined ? !!isAvailable : true,
        tags: Array.isArray(tags) ? tags : [],
        minStock: minStock !== undefined ? parseInt(minStock) : 10,
        expiryDate: expiryDate ? new Date(expiryDate) : null,
        costPrice: costPrice !== undefined ? parseFloat(costPrice) : 0,
      },
      include: {
        category: true,
      }
    })

    return NextResponse.json(product, { status: 201 })
  } catch (error: any) {
    console.error('Failed to create product:', error)
    return NextResponse.json({ error: 'Failed to create product' }, { status: 500 })
  }
}
