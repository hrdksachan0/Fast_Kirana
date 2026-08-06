import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'

export async function GET(request: Request) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  const { searchParams } = new URL(request.url)
  const page = parseInt(searchParams.get('page') || '1')
  const limit = parseInt(searchParams.get('limit') || '20')
  const status = searchParams.get('status')
  const search = searchParams.get('search')
  
  const skip = (page - 1) * limit

  try {
    const where: any = {}

    if (status && status !== 'ALL') {
      where.status = status
    }

    if (search) {
      where.OR = [
        { id: { contains: search, mode: 'insensitive' } },
        { user: { name: { contains: search, mode: 'insensitive' } } },
        { user: { email: { contains: search, mode: 'insensitive' } } },
        { shopName: { contains: search, mode: 'insensitive' } },
      ]
    }

    const whereForCounts = { ...where }
    delete whereForCounts.status

    let ordersRaw: any[] = []
    
    // Construct dynamic raw SQL query based on filters to avoid enum deserialization bug
    if (status && status !== 'ALL' && search) {
      const searchLike = `%${search}%`
      ordersRaw = await prisma.$queryRaw`
        SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
               o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId"
        FROM orders o
        LEFT JOIN users u ON o."userId" = u.id
        WHERE o.status::text = ${status}
          AND (
            o.id ILIKE ${searchLike}
            OR o."readableId"::text ILIKE ${searchLike}
            OR u.name ILIKE ${searchLike}
            OR u.email ILIKE ${searchLike}
            OR o."shopName" ILIKE ${searchLike}
          )
        ORDER BY o."createdAt" DESC
        LIMIT ${limit} OFFSET ${skip}
      `
    } else if (status && status !== 'ALL') {
      ordersRaw = await prisma.$queryRaw`
        SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
               o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId"
        FROM orders o
        WHERE o.status::text = ${status}
        ORDER BY o."createdAt" DESC
        LIMIT ${limit} OFFSET ${skip}
      `
    } else if (search) {
      const searchLike = `%${search}%`
      ordersRaw = await prisma.$queryRaw`
        SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
               o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId"
        FROM orders o
        LEFT JOIN users u ON o."userId" = u.id
        WHERE o.id ILIKE ${searchLike}
          OR o."readableId"::text ILIKE ${searchLike}
          OR u.name ILIKE ${searchLike}
          OR u.email ILIKE ${searchLike}
          OR o."shopName" ILIKE ${searchLike}
        ORDER BY o."createdAt" DESC
        LIMIT ${limit} OFFSET ${skip}
      `
    } else {
      ordersRaw = await prisma.$queryRaw`
        SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
               o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId"
        FROM orders o
        ORDER BY o."createdAt" DESC
        LIMIT ${limit} OFFSET ${skip}
      `
    }

    const orderIds = ordersRaw.map(o => o.id)
    const userIds = [...new Set(ordersRaw.map(o => o.userId))]
    const addressIds = [...new Set(ordersRaw.map(o => o.addressId))].filter(Boolean)
    const restaurantIds = [...new Set(ordersRaw.map(o => o.restaurantId))].filter(Boolean)

    const startOfToday = new Date()
    startOfToday.setHours(0, 0, 0, 0)

    const [allUsers, allAddresses, allOrderItems, allRestaurants, total, allCount, pendingCount, confirmedCount, packedCount, shippedCount, deliveredCount, cancelledCount, todaySalesAgg] = await Promise.all([
      userIds.length > 0
        ? (prisma.$queryRaw`
            SELECT id, name, email, phone FROM users WHERE id = ANY(${userIds})
          ` as Promise<any[]>)
        : [],
      addressIds.length > 0
        ? prisma.address.findMany({ where: { id: { in: addressIds } } })
        : [],
      orderIds.length > 0
        ? prisma.orderItem.findMany({ where: { orderId: { in: orderIds } } })
        : [],
      restaurantIds.length > 0
        ? prisma.restaurant.findMany({ where: { id: { in: restaurantIds } }, select: { id: true, name: true, address: true, logoUrl: true } })
        : [],
      prisma.order.count({ where }),
      prisma.order.count({ where: whereForCounts }),
      prisma.order.count({ where: { ...whereForCounts, status: 'PENDING' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'CONFIRMED' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'PACKED' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'SHIPPED' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'DELIVERED' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'CANCELLED' } }),
      prisma.order.aggregate({
        where: {
          createdAt: { gte: startOfToday },
          status: { not: 'CANCELLED' },
        },
        _sum: { total: true },
        _count: { id: true },
      }),
    ])

    const todaySales = todaySalesAgg._sum?.total || 0
    const todayOrdersCount = todaySalesAgg._count?.id || 0

    const orders = ordersRaw.map((o) => {
      const user = allUsers.find(u => u.id === o.userId) || { name: 'Customer', email: '', phone: '' }
      const address = allAddresses.find(a => a.id === o.addressId) || null
      const restaurant = o.restaurantId ? allRestaurants.find(r => r.id === o.restaurantId) : null
      const items = allOrderItems.filter(item => item.orderId === o.id).map(item => ({
        id: item.id,
        name: item.name,
        price: item.price,
        quantity: item.quantity,
        imageUrl: item.imageUrl,
        selectedVariant: item.selectedVariant,
      }))

      return {
        id: o.id,
        readableId: o.readableId,
        status: o.status,
        total: o.total,
        createdAt: new Date(o.createdAt).toISOString(),
        updatedAt: new Date(o.updatedAt).toISOString(),
        userName: user.name,
        userEmail: user.email,
        userPhone: user.phone,
        isB2B: o.isB2B,
        deliveryMethod: o.deliveryMethod,
        shopName: o.shopName,
        restaurantId: o.restaurantId,
        restaurantName: restaurant?.name || o.shopName,
        restaurant,
        shopPhone: o.shopPhone,
        items,
        address: address ? {
          houseNo: address.houseNo,
          street: address.street,
          area: address.area,
          city: address.city,
          phone: address.phone,
        } : null,
      }
    })

    return NextResponse.json({
      orders,
      total,
      page,
      limit,
      todaySales,
      todayOrdersCount,
      counts: {
        ALL: allCount,
        PENDING: pendingCount,
        CONFIRMED: confirmedCount,
        PACKED: packedCount,
        SHIPPED: shippedCount,
        DELIVERED: deliveredCount,
        CANCELLED: cancelledCount,
      }
    })
  } catch (error: any) {
    console.error('Failed to fetch admin orders:', error)
    return NextResponse.json({ error: 'Failed to fetch orders' }, { status: 500 })
  }
}
