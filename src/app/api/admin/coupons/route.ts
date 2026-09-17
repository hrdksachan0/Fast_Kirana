import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth-guard'

export async function GET() {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error

  try {
    const coupons = await prisma.coupon.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        restaurant: {
          select: { id: true, name: true, slug: true }
        },
        category: {
          select: { id: true, name: true }
        }
      }
    })
    return NextResponse.json(coupons)
  } catch (error: any) {
    console.error('Failed to fetch coupons:', error)
    return NextResponse.json({ error: 'Failed to fetch coupons' }, { status: 500 })
  }
}

export async function POST(request: Request) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error

  try {
    const body = await request.json()
    const { 
      code, 
      discountType, 
      bogoType,
      triggerVariant,
      rewardVariant,
      defaultFreeDishId,
      maxFreeItems = 3,
      bogoDishId,
      autoApply = false,
      badgeText,
      menuSection,
      value = 0, 
      minOrder = 0, 
      maxDiscount, 
      maxUses, 
      isActive = true, 
      expiresAt, 
      categoryId, 
      restaurantId,
      oncePerCustomer = false,
      syncRestaurantBadge = true
    } = body

    if (!code || !discountType) {
      return NextResponse.json({ error: 'Missing required code or discountType' }, { status: 400 })
    }

    const validDiscountTypes = ['FLAT', 'PERCENT', 'BOGO', 'FREE_DELIVERY']
    if (!validDiscountTypes.includes(discountType)) {
      return NextResponse.json({ error: 'Invalid discount type' }, { status: 400 })
    }

    const cleanCode = code.toUpperCase().trim()

    // Determine default badge text if not supplied
    let effectiveBadge = badgeText?.trim() || null
    if (!effectiveBadge) {
      if (discountType === 'BOGO') {
        if (bogoType === 'BUY_LARGE_GET_SMALL') {
          effectiveBadge = `BUY ${triggerVariant?.toUpperCase() || 'LARGE'} GET ${rewardVariant?.toUpperCase() || 'SMALL'} FREE`
        } else if (bogoType === 'CHEAPEST_FREE') {
          effectiveBadge = 'BUY 2 GET CHEAPEST FREE'
        } else {
          effectiveBadge = 'BUY 1 GET 1 FREE'
        }
      } else if (discountType === 'FREE_DELIVERY') {
        effectiveBadge = 'FREE DELIVERY'
      } else if (discountType === 'PERCENT') {
        effectiveBadge = `${value}% OFF`
      } else if (discountType === 'FLAT') {
        effectiveBadge = `FLAT ₹${value} OFF`
      }
    }

    // Insert coupon using raw SQL to ensure proper enum casting
    await prisma.$executeRaw`
      INSERT INTO coupons (
        id, 
        code, 
        "discountType", 
        "bogoType",
        "triggerVariant",
        "rewardVariant",
        "defaultFreeDishId",
        "maxFreeItems",
        "bogoDishId",
        "autoApply",
        "badgeText",
        "menuSection",
        value, 
        "minOrder", 
        "maxDiscount", 
        "maxUses", 
        "usedCount", 
        "isActive", 
        "expiresAt", 
        "createdAt", 
        "categoryId", 
        "restaurantId",
        "oncePerCustomer"
      )
      VALUES (
        gen_random_uuid()::text,
        ${cleanCode},
        ${discountType}::"DiscountType",
        ${bogoType ? bogoType : null}::"BogoType",
        ${triggerVariant || null},
        ${rewardVariant || null},
        ${defaultFreeDishId || null},
        ${maxFreeItems ? parseInt(String(maxFreeItems)) : 3},
        ${bogoDishId || null},
        ${autoApply === true},
        ${effectiveBadge},
        ${menuSection || null},
        ${parseFloat(String(value)) || 0},
        ${parseFloat(String(minOrder)) || 0},
        ${maxDiscount ? parseFloat(String(maxDiscount)) : null},
        ${maxUses ? parseInt(String(maxUses)) : null},
        0,
        ${isActive !== false},
        ${expiresAt ? new Date(expiresAt) : null},
        NOW(),
        ${categoryId || null},
        ${restaurantId || null},
        ${oncePerCustomer === true}
      )
    `

    // Auto-sync restaurant storefront ribbon if requested
    if (restaurantId && syncRestaurantBadge && effectiveBadge) {
      try {
        await prisma.restaurant.update({
          where: { id: restaurantId },
          data: {
            discountOffer: effectiveBadge,
            discountBadge: effectiveBadge,
          }
        })
      } catch (restErr) {
        console.warn('Failed to auto-sync restaurant badge:', restErr)
      }
    }

    const coupon = await prisma.coupon.findFirst({
      where: { code: cleanCode },
      include: {
        restaurant: {
          select: { id: true, name: true, slug: true }
        }
      }
    })

    return NextResponse.json(coupon)
  } catch (error: any) {
    console.error('Failed to create coupon:', error)
    return NextResponse.json({ error: error.message || 'Failed to create coupon' }, { status: 500 })
  }
}

