import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'

export const dynamic = 'force-dynamic'

export async function GET(request: Request) {
  try {
    const session = await auth()
    const { searchParams } = new URL(request.url)
    const restaurantId = searchParams.get('restaurantId')
    const storeId = searchParams.get('storeId')

    const userRole = (session?.user?.role || '').toUpperCase()
    const isAdmin = userRole === 'ADMIN' || userRole === 'SUPER_ADMIN'
    const userAssignedStoreId = (session?.user as any)?.assignedStoreId || null
    const userAssignedRestId = (session?.user as any)?.assignedRestaurantId || null

    const effectiveStoreId = (storeId && storeId !== 'all') ? storeId : userAssignedStoreId

    let targetRest: any = null
    let whereCondition: any = {}

    if (restaurantId && restaurantId !== 'ALL' && restaurantId !== 'NONE') {
      targetRest = await prisma.restaurant.findFirst({
        where: {
          OR: [{ id: restaurantId }, { slug: restaurantId }]
        }
      })
      if (targetRest) {
        whereCondition = { restaurantId: targetRest.id }
      } else {
        whereCondition = { restaurantId }
      }
    } else if (effectiveStoreId && effectiveStoreId !== 'all') {
      // Hub-scoped admin or hub filter: fetch all dishes in this hub
      const hubRests = await prisma.restaurant.findMany({
        where: { storeId: effectiveStoreId },
        select: { id: true }
      })
      const restIds = hubRests.map(r => r.id)
      whereCondition = { restaurantId: { in: restIds } }
      if (hubRests.length > 0) {
        targetRest = await prisma.restaurant.findUnique({ where: { id: hubRests[0].id } })
      }
    } else if (userAssignedRestId) {
      targetRest = await prisma.restaurant.findFirst({
        where: { OR: [{ id: userAssignedRestId }, { slug: userAssignedRestId }] }
      })
      whereCondition = { restaurantId: targetRest?.id || userAssignedRestId }
    } else {
      whereCondition = { restaurantId: { not: null } }
      targetRest = await prisma.restaurant.findFirst({ orderBy: { id: 'asc' } })
    }

    const products = await prisma.product.findMany({
      where: whereCondition,
      include: {
        category: {
          select: { id: true, name: true, slug: true }
        },
        restaurant: {
          select: { id: true, name: true, slug: true, storeId: true }
        }
      },
      orderBy: { createdAt: 'desc' }
    })

    return NextResponse.json({
      products: products.map(p => ({
        id: p.id,
        name: p.name,
        slug: p.slug,
        description: p.description,
        price: Number(p.price),
        mrp: Number(p.mrp || p.price),
        stock: p.stock,
        isAvailable: p.isAvailable,
        imageUrl: p.imageUrl,
        restaurantId: p.restaurantId,
        menuSection: p.category?.name || 'Main Menu',
        category: p.category,
        variants: p.variants,
        tags: p.tags,
      })),
      restaurant: targetRest ? {
        id: targetRest.id,
        name: targetRest.name,
        slug: targetRest.slug,
        isOpen: targetRest.isOpen,
        commissionRate: targetRest.commissionRate ?? 0.15,
        menuSections: targetRest.menuSections,
      } : null
    })
  } catch (err: any) {
    console.error('Error in GET /api/restaurant-dashboard/products:', err)
    return NextResponse.json({ error: err.message || 'Failed to fetch dishes' }, { status: 500 })
  }
}

