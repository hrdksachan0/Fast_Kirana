import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { getLast10Digits } from '@/lib/phone'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    const { searchParams } = new URL(request.url)
    const paramRestId = searchParams.get('restaurantId')
    const headerPhone = request.headers.get('x-user-phone')
    const cleanPhone = headerPhone ? getLast10Digits(headerPhone) : ''

    const isPlatformAdmin = session?.user?.role === 'ADMIN'
    const sessionRestId = (session?.user as any)?.assignedRestaurantId

    let effectiveRestId = (!isPlatformAdmin && sessionRestId)
      ? sessionRestId
      : (paramRestId || sessionRestId)

    if (!effectiveRestId && cleanPhone) {
      const dbUser = await prisma.user.findFirst({
        where: {
          OR: [
            { phone: { endsWith: cleanPhone } },
            { phone: `+91${cleanPhone}` }
          ],
          assignedRestaurantId: { not: null }
        },
        select: { assignedRestaurantId: true }
      })
      if (dbUser?.assignedRestaurantId) {
        effectiveRestId = dbUser.assignedRestaurantId
      } else {
        const rest = await prisma.restaurant.findFirst({
          where: { ownerPhone: { contains: cleanPhone } },
          select: { id: true }
        })
        if (rest) effectiveRestId = rest.id
      }
    }

    // If still not resolved and session user is restaurant owner
    if (!effectiveRestId && session?.user?.id) {
      const user = await prisma.user.findUnique({
        where: { id: session.user.id },
        select: { assignedRestaurantId: true, role: true }
      })
      if (user?.assignedRestaurantId) {
        effectiveRestId = user.assignedRestaurantId
      }
    }

    // If no restaurant resolved, return clean zero stats
    if (!effectiveRestId) {
      return NextResponse.json({
        totalRevenue: 0,
        netPayout: 0,
        totalOrders: 0,
        pendingOrders: 0,
        completedOrders: 0,
        commissionRate: 0.15,
        restaurantName: '',
        todayRevenue: 0,
        todayOrders: 0
      })
    }

    let commissionRate = 0.25
    let restaurantName = ''
    if (effectiveRestId) {
      const rest = await prisma.restaurant.findUnique({
        where: { id: effectiveRestId },
        select: { commissionRate: true, name: true }
      })
      if (rest) {
        restaurantName = rest.name || ''
        if (rest.commissionRate != null) {
          commissionRate = rest.commissionRate > 1.0 ? rest.commissionRate / 100 : rest.commissionRate
        }
      }
    }

    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const where: any = {
      createdAt: { gte: today },
      status: { not: 'CANCELLED' }
    }

    if (effectiveRestId) {
      where.OR = [
        { restaurantId: effectiveRestId },
        { storeId: effectiveRestId },
      ]
    }

    const [todayOrders, pendingCount, totalRevenueAgg] = await Promise.all([
      prisma.order.count({ where }),
      prisma.order.count({ where: { ...where, status: 'PENDING' } }),
      prisma.order.aggregate({
        where: { ...where, status: { in: ['CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED'] } },
        _sum: { total: true, refundAmount: true },
      }),
    ])

    const rawTotal = totalRevenueAgg._sum.total || 0
    const rawRefund = totalRevenueAgg._sum.refundAmount || 0
    const totalSales = Math.max(0, Math.round((rawTotal - rawRefund) * 100) / 100)
    const commissionPercent = Math.round(commissionRate * 100)
    const restaurantProfit = Math.round(totalSales * (1 - commissionRate) * 100) / 100

    return NextResponse.json({
      restaurantName,
      todayOrders,
      ordersCount: todayOrders,
      totalSales,
      totalRevenue: totalSales,
      commissionRate: commissionPercent,
      commissionDecimal: commissionRate,
      restaurantProfit,
      pendingCount,
      grossSales: totalSales,
    })
  } catch (error) {
    console.error('Restaurant dashboard stats error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

