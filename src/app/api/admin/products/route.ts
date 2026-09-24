import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { requireAdmin, getEffectiveStoreId } from '@/lib/auth-guard'
import { revalidateStorefront } from '@/lib/revalidate'
import { extractCityFromStoreName } from '@/lib/store-resolver'

export async function GET(request: Request) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  const { searchParams } = new URL(request.url)
  const page = parseInt(searchParams.get('page') || '1')
  const limit = parseInt(searchParams.get('limit') || '20')
  const categoryId = searchParams.get('categoryId')
  const search = searchParams.get('search')
  const lowStock = searchParams.get('lowStock') === 'true'
  const flashDeals = searchParams.get('flashDeals') === 'true'
  const topPicks = searchParams.get('topPicks') === 'true'
  const bestSellers = searchParams.get('bestSellers') === 'true'
  const type = searchParams.get('type')
  const storeId = getEffectiveStoreId(session, searchParams.get('storeId'))
  
  const skip = (page - 1) * limit

  try {
    const where: any = {}
    const andClauses: any[] = []

    if (categoryId && categoryId !== 'ALL' && categoryId !== 'undefined' && categoryId !== 'null') {
      andClauses.push({
        OR: [
          { categoryId },
          { category: { parentId: categoryId } },
        ]
      })
    }

    if (lowStock) {
      andClauses.push({ stock: { lt: 15 } })
    }

    if (flashDeals) {
      andClauses.push({ isFlashDeal: true })
    }

    if (topPicks) {
      andClauses.push({ isTopPick: true })
    }

    if (bestSellers) {
      andClauses.push({ isBestSeller: true })
    }

    if (search) {
      andClauses.push({
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { slug: { contains: search, mode: 'insensitive' } },
          { description: { contains: search, mode: 'insensitive' } },
          { tags: { has: search } },
        ]
      })
    }

    if (type === 'cafe' || type === 'restaurant') {
      andClauses.push({
        restaurantId: { not: null }
      })
    } else if (type === 'grocery') {
      andClauses.push({
        restaurantId: null
      })
    }

    if (storeId && storeId !== 'all') {
      andClauses.push({
        OR: [
          {
            restaurantId: null,
            inventories: {
              some: {
                storeId
              }
            }
          },
          {
            restaurant: {
              storeId
            }
          }
        ]
      })
    }

    if (andClauses.length > 0) {
      where.AND = andClauses
    }

    const [productsRaw, total] = await Promise.all([
      prisma.product.findMany({
        where,
        include: {
          category: true,
          restaurant: {
            select: {
              id: true,
              name: true,
              slug: true,
            }
          },
        },
        orderBy: {
          createdAt: 'desc',
        },
        skip,
        take: limit,
      }),
      prisma.product.count({ where }),
    ])

    // Localize stock from store_inventories if a specific store is selected
    let inventoryMap = new Map<string, number>()
    if (storeId && storeId !== 'all') {
      try {
        const inventories = await prisma.storeInventory.findMany({
          where: {
            storeId,
            productId: { in: productsRaw.map((p) => p.id) }
          }
        })
        inventoryMap = new Map(inventories.map((inv) => [inv.productId, inv.stock]))
      } catch (invErr) {
        console.warn('Could not query store_inventories in admin products:', invErr)
      }
    }

    const products = productsRaw.map((p) => {
      let localStock = p.stock
      if (storeId && storeId !== 'all') {
        if (p.restaurantId) {
          localStock = p.stock
        } else {
          localStock = inventoryMap.get(p.id) ?? 0
        }
      }

      return {
        id: p.id,
        name: p.name,
        slug: p.slug,
        description: p.description,
        imageUrl: p.imageUrl,
        categoryId: p.categoryId,
        restaurantId: p.restaurantId,
        mrp: p.mrp,
        price: p.price,
        discount: p.discount,
        unit: p.unit,
        stock: localStock,
        isAvailable: p.isAvailable,
        tags: p.tags,
        variants: p.variants,
        costPrice: p.costPrice ?? 0,
        minStock: p.minStock ?? 10,
        location: p.location,
        barcode: p.barcode || '',
        sortOrder: p.sortOrder ?? 0,
        isFlashDeal: p.isFlashDeal,
        isTopPick: p.isTopPick,
        isBestSeller: p.isBestSeller,
        vendor: p.vendor || '',
        storeId: storeId || 'all',
        category: p.category ? {
          id: p.category.id,
          name: p.category.name,
          slug: p.category.slug,
        } : null,
        restaurant: p.restaurant ? {
          id: p.restaurant.id,
          name: p.restaurant.name,
          slug: p.restaurant.slug,
        } : null,
      }
    })

    return NextResponse.json({ products, total, page, limit })
  } catch (error: any) {
    console.error('Failed to fetch admin products:', error)
    return NextResponse.json({ error: 'Failed to fetch products' }, { status: 500 })
  }
}

