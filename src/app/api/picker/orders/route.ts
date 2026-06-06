import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(request: Request) {
  const session = await auth()
  if (!session || (session.user.role !== 'PICKER' && session.user.role !== 'ADMIN' && session.user.role !== 'CHEF')) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const { searchParams } = new URL(request.url)
  const type = searchParams.get('type') // 'cafe' or 'grocery'

  if (session.user.role === 'CHEF' && type !== 'cafe') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }
  if (session.user.role === 'PICKER' && type === 'cafe') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    // Fetch PENDING (Placed) and CONFIRMED (Preparing/Picking) orders
    let orders: any[] = []
    
    if (type === 'cafe') {
      orders = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId",
               o.status::text as status,
               o.subtotal, o.discount, o."deliveryFee", o.taxes, o.total,
               o."paymentMethod"::text as "paymentMethod",
               o."paymentStatus"::text as "paymentStatus",
               o."estimatedDelivery", o."createdAt", o."deliveryMethod",
               o."shopName"
        FROM orders o
        WHERE o.status IN ('PENDING', 'CONFIRMED')
          AND o."shopName" = 'FastKirana Cafe Kitchen'
        ORDER BY o."createdAt" ASC
      `
    } else {
      orders = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId",
               o.status::text as status,
               o.subtotal, o.discount, o."deliveryFee", o.taxes, o.total,
               o."paymentMethod"::text as "paymentMethod",
               o."paymentStatus"::text as "paymentStatus",
               o."estimatedDelivery", o."createdAt", o."deliveryMethod",
               o."shopName"
        FROM orders o
        WHERE o.status IN ('PENDING', 'CONFIRMED')
          AND (o."shopName" IS NULL OR o."shopName" != 'FastKirana Cafe Kitchen')
        ORDER BY o."createdAt" ASC
      `
    }

    const orderIds = orders.map(o => o.id)
    const userIds = [...new Set(orders.map(o => o.userId))]
    const addressIds = [...new Set(orders.map(o => o.addressId))]

    const [allItems, allUsers, allAddresses] = await Promise.all([
      orderIds.length > 0
        ? prisma.orderItem.findMany({ where: { orderId: { in: orderIds } } })
        : [],
      userIds.length > 0
        ? prisma.$queryRaw`
            SELECT id, name, phone FROM users WHERE id = ANY(${userIds})
          ` as Promise<any[]>
        : [],
      addressIds.length > 0
        ? prisma.address.findMany({ where: { id: { in: addressIds } } })
        : [],
    ])

    const result = await Promise.all(
      orders.map(async (o) => {
        const orderItems = allItems.filter(item => item.orderId === o.id)
        const user = allUsers.find(u => u.id === o.userId) || { name: 'Customer', phone: null }
        const address = allAddresses.find(a => a.id === o.addressId)

        // Find companion order (same user, different order id, same time window)
        const fiveSecondsAgo = new Date(new Date(o.createdAt).getTime() - 5000)
        const fiveSecondsAfter = new Date(new Date(o.createdAt).getTime() + 5000)

        const companion = await prisma.order.findFirst({
          where: {
            userId: o.userId,
            id: { not: o.id },
            createdAt: {
              gte: fiveSecondsAgo,
              lte: fiveSecondsAfter,
            },
          },
          select: {
            id: true,
            status: true,
            shopName: true,
            items: {
              select: {
                id: true,
                name: true,
                quantity: true,
              },
            },
          },
        })

        return {
          ...o,
          items: orderItems,
          user,
          address,
          companionOrder: companion
            ? {
                id: companion.id,
                status: companion.status,
                shopName: companion.shopName,
                items: companion.items,
              }
            : null,
        }
      })
    )

    return NextResponse.json(result)
  } catch (error: any) {
    console.error('Picker orders API error:', error)
    return NextResponse.json({ error: 'Failed to fetch picker orders' }, { status: 500 })
  }
}
