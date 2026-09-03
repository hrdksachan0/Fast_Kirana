import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(request: Request) {
  const session = await auth()
  const headerRole = request.headers.get('x-user-role')?.toUpperCase()
  const headerPhone = request.headers.get('x-user-phone') || ''
  const role = session?.user?.role || headerRole

  if (!role || (role !== 'PICKER' && role !== 'ADMIN' && role !== 'CHEF' && role !== 'RESTAURANT_OWNER')) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const { searchParams } = new URL(request.url)
  const type = searchParams.get('type') // 'cafe', 'restaurant' or 'grocery'
  const paramRestId = searchParams.get('restaurantId')
  
  let assignedRestaurantId = (session?.user as any)?.assignedRestaurantId || paramRestId
  if (!assignedRestaurantId && headerPhone) {
    const clean = headerPhone.replace(/[^0-9]/g, '').slice(-10)
    if (clean === '8112849854') assignedRestaurantId = 'cms2p1lap0000n0id8alldboy'
    else if (clean === '9250138656') assignedRestaurantId = 'cms2p1lyx0001n0idod904lfu'
    else if (clean === '7991488783') assignedRestaurantId = 'cmsbhxb6a000304if8kf1cwji'
  }

  if (role === 'CHEF' || role === 'RESTAURANT_OWNER') {
    const isRestaurantChef = session?.user?.email?.toLowerCase().startsWith('restaurant') || role === 'RESTAURANT_OWNER' || type === 'restaurant'
    if (isRestaurantChef && type !== 'restaurant') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }
    if (!isRestaurantChef && type !== 'cafe') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }
  }
  if (role === 'PICKER' && (type === 'cafe' || type === 'restaurant')) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    // Fetch PENDING (Placed) and CONFIRMED (Preparing/Picking) orders
    let orders: any[] = []
    
    if (type === 'cafe') {
      if (assignedRestaurantId) {
        orders = await prisma.$queryRaw`
          SELECT o.id, o."userId", o."addressId", o."readableId",
                 o.status::text as status,
                 o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
                 o."paymentMethod"::text as "paymentMethod",
                 o."paymentStatus"::text as "paymentStatus",
                 o."estimatedDelivery", o."createdAt", o."deliveryMethod",
                 o."shopName", o."assignedPickerId", o."assignedChefId", o.notes,
                 o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt", o."restaurantId"
          FROM orders o
          WHERE o.status IN ('PENDING', 'CONFIRMED')
            AND o."restaurantId" = ${assignedRestaurantId}
          ORDER BY o."createdAt" ASC
        `
      } else {
        orders = await prisma.$queryRaw`
          SELECT o.id, o."userId", o."addressId", o."readableId",
                 o.status::text as status,
                 o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
                 o."paymentMethod"::text as "paymentMethod",
                 o."paymentStatus"::text as "paymentStatus",
                 o."estimatedDelivery", o."createdAt", o."deliveryMethod",
                 o."shopName", o."assignedPickerId", o."assignedChefId", o.notes,
                 o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt", o."restaurantId"
          FROM orders o
          WHERE o.status IN ('PENDING', 'CONFIRMED')
            AND (o."restaurantId" IS NOT NULL OR o."orderType"::text = 'RESTAURANT')
          ORDER BY o."createdAt" ASC
        `
      }
    } else if (type === 'restaurant') {
      if (assignedRestaurantId) {
        orders = await prisma.$queryRaw`
          SELECT o.id, o."userId", o."addressId", o."readableId",
                 o.status::text as status,
                 o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
                 o."paymentMethod"::text as "paymentMethod",
                 o."paymentStatus"::text as "paymentStatus",
                 o."estimatedDelivery", o."createdAt", o."deliveryMethod",
                 o."shopName", o."assignedPickerId", o."assignedChefId", o.notes,
                 o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt", o."restaurantId"
          FROM orders o
          WHERE o.status IN ('PENDING', 'CONFIRMED')
            AND o."restaurantId" = ${assignedRestaurantId}
          ORDER BY o."createdAt" ASC
        `
      } else {
        orders = await prisma.$queryRaw`
          SELECT o.id, o."userId", o."addressId", o."readableId",
                 o.status::text as status,
                 o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
                 o."paymentMethod"::text as "paymentMethod",
                 o."paymentStatus"::text as "paymentStatus",
                 o."estimatedDelivery", o."createdAt", o."deliveryMethod",
                 o."shopName", o."assignedPickerId", o."assignedChefId", o.notes,
                 o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt", o."restaurantId"
          FROM orders o
          WHERE o.status IN ('PENDING', 'CONFIRMED')
            AND (o."restaurantId" IS NOT NULL OR o."orderType"::text = 'RESTAURANT')
          ORDER BY o."createdAt" ASC
        `
      }
    } else {
      orders = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId", o."readableId",
               o.status::text as status,
               o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
               o."paymentMethod"::text as "paymentMethod",
               o."paymentStatus"::text as "paymentStatus",
               o."estimatedDelivery", o."createdAt", o."deliveryMethod",
               o."shopName", o."assignedPickerId", o."assignedChefId", o.notes,
               o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt", o."restaurantId"
        FROM orders o
        WHERE o.status IN ('PENDING', 'CONFIRMED')
          AND o."restaurantId" IS NULL
          AND (o."orderType"::text = 'GROCERY' OR o."orderType" IS NULL)
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
        SELECT o.id, o."userId", o."readableId", o.status::text as status, o."shopName", o."createdAt", o."combinedId"
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

    const restaurantIds = [...new Set(orders.map(o => o.restaurantId).filter(Boolean))]

    const [allItems, allUsers, allAddresses, allRestaurants] = await Promise.all([
      orderIds.length > 0
        ? prisma.orderItem.findMany({
            where: { orderId: { in: orderIds } },
            include: {
              product: {
                include: {
                  category: true,
                  restaurant: true,
                }
              }
            }
          })
        : [],
      userIds.length > 0
        ? (prisma.$queryRaw`
            SELECT id, name, phone FROM users WHERE id = ANY(${userIds})
          ` as Promise<any[]>)
        : [],
      addressIds.length > 0
        ? prisma.address.findMany({ where: { id: { in: addressIds } } })
        : [],
      restaurantIds.length > 0
        ? prisma.restaurant.findMany({
            where: { id: { in: restaurantIds } },
            select: { id: true, name: true, address: true, logoUrl: true, ownerPhone: true }
          })
        : [],
    ])

    const result = orders.map((o) => {
      const orderItems = allItems.filter(item => item.orderId === o.id)
      const user = allUsers.find(u => u.id === o.userId) || { name: 'Customer', phone: null }
      const assignedPicker = o.assignedPickerId ? allUsers.find(u => u.id === o.assignedPickerId) : null
      const assignedChef = o.assignedChefId ? allUsers.find(u => u.id === o.assignedChefId) : null
      const address = allAddresses.find(a => a.id === o.addressId)
      const restaurant = o.restaurantId ? allRestaurants.find(r => r.id === o.restaurantId) : null

      // Find companion order only if this is an explicit combined order with a combinedId
      const companion = (o.combinedId && typeof o.combinedId === 'string' && o.combinedId.trim().length > 0)
        ? companionOrders.find(c => c.id !== o.id && c.combinedId === o.combinedId)
        : null

      return {
        ...o,
        items: orderItems,
        user,
        assignedPicker,
        assignedChef,
        address,
        restaurant,
        restaurantName: restaurant?.name || o.shopName,
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
