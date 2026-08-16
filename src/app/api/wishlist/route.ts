import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

const getWishlistDelegate = () => (prisma as any)?.wishlistItem || (prisma as any)?.wishlistItems

// GET /api/wishlist - List user's wishlist
export async function GET() {
  try {
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const delegate = getWishlistDelegate()
    let rawItems: any[] = []
    if (delegate?.findMany) {
      rawItems = await delegate.findMany({
        where: { userId: session.user.id },
        include: {
          product: {
            include: {
              category: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      }).catch(() => [])
    }

    const items = rawItems.map((item: any) => {
      let prod = item.product
      if (prod && typeof prod.variants === 'string') {
        try {
          prod = { ...prod, variants: JSON.parse(prod.variants) }
        } catch {}
      }
      return {
        id: item.id,
        productId: item.productId,
        createdAt: item.createdAt,
        product: prod,
      }
    })

    return NextResponse.json({ items })
  } catch (error) {
    console.error('Wishlist GET error:', error)
    return NextResponse.json({ error: 'Failed to fetch wishlist' }, { status: 500 })
  }
}

// POST /api/wishlist - Add item to wishlist
export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { productId } = await request.json()
    if (!productId) {
      return NextResponse.json({ error: 'Product ID required' }, { status: 400 })
    }

    const delegate = getWishlistDelegate()
    if (!delegate?.upsert) {
      return NextResponse.json({ error: 'Wishlist service unavailable' }, { status: 503 })
    }

    const item = await delegate.upsert({
      where: {
        userId_productId: {
          userId: session.user.id,
          productId,
        },
      },
      create: {
        userId: session.user.id,
        productId,
      },
      update: {},
      include: {
        product: {
          include: {
            category: true,
            images: true,
          },
        },
      },
    })

    return NextResponse.json({ item })
  } catch (error) {
    console.error('Wishlist add error:', error)
    return NextResponse.json({ error: 'Failed to add to wishlist' }, { status: 500 })
  }
}

// DELETE /api/wishlist - Remove item from wishlist
export async function DELETE(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { productId } = await request.json()
    if (!productId) {
      return NextResponse.json({ error: 'Product ID required' }, { status: 400 })
    }

    const delegate = getWishlistDelegate()
    if (delegate?.deleteMany) {
      await delegate.deleteMany({
        where: {
          userId: session.user.id,
          productId,
        },
      })
    }

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Wishlist remove error:', error)
    return NextResponse.json({ error: 'Failed to remove from wishlist' }, { status: 500 })
  }
}
