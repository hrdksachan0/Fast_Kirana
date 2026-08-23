import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const assignedRestaurantId = (session.user as any).assignedRestaurantId
    const userEmail = session.user.email || ''

    const isAllowed =
      role === 'ADMIN' ||
      role === 'RESTAURANT_OWNER' ||
      role === 'CHEF' ||
      userEmail.toLowerCase().startsWith('restaurant') ||
      !!assignedRestaurantId

    if (!isAllowed) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const { searchParams } = new URL(request.url)
    const paramRestId = searchParams.get('restaurantId')
    const effectiveRestId = paramRestId || assignedRestaurantId

    if (!effectiveRestId && role !== 'ADMIN') {
      return NextResponse.json({ error: 'No restaurant assigned' }, { status: 400 })
    }

    const where: any = {}
    if (effectiveRestId) {
      where.restaurantId = effectiveRestId
    }

    const [products, restaurant] = await Promise.all([
      prisma.product.findMany({
        where,
        include: { category: true, images: true },
        orderBy: [{ sortOrder: 'desc' }, { createdAt: 'desc' }],
      }),
      effectiveRestId
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
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const assignedRestaurantId = (session.user as any).assignedRestaurantId
    const userEmail = session.user.email || ''

    const isAllowed =
      role === 'ADMIN' ||
      role === 'RESTAURANT_OWNER' ||
      role === 'CHEF' ||
      userEmail.toLowerCase().startsWith('restaurant') ||
      !!assignedRestaurantId

    if (!isAllowed) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
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

    const effectiveRestId = body.restaurantId || assignedRestaurantId
    if (!effectiveRestId && role !== 'ADMIN') {
      return NextResponse.json({ error: 'No restaurant assigned' }, { status: 400 })
    }

    if (!name || price === undefined || price === null) {
      return NextResponse.json({ error: 'Missing required fields: name, price' }, { status: 400 })
    }

    let targetCategoryId = categoryId
    if (!targetCategoryId || targetCategoryId === '') {
      const anyCat = await prisma.category.findFirst()
      targetCategoryId = anyCat?.id
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
        tags: Array.isArray(tags) ? tags : [],
        categoryId: targetCategoryId,
        restaurantId: effectiveRestId || null,
        variants: variants || null,
        availableStartTime: availableStartTime || null,
        availableEndTime: availableEndTime || null,
        isAvailable: true,
      },
      include: { category: true },
    })

    try {
      revalidateStorefront(product.category?.slug)
    } catch (e) {}

    return NextResponse.json({ product, success: true }, { status: 201 })
  } catch (error: any) {
    console.error('Restaurant dashboard products POST error:', error)
    return NextResponse.json({ error: error?.message || 'Failed to create menu item' }, { status: 500 })
  }
}
