import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function GET() {
  try {
    const now = new Date()
    const coupons = await prisma.coupon.findMany({
      where: {
        isActive: true,
      },
      select: {
        id: true,
        code: true,
        discountType: true,
        value: true,
        minOrder: true,
        maxDiscount: true,
        categoryId: true,
        restaurantId: true,
        isActive: true,
        expiresAt: true,
      },
      orderBy: { value: 'desc' },
    })

    const validCoupons = coupons.filter(c => !c.expiresAt || new Date(c.expiresAt) > now)

    return NextResponse.json(validCoupons, {
      headers: {
        'Cache-Control': 'public, s-maxage=30, stale-while-revalidate=60',
      },
    })
  } catch (error: any) {
    console.error('Error fetching public coupons:', error)
    return NextResponse.json([], { status: 200 })
  }
}
