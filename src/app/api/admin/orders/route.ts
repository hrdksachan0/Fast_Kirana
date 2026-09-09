import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'

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
  const userAssignedStoreId = (session?.user as any)?.assignedStoreId
  const effectiveStoreId = userAssignedStoreId || (paramStoreId && paramStoreId !== 'ALL' ? paramStoreId : null)
  
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
    
    // Construct dynamic raw SQL query based on filters to avoid enum deserialization bug
    if (status && status !== 'ALL' && cleanSearch) {
      const searchLike = `%${cleanSearch}%`
      if (effectiveStoreId) {
        ordersRaw = await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId"
          FROM orders o
          LEFT JOIN users u ON o."userId" = u.id
          WHERE o.status::text = ${status}
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
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId"
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
      }
    } else if (status && status !== 'ALL') {
      if (effectiveStoreId) {
        ordersRaw = await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId"
          FROM orders o
          WHERE o.status::text = ${status}
            AND o."storeId" = ${effectiveStoreId}
          ORDER BY o."createdAt" DESC
          LIMIT ${limit} OFFSET ${skip}
        `
      } else {
        ordersRaw = await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId"
          FROM orders o
          WHERE o.status::text = ${status}
          ORDER BY o."createdAt" DESC
          LIMIT ${limit} OFFSET ${skip}
        `
      }
    } else if (cleanSearch) {
      const searchLike = `%${cleanSearch}%`
      if (effectiveStoreId) {
        ordersRaw = await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId"
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
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId"
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
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId"
          FROM orders o
          WHERE o."storeId" = ${effectiveStoreId}
          ORDER BY o."createdAt" DESC
          LIMIT ${limit} OFFSET ${skip}
        `
      } else {
        ordersRaw = await prisma.$queryRaw`
          SELECT o.id, o."readableId", o.status::text as status, o.total, o."createdAt", o."updatedAt",
                 o."paymentStatus"::text as "paymentStatus", o."paymentMethod"::text as "paymentMethod",
                 o."isB2B", o."deliveryMethod", o."shopName", o."shopPhone", o."addressId", o."userId", o."restaurantId", o.notes,
                 o."combinedId", o."orderType"::text as "orderType", o."deliveryLat", o."deliveryLng", o."storeId"
          FROM orders o
          ORDER BY o."createdAt" DESC
          LIMIT ${limit} OFFSET ${skip}
        `
      }
    }

    const orderIds = ordersRaw.map(o => o.id)
    const userIds = [...new Set(ordersRaw.map(o => o.userId))]
    const addressIds = [...new Set(ordersRaw.map(o => o.addressId))].filter(Boolean)
    const restaurantIds = [...new Set(ordersRaw.map(o => o.restaurantId))].filter(Boolean)

    const startOfToday = new Date()
    startOfToday.setHours(0, 0, 0, 0)

    const [allUsers, allAddresses, allOrderItems, allRestaurants, total, allCount, pendingCount, confirmedCount, packedCount, shippedCount, deliveredCount, cancelledCount, todaySalesAgg, todayDeliveredSalesAgg] = await Promise.all([
      userIds.length > 0
        ? (prisma.$queryRaw`
            SELECT id, name, email, phone FROM users WHERE id = ANY(${userIds})
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
      prisma.order.count({ where }),
      prisma.order.count({ where: { ...whereForCounts, deliveryMethod: { not: 'RETAIL' } } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'PENDING', deliveryMethod: { not: 'RETAIL' } } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'CONFIRMED', deliveryMethod: { not: 'RETAIL' } } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'PACKED', deliveryMethod: { not: 'RETAIL' } } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'SHIPPED', deliveryMethod: { not: 'RETAIL' } } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'DELIVERED', deliveryMethod: { not: 'RETAIL' } } }),
      prisma.order.count({ where: { ...whereForCounts, status: 'CANCELLED', deliveryMethod: { not: 'RETAIL' } } }),
      prisma.order.aggregate({
        where: {
          ...whereForCounts,
          createdAt: { gte: startOfToday },
          status: { not: 'CANCELLED' },
          deliveryMethod: { not: 'RETAIL' },
        },
        _sum: { total: true },
        _count: { id: true },
      }),
      prisma.order.aggregate({
        where: {
          ...whereForCounts,
          createdAt: { gte: startOfToday },
          status: 'DELIVERED',
          deliveryMethod: { not: 'RETAIL' },
        },
        _sum: { total: true },
      }),
    ])

    const todaySales = todaySalesAgg._sum?.total || 0
    const todayNetSales = todayDeliveredSalesAgg._sum?.total || 0
    const todayOrdersCount = todaySalesAgg._count?.id || 0

    // Background auto-sync: Automatically check Razorpay for recent unpaid orders (last 2 hours)
    const recentUnpaid = ordersRaw.filter((o: any) => 
      o.paymentStatus !== 'PAID' && (Date.now() - new Date(o.createdAt).getTime()) < 2 * 60 * 60 * 1000
    )

    if (recentUnpaid.length > 0) {
      try {
        const keyId = process.env.NEXT_PUBLIC_RAZORPAY_KEY_ID
        const keySecret = process.env.RAZORPAY_KEY_SECRET
        if (!keyId || !keySecret) throw new Error('Razorpay credentials not configured')
        const authHeader = 'Basic ' + Buffer.from(`${keyId}:${keySecret}`).toString('base64')
        const rzpRes = await fetch('https://api.razorpay.com/v1/payments?count=50', {
          headers: { Authorization: authHeader },
          cache: 'no-store'
        })
        if (rzpRes.ok) {
          const rzpData = await rzpRes.json()
          const items = rzpData.items || []

          for (const unp of recentUnpaid) {
            const orderTotalPaise = Math.round(Number(unp.total) * 100)
            const targetReadableId = String(unp.readableId || '')
            const matched = items.find((p: any) => {
              if (p.status !== 'captured' && p.status !== 'authorized') return false
              const hasExplicitIdMatch = 
                (p.notes?.orderId && p.notes.orderId === unp.id) ||
                (targetReadableId && p.notes?.readableId === targetReadableId) ||
                (targetReadableId && p.description && p.description.includes(targetReadableId)) ||
                (p.order_id && (unp as any).razorpayOrderId && p.order_id === (unp as any).razorpayOrderId)
              
              if (hasExplicitIdMatch && p.amount === orderTotalPaise) {
                return true
              }
              return false
            })

            if (matched) {
              unp.paymentStatus = 'PAID'
              unp.paymentMethod = 'UPI'
              if (unp.status === 'PENDING' || unp.status === 'CANCELLED') {
                unp.status = 'CONFIRMED'
              }
              // Update in DB asynchronously
              prisma.$executeRaw`
                UPDATE orders 
                SET "paymentStatus" = 'PAID'::"PaymentStatus",
                    "paymentMethod" = 'UPI'::"PaymentMethod",
                    status = CASE WHEN status IN ('PENDING', 'CANCELLED') THEN 'CONFIRMED'::"OrderStatus" ELSE status END,
                    "updatedAt" = NOW()
                WHERE id = ${unp.id}
              `.catch(() => {})
            }
          }
        }
      } catch (e) {
        console.warn('Background auto-sync Razorpay notice in admin orders API:', e)
      }
    }

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
        combinedId: o.combinedId || null,
        orderType: o.orderType || (o.restaurantId ? 'RESTAURANT' : 'GROCERY'),
        deliveryLat: o.deliveryLat || address?.lat || null,
        deliveryLng: o.deliveryLng || address?.lng || null,
        storeId: o.storeId || null,
        status: o.status,
        paymentStatus: o.paymentStatus || 'PENDING',
        paymentMethod: o.paymentMethod || 'COD',
        total: o.total,
        createdAt: new Date(o.createdAt).toISOString(),
        updatedAt: new Date(o.updatedAt).toISOString(),
        userName: user.name,
        userEmail: user.email,
        userPhone: address?.phone || user.phone || o.shopPhone || null,
        notes: o.notes,
        isB2B: o.isB2B,
        deliveryMethod: o.deliveryMethod,
        shopName: o.restaurantId ? (restaurant?.name || o.shopName || 'Restaurant') : (o.shopName || 'FastKirana Dark Store'),
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
