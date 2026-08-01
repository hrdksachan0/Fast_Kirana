import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET() {
  const session = await auth()
  if (!session || (session.user.role !== 'DELIVERY' && session.user.role !== 'ADMIN')) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const orders: any[] = await prisma.$queryRaw`
      SELECT o.id, o."userId", o."addressId", o."readableId",
             o.status::text as status,
             o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
             o."paymentMethod"::text as "paymentMethod",
             o."paymentStatus"::text as "paymentStatus",
             o."estimatedDelivery", o."createdAt",
             o."shopName", o."deliveryUserId", o.notes,
             o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt",
             o."deliveryLat", o."deliveryLng"
      FROM orders o
      WHERE (o."deliveryMethod" = 'DELIVERY' OR o."deliveryMethod" IS NULL)
        AND (
          (o.status::text IN ('CONFIRMED', 'PREPARING', 'PACKED') AND (o."deliveryUserId" IS NULL OR o."deliveryUserId" = ${session.user.id}))
          OR
          (o.status::text = 'SHIPPED' AND o."deliveryUserId" = ${session.user.id})
          OR
          (o.status::text = 'DELIVERED' AND o."deliveryUserId" = ${session.user.id} AND COALESCE(o."deliveredAt", o."updatedAt", o."createdAt") >= CURRENT_DATE)
        )
      ORDER BY o."createdAt" DESC
    `

    // Fetch related data
    const orderIds = orders.map(o => o.id)
    const userIds = [...new Set(orders.map(o => o.userId).filter(Boolean))]
    const addressIds = [...new Set(orders.map(o => o.addressId).filter(Boolean))]

    const [allItems, allUsers, allAddresses] = await Promise.all([
      orderIds.length > 0
        ? prisma.orderItem.findMany({ where: { orderId: { in: orderIds } } })
        : [],
      userIds.length > 0
        ? prisma.user.findMany({ where: { id: { in: userIds } }, select: { id: true, name: true, phone: true } })
        : [],
      addressIds.length > 0
        ? prisma.address.findMany({ where: { id: { in: addressIds } } })
        : [],
    ])

    const result = orders.map(o => ({
      ...o,
      items: allItems.filter(item => item.orderId === o.id),
      user: allUsers.find(u => u.id === o.userId) || { name: 'Customer', phone: null },
      address: allAddresses.find(a => a.id === o.addressId),
    }))

    return NextResponse.json(result)
  } catch (error: any) {
    console.error('Delivery orders API error:', error)
    return NextResponse.json({ error: 'Failed to fetch delivery orders' }, { status: 500 })
  }
}
