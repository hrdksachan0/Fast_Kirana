import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { auth } from '@/auth'
import { requireAdmin, getEffectiveStoreId } from '@/lib/auth-guard'

// 15-second in-memory stats cache per store to prevent concurrent full-table aggregation hammering
interface OrdersStatsCacheEntry {
  timestamp: number
  statRow: any
  todayRow: any
}
const ordersStatsCache = new Map<string, OrdersStatsCacheEntry>()

export async function GET(request: Request) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  const { searchParams } = new URL(request.url)
  const page = parseInt(searchParams.get('page') || '1')
  const limit = parseInt(searchParams.get('limit') || '20')
  const status = searchParams.get('status')
  const search = searchParams.get('search')
  const paramStoreId = searchParams.get('storeId')
  const skipStats = searchParams.get('skipStats') === 'true'
  
  // Strictly enforce hub isolation: branch admins CANNOT query other hubs or ALL!
  const effectiveStoreId = getEffectiveStoreId(session, paramStoreId)
  
  const skip = (page - 1) * limit

  try {
    const where: any = {}

    if (status && status !== 'ALL') {
      where.status = status
    }

    if (effectiveStoreId) {
      where.storeId = effectiveStoreId
    }

    const cleanSearch = search ? search.replace(/^#/, '').trim() : ''
    const parsedReadableId = cleanSearch && /^\d+$/.test(cleanSearch) ? parseInt(cleanSearch, 10) : null

    if (cleanSearch) {
      where.AND = [
        ...(where.AND || []),
        {
          OR: [
            { id: { contains: cleanSearch, mode: 'insensitive' } },
            ...(parsedReadableId !== null ? [{ readableId: parsedReadableId }] : []),
            { user: { name: { contains: cleanSearch, mode: 'insensitive' } } },
            { user: { email: { contains: cleanSearch, mode: 'insensitive' } } },
            { shopName: { contains: cleanSearch, mode: 'insensitive' } },
          ]
        }
      ]
    }

    const whereForCounts = { ...where }
    delete whereForCounts.status

    let ordersRaw: any[] = []
    
    const isPaymentPendingFilter = status === 'PAYMENT_PENDING'
    const sqlStatus = isPaymentPendingFilter ? 'PENDING' : status

    // Construct dynamic raw SQL query based on filters to avoid enum deserialization bug
    if (status && status !== 'ALL' && cleanSearch) {
      const searchLike = `%${cleanSearch}%`
      const onlinePaidFilter = isPaymentPendingFilter
        ? Prisma.sql`AND o."paymentMethod" != 'COD' AND o."paymentStatus" != 'PAID'`
        : status === 'PENDING'
        ? Prisma.sql`AND (o."paymentMethod" = 'COD' OR o."paymentStatus" = 'PAID')`
        : Prisma.empty

      if (effectiveStoreId) {
        ordersRaw = await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
                 o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt",
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId", o."deliveryUserId"
          FROM orders o
          LEFT JOIN users u ON o."userId" = u.id
          WHERE o.status::text = ${sqlStatus}
            ${onlinePaidFilter}
            AND o."storeId" = ${effectiveStoreId}
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
      } else {
        ordersRaw = await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
                 o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt",
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId", o."deliveryUserId"
          FROM orders o
          LEFT JOIN users u ON o."userId" = u.id
          WHERE o.status::text = ${sqlStatus}
            ${onlinePaidFilter}
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
      }
    } else if (status && status !== 'ALL') {
      const onlinePaidFilter = isPaymentPendingFilter
        ? Prisma.sql`AND o."paymentMethod" != 'COD' AND o."paymentStatus" != 'PAID'`
        : status === 'PENDING'
        ? Prisma.sql`AND (o."paymentMethod" = 'COD' OR o."paymentStatus" = 'PAID')`
        : Prisma.empty

      if (effectiveStoreId) {
        ordersRaw = await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
                 o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt",
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId", o."deliveryUserId"
          FROM orders o
          WHERE o.status::text = ${sqlStatus}
            ${onlinePaidFilter}
            AND o."storeId" = ${effectiveStoreId}
          ORDER BY o."createdAt" DESC
          LIMIT ${limit} OFFSET ${skip}
        `
      } else {
        ordersRaw = await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
                 o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt",
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId", o."deliveryUserId"
          FROM orders o
          WHERE o.status::text = ${sqlStatus}
            ${onlinePaidFilter}
          ORDER BY o."createdAt" DESC
          LIMIT ${limit} OFFSET ${skip}
        `
      }
    } else if (cleanSearch) {
      const searchLike = `%${cleanSearch}%`
      if (effectiveStoreId) {
        ordersRaw = await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
                 o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt",
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId", o."deliveryUserId"
          FROM orders o
          LEFT JOIN users u ON o."userId" = u.id
          WHERE o."storeId" = ${effectiveStoreId}
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
      } else {
        ordersRaw = await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
                 o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt",
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId", o."deliveryUserId"
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
      }
    } else {
      if (effectiveStoreId) {
        ordersRaw = await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
                 o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt",
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId", o."deliveryUserId"
          FROM orders o
          WHERE o."storeId" = ${effectiveStoreId}
          ORDER BY o."createdAt" DESC
          LIMIT ${limit} OFFSET ${skip}
        `
      } else {
        ordersRaw = await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
                 o."confirmedAt", o."packedAt", o."shippedAt", o."deliveredAt",
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId", o."deliveryUserId"
          FROM orders o
          ORDER BY o."createdAt" DESC
          LIMIT ${limit} OFFSET ${skip}
        `
      }
    }

    const orderIds = ordersRaw.map(o => o.id)
    const userIds = [...new Set(ordersRaw.map(o => o.userId))]
    const deliveryUserIds = [...new Set(ordersRaw.map(o => o.deliveryUserId))].filter(Boolean)
    const addressIds = [...new Set(ordersRaw.map(o => o.addressId))].filter(Boolean)
    const restaurantIds = [...new Set(ordersRaw.map(o => o.restaurantId))].filter(Boolean)

    // Exact Indian Standard Time (IST) start of day
    const now = new Date()
    const istOffset = 5.5 * 60 * 60 * 1000
    const istDate = new Date(now.getTime() + istOffset)
    istDate.setUTCHours(0, 0, 0, 0)
    const startOfToday = new Date(istDate.getTime() - istOffset)

    const [allUsers, allDeliveryUsers, allAddresses, allOrderItems, allRestaurants] = await Promise.all([
      userIds.length > 0
        ? (prisma.$queryRaw`
            SELECT id, name, email, phone FROM users WHERE id = ANY(${userIds})
          ` as Promise<any[]>)
        : [],
      deliveryUserIds.length > 0
        ? (prisma.$queryRaw`
            SELECT id, name, email, phone FROM users WHERE id = ANY(${deliveryUserIds})
          ` as Promise<any[]>)
        : [],
      addressIds.length > 0
        ? prisma.address.findMany({ where: { id: { in: addressIds as string[] } } })
        : [],
      orderIds.length > 0
        ? prisma.orderItem.findMany({ where: { orderId: { in: orderIds } } })
        : [],
      restaurantIds.length > 0
        ? prisma.restaurant.findMany({ where: { id: { in: restaurantIds as string[] } }, select: { id: true, name: true, slug: true, address: true, logoUrl: true } })
        : [],
    ])

    const storeSqlWhere = effectiveStoreId
      ? Prisma.sql`AND "storeId" = ${effectiveStoreId}`
      : Prisma.empty

    const cacheKey = effectiveStoreId || 'all'
    const cachedStats = ordersStatsCache.get(cacheKey)
    const isCacheValid = cachedStats && (Date.now() - cachedStats.timestamp < 15000)

    let statRow = { total: 0, admin_pending: 0, pending: 0, payment_pending: 0, confirmed: 0, packed: 0, shipped: 0, delivered: 0, cancelled: 0 }
    let todayRow = { today_orders: 0, today_sales: 0, today_delivered_sales: 0, today_delivery_fee: 0, today_packaging_fee: 0 }

    if (skipStats) {
      if (cachedStats) {
        statRow = cachedStats.statRow
        todayRow = cachedStats.todayRow
      }
    } else if (isCacheValid) {
      statRow = cachedStats.statRow
      todayRow = cachedStats.todayRow
    } else {
      const [statusStatsRaw, todayStatsRaw] = await Promise.all([
        prisma.$queryRaw<Array<{
          status: string
          paymentMethod: string
          paymentStatus: string
          count: number
        }>>`
          SELECT 
            status::text as status,
            "paymentMethod"::text as "paymentMethod",
            "paymentStatus"::text as "paymentStatus",
            COUNT(DISTINCT COALESCE("combinedId", id))::int as count
          FROM orders
          WHERE ("deliveryMethod" != 'RETAIL' OR "deliveryMethod" IS NULL)
            ${storeSqlWhere}
          GROUP BY status, "paymentMethod", "paymentStatus"
        `,
        prisma.$queryRaw<Array<{
          today_orders: number
          today_sales: number
          today_delivered_sales: number
          today_delivery_fee: number
          today_packaging_fee: number
        }>>`
          SELECT 
            COUNT(DISTINCT COALESCE("combinedId", id))::int as today_orders,
            COALESCE(SUM(total), 0)::float as today_sales,
            COALESCE(SUM(CASE WHEN status::text = 'DELIVERED' THEN GREATEST(0, (total - COALESCE("refundAmount", 0))) ELSE 0 END), 0)::float as today_delivered_sales,
            COALESCE(SUM("deliveryFee"), 0)::float as today_delivery_fee,
            COALESCE(SUM("miscFee"), 0)::float as today_packaging_fee
          FROM orders
          WHERE ("deliveryMethod" != 'RETAIL' OR "deliveryMethod" IS NULL)
            AND status::text != 'CANCELLED'
            AND ("paymentMethod" = 'COD' OR "paymentStatus" = 'PAID')
            AND "createdAt" >= ${startOfToday}
            ${storeSqlWhere}
        `
      ])

      let totalAgg = 0
      let adminPendingAgg = 0
      let pendingAgg = 0
      let paymentPendingAgg = 0
      let confirmedAgg = 0
      let packedAgg = 0
      let shippedAgg = 0
      let deliveredAgg = 0
      let cancelledAgg = 0

      for (const row of (statusStatsRaw as any[] || [])) {
        const st = row.status
        const pm = row.paymentMethod
        const ps = row.paymentStatus
        const c = Number(row.count) || 0

        if (st === 'ADMIN_PENDING') {
          adminPendingAgg += c
          totalAgg += c
        } else if (st === 'PENDING') {
          if (pm === 'COD' || ps === 'PAID') {
            pendingAgg += c
            totalAgg += c
          } else {
            paymentPendingAgg += c
          }
        } else if (st === 'CONFIRMED') {
          confirmedAgg += c
          totalAgg += c
        } else if (st === 'PACKED') {
          packedAgg += c
          totalAgg += c
        } else if (st === 'SHIPPED') {
          shippedAgg += c
          totalAgg += c
        } else if (st === 'DELIVERED') {
          deliveredAgg += c
          totalAgg += c
        } else if (st === 'CANCELLED') {
          cancelledAgg += c
          totalAgg += c
        } else {
          totalAgg += c
        }
      }

      statRow = {
        total: totalAgg,
        admin_pending: adminPendingAgg,
        pending: pendingAgg,
        payment_pending: paymentPendingAgg,
        confirmed: confirmedAgg,
        packed: packedAgg,
        shipped: shippedAgg,
        delivered: deliveredAgg,
        cancelled: cancelledAgg,
      }
      todayRow = (todayStatsRaw as any[])?.[0] || { today_orders: 0, today_sales: 0, today_delivered_sales: 0, today_delivery_fee: 0, today_packaging_fee: 0 }

      ordersStatsCache.set(cacheKey, {
        timestamp: Date.now(),
        statRow,
        todayRow,
      })
    }

    const allCount = statRow.total || 0
    const adminPendingCount = statRow.admin_pending || 0
    const pendingCount = statRow.pending || 0
    const paymentPendingCount = statRow.payment_pending || 0
    const confirmedCount = statRow.confirmed || 0
    const packedCount = statRow.packed || 0
    const shippedCount = statRow.shipped || 0
    const deliveredCount = statRow.delivered || 0
    const cancelledCount = statRow.cancelled || 0

    const todaySales = todayRow.today_sales || 0
    const todayNetSales = todayRow.today_delivered_sales || 0
    const todayOrdersCount = todayRow.today_orders || 0
    const total = status && status !== 'ALL'
      ? (status === 'ADMIN_PENDING' ? adminPendingCount : status === 'PAYMENT_PENDING' ? paymentPendingCount : (statRow[status.toLowerCase() as keyof typeof statRow] ?? allCount))
      : allCount

    // Cashfree is the sole payment gateway. No external polling is needed here; Cashfree uses webhooks and explicit verification.

    const orders = ordersRaw.map((o) => {
      const user = allUsers.find(u => u.id === o.userId) || { name: 'Customer', email: '', phone: '' }
      const address = allAddresses.find(a => a.id === o.addressId) || null
      const restaurant = o.restaurantId ? allRestaurants.find(r => r.id === o.restaurantId) : null
      const deliveryUser = o.deliveryUserId ? allDeliveryUsers.find(d => d.id === o.deliveryUserId) : null
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
        combinedId: o.combinedId || null,
        orderType: o.orderType || (o.restaurantId ? 'RESTAURANT' : 'GROCERY'),
        deliveryLat: o.deliveryLat || address?.lat || null,
        deliveryLng: o.deliveryLng || address?.lng || null,
        storeId: o.storeId || null,
        deliveryUserId: o.deliveryUserId || null,
        deliveryUser: deliveryUser ? {
          id: deliveryUser.id,
          name: deliveryUser.name,
          phone: deliveryUser.phone,
        } : null,
        deliveryBoyName: deliveryUser?.name || null,
        deliveryBoyPhone: deliveryUser?.phone || null,
        status: o.status,
        paymentStatus: o.paymentStatus || 'PENDING',
        paymentMethod: o.paymentMethod || 'COD',
        total: o.total,
        createdAt: new Date(o.createdAt).toISOString(),
        updatedAt: new Date(o.updatedAt).toISOString(),
        confirmedAt: o.confirmedAt ? new Date(o.confirmedAt).toISOString() : null,
        packedAt: o.packedAt ? new Date(o.packedAt).toISOString() : null,
        shippedAt: o.shippedAt ? new Date(o.shippedAt).toISOString() : null,
        deliveredAt: o.deliveredAt ? new Date(o.deliveredAt).toISOString() : null,
        userName: user.name,
        userEmail: user.email,
        userPhone: address?.phone || user.phone || o.shopPhone || null,
        notes: o.notes,
        isB2B: o.isB2B,
        deliveryMethod: o.deliveryMethod,
        shopName: o.restaurantId 
          ? (restaurant?.name || o.shopName || 'Restaurant') 
          : ((!o.shopName || o.shopName.toLowerCase().includes('restaurant') || o.orderType === 'GROCERY') ? 'FastKirana Dark Store' : o.shopName),
        restaurantId: o.restaurantId || null,
        restaurantName: o.restaurantId ? (restaurant?.name || o.shopName || 'Restaurant') : null,
        restaurant,
        shopPhone: o.shopPhone,
        items,
        address: address ? {
          houseNo: address.houseNo,
          street: address.street,
          area: address.area,
          city: address.city,
          phone: address.phone,
          lat: address.lat,
          lng: address.lng,
        } : null,
      }
    })

    return NextResponse.json({
      orders,
      total,
      page,
      limit,
      todaySales,
      todayNetSales,
      todayOrdersCount,
      todayDeliveryFee: todayRow.today_delivery_fee || 0,
      todayPackagingFee: todayRow.today_packaging_fee || 0,
      counts: {
        ALL: allCount,
        ADMIN_PENDING: adminPendingCount,
        PENDING: pendingCount,
        PAYMENT_PENDING: paymentPendingCount,
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
