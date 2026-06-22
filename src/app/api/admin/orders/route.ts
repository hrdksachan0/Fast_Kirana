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

    const [
      ordersRaw,
      total,
      allCount,
      pendingCount,
      confirmedCount,
      packedCount,
      shippedCount,
      deliveredCount,
      cancelledCount,
    ] = await Promise.all([
      prisma.order.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        include: {
          user: {
            select: {
              name: true,
              email: true,
            },
          },
          address: true,
        },
        skip,
        take: limit,
      }),
      prisma.order.count({ where }),
      prisma.order.count({ where: whereForCounts }),
      prisma.order.count({ where: { ...whereForCounts, status: 'PENDING' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'CONFIRMED' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'PACKED' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'SHIPPED' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'DELIVERED' } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'CANCELLED' } }),
    ])

    const orders = ordersRaw.map((o) => ({
      id: o.id,
      status: o.status,
      total: o.total,
      createdAt: o.createdAt.toISOString(),
      updatedAt: o.updatedAt.toISOString(),
      userName: o.user.name,
      userEmail: o.user.email,
      isB2B: o.isB2B,
      deliveryMethod: o.deliveryMethod,
      shopName: o.shopName,
      shopPhone: o.shopPhone,
      address: o.address ? {
        houseNo: o.address.houseNo,
        street: o.address.street,
        area: o.address.area,
        city: o.address.city,
      } : null,
    }))

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