export async function POST(request: Request) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const body = await request.json()
    const { name, categoryId, restaurantId, barcode, mrp, price, stock, unit, imageUrl, brand, isAvailable } = body

    if (!name || mrp === undefined || price === undefined) {
      return NextResponse.json({ error: 'Name, MRP, and Price are required' }, { status: 400 })
    }

    let finalCategoryId = categoryId
    let finalRestaurantId = restaurantId ? String(restaurantId).trim() : null
    if (finalRestaurantId) {
      finalCategoryId = null
    } else if (!finalCategoryId) {
      const firstCat = await prisma.category.findFirst({
        where: { slug: { notIn: ['restaurant-food', 'restaurant', 'cafe'] } },
        orderBy: { sortOrder: 'asc' }
      })
      if (firstCat) finalCategoryId = firstCat.id
    }

    const slug = name
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)+/g, '')

    const existingSlug = await prisma.product.findUnique({ where: { slug } })
    const finalSlug = existingSlug ? `${slug}-${Date.now().toString().slice(-4)}` : slug

    const parsedMrp = parseFloat(String(mrp)) || 0
    const parsedPrice = parseFloat(String(price)) || parsedMrp
    const discount = parsedMrp > parsedPrice ? Math.max(0, Math.round(((parsedMrp - parsedPrice) / parsedMrp) * 100)) : 0

    const lastProduct = await prisma.product.findFirst({
      orderBy: { readableId: 'desc' },
      select: { readableId: true }
    })
    const nextReadableId = lastProduct?.readableId ? lastProduct.readableId + 1 : 200001

    const product = await prisma.product.create({
      data: {
        name: name.trim(),
        slug: finalSlug,
        readableId: nextReadableId,
        categoryId: finalCategoryId,
        restaurantId: finalRestaurantId,
        barcode: barcode && typeof barcode === 'string' ? barcode.trim() : null,
        mrp: parsedMrp,
        price: parsedPrice,
        discount,
        stock: parseInt(String(stock), 10) || 0,
        unit: (unit && typeof unit === 'string') ? unit.trim() : (finalRestaurantId ? '1 Serving' : '1 pc'),
        imageUrl: imageUrl || null,
        isAvailable: isAvailable !== undefined ? !!isAvailable : true,
      },
      include: {
        category: true,
        restaurant: true,
      }
    })

    // Seed store-level inventory
    try {
      const targetStoreId = (body.storeId && body.storeId !== 'all') ? String(body.storeId).trim() : ((session?.user as any)?.assignedStoreId || null)
      const initialStockNum = parseInt(String(stock), 10) || 0

      if (targetStoreId && targetStoreId !== 'all') {
        // Only seed inventory for the targeted dark store
        await prisma.storeInventory.upsert({
          where: {
            productId_storeId: {
              productId: product.id,
              storeId: targetStoreId,
            }
          },
          create: {
            productId: product.id,
            storeId: targetStoreId,
            stock: initialStockNum,
          },
          update: {
            stock: initialStockNum,
          }
        })
      } else {
        const allStores = await prisma.darkStore.findMany({ select: { id: true } })
        if (allStores.length > 0) {
          await prisma.storeInventory.createMany({
            data: allStores.map((s) => ({
              storeId: s.id,
              productId: product.id,
              stock: initialStockNum,
            })),
            skipDuplicates: true,
          })
        }
      }
    } catch (seedErr) {
      console.warn('Could not seed store_inventories for new product:', seedErr)
    }

    revalidateStorefront(product.category?.slug)

    return NextResponse.json(product, { status: 201 })
  } catch (err: any) {
    console.error('Failed to create product in admin API:', err)
    return NextResponse.json({ error: err.message || 'Failed to create product' }, { status: 500 })
  }
}
