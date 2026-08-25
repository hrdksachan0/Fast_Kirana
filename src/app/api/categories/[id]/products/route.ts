import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getCache, setCache } from '@/lib/search-cache'

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const { searchParams } = new URL(request.url)

    const page = Math.max(1, parseInt(searchParams.get('page') || '1', 10))
    const limit = Math.min(100, Math.max(1, parseInt(searchParams.get('limit') || '30', 10)))
    const sort = searchParams.get('sort') || 'default'
    const search = searchParams.get('search')?.trim().toLowerCase() || ''
    const skip = (page - 1) * limit

    const cacheKey = `category_products:${id}:${page}:${limit}:${sort}:${search}`
    const cached = await getCache(cacheKey)
    if (cached) {
      return NextResponse.json(cached)
    }

    // 1. Find category by ID or Slug
    const category = await prisma.category.findFirst({
      where: {
        OR: [
          { id },
          { slug: id }
        ]
      },
      select: {
        id: true,
        name: true,
        slug: true,
        imageUrl: true,
        parentId: true,
        sortOrder: true
      }
    })

    if (!category) {
      return NextResponse.json({ error: 'Category not found' }, { status: 404 })
    }

    // 2. Build Where Query
    const where: any = {
      categoryId: category.id,
      restaurantId: null, // Grocery products only
      isAvailable: true
    }

    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { description: { contains: search, mode: 'insensitive' } },
        { tags: { has: search } }
      ]
    }

    // 3. Build Sorting
    let orderBy: any = [{ sortOrder: 'desc' }, { createdAt: 'desc' }]
    if (sort === 'price-asc') {
      orderBy = [{ price: 'asc' }, { sortOrder: 'desc' }]
    } else if (sort === 'price-desc') {
      orderBy = [{ price: 'desc' }, { sortOrder: 'desc' }]
    } else if (sort === 'discount') {
      orderBy = [{ discount: 'desc' }, { sortOrder: 'desc' }]
    } else if (sort === 'newest') {
      orderBy = [{ createdAt: 'desc' }]
    } else if (sort === 'popular') {
      orderBy = [{ isBestSeller: 'desc' }, { sortOrder: 'desc' }]
    }

    // 4. Fetch Products & Count
    const [products, totalCount] = await Promise.all([
      prisma.product.findMany({
        where,
        include: {
          category: { select: { id: true, name: true, slug: true } },
          images: { select: { id: true, url: true, sortOrder: true } }
        },
        orderBy,
        skip,
        take: limit
      }),
      prisma.product.count({ where })
    ])

    const totalPages = Math.ceil(totalCount / limit)

    const responsePayload = {
      success: true,
      category,
      pagination: {
        totalItems: totalCount,
        totalPages,
        currentPage: page,
        limit,
        hasNextPage: page < totalPages,
        hasPrevPage: page > 1
      },
      products
    }

    // Cache for 60 seconds
    await setCache(cacheKey, responsePayload, 60)

    return NextResponse.json(responsePayload)
  } catch (error: any) {
    console.error('Error fetching category products by ID:', error)
    return NextResponse.json(
      { error: error?.message || 'Failed to fetch category products' },
      { status: 500 }
    )
  }
}