export async function POST(request: Request) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized: Please log in' }, { status: 401 })
    }

    const userRole = (session.user.role || '').toUpperCase()
    const isAdmin = userRole === 'ADMIN' || userRole === 'SUPER_ADMIN'
    const userAssignedStoreId = (session.user as any)?.assignedStoreId || null
    const userAssignedRestId = (session.user as any)?.assignedRestaurantId || null

    const body = await request.json()
    const { name, price, mrp, stock, imageUrl, tags, restaurantId, description, unit, variants } = body

    if (!name || !name.trim()) {
      return NextResponse.json({ error: 'Dish name is required' }, { status: 400 })
    }
    if (price === undefined || price === null) {
      return NextResponse.json({ error: 'Price is required' }, { status: 400 })
    }

    // Determine target restaurant outlet
    let targetRestId = restaurantId ? String(restaurantId).trim() : null
    if (!targetRestId || targetRestId.toUpperCase() === 'ALL' || targetRestId.toUpperCase() === 'NONE') {
      if (userAssignedRestId) {
        targetRestId = userAssignedRestId
      } else if (userAssignedStoreId) {
        const hubRest = await prisma.restaurant.findFirst({
          where: { storeId: userAssignedStoreId },
          orderBy: { sortOrder: 'asc' }
        })
        targetRestId = hubRest?.id || null
      }
    }

    if (!targetRestId) {
      return NextResponse.json({ error: 'Please select a restaurant outlet before adding a dish' }, { status: 400 })
    }

    const restaurant = await prisma.restaurant.findFirst({
      where: {
        OR: [{ id: targetRestId }, { slug: targetRestId }]
      }
    })

    if (!restaurant) {
      return NextResponse.json({ error: `Restaurant "${targetRestId}" not found` }, { status: 404 })
    }

    // Permission check: if non-admin, ensure user is assigned to this restaurant
    if (!isAdmin) {
      const allowed = userAssignedRestId === restaurant.id || userAssignedRestId === restaurant.slug
      if (!allowed) {
        return NextResponse.json({ error: 'Access denied: You can only add dishes to your assigned restaurant' }, { status: 403 })
      }
    }

    // Generate unique slug
    const cleanNameSlug = name.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)+/g, '')
    let slug = `${restaurant.slug}-${cleanNameSlug}`
    let suffix = 1
    while (await prisma.product.findUnique({ where: { slug } })) {
      slug = `${restaurant.slug}-${cleanNameSlug}-${suffix++}`
    }

    // Get next readableId
    const maxProd = await prisma.product.findFirst({
      where: { readableId: { not: null } },
      orderBy: { readableId: 'desc' },
      select: { readableId: true }
    })
    let nextReadableId = (maxProd?.readableId || 200000) + 1
    while (await prisma.product.findUnique({ where: { readableId: nextReadableId } })) {
      nextReadableId++
    }

    const parsedPrice = parseFloat(String(price)) || 0
    const parsedMrp = mrp !== undefined ? (parseFloat(String(mrp)) || parsedPrice) : parsedPrice
    const discount = parsedMrp > parsedPrice ? Math.max(0, Math.round(((parsedMrp - parsedPrice) / parsedMrp) * 100)) : 0
    const initialStock = stock !== undefined ? (parseInt(String(stock), 10) || 999) : 999

    const rawTags = Array.isArray(tags) ? tags.map(t => String(t).trim()).filter(Boolean) : ['restaurant']
    if (!rawTags.includes('restaurant')) rawTags.push('restaurant')

    const newProduct = await prisma.product.create({
      data: {
        name: name.trim(),
        slug,
        readableId: nextReadableId,
        description: description ? String(description).trim() : null,
        imageUrl: imageUrl ? String(imageUrl).trim() : '🍲',
        restaurantId: restaurant.id,
        categoryId: null,
        mrp: parsedMrp,
        price: parsedPrice,
        discount,
        unit: unit ? String(unit).trim() : '1 Serving',
        stock: initialStock,
        isAvailable: true,
        tags: rawTags,
        variants: variants && typeof variants === 'object' ? variants : null,
      },
      include: {
        category: true,
        restaurant: true,
      }
    })

    // Seed storeInventory for the restaurant's hub so search & POS see availability
    if (restaurant.storeId) {
      try {
        await prisma.storeInventory.upsert({
          where: {
            productId_storeId: {
              productId: newProduct.id,
              storeId: restaurant.storeId,
            }
          },
          create: {
            productId: newProduct.id,
            storeId: restaurant.storeId,
            stock: initialStock,
            isAvailable: true,
          },
          update: {
            stock: initialStock,
            isAvailable: true,
          }
        })
      } catch (invErr) {
        console.warn('Could not upsert storeInventory for new restaurant dish:', invErr)
      }
    }

    revalidateStorefront(restaurant.slug)

    return NextResponse.json({
      success: true,
      message: 'Dish added successfully to restaurant menu',
      product: {
        id: newProduct.id,
        name: newProduct.name,
        slug: newProduct.slug,
        price: Number(newProduct.price),
        mrp: Number(newProduct.mrp),
        discount: Number(newProduct.discount),
        stock: newProduct.stock,
        isAvailable: newProduct.isAvailable,
        restaurantId: newProduct.restaurantId,
        imageUrl: newProduct.imageUrl,
        tags: newProduct.tags,
      }
    }, { status: 201 })
  } catch (err: any) {
    console.error('Error in POST /api/restaurant-dashboard/products:', err)
    return NextResponse.json({ error: err.message || 'Failed to create dish' }, { status: 500 })
  }
}