export async function PATCH(request: Request) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error

  try {
    const body = await request.json()
    const { 
      couponId, 
      isActive, 
      value, 
      minOrder, 
      maxDiscount, 
      maxUses, 
      expiresAt, 
      code, 
      discountType, 
      bogoType,
      triggerVariant,
      rewardVariant,
      defaultFreeDishId,
      maxFreeItems,
      bogoDishId,
      autoApply,
      badgeText,
      menuSection,
      categoryId, 
      restaurantId,
      oncePerCustomer,
      syncRestaurantBadge
    } = body

    if (!couponId) {
      return NextResponse.json({ error: 'Missing coupon ID' }, { status: 400 })
    }

    const updateData: any = {}
    if (isActive !== undefined) updateData.isActive = isActive
    if (value !== undefined) updateData.value = parseFloat(String(value))
    if (minOrder !== undefined) updateData.minOrder = parseFloat(String(minOrder))
    if (maxDiscount !== undefined) updateData.maxDiscount = maxDiscount ? parseFloat(String(maxDiscount)) : null
    if (maxUses !== undefined) updateData.maxUses = maxUses ? parseInt(String(maxUses)) : null
    if (expiresAt !== undefined) updateData.expiresAt = expiresAt ? new Date(expiresAt) : null
    if (categoryId !== undefined) updateData.categoryId = categoryId ? categoryId : null
    if (restaurantId !== undefined) updateData.restaurantId = restaurantId ? restaurantId : null
    if (menuSection !== undefined) updateData.menuSection = menuSection ? menuSection : null
    if (oncePerCustomer !== undefined) updateData.oncePerCustomer = oncePerCustomer
    if (triggerVariant !== undefined) updateData.triggerVariant = triggerVariant
    if (rewardVariant !== undefined) updateData.rewardVariant = rewardVariant
    if (defaultFreeDishId !== undefined) updateData.defaultFreeDishId = defaultFreeDishId
    if (maxFreeItems !== undefined) updateData.maxFreeItems = maxFreeItems ? parseInt(String(maxFreeItems)) : 3
    if (bogoDishId !== undefined) updateData.bogoDishId = bogoDishId
    if (autoApply !== undefined) updateData.autoApply = autoApply
    if (badgeText !== undefined) updateData.badgeText = badgeText

    if (code !== undefined) {
      const codeUpper = code.toUpperCase().trim()
      if (!codeUpper) {
        return NextResponse.json({ error: 'Coupon code cannot be empty' }, { status: 400 })
      }
      const existing = await prisma.coupon.findFirst({
        where: { code: codeUpper, id: { not: couponId } }
      })
      if (existing) {
        return NextResponse.json({ error: 'Coupon code already exists' }, { status: 400 })
      }
      updateData.code = codeUpper
    }

    if (discountType !== undefined) {
      await prisma.$executeRaw`
        UPDATE coupons SET "discountType" = ${discountType}::"DiscountType" WHERE id = ${couponId}
      `
    }

    if (bogoType !== undefined) {
      await prisma.$executeRaw`
        UPDATE coupons SET "bogoType" = ${bogoType ? bogoType : null}::"BogoType" WHERE id = ${couponId}
      `
    }

    const coupon = await prisma.coupon.update({
      where: { id: couponId },
      data: updateData,
      include: {
        restaurant: {
          select: { id: true, name: true, slug: true }
        }
      }
    })

    // Auto-sync restaurant badge on edit if requested
    if (coupon.restaurantId && syncRestaurantBadge && coupon.badgeText) {
      try {
        await prisma.restaurant.update({
          where: { id: coupon.restaurantId },
          data: {
            discountOffer: coupon.badgeText,
            discountBadge: coupon.badgeText,
          }
        })
      } catch (restErr) {
        console.warn('Failed to sync restaurant badge on edit:', restErr)
      }
    }

    return NextResponse.json(coupon)
  } catch (error: any) {
    console.error('Failed to update coupon:', error)
    return NextResponse.json({ error: error.message || 'Failed to update coupon' }, { status: 500 })
  }
}

export async function DELETE(request: Request) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error

  try {
    const { couponId } = await request.json()

    if (!couponId) {
      return NextResponse.json({ error: 'Missing coupon ID' }, { status: 400 })
    }

    await prisma.coupon.delete({
      where: { id: couponId },
    })

    return NextResponse.json({ success: true, message: 'Coupon deleted successfully' })
  } catch (error: any) {
    console.error('Failed to delete coupon:', error)
    return NextResponse.json({ error: 'Failed to delete coupon' }, { status: 500 })
  }
}
