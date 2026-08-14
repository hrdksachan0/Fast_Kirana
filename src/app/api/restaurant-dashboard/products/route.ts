import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const isOwner = role === 'RESTAURANT_OWNER' || role === 'ADMIN'
    if (!isOwner) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const restaurantId = (session.user as any).assignedRestaurantId
    if (!restaurantId && role !== 'ADMIN') {
      return NextResponse.json({ error: 'No restaurant assigned' }, { status: 400 })
    }

    const where: any = {}
    if (role !== 'ADMIN') {
      where.restaurantId = restaurantId
    }

    const [products, restaurant] = await Promise.all([
      prisma.product.findMany({
        where,
        include: { category: true, images: true },
        orderBy: [{ sortOrder: 'desc' }, { createdAt: 'desc' }],
      }),
      restaurantId ? prisma.restaurant.findUnique({
        where: { id: restaurantId },
        select: { id: true, name: true, slug: true, menuSections: true, cuisineTags: true }
      }) : null
    ])

    return NextResponse.json({ products, restaurant })
  } catch (error) {
    console.error('Restaurant dashboard products GET error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const isOwner = role === 'RESTAURANT_OWNER' || role === 'ADMIN'
    if (!isOwner) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const restaurantId = (session.user as any).assignedRestaurantId
    if (!restaurantId && role !== 'ADMIN') {
      return NextResponse.json({ error: 'No restaurant assigned' }, { status: 400 })
    }

    const body = await request.json()
    const { name, description, imageUrl, price, mrp, unit, stock, tags, categoryId, variants } = body

    if (!name || price === undefined || price === null || !unit || !categoryId) {
      return NextResponse.json({ error: 'Missing required fields: name, price, unit, categoryId' }, { status: 400 })
    }

    // Generate slug from name
    const baseSlug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
    const existingCount = await prisma.product.count({ where: { slug: { startsWith: baseSlug } } })
    const slug = existingCount > 0 ? `${baseSlug}-${existingCount + 1}` : baseSlug

    const product = await prisma.product.create({
      data: {
        name,
        slug,
        description: description || null,
        imageUrl: imageUrl || null,
        price: parseFloat(price),
        mrp: parseFloat(mrp || price),
        discount: mrp && parseFloat(mrp) > parseFloat(price) ? Math.round(((parseFloat(mrp) - parseFloat(price)) / parseFloat(mrp)) * 100) : 0,
        unit,
        stock: parseInt(stock || '999'),
        tags: tags || [],
        categoryId,
        restaurantId: restaurantId || body.restaurantId,
        variants: variants || null,
        isAvailable: true,
      },
      include: { category: true },
    })

    return NextResponse.json({ product }, { status: 201 })
  } catch (error) {
    console.error('Restaurant dashboard products POST error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
