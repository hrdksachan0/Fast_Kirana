import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params
    const reviews = await prisma.restaurantReview.findMany({
      where: { restaurantId: id },
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
  } catch (error) {
    console.error('Restaurant reviews GET error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

export async function POST(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { id: restaurantId } = await params
    const body = await request.json()
    const { rating, comment } = body

    if (!rating || rating < 1 || rating > 5) {
      return NextResponse.json({ error: 'Rating must be an integer between 1 and 5' }, { status: 400 })
    }

    // Verify if customer has ordered from this restaurant and order is DELIVERED
    const deliveredOrder = await prisma.order.findFirst({
      where: {
        userId: session.user.id,
        restaurantId: restaurantId,
        status: 'DELIVERED',
      },
    })

    if (!deliveredOrder) {
      return NextResponse.json({
        error: 'You can only review restaurants after you have ordered from them and the order is delivered.',
      }, { status: 403 })
    }

    // Create review
    const review = await prisma.restaurantReview.create({
      data: {
        userId: session.user.id,
        restaurantId,
        rating: parseInt(rating),
        comment: comment || null,
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

    // Re-calculate average restaurant rating
    const aggregate = await prisma.restaurantReview.aggregate({
      where: { restaurantId },
      _avg: { rating: true },
      _count: { id: true },
    })

    await prisma.restaurant.update({
      where: { id: restaurantId },
      data: {
        rating: aggregate._avg.rating || 4.0,
        reviewCount: aggregate._count.id || 0,
      },
    })

    return NextResponse.json({ review })
  } catch (error) {
    console.error('Restaurant reviews POST error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
