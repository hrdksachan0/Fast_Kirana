import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(request: Request) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

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
        SELECT o.id, o.status::text as status, o.total, o."createdAt", o."updatedAt",
               o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId"
        FROM orders o
        LEFT JOIN users u ON o."userId" = u.id
        WHERE o.status::text = ${status}
          AND (
            o.id ILIKE ${searchLike}
            OR u.name ILIKE ${searchLike}
            OR u.email ILIKE ${searchLike}
            OR o."shopName" ILIKE ${searchLike}
          )
        ORDER BY o."createdAt" DESC
        LIMIT ${limit} OFFSET ${skip}
      `
    } else if (status && status !== 'ALL') {
      ordersRaw = await prisma.$queryRaw`
        SELECT o.id, o.status::text as status, o.total, o."createdAt", o."updatedAt",
               o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId"
        FROM orders o
        WHERE o.status::text = ${status}
        ORDER BY o."createdAt" DESC
        LIMIT ${limit} OFFSET ${skip}
      `
    } else if (search) {
      const searchLike = `%${search}%`
      ordersRaw = await prisma.$queryRaw`
        SELECT o.id, o.status::text as status, o.total, o."createdAt", o."updatedAt",
               o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId"
        FROM orders o
        LEFT JOIN users u ON o."userId" = u.id
        WHERE o.id ILIKE ${searchLike}
          OR u.name ILIKE ${searchLike}
          OR u.email ILIKE ${searchLike}
          OR o."shopName" ILIKE ${searchLike}
        ORDER BY o."createdAt" DESC
        LIMIT ${limit} OFFSET ${skip}
      `
    } else {
      ordersRaw = await prisma.$queryRaw`
        SELECT o.id, o.status::text as status, o.total, o."createdAt", o."updatedAt",
               o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId"
        FROM orders o
        ORDER BY o."createdAt" DESC
        LIMIT ${limit} OFFSET ${skip}
      `
    }

    const userIds = [...new Set(ordersRaw.map(o => o.userId))]
    const addressIds = [...new Set(ordersRaw.map(o => o.addressId))].filter(Boolean)

    const [allUsers, allAddresses, total, allCount, pendingCount, confirmedCount, packedCount, shippedCount, deliveredCount, cancelledCount] = await Promise.all([
      userIds.length > 0
        ? (prisma.$queryRaw`
            SELECT id, name, email, phone FROM users WHERE id = ANY(${userIds})
          ` as Promise<any[]>)
        : [],
      addressIds.length > 0
        ? prisma.address.findMany({ where: { id: { in: addressIds } } })
        : [],
      prisma.order.count({ where }),
      prisma.order.count({ where: whereForCounts }),
      prisma.order.count({ where: { ...whereForCounts, status: 'PENDING' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'CONFIRMED' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'PACKED' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'SHIPPED' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'DELIVERED' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'CANCELLED' } }),
    ])

    const orders = ordersRaw.map((o) => {
      const user = allUsers.find(u => u.id === o.userId) || { name: 'Customer', email: '', phone: '' }
      const address = allAddresses.find(a => a.id === o.addressId) || null
      return {
        id: o.id,
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
        shopPhone: o.shopPhone,
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
