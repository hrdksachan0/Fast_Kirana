import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { auth } from '@/auth'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  const session = await auth()
  const searchParams = request.nextUrl.searchParams
  const queryUserId = searchParams.get('userId') || searchParams.get('deliveryUserId')
  const queryPhone = searchParams.get('phone')

  const queryStoreId = searchParams.get('storeId')

  let effectiveUserId = session?.user?.id || queryUserId || null

  if (!effectiveUserId && queryPhone) {
    const cleanPhone = queryPhone.replace(/\D/g, '').slice(-10)
    const riderUser = await prisma.user.findFirst({
      where: { phone: { contains: cleanPhone } },
      select: { id: true, role: true }
    })
    if (riderUser) effectiveUserId = riderUser.id
  }

  let riderStoreId: string | null = queryStoreId || null
  if (effectiveUserId && !riderStoreId) {
    try {
      const riderUser = await prisma.user.findUnique({
        where: { id: effectiveUserId },
        select: { assignedStoreId: true }
      })
      riderStoreId = riderUser?.assignedStoreId || null
    } catch (_) {}
  }

  try {
    let orders: any[] = []

    if (effectiveUserId) {
      orders = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId", o."readableId", o."combinedId", o."restaurantId", o."storeId",
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
            (o.status::text IN ('CONFIRMED', 'PREPARING', 'PACKED') AND (o."deliveryUserId" IS NULL OR o."deliveryUserId" = ${effectiveUserId}))
            OR
            (o.status::text = 'SHIPPED' AND (o."deliveryUserId" = ${effectiveUserId} OR o."deliveryUserId" IS NULL))
            OR
            (o.status::text = 'DELIVERED' AND (o."deliveryUserId" = ${effectiveUserId} OR o."deliveryUserId" IS NULL) AND COALESCE(o."deliveredAt", o."updatedAt", o."createdAt") >= CURRENT_DATE)
          )
          AND (${riderStoreId}::text IS NULL OR o."storeId" = ${riderStoreId} OR o."storeId" IS NULL)
        ORDER BY o."createdAt" DESC
      `
    } else {
      // General active delivery queue for dark store / riders
      orders = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId", o."readableId", o."combinedId", o."restaurantId", o."storeId",
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
          AND o.status::text IN ('CONFIRMED', 'PREPARING', 'PACKED', 'SHIPPED', 'DELIVERED')
          AND (${riderStoreId}::text IS NULL OR o."storeId" = ${riderStoreId} OR o."storeId" IS NULL)
        ORDER BY o."createdAt" DESC
        LIMIT 50
      `
    }

    // Fetch companion orders sharing combinedId
    const combinedIds = Array.from(new Set(orders.map(o => o.combinedId).filter(Boolean)))
    let companionOrders: any[] = []
    if (combinedIds.length > 0) {
      companionOrders = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId", o."readableId", o."combinedId", o."restaurantId",
               o.status::text as status,
               o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
               o."paymentMethod"::text as "paymentMethod",
               o."paymentStatus"::text as "paymentStatus",
               o."createdAt", o."shopName", o."deliveryUserId"
        FROM orders o
        WHERE o."combinedId" IN (${Prisma.join(combinedIds)})
      `
    }

    // Fetch related data
    const allOrderIds = Array.from(new Set([...orders.map(o => o.id), ...companionOrders.map(c => c.id)]))
    const userIds = Array.from(new Set([...orders.map(o => o.userId), ...companionOrders.map(c => c.userId)].filter(Boolean)))
    const addressIds = Array.from(new Set([...orders.map(o => o.addressId), ...companionOrders.map(c => c.addressId)].filter(Boolean)))

    const [allItems, allUsers, allAddresses] = await Promise.all([
      allOrderIds.length > 0
        ? prisma.orderItem.findMany({ where: { orderId: { in: allOrderIds } } })
        : [],
      userIds.length > 0
        ? prisma.user.findMany({ where: { id: { in: userIds as string[] } }, select: { id: true, name: true, phone: true } })
        : [],
      addressIds.length > 0
        ? prisma.address.findMany({ where: { id: { in: addressIds as string[] } } })
        : [],
    ])

    const result = orders.map(o => {
      let companion = null
      if (o.combinedId) {
        const matchingCompanion = companionOrders.find(c => c.combinedId === o.combinedId && c.id !== o.id)
        if (matchingCompanion) {
          companion = {
            ...matchingCompanion,
            items: allItems.filter(item => item.orderId === matchingCompanion.id)
          }
        }
      }

      return {
        ...o,
        items: allItems.filter(item => item.orderId === o.id),
        user: allUsers.find(u => u.id === o.userId) || { name: 'Customer', phone: null },
        address: allAddresses.find(a => a.id === o.addressId),
        companionOrder: companion
      }
    })

    return NextResponse.json(result)
  } catch (error: any) {
    console.error('Delivery orders API error:', error)
    return NextResponse.json({ error: 'Failed to fetch delivery orders' }, { status: 500 })
  }
}
