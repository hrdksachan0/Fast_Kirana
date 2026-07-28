import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET() {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const [reviews, restaurantReviews] = await Promise.all([
      prisma.review.findMany({
        orderBy: { createdAt: 'desc' },
        include: {
          user: { select: { id: true, name: true, email: true } },
          product: { select: { id: true, name: true, slug: true, imageUrl: true } },
        },
      }),
      prisma.restaurantReview.findMany({
        orderBy: { createdAt: 'desc' },
        include: {
          user: { select: { id: true, name: true, email: true } },
          restaurant: { select: { id: true, name: true, slug: true, logoUrl: true } },
        },
      })
    ])

    const serializedProducts = reviews.map((review) => ({
      ...review,
      type: 'PRODUCT',
      createdAt: review.createdAt.toISOString(),
    }))

    const serializedRestaurants = restaurantReviews.map((review) => ({
      id: review.id,
      userId: review.userId,
      rating: review.rating,
      comment: review.comment,
      createdAt: review.createdAt.toISOString(),
      user: review.user,
      type: 'RESTAURANT',
      // Format as product so frontend renders nicely without breaking
      product: {
        id: review.restaurant.id,
        name: `Restaurant: ${review.restaurant.name}`,
        slug: `food/${review.restaurant.slug}`,
        imageUrl: review.restaurant.logoUrl || null,
      }
    }))

    // Merge both
    const allReviews = [...serializedProducts, ...serializedRestaurants].sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    )

    return NextResponse.json(allReviews)
  } catch (error: any) {
    console.error('Failed to fetch reviews:', error)
    return NextResponse.json({ error: 'Failed to fetch reviews' }, { status: 500 })
  }
}

export async function PATCH(request: Request) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { reviewId, rating, comment, type } = await request.json()

    if (!reviewId) {
      return NextResponse.json({ error: 'Missing review ID' }, { status: 400 })
    }

    const updateData: any = {}
    if (rating !== undefined) updateData.rating = parseInt(rating)
    if (comment !== undefined) updateData.comment = comment

    let updated
    if (type === 'RESTAURANT') {
      updated = await prisma.restaurantReview.update({
        where: { id: reviewId },
        data: updateData,
      })
    } else {
      updated = await prisma.review.update({
        where: { id: reviewId },
        data: updateData,
      })
    }

    return NextResponse.json(updated)
  } catch (error: any) {
    console.error('Failed to update review:', error)
    return NextResponse.json({ error: 'Failed to update review' }, { status: 500 })
  }
}

export async function DELETE(request: Request) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { reviewId, type } = await request.json()

    if (!reviewId) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    if (type === 'RESTAURANT') {
      await prisma.restaurantReview.delete({ where: { id: reviewId } })
    } else {
      await prisma.review.delete({ where: { id: reviewId } })
    }

    return NextResponse.json({ success: true, message: 'Review deleted successfully' })
  } catch (error: any) {
    console.error('Failed to delete review:', error)
    return NextResponse.json({ error: 'Failed to delete review' }, { status: 500 })
  }
}
