import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'
import { invalidateProductCache } from '@/lib/search-cache'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const session = await auth()
    const paramRestId = searchParams.get('restaurantId')
    const assignedRestaurantId = (session?.user as any)?.assignedRestaurantId || request.headers.get('x-restaurant-id')
    const effectiveRestId = paramRestId || assignedRestaurantId

    const where: any = {}
    if (effectiveRestId && effectiveRestId !== 'ALL') {
      where.restaurantId = effectiveRestId
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
  } catch (error: any) {
    console.error('Restaurant dashboard products GET error:', error)
    return NextResponse.json({ error: error?.message || 'Internal server error' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
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

    const assignedRestaurantId = (session?.user as any)?.assignedRestaurantId || request.headers.get('x-restaurant-id')

    // Determine target restaurant ID
    let finalRestaurantId = body.restaurantId || assignedRestaurantId
    if (!finalRestaurantId) {
      const defaultRest = await prisma.restaurant.findFirst({ where: { isActive: true } })
      finalRestaurantId = defaultRest?.id || null
    }

    let targetCategoryId = categoryId
    if (!targetCategoryId || targetCategoryId === '') {
      let restCat = await prisma.category.findFirst({ where: { slug: 'restaurant' } })
      if (!restCat) {
        restCat = await prisma.category.findFirst()
      }
      targetCategoryId = restCat?.id
    }

    if (!targetCategoryId) {
      return NextResponse.json({ error: 'No product category found. Please create a category first.' }, { status: 400 })
    }

    const finalUnit = (unit && typeof unit === 'string' && unit.trim()) ? unit.trim() : '1 Serving'
    const parsedPrice = parseFloat(price) || 0
    const parsedMrp = mrp ? (parseFloat(mrp) || parsedPrice) : parsedPrice
    const parsedStock = stock !== undefined ? (parseInt(stock) || 999) : 999

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
    } catch (e) {}

    return NextResponse.json({ product, success: true }, { status: 201 })
  } catch (error: any) {
    console.error('Restaurant dashboard products POST error:', error)
    return NextResponse.json({ error: error?.message || 'Failed to create menu item' }, { status: 500 })
  }
}
