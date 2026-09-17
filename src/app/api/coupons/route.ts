import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const restaurantId = searchParams.get('restaurantId')
    const now = new Date()

    const whereClause: any = {
      isActive: true,
      OR: [
        { expiresAt: null },
        { expiresAt: { gt: now } },
      ],
    }

    if (restaurantId) {
      whereClause.AND = [
        {
          OR: [
            { restaurantId: restaurantId },
            { restaurantId: null, categoryId: null }, // Global coupons also available
          ],
        },
      ]
    }

    const coupons = await prisma.coupon.findMany({
      where: whereClause,
      select: {
        id: true,
        code: true,
        discountType: true,
        bogoType: true,
        triggerVariant: true,
        rewardVariant: true,
        defaultFreeDishId: true,
        maxFreeItems: true,
        bogoDishId: true,
        autoApply: true,
        badgeText: true,
        menuSection: true,
        value: true,
        minOrder: true,
        maxDiscount: true,
        categoryId: true,
        restaurantId: true,
        isActive: true,
        expiresAt: true,
        restaurant: {
          select: {
            id: true,
            name: true,
            slug: true,
          }
        }
      },
      orderBy: [
        { autoApply: 'desc' },
        { value: 'desc' },
      ],
    })

    return NextResponse.json(coupons, {
      headers: {
        'Cache-Control': 'no-store, max-age=0',
      },
    })
  } catch (error: any) {
    console.error('Error fetching coupons:', error)
    return NextResponse.json([], { status: 200 })
  }
}
