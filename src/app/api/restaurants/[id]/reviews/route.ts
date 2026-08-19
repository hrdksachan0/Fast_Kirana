import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { OUTLET_AS_RESTAURANT_ID, OUTLET_WEDSON_ID } from '@/lib/constants'

export async function GET(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params
    const decodedId = decodeURIComponent(id).toLowerCase()

    // 1. Resolve target restaurant by ID or slug or outlet alias
    const restaurant = await prisma.restaurant.findFirst({
      where: {
        OR: [
          { id },
          { slug: { equals: decodedId, mode: 'insensitive' } },
          ...(decodedId === 'as-restaurant' || decodedId === 'as-cafe' || decodedId === 'as'
            ? [{ id: OUTLET_AS_RESTAURANT_ID }]
            : []),
          ...(decodedId === 'wedson' || decodedId === 'restaurant-kitchen'
            ? [{ id: OUTLET_WEDSON_ID }]
            : []),
        ],
      },
    })

    const targetRestaurantIds = restaurant
      ? [restaurant.id, ...(restaurant.id === OUTLET_AS_RESTAURANT_ID ? [OUTLET_AS_RESTAURANT_ID] : [])]
      : [id]

    // 2. Query reviews by canonical database restaurant IDs
    const reviews = await prisma.restaurantReview.findMany({
      where: {
        restaurantId: { in: targetRestaurantIds },
      },
      include: {
        user: {
          select: {
            name: true,
            image: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    })

    return NextResponse.json({ reviews })
  } catch (error: any) {
    console.error('Restaurant reviews GET error:', error)
    return NextResponse.json({ error: 'Internal server error', reviews: [] }, { status: 500 })
  }
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Please log in to submit a review' }, { status: 401 })
    }

    const { id } = await params
    const decodedId = decodeURIComponent(id).toLowerCase()
    const body = await request.json()
    const { rating, comment } = body

    const parsedRating = parseInt(rating)
    if (!parsedRating || parsedRating < 1 || parsedRating > 5) {
      return NextResponse.json({ error: 'Rating must be a number between 1 and 5 stars' }, { status: 400 })
    }

    // 1. Resolve target restaurant first
    const restaurant = await prisma.restaurant.findFirst({
      where: {
        OR: [
          { id },
          { slug: { equals: decodedId, mode: 'insensitive' } },
          ...(decodedId === 'as-restaurant' || decodedId === 'as-cafe' || decodedId === 'as'
            ? [{ id: OUTLET_AS_RESTAURANT_ID }]
            : []),
          ...(decodedId === 'wedson' || decodedId === 'restaurant-kitchen'
            ? [{ id: OUTLET_WEDSON_ID }]
            : []),
        ],
      },
    })

    if (!restaurant) {
      return NextResponse.json({ error: 'Restaurant not found' }, { status: 404 })
    }

    const realRestaurantId = restaurant.id
    const userRole = session.user.role

    // 2. Customer validation: Check if user has a DELIVERED order matching restaurant ID or order items
    if (userRole !== 'ADMIN') {
      const deliveredOrder = await prisma.order.findFirst({
        where: {
          userId: session.user.id,
          status: 'DELIVERED',
          OR: [
            { restaurantId: realRestaurantId },
            { items: { some: { product: { restaurantId: realRestaurantId } } } },
            { items: { some: { product: { restaurant: { slug: restaurant.slug } } } } },
          ],
        },
      })

      if (!deliveredOrder) {
        return NextResponse.json({
          error: 'You can only review restaurants after your order from this outlet has been delivered.',
        }, { status: 403 })
      }
    }

    // 3. Create or Update review for this user & restaurant
    const existingReview = await prisma.restaurantReview.findFirst({
      where: {
        userId: session.user.id,
        restaurantId: realRestaurantId,
      },
    })

    let review
    if (existingReview) {
      review = await prisma.restaurantReview.update({
        where: { id: existingReview.id },
        data: {
          rating: parsedRating,
          comment: comment ? String(comment).trim() : null,
        },
        include: {
          user: {
            select: {
              name: true,
              image: true,
            },
          },
        },
      })
    } else {
      review = await prisma.restaurantReview.create({
        data: {
          userId: session.user.id,
          restaurantId: realRestaurantId,
          rating: parsedRating,
          comment: comment ? String(comment).trim() : null,
        },
        include: {
          user: {
            select: {
              name: true,
              image: true,
            },
          },
        },
      })
    }

    // 4. Re-calculate aggregate rating & review count for restaurant
    const aggregate = await prisma.restaurantReview.aggregate({
      where: { restaurantId: realRestaurantId },
      _avg: { rating: true },
      _count: { id: true },
    })

    await prisma.restaurant.update({
      where: { id: realRestaurantId },
      data: {
        rating: aggregate._avg.rating ? Math.round(aggregate._avg.rating * 10) / 10 : 4.0,
        reviewCount: aggregate._count.id || 0,
      },
    })

    return NextResponse.json({ review, message: 'Review submitted successfully!' })
  } catch (error: any) {
    console.error('Restaurant reviews POST error:', error)
    return NextResponse.json({ error: error.message || 'Internal server error' }, { status: 500 })
  }
}
