import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'
import { invalidateProductCache } from '@/lib/search-cache'
import { getSessionRestaurantId, normalizeRestaurantId } from '@/lib/restaurant-ids'
import { logger } from '@/lib/logger'
import { Prisma } from '@prisma/client'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    let session = null
    try {
      session = await auth()
    } catch (e) {
      logger.warn('auth', 'Auth check failed in restaurant products GET', e)
    }

    const paramRestId = searchParams.get('restaurantId')
    const effectiveRestId = getSessionRestaurantId(session, request, paramRestId)

    const where: Prisma.ProductWhereInput = {}
    if (effectiveRestId === 'ALL') {
      where.restaurantId = { not: null }
    } else if (effectiveRestId) {
      where.restaurantId = effectiveRestId
    } else {
      return NextResponse.json({ products: [], restaurant: null })
    }

    const [products, restaurant] = await Promise.all([
      prisma.product.findMany({
        where,
        include: { category: true, images: true },
        orderBy: [{ sortOrder: 'desc' }, { createdAt: 'desc' }],
      }),
      effectiveRestId && effectiveRestId !== 'ALL'
        ? prisma.restaurant.findUnique({
            where: { id: effectiveRestId },
            select: { id: true, name: true, slug: true, menuSections: true, cuisineTags: true },
          })
        : null,
    ])

    return NextResponse.json({ products, restaurant })
  } catch (error: unknown) {
    logger.error('restaurant-products', 'Restaurant dashboard products GET error', error)
    const message = error instanceof Error ? error.message : 'Internal server error'
    return NextResponse.json({ error: message }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    let session = null
    try {
      session = await auth()
    } catch (e) {
      logger.warn('auth', 'Auth check failed in restaurant products POST', e)
    }

    const body = await request.json()
    const {
      name,
      description,
      imageUrl,
      price,
      mrp,
      unit,
      stock,
      tags,
      categoryId,
      variants,
      availableStartTime,
      availableEndTime,
    } = body

    if (!name || price === undefined || price === null) {
      return NextResponse.json({ error: 'Missing required fields: name, price' }, { status: 400 })
    }

    // Determine target restaurant ID cleanly
    const finalRestaurantId = getSessionRestaurantId(session, request, body.restaurantId)
    if (!finalRestaurantId || finalRestaurantId === 'ALL') {
      return NextResponse.json({ error: 'Valid target restaurant ID is required to create a dish' }, { status: 400 })
    }

    const targetCategoryId = (categoryId && typeof categoryId === 'string' && categoryId.trim()) ? categoryId.trim() : null

    const finalUnit = (unit && typeof unit === 'string' && unit.trim()) ? unit.trim() : '1 Serving'
    const parsedPrice = parseFloat(price) || 0
    const parsedMrp = mrp ? (parseFloat(mrp) || parsedPrice) : parsedPrice
    const parsedStock = stock !== undefined ? (parseInt(stock) || 999) : 999

    if (parsedPrice <= 0) {
      return NextResponse.json({ error: 'Selling price must be greater than 0' }, { status: 400 })
    }
    if (parsedPrice > parsedMrp) {
      return NextResponse.json({ error: 'Selling price cannot exceed MRP' }, { status: 400 })
    }

    const discountVal =
      parsedMrp > parsedPrice ? Math.max(0, Math.round(((parsedMrp - parsedPrice) / parsedMrp) * 100)) : 0

    // Generate unique slug from name
    const baseSlug = name
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '') || `item-${Date.now()}`
    const existingCount = await prisma.product.count({ where: { slug: { startsWith: baseSlug } } })
    const slug = existingCount > 0 ? `${baseSlug}-${existingCount + 1}-${Date.now().toString().slice(-4)}` : baseSlug

    const tagsList = Array.isArray(tags) ? [...tags] : []
    if (!tagsList.includes('restaurant')) {
      tagsList.push('restaurant')
    }

    // Add food type tag: 'veg', 'non-veg', 'egg'
    if (body.foodType) {
      const ft = String(body.foodType).toLowerCase().trim()
      if (['veg', 'non-veg', 'egg'].includes(ft) && !tagsList.includes(ft)) {
        tagsList.push(ft)
      }
    }

    // Add prep time tag if provided
    if (body.prepTime) {
      const pt = parseInt(String(body.prepTime), 10)
      if (pt > 0) {
        tagsList.push(`prep-${pt}m`)
      }
    }

    // Add unique section ID for relational indexing
    const secId = body.sectionId || body.menuSectionId
    if (secId && typeof secId === 'string' && secId.trim() && !tagsList.includes(secId.trim())) {
      tagsList.push(secId.trim())
    }

    const product = await prisma.product.create({
      data: {
        name: name.trim(),
        slug,
        description: description || null,
        imageUrl: imageUrl || null,
        price: parsedPrice,
        mrp: parsedMrp,
        discount: discountVal,
        unit: finalUnit,
        stock: parsedStock,
        tags: tagsList,
        categoryId: targetCategoryId,
        restaurantId: finalRestaurantId,
        variants: variants || null,
        availableStartTime: availableStartTime || null,
        availableEndTime: availableEndTime || null,
        isAvailable: true,
      },
      include: { category: true },
    })

    try {
      revalidateStorefront(product.category?.slug)
      await invalidateProductCache()
    } catch (e) {
      logger.warn('cache', 'Cache revalidation failed after dish creation', e)
    }

    return NextResponse.json({ product, success: true }, { status: 201 })
  } catch (error: unknown) {
    logger.error('restaurant-products', 'Restaurant dashboard products POST error', error)
    const message = error instanceof Error ? error.message : 'Failed to create menu item'
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
