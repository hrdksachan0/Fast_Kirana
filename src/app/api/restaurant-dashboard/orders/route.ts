import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { normalizeRestaurantId } from '@/lib/restaurant-ids'
import { logger } from '@/lib/logger'
import { OrderStatus, Prisma } from '@prisma/client'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    const { searchParams } = new URL(request.url)
    const paramRestId = searchParams.get('restaurantId')
    const headerPhone = request.headers.get('x-user-phone')
    const headerUserId = request.headers.get('x-user-id')
    const cleanPhone = headerPhone ? headerPhone.replace(/[^0-9]/g, '') : ''

    const isPlatformAdmin = session?.user?.role === 'ADMIN'
    const sessionRestId = session?.user?.assignedRestaurantId

    // Strict tenant isolation: If not admin, always force their own assigned restaurant ID
    let effectiveRestId = (!isPlatformAdmin && sessionRestId)
      ? sessionRestId
      : (paramRestId || sessionRestId)

    if (!effectiveRestId && cleanPhone) {
      const last10 = cleanPhone.slice(-10)
      const dbUser = await prisma.user.findFirst({
        where: {
          OR: [
            { phone: { endsWith: last10 } },
            { phone: `+91${last10}` }
          ],
          assignedRestaurantId: { not: null }
        },
        select: { assignedRestaurantId: true }
      })
      if (dbUser?.assignedRestaurantId) {
        effectiveRestId = dbUser.assignedRestaurantId
      } else {
        const rest = await prisma.restaurant.findFirst({
          where: { ownerPhone: { contains: last10 } },
          select: { id: true }
        })
        if (rest) effectiveRestId = rest.id
      }
    }

    if (!effectiveRestId && headerUserId) {
      const dbUser = await prisma.user.findUnique({
        where: { id: headerUserId },
        select: { assignedRestaurantId: true, role: true }
      })
      if (dbUser?.assignedRestaurantId) {
        effectiveRestId = dbUser.assignedRestaurantId
      }
    }

    // Universal normalization to canonical ID
    effectiveRestId = normalizeRestaurantId(effectiveRestId)

    // If no restaurant ID resolved, return empty list (no mixup)
    if (!effectiveRestId) {
      return NextResponse.json([])
    }

    const status = searchParams.get('status')

    const where: Prisma.OrderWhereInput = {
      OR: [
        { paymentMethod: 'COD' },
        { paymentStatus: 'PAID' }
      ]
    }
    if (effectiveRestId) {
      where.AND = [
        {
          OR: [
            { restaurantId: effectiveRestId },
            { storeId: effectiveRestId },
          ]
        }
      ]
    }
    const VALID_ORDER_STATUSES: OrderStatus[] = [
      OrderStatus.PENDING,
      OrderStatus.CONFIRMED,
      OrderStatus.PACKED,
      OrderStatus.SHIPPED,
      OrderStatus.DELIVERED,
      OrderStatus.CANCELLED
    ]

    if (status) {
      if (status === 'live' || status === 'active') {
        where.status = { in: [OrderStatus.PENDING, OrderStatus.CONFIRMED, OrderStatus.PACKED, OrderStatus.SHIPPED] }
      } else if (status.includes(',')) {
        const statuses = status
          .split(',')
          .map(s => s.trim().toUpperCase())
          .filter((s): s is OrderStatus => VALID_ORDER_STATUSES.includes(s as OrderStatus))
        if (statuses.length > 0) {
          where.status = { in: statuses }
        }
      } else {
        const upper = status.trim().toUpperCase()
        if (VALID_ORDER_STATUSES.includes(upper as OrderStatus)) {
          where.status = upper as OrderStatus
        }
      }
    }

    const limit = Math.min(parseInt(searchParams.get('limit') || '50'), 100)

    const rawOrders = await prisma.order.findMany({
      where,
      include: {
        items: true,
        address: true,
        user: { select: { name: true, phone: true } },
        restaurant: { select: { id: true, name: true, ownerPhone: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    })

    const orders = rawOrders.map(o => ({
      ...o,
      restaurantName: o.restaurant?.name || o.shopName || '',
    }))

    // Fetch restaurant commission rate for Sales tab
    let commissionRate = 0.15
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

    const commissionPercent = Math.round(commissionRate * 100)

    return NextResponse.json({ orders, commissionRate: commissionPercent, commissionDecimal: commissionRate, restaurantName })
  } catch (error: unknown) {
    logger.error('restaurant-orders', 'Restaurant dashboard orders GET error', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

export async function PATCH(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const isOwner = role === 'RESTAURANT_OWNER' || role === 'ADMIN' || role === 'CHEF'
    if (!isOwner) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const { orderId, action, restaurantId } = await request.json()

    if (!orderId || !action) {
      return NextResponse.json({ error: 'Missing orderId or action' }, { status: 400 })
    }

    const order = await prisma.order.findUnique({ where: { id: orderId } })
    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }
    const targetRestId = restaurantId || session.user.assignedRestaurantId
    if (role !== 'ADMIN' && order.restaurantId !== targetRestId) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    let updateData: Prisma.OrderUpdateInput = {}

    switch (action) {
      case 'accept':
        if (order.status !== 'PENDING') {
          return NextResponse.json({ error: 'Can only accept PENDING orders' }, { status: 400 })
        }
        updateData = { status: 'CONFIRMED', confirmedAt: new Date() }
        break

      case 'pack':
        if (order.status !== 'CONFIRMED') {
          return NextResponse.json({ error: 'Can only pack CONFIRMED orders' }, { status: 400 })
        }
        updateData = { status: 'PACKED', packedAt: new Date() }
        break

      case 'reject':
        if (!['PENDING', 'CONFIRMED'].includes(order.status)) {
          return NextResponse.json({ error: 'Cannot reject this order' }, { status: 400 })
        }
        updateData = { status: 'CANCELLED' }
        break

      default:
        return NextResponse.json({ error: 'Invalid action. Use: accept, pack, reject' }, { status: 400 })
    }

    const updated = await prisma.order.update({
      where: { id: orderId },
      data: updateData,
      include: { items: true },
    })

    return NextResponse.json({ order: updated })
  } catch (error: unknown) {
    logger.error('restaurant-orders', 'Restaurant dashboard orders PATCH error', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
