import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const isOwner = role === 'RESTAURANT_OWNER' || role === 'ADMIN'
    if (!isOwner) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const restaurantId = (session.user as any).assignedRestaurantId
    if (!restaurantId && role !== 'ADMIN') {
      return NextResponse.json({ error: 'No restaurant assigned' }, { status: 400 })
    }

    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const where: any = { createdAt: { gte: today } }
    if (role !== 'ADMIN') {
      where.restaurantId = restaurantId
    }

    const [todayOrders, pendingCount, totalRevenue] = await Promise.all([
      prisma.order.count({ where }),
      prisma.order.count({ where: { ...where, status: 'PENDING' } }),
      prisma.order.aggregate({
        where: { ...where, status: { in: ['CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED'] } },
        _sum: { total: true },
      }),
    ])

    return NextResponse.json({
      todayOrders,
      pendingCount,
      totalRevenue: totalRevenue._sum.total || 0,
    })
  } catch (error) {
    console.error('Restaurant dashboard stats error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
