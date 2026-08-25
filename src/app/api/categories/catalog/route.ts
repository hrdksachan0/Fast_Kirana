import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getCache, setCache } from '@/lib/search-cache'

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const includeProducts = searchParams.get('includeProducts') === 'true'
    const limitPerCat = parseInt(searchParams.get('limitPerCat') || '8', 10)

    const cacheKey = `grocery_categories_catalog:${includeProducts}:${limitPerCat}`
    const cached = await getCache(cacheKey)
    if (cached) {
      return NextResponse.json(cached)
    }

    // 1. Fetch All Grocery Categories (excluding restaurant food category)
    const categories = await prisma.category.findMany({
      where: {
        slug: { notIn: ['restaurant-food', 'restaurant', 'cafe'] }
      },
      select: {
        id: true,
        name: true,
        slug: true,
        imageUrl: true,
        parentId: true,
        sortOrder: true,
        _count: {
          select: {
            products: {
              where: {
                restaurantId: null,
                isAvailable: true
              }
            }
          }
        },
        ...(includeProducts
          ? {
              products: {
                where: {
                  restaurantId: null,
                  isAvailable: true
                },
                select: {
                  id: true,
                  name: true,
                  slug: true,
                  description: true,
                  imageUrl: true,
                  price: true,
                  mrp: true,
                  discount: true,
                  unit: true,
                  stock: true,
                  isAvailable: true,
                  tags: true,
                  categoryId: true
                },
                orderBy: [
                  { sortOrder: 'desc' },
                  { isBestSeller: 'desc' },
                  { createdAt: 'desc' }
                ],
                take: limitPerCat
              }
            }
          : {})
      },
      orderBy: {
        sortOrder: 'asc'
      }
    })

    const formattedCatalog = categories.map(cat => ({
      id: cat.id,
      name: cat.name,
      slug: cat.slug,
      imageUrl: cat.imageUrl,
      parentId: cat.parentId,
      sortOrder: cat.sortOrder,
      productCount: (cat as any)._count?.products || 0,
      products: (cat as any).products || []
    }))

    const totalGroceryProducts = await prisma.product.count({
      where: { restaurantId: null, isAvailable: true }
    })

    const payload = {
      success: true,
      totalCategories: formattedCatalog.length,
      totalGroceryProducts,
      categories: formattedCatalog
    }

    // Cache for 60 seconds
    await setCache(cacheKey, payload, 60)

    return NextResponse.json(payload)
  } catch (error: any) {
    console.error('Error fetching grocery categories catalog:', error)
    return NextResponse.json(
      { error: error?.message || 'Failed to fetch categories catalog' },
      { status: 500 }
    )
  }
}
