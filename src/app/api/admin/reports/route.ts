import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'

export const dynamic = 'force-dynamic'
export const revalidate = 0

export async function GET(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const { searchParams } = new URL(request.url)
    const startDateParam = searchParams.get('startDate')
    const endDateParam = searchParams.get('endDate')

    const now = new Date()
    let start: Date
    let end: Date

    if (startDateParam) {
      start = new Date(`${startDateParam}T00:00:00.000`)
    } else {
      start = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)
      start.setHours(0, 0, 0, 0)
    }

    if (endDateParam) {
      end = new Date(`${endDateParam}T23:59:59.999`)
    } else {
      end = new Date(now.getTime())
      end.setHours(23, 59, 59, 999)
    }

    const storeId = searchParams.get('storeId') || (session?.user as any)?.assignedStoreId || null

    const storeWhereOrders = storeId && storeId !== 'all'
      ? Prisma.sql`AND "storeId" = ${storeId}`
      : Prisma.empty

    const storeWhereOrderItems = storeId && storeId !== 'all'
      ? Prisma.sql`AND o."storeId" = ${storeId}`
      : Prisma.empty

    // 1. Fetch delivered orders within range
    const orders = await prisma.$queryRaw<
      Array<{
        id: string
        total: number
        subtotal: number
        discount: number
        deliveryFee: number
        taxes: number
        miscFee: number
        deliveryMethod: string
        createdAt: Date
        combinedId: string | null
        refundAmount: number
      }>
    >`
      SELECT id, total, subtotal, discount, "deliveryFee", taxes, "miscFee", "deliveryMethod", "createdAt", "combinedId",
             COALESCE("refundAmount", 0)::float as "refundAmount"
      FROM orders
      WHERE status::text = 'DELIVERED'
        AND "createdAt" >= ${start}
        AND "createdAt" <= ${end}
        ${storeWhereOrders}
      ORDER BY "createdAt" ASC
    `

    // 2. Fetch all order items inside delivered orders with cost price
    const orderItems = await prisma.$queryRaw<
      Array<{
        orderId: string
        productId: string
        price: number
        mrp: number
        quantity: number
        name: string
        costPrice: number
        vendor: string | null
        categoryName: string
        categorySlug: string
        productTags: string[] | null
        variants: any
        selectedVariant: string | null
        shopName: string | null
        prodRestaurantId?: string | null
        orderRestaurantId?: string | null
        restaurantId?: string | null
        restaurantName: string | null
        restaurantCommissionRate: number | null
        orderType: string | null
        refundAmount: number
        isRefunded: boolean
        isGroceryProduct?: boolean
      }>
    >`
      SELECT oi."orderId", oi."productId", oi.price, COALESCE(p.mrp, oi.price) as mrp, oi.quantity, oi.name, 
             COALESCE(NULLIF(oi."costPrice", 0), p."costPrice", 0) as "costPrice", 
             COALESCE(p.vendor, 'Direct / FastKirana') as "vendor",
             COALESCE(c.name, CASE WHEN p."restaurantId" IS NOT NULL THEN r.name ELSE 'General Grocery' END) as "categoryName",
             COALESCE(c.slug, CASE WHEN p."restaurantId" IS NOT NULL THEN r.slug ELSE 'general-grocery' END) as "categorySlug",
             p.tags as "productTags",
             COALESCE(oi.variants, p.variants) as "variants", 
             oi."selectedVariant",
             o."shopName" as "shopName",
             p."restaurantId" as "prodRestaurantId",
             o."restaurantId" as "orderRestaurantId",
             r.name as "restaurantName",
             r."commissionRate" as "restaurantCommissionRate",
             o."orderType"::text as "orderType",
             COALESCE(oi."refundAmount", 0)::float as "refundAmount",
             COALESCE(oi."isRefunded", false) as "isRefunded",
             CASE WHEN p.id IS NOT NULL AND p."restaurantId" IS NULL THEN true ELSE false END as "isGroceryProduct"
      FROM order_items oi
      JOIN orders o ON oi."orderId" = o.id
      LEFT JOIN products p ON oi."productId" = p.id
      LEFT JOIN categories c ON p."categoryId" = c.id
      LEFT JOIN restaurants r ON p."restaurantId" = r.id
      WHERE o.status::text = 'DELIVERED'
        AND o."createdAt" >= ${start}
        AND o."createdAt" <= ${end}
        ${storeWhereOrderItems}
    `

    // Map order items by order ID for easier processing
    const itemsByOrder: Record<string, typeof orderItems> = {}
    for (const item of orderItems) {
      if (!itemsByOrder[item.orderId]) {
        itemsByOrder[item.orderId] = []
      }
      itemsByOrder[item.orderId].push(item)
    }

    // Track missing cost products
    const missingCostProductsMap: Record<string, { id: string; name: string; price: number }> = {}

    // Fetch all restaurants and their actual configured commission rates from DB
    const allRestaurants = await prisma.restaurant.findMany({
      select: { id: true, name: true, slug: true, commissionRate: true }
    })
    const restaurantById = new Map(allRestaurants.map(r => [r.id, r]))
    const restaurantByName = new Map(allRestaurants.map(r => [r.name.toLowerCase().trim(), r]))
    const restaurantBySlug = new Map(allRestaurants.map(r => [r.slug.toLowerCase().trim(), r]))

    // Fetch dynamic settings
    const settingsList = await prisma.storeSetting.findMany({
      where: { key: { in: ['restaurant_commission', 'restaurant_default_margin', 'cafe_default_margin'] } }
    })
    const settingsMap = new Map(settingsList.map(s => [s.key, s.value]))
    const dynamicCommissionRate = parseFloat(settingsMap.get('restaurant_commission') || '10') / 100

    const resolveRestaurantForItem = (item: typeof orderItems[0]) => {
      // If it's a catalog grocery product with no restaurantId on the product, it is NEVER a restaurant item
      if (item.isGroceryProduct) return null

      if (item.prodRestaurantId && restaurantById.has(item.prodRestaurantId)) {
        return restaurantById.get(item.prodRestaurantId)
      }
      if (!item.productId && item.orderRestaurantId && restaurantById.has(item.orderRestaurantId)) {
        return restaurantById.get(item.orderRestaurantId)
      }
      const catLower = (item.categoryName || '').toLowerCase().trim()
      const catSlug = (item.categorySlug || '').toLowerCase().trim()
      for (const r of allRestaurants) {
        if (r.name.toLowerCase() === catLower || r.slug.toLowerCase() === catSlug) {
          return r
        }
      }
      return null
    }

    const getItemMetrics = (item: typeof orderItems[0]) => {
      const grossRevenue = (item.price || 0) * (item.quantity || 1)
      const itemRevenue = Math.max(0, grossRevenue - (item.refundAmount || 0))
      if (item.isRefunded && itemRevenue === 0) {
        return { cost: 0, revenue: 0, profit: 0, matchedRest: null }
      }
      const isGrocery = Boolean(item.isGroceryProduct)
      const matchedRest = !isGrocery ? resolveRestaurantForItem(item) : null
      const isRestaurant = !isGrocery && (!!matchedRest || !!item.prodRestaurantId)

      // Real Restaurant Commission Logic synced from Outlet Setup:
      if (isRestaurant) {
        let commRate = dynamicCommissionRate
        if (matchedRest?.commissionRate !== undefined && matchedRest?.commissionRate !== null) {
          const rawRate = Number(matchedRest.commissionRate)
          commRate = rawRate > 1 ? rawRate / 100 : rawRate
        } else if (item.restaurantCommissionRate !== undefined && item.restaurantCommissionRate !== null) {
          const rawRate = Number(item.restaurantCommissionRate)
          commRate = rawRate > 1 ? rawRate / 100 : rawRate
        }

        const itemProfit = itemRevenue * commRate
        const itemCost = itemRevenue * (1 - commRate)
        return { cost: itemCost, revenue: itemRevenue, profit: itemProfit, matchedRest }
      }

      let costPrice = item.costPrice || 0

      // If there is a selected variant, try to find its cost price in the variants array
      if (item.selectedVariant && item.variants) {
        try {
          const variantsList = typeof item.variants === 'string' ? JSON.parse(item.variants) : item.variants
          if (Array.isArray(variantsList)) {
            const matchedVariant = variantsList.find((v: any) => v && v.name === item.selectedVariant)
            if (matchedVariant && matchedVariant.costPrice !== undefined) {
              costPrice = parseFloat(matchedVariant.costPrice) || 0
            }
          }
        } catch (e) {
          console.error('Error parsing variants for item cost calculation:', e)
        }
      }

      const hasCostPrice = costPrice > 0
      let costPerUnit = costPrice
      if (!hasCostPrice) {
        costPerUnit = (item.price || 0) * 0.75
        const prodKey = item.productId || `manual_${(item.name || 'item').toLowerCase().replace(/[^a-z0-9]/g, '_')}`
        missingCostProductsMap[prodKey] = {
          id: prodKey,
          name: item.name || 'Unnamed Product',
          price: item.price || 0
        }
      }
      const itemCost = costPerUnit * (item.quantity || 1)
      const itemProfit = itemRevenue - itemCost
      
      return { cost: itemCost, revenue: itemRevenue, profit: itemProfit, matchedRest: null }
    }

    // Calculate aggregated metrics
    let totalRevenue = 0
    let totalProfit = 0
    let totalCost = 0
    let totalMiscFee = 0
    let totalTaxes = 0
    let totalDeliveryFee = 0
    let totalProductSales = 0 // subtotal - discount
    // Treat combined sub-orders sharing combinedId as 1 single customer order
    const uniqueDeliveredOrderIds = new Set(
      orders
        .filter(o => o.deliveryMethod !== 'RETAIL')
        .map(o => o.combinedId || o.id)
    )
    const totalOrders = uniqueDeliveredOrderIds.size

    // Group by Date (YYYY-MM-DD)
    type DailySale = { date: string; sales: number; profit: number; orders: number }
    const dailyData: Record<string, DailySale> = {}
    
    // Initialize days in range with 0 to ensure continuous charts
    const currentDate = new Date(start)
    while (currentDate <= end) {
      const dateString = currentDate.toISOString().split('T')[0]
      dailyData[dateString] = { date: dateString, sales: 0, profit: 0, orders: 0 }
      currentDate.setDate(currentDate.getDate() + 1)
    }

    // Category breakdown
    const categoryData: Record<string, { categoryName: string; sales: number; cost: number; profit: number; quantity: number; type: 'restaurant' | 'grocery' }> = {}

    // Product performance
    const productData: Record<
      string,
      { 
        productId: string; 
        name: string; 
        mrp: number; 
        price: number; 
        costPrice: number; 
        quantity: number; 
        sales: number; 
        profit: number; 
        categoryName: string; 
        vendor: string;
        type: 'restaurant' | 'grocery' 
      }
    > = {}

    let deliveryOrdersCount = 0
    let deliverySales = 0
    let deliveryProfit = 0
    let pickupOrdersCount = 0
    let pickupSales = 0
    let pickupProfit = 0
    let retailOrdersCount = 0
    let retailSales = 0
    let retailProfit = 0

    const seenDailyCombined = new Set<string>()
    const seenDeliveryCombined = new Set<string>()
    const seenPickupCombined = new Set<string>()
    const seenRetailCombined = new Set<string>()

    // Process each order
    for (const order of orders) {
      const isPickup = order.deliveryMethod === 'PICKUP'
      const isRetail = order.deliveryMethod === 'RETAIL'
      const orderMasterKey = order.combinedId || order.id
      const createdAtDate = order.createdAt instanceof Date ? order.createdAt : new Date(order.createdAt)
      const dateString = createdAtDate.toISOString().split('T')[0]
      const rawSales = isRetail ? (order.total || order.subtotal || 0) : ((order.subtotal || 0) - (order.discount || 0))
      const orderSales = Math.max(0, rawSales - (order.refundAmount || 0))
      
      // Ensure dailyData has the key (in case it fell outside initialized range due to timezone)
      if (!dailyData[dateString]) {
        dailyData[dateString] = { date: dateString, sales: 0, profit: 0, orders: 0 }
      }

      if (!isRetail) {
        const dailyKey = `${dateString}_${orderMasterKey}`
        if (!seenDailyCombined.has(dailyKey)) {
          seenDailyCombined.add(dailyKey)
          dailyData[dateString].orders++
        }
        dailyData[dateString].sales += orderSales
        totalRevenue += orderSales
        totalMiscFee += order.miscFee || 0
        totalTaxes += order.taxes || 0
        totalDeliveryFee += order.deliveryFee || 0
        totalProductSales += orderSales
      }

      // Process items for profit calculation
      const items = itemsByOrder[order.id] || []
      let orderCost = 0

      for (const item of items) {
        const { cost, revenue: itemRev, profit: itemProf, matchedRest } = getItemMetrics(item)
        orderCost += cost

        if (isRetail) continue // Skip adding retail items to category and product breakdown

        // Strict Category Resolution
        const isGrocery = Boolean(item.isGroceryProduct)

        let targetCategoryName = item.categoryName || 'General Store'
        let targetType: 'restaurant' | 'grocery' = 'grocery'

        if (isGrocery) {
          targetCategoryName = item.categoryName || 'Grocery Essentials'
          targetType = 'grocery'
        } else if (matchedRest) {
          targetCategoryName = matchedRest.name || 'Restaurant'
          targetType = 'restaurant'
        } else if (item.prodRestaurantId) {
          const rObj = restaurantById.get(item.prodRestaurantId)
          targetCategoryName = rObj?.name || item.restaurantName || 'Restaurant Food'
          targetType = 'restaurant'
        } else {
          targetCategoryName = item.categoryName || 'General Store'
          targetType = 'grocery'
        }

        // Category breakdown
        if (!categoryData[targetCategoryName]) {
          categoryData[targetCategoryName] = { 
            categoryName: targetCategoryName, 
            sales: 0, 
            cost: 0, 
            profit: 0, 
            quantity: 0, 
            type: targetType 
          }
        }
        categoryData[targetCategoryName].sales += itemRev
        categoryData[targetCategoryName].cost += cost
        categoryData[targetCategoryName].profit += itemProf
        categoryData[targetCategoryName].quantity += (item.quantity || 1)

        // Product breakdown
        const prodKey = item.productId || `manual_${(item.name || 'item').toLowerCase().replace(/[^a-z0-9]/g, '_')}`
        if (!productData[prodKey]) {
          productData[prodKey] = {
            productId: prodKey,
            name: item.name || 'Unnamed Product',
            mrp: item.mrp || item.price || 0,
            price: item.price || 0,
            costPrice: item.costPrice || 0,
            quantity: 0,
            sales: 0,
            profit: 0,
            categoryName: targetCategoryName,
            vendor: item.vendor || 'Direct / FastKirana',
            type: targetType
          }
        }
        productData[prodKey].quantity += (item.quantity || 1)
        productData[prodKey].sales += itemRev
        productData[prodKey].profit += itemProf
      }

      // Order profit = order.total - orderCost
      const orderProfit = (order.total || 0) - orderCost
      
      if (!isRetail) {
        dailyData[dateString].profit += orderProfit
        totalProfit += orderProfit
        totalCost += orderCost
      }

      if (isPickup) {
        if (!seenPickupCombined.has(orderMasterKey)) {
          seenPickupCombined.add(orderMasterKey)
          pickupOrdersCount++
        }
        pickupSales += orderSales
        pickupProfit += orderProfit
      } else if (isRetail) {
        if (!seenRetailCombined.has(orderMasterKey)) {
          seenRetailCombined.add(orderMasterKey)
          retailOrdersCount++
        }
        retailSales += orderSales
        retailProfit += orderProfit
      } else {
        if (!seenDeliveryCombined.has(orderMasterKey)) {
          seenDeliveryCombined.add(orderMasterKey)
          deliveryOrdersCount++
        }
        deliverySales += orderSales
        deliveryProfit += orderProfit
      }
    }

    // Convert grouped records to arrays
    const dailyList = Object.values(dailyData).sort((a, b) => a.date.localeCompare(b.date))
    const categoryList = Object.values(categoryData).sort((a, b) => b.sales - a.sales)
    const productList = Object.values(productData)
      .sort((a, b) => b.sales - a.sales)
      .slice(0, 200) // All sold products in date range (up to 200 items)

    const averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0
    const profitMargin = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0

    return NextResponse.json({
      success: true,
      summary: {
        totalSales: Math.round(totalRevenue * 100) / 100,
        totalCollected: Math.round((totalRevenue + totalDeliveryFee + totalTaxes + totalMiscFee) * 100) / 100,
        totalProfit: Math.round(totalProfit * 100) / 100,
        totalCost: Math.round(totalCost * 100) / 100,
        totalOrders,
        averageOrderValue: Math.round(averageOrderValue * 100) / 100,
        profitMargin: Math.round(profitMargin * 10) / 10,
        totalMiscFee: Math.round(totalMiscFee * 100) / 100,
        totalTaxes: Math.round(totalTaxes * 100) / 100,
        totalDeliveryFee: Math.round(totalDeliveryFee * 100) / 100,
        productSales: Math.round(totalProductSales * 100) / 100,
        missingCostCount: Object.keys(missingCostProductsMap).length,
        delivery: {
          ordersCount: deliveryOrdersCount,
          sales: Math.round(deliverySales * 100) / 100,
          profit: Math.round(deliveryProfit * 100) / 100,
        },
        pickup: {
          ordersCount: pickupOrdersCount,
          sales: Math.round(pickupSales * 100) / 100,
          profit: Math.round(pickupProfit * 100) / 100,
        },
        retail: {
          ordersCount: retailOrdersCount,
          sales: Math.round(retailSales * 100) / 100,
          profit: Math.round(retailProfit * 100) / 100,
        }
      },
      dailySales: dailyList,
      categorySales: categoryList,
      topProducts: productList,
      missingCostProducts: Object.values(missingCostProductsMap),
    })
  } catch (error: any) {
    console.error('Reports API error:', error)
    return NextResponse.json(
      { error: 'Failed to generate reports', details: error.message || error },
      { status: 500 }
    )
  }
}
