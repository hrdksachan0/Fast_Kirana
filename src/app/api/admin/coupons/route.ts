import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET() {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const coupons = await prisma.coupon.findMany({
      orderBy: { createdAt: 'desc' },
    })
    return NextResponse.json(coupons)
  } catch (error: any) {
    console.error('Failed to fetch coupons:', error)
    return NextResponse.json({ error: 'Failed to fetch coupons' }, { status: 500 })
  }
}

export async function POST(request: Request) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { code, discountType, value, minOrder, maxDiscount, maxUses, isActive, expiresAt, categoryId, oncePerCustomer } = await request.json()

    if (!code || !discountType || value === undefined) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    if (discountType !== 'FLAT' && discountType !== 'PERCENT') {
      return NextResponse.json({ error: 'Invalid discount type' }, { status: 400 })
    }

    // Use raw SQL to bypass PrismaPg enum casting issue
    await prisma.$executeRaw`
      INSERT INTO coupons (id, code, "discountType", value, "minOrder", "maxDiscount", "maxUses", "usedCount", "isActive", "expiresAt", "createdAt", "categoryId", "oncePerCustomer")
      VALUES (
        gen_random_uuid()::text,
        ${code.toUpperCase()},
        ${discountType}::"DiscountType",
        ${parseFloat(value)},
        ${parseFloat(minOrder) || 0},
        ${maxDiscount ? parseFloat(maxDiscount) : null},
        ${maxUses ? parseInt(maxUses) : null},
        0,
        ${isActive !== false},
        ${expiresAt ? new Date(expiresAt) : null},
        NOW(),
        ${categoryId || null},
        ${oncePerCustomer === true}
      )
    `

    const coupon = await prisma.coupon.findFirst({
      where: { code: code.toUpperCase() },
    })

    return NextResponse.json(coupon)
  } catch (error: any) {
    console.error('Failed to create coupon:', error)
    return NextResponse.json({ error: 'Failed to create coupon' }, { status: 500 })
  }
}

export async function PATCH(request: Request) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { couponId, isActive, value, minOrder, maxDiscount, maxUses, expiresAt, code, discountType, categoryId, oncePerCustomer } = await request.json()

    if (!couponId) {
      return NextResponse.json({ error: 'Missing coupon ID' }, { status: 400 })
    }

    const updateData: any = {}
    if (isActive !== undefined) updateData.isActive = isActive
    if (value !== undefined) updateData.value = parseFloat(value)
    if (minOrder !== undefined) updateData.minOrder = parseFloat(minOrder)
    if (maxDiscount !== undefined) updateData.maxDiscount = maxDiscount ? parseFloat(maxDiscount) : null
    if (maxUses !== undefined) updateData.maxUses = maxUses ? parseInt(maxUses) : null
    if (expiresAt !== undefined) updateData.expiresAt = expiresAt ? new Date(expiresAt) : null
    if (categoryId !== undefined) updateData.categoryId = categoryId ? categoryId : null
    if (oncePerCustomer !== undefined) updateData.oncePerCustomer = oncePerCustomer

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
      if (discountType !== 'FLAT' && discountType !== 'PERCENT') {
        return NextResponse.json({ error: 'Invalid discount type' }, { status: 400 })
      }
      // Update custom enum using raw SQL to bypass PrismaPg cast issues
      await prisma.$executeRaw`
        UPDATE coupons SET "discountType" = ${discountType}::"DiscountType" WHERE id = ${couponId}
      `
    }

    const coupon = await prisma.coupon.update({
      where: { id: couponId },
      data: updateData,
    })

    return NextResponse.json(coupon)
  } catch (error: any) {
    console.error('Failed to update coupon:', error)
    return NextResponse.json({ error: 'Failed to update coupon' }, { status: 500 })
  }
}

export async function DELETE(request: Request) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

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
