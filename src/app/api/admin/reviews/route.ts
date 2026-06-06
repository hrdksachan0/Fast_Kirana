import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET() {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const reviews = await prisma.review.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, name: true, email: true } },
        product: { select: { id: true, name: true, slug: true, imageUrl: true } },
      },
    })

    const serialized = reviews.map((review) => ({
      ...review,
      createdAt: review.createdAt.toISOString(),
    }))

    return NextResponse.json(serialized)
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
    const { reviewId, rating, comment } = await request.json()

    if (!reviewId) {
      return NextResponse.json({ error: 'Missing review ID' }, { status: 400 })
    }

    const updateData: any = {}
    if (rating !== undefined) updateData.rating = parseInt(rating)
    if (comment !== undefined) updateData.comment = comment

    const updated = await prisma.review.update({
      where: { id: reviewId },
      data: updateData,
    })

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
    const { reviewId } = await request.json()

    if (!reviewId) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    await prisma.review.delete({ where: { id: reviewId } })

    return NextResponse.json({ success: true, message: 'Review deleted successfully' })
  } catch (error: any) {
    console.error('Failed to delete review:', error)
    return NextResponse.json({ error: 'Failed to delete review' }, { status: 500 })
  }
}
