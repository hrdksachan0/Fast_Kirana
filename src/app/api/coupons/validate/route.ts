import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { couponLimiter } from '@/lib/rate-limit'

export async function POST(request: Request) {
  // Prevent coupon-code enumeration via brute force.
  // Coupon codes are short and guessable; without this, an attacker can
  // POST every 3-letter combination to find valid codes.
  const limited = await couponLimiter.check(request as any)
  if (limited) return limited

  try {
    const { code, subtotal, items } = await request.json()

    if (!code) {
      return NextResponse.json({ error: 'Coupon code is required' }, { status: 400 })
    }

    const session = await auth()

    const coupon = await prisma.coupon.findUnique({
      where: { code: code.toUpperCase() },
    })

    if (!coupon || !coupon.isActive) {
      return NextResponse.json({ error: 'Invalid or inactive coupon code' }, { status: 400 })
    }

    // Check once per customer restriction
    if (coupon.oncePerCustomer) {
      if (!session?.user?.id) {
        return NextResponse.json({ error: 'Please log in to use this coupon' }, { status: 400 })
      }
      const alreadyUsed = await prisma.order.findFirst({
        where: {
          userId: session.user.id,
          couponCode: code.toUpperCase(),
          status: { not: 'CANCELLED' }
        }
      })
      if (alreadyUsed) {
        return NextResponse.json({ error: 'You have already used this coupon code once' }, { status: 400 })
      }
    }

    // Check expiration
    if (coupon.expiresAt && new Date(coupon.expiresAt) < new Date()) {
      return NextResponse.json({ error: 'Coupon code has expired' }, { status: 400 })
    }

    // Check usage limits
    if (coupon.maxUses && coupon.usedCount >= coupon.maxUses) {
      return NextResponse.json({ error: 'Coupon code limit reached' }, { status: 400 })
    }

    // Check category restriction
    let eligibleSubtotal = subtotal
    if (coupon.categoryId) {
      if (!items || !Array.isArray(items) || items.length === 0) {
        return NextResponse.json({ error: 'This coupon is restricted to a category. Cart items are required.' }, { status: 400 })
      }

      const categoryItems = items.filter((item: any) => item.categoryId === coupon.categoryId)
      const categorySubtotal = categoryItems.reduce((sum: number, item: any) => sum + (item.price * item.quantity), 0)

      if (categorySubtotal === 0) {
        return NextResponse.json({ error: 'This coupon is only valid for items in the restricted category.' }, { status: 400 })
      }

      if (categorySubtotal < coupon.minOrder) {
        return NextResponse.json(
          { error: `Minimum order of ₹${coupon.minOrder} in the restricted category is required.` },
          { status: 400 }
        )
      }
      eligibleSubtotal = categorySubtotal
    } else if (coupon.restaurantId) {
      if (!items || !Array.isArray(items) || items.length === 0) {
        return NextResponse.json({ error: 'This coupon is restricted to a restaurant. Cart items are required.' }, { status: 400 })
      }

      const restaurant = await prisma.restaurant.findUnique({
        where: { id: coupon.restaurantId },
        select: { name: true }
      })

      const restaurantItems = items.filter((item: any) => {
        const itemRestaurantId = item.restaurantId || item.product?.restaurantId
        return itemRestaurantId === coupon.restaurantId
      })
      const restaurantSubtotal = restaurantItems.reduce((sum: number, item: any) => sum + (item.price * item.quantity), 0)

      if (restaurantSubtotal === 0) {
        return NextResponse.json({ error: `This coupon is only valid for items from ${restaurant?.name || 'the restricted restaurant'}.` }, { status: 400 })
      }

      if (restaurantSubtotal < coupon.minOrder) {
        return NextResponse.json(
          { error: `Minimum order of ₹${coupon.minOrder} from ${restaurant?.name || 'the restaurant'} is required.` },
          { status: 400 }
        )
      }
      eligibleSubtotal = restaurantSubtotal
    } else {
      // Check minimum order value against overall subtotal
      if (subtotal < coupon.minOrder) {
        return NextResponse.json(
          { error: `Minimum order of ₹${coupon.minOrder} required for this coupon` },
          { status: 400 }
        )
      }
    }

    // Calculate discount amount
    let discountAmount = 0
    if (coupon.discountType === 'FLAT') {
      discountAmount = Math.min(coupon.value, eligibleSubtotal)
    } else if (coupon.discountType === 'PERCENT') {
      discountAmount = (eligibleSubtotal * coupon.value) / 100
      if (coupon.maxDiscount) {
        discountAmount = Math.min(discountAmount, coupon.maxDiscount)
      }
    }

    return NextResponse.json({
      message: 'Coupon applied successfully!',
      coupon: {
        id: coupon.id,
        code: coupon.code,
        discountType: coupon.discountType,
        value: coupon.value,
        discountAmount,
      },
    })

  } catch (error: any) {
    console.error('Coupon validation error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
