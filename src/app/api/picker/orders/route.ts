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
               o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
               o."paymentMethod"::text as "paymentMethod",
               o."paymentStatus"::text as "paymentStatus",
               o."estimatedDelivery", o."createdAt", o."deliveryMethod",
               o."shopName", o."assignedPickerId", o."assignedChefId", o.notes,
               o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt"
        FROM orders o
        WHERE o.status IN ('PENDING', 'CONFIRMED')
          AND o."shopName" = 'FastKirana Cafe Kitchen'
        ORDER BY o."createdAt" ASC
      `
    } else {
      orders = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId",
               o.status::text as status,
               o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
               o."paymentMethod"::text as "paymentMethod",
               o."paymentStatus"::text as "paymentStatus",
               o."estimatedDelivery", o."createdAt", o."deliveryMethod",
               o."shopName", o."assignedPickerId", o."assignedChefId", o.notes,
               o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt"
        FROM orders o
        WHERE o.status IN ('PENDING', 'CONFIRMED')
          AND (o."shopName" IS NULL OR o."shopName" != 'FastKirana Cafe Kitchen')
        ORDER BY o."createdAt" ASC
      `
    }

    const orderIds = orders.map(o => o.id)
    const pickerIds = orders.map(o => o.assignedPickerId).filter(Boolean)
    const chefIds = orders.map(o => o.assignedChefId).filter(Boolean)
    const userIds = [...new Set([...orders.map(o => o.userId), ...pickerIds, ...chefIds])]
    const addressIds = [...new Set(orders.map(o => o.addressId))]

    // Batch all potential companions to avoid N+1 query
    const minTime = orders.length > 0 ? new Date(Math.min(...orders.map(o => new Date(o.createdAt).getTime())) - 5000) : null
    const maxTime = orders.length > 0 ? new Date(Math.max(...orders.map(o => new Date(o.createdAt).getTime())) + 5000) : null

    let companionOrders: any[] = []
    let companionItems: any[] = []

    if (orders.length > 0 && minTime && maxTime) {
      companionOrders = await prisma.$queryRaw`
        SELECT o.id, o."userId", o.status::text as status, o."shopName", o."createdAt"
        FROM orders o
        WHERE o."userId" = ANY(${userIds})
          AND o."createdAt" >= ${minTime}
          AND o."createdAt" <= ${maxTime}
      `
      
      const companionIds = companionOrders.map(c => c.id)
      if (companionIds.length > 0) {
        companionItems = await prisma.orderItem.findMany({
          where: { orderId: { in: companionIds } },
          select: { id: true, name: true, quantity: true, orderId: true }
        })
      }
    }

    const [allItems, allUsers, allAddresses] = await Promise.all([
      orderIds.length > 0
        ? prisma.orderItem.findMany({
            where: { orderId: { in: orderIds } },
            include: {
              product: {
                include: {
                  category: true
                }
              }
            }
          })
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

    const result = orders.map((o) => {
      const orderItems = allItems.filter(item => item.orderId === o.id)
      const user = allUsers.find(u => u.id === o.userId) || { name: 'Customer', phone: null }
      const assignedPicker = o.assignedPickerId ? allUsers.find(u => u.id === o.assignedPickerId) : null
      const assignedChef = o.assignedChefId ? allUsers.find(u => u.id === o.assignedChefId) : null
      const address = allAddresses.find(a => a.id === o.addressId)

      // Find companion order from pre-fetched list
      const fiveSecondsAgo = new Date(new Date(o.createdAt).getTime() - 5000).getTime()
      const fiveSecondsAfter = new Date(new Date(o.createdAt).getTime() + 5000).getTime()

      const companion = companionOrders.find(c => 
        c.userId === o.userId &&
        c.id !== o.id &&
        new Date(c.createdAt).getTime() >= fiveSecondsAgo &&
        new Date(c.createdAt).getTime() <= fiveSecondsAfter
      )

      return {
        ...o,
        items: orderItems,
        user,
        assignedPicker,
        assignedChef,
        address,
        companionOrder: companion
          ? {
              id: companion.id,
              status: companion.status,
              shopName: companion.shopName,
              items: companionItems.filter(item => item.orderId === companion.id),
            }
          : null,
      }
    })

    return NextResponse.json(result)
  } catch (error: any) {
    console.error('Picker orders API error:', error)
    return NextResponse.json({ error: 'Failed to fetch picker orders' }, { status: 500 })
  }
}
