import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'

export const dynamic = 'force-dynamic'
export const revalidate = 0

export async function GET(request: NextRequest) {
  const adminResult = await requireAdmin()
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
      }>
    >`
      SELECT id, total, subtotal, discount, "deliveryFee", taxes, "miscFee", "deliveryMethod", "createdAt"
      FROM orders
      WHERE status::text = 'DELIVERED'
        AND "createdAt" >= ${start}
        AND "createdAt" <= ${end}
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
        categoryName: string
        categorySlug: string
        productTags: string[] | null
        variants: any
        selectedVariant: string | null
        shopName: string | null
        restaurantId: string | null
        restaurantName: string | null
        restaurantCommissionRate: number | null
        orderType: string | null
      }>
    >`
      SELECT oi."orderId", oi."productId", oi.price, COALESCE(p.mrp, oi.price) as mrp, oi.quantity, oi.name, 
             COALESCE(NULLIF(oi."costPrice", 0), p."costPrice", 0) as "costPrice", 
             c.name as "categoryName",
             c.slug as "categorySlug",
             p.tags as "productTags",
             COALESCE(oi.variants, p.variants) as "variants", 
             oi."selectedVariant",
             o."shopName" as "shopName",
             COALESCE(p."restaurantId", o."restaurantId") as "restaurantId",
             r.name as "restaurantName",
             r."commissionRate" as "restaurantCommissionRate",
             o."orderType"::text as "orderType"
      FROM order_items oi
      JOIN products p ON oi."productId" = p.id
      JOIN categories c ON p."categoryId" = c.id
      JOIN orders o ON oi."orderId" = o.id
      LEFT JOIN restaurants r ON COALESCE(p."restaurantId", o."restaurantId") = r.id
      WHERE o.status::text = 'DELIVERED'
        AND o."createdAt" >= ${start}
        AND o."createdAt" <= ${end}
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

    // Helper: calculate cost and profit for an item
    const isPureGroceryItem = (item: typeof orderItems[0]) => {
      const catNameLower = (item.categoryName || '').toLowerCase().trim()
      const catSlugLower = (item.categorySlug || '').toLowerCase().trim()
      return (
        catNameLower.includes('ice cream') || catSlugLower.includes('ice-cream') ||
        catNameLower.includes('beverage') || catNameLower.includes('drink') || catSlugLower.includes('beverage') ||
        catNameLower.includes('fruit') || catNameLower.includes('vegetable') || catSlugLower.includes('fruits-vegetables') ||
        catNameLower.includes('dairy') || catNameLower.includes('milk') || catSlugLower.includes('dairy-breakfast') ||
        catNameLower.includes('snack') || catNameLower.includes('munch') || catSlugLower.includes('snacks-munchies') ||
        catNameLower.includes('bakery') || catNameLower.includes('biscuit') || catSlugLower.includes('bakery-biscuits') ||
        catNameLower.includes('atta') || catNameLower.includes('rice') || catSlugLower.includes('dal') || catSlugLower.includes('atta-rice-dal') ||
        catNameLower.includes('personal') || catSlugLower.includes('personal-care') ||
        catNameLower.includes('house') || catSlugLower.includes('household') ||
        catNameLower.includes('essential') || catSlugLower.includes('grocery-essential')
      )
    }

    const resolveRestaurantForItem = (item: typeof orderItems[0]) => {
      if (item.restaurantId && restaurantById.has(item.restaurantId)) {
        return restaurantById.get(item.restaurantId)
      }
      if (item.restaurantName && restaurantByName.has(item.restaurantName.toLowerCase().trim())) {
        return restaurantByName.get(item.restaurantName.toLowerCase().trim())
      }
      if (item.shopName && restaurantByName.has(item.shopName.toLowerCase().trim())) {
        return restaurantByName.get(item.shopName.toLowerCase().trim())
      }
      const catLower = (item.categoryName || '').toLowerCase().trim()
      if (catLower.includes('wedson')) {
        return allRestaurants.find(r => r.slug.includes('wedson') || r.name.toLowerCase().includes('wedson'))
      }
      if (catLower.includes('as') || catLower.includes('a.s')) {
        return allRestaurants.find(r => r.slug.includes('as') || r.name.toLowerCase().includes('a.s') || r.name.toLowerCase().includes('as'))
      }
      if (catLower.includes('bal udyan') || catLower.includes('baludyan')) {
        return allRestaurants.find(r => r.slug.includes('bal') || r.name.toLowerCase().includes('bal udyan'))
      }
      if (Array.isArray(item.productTags)) {
        for (const t of item.productTags) {
          const tLower = (t || '').toLowerCase()
          if (restaurantBySlug.has(tLower)) return restaurantBySlug.get(tLower)
        }
      }
      return null
    }

    const getItemMetrics = (item: typeof orderItems[0]) => {
      const itemRevenue = item.price * item.quantity
      const isGrocery = isPureGroceryItem(item)
      const matchedRest = !isGrocery ? resolveRestaurantForItem(item) : null
      const isRestaurant = !isGrocery && (
        !!matchedRest ||
        !!item.restaurantId || 
        item.orderType === 'RESTAURANT' || 
        item.categoryName.toLowerCase().includes('restaurant') || 
        item.categoryName.toLowerCase().includes('cafe')
      )

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

      let costPrice = item.costPrice

      // If there is a selected variant, try to find its cost price in the variants array
      if (item.selectedVariant && item.variants) {
        try {
          const variantsList = typeof item.variants === 'string' ? JSON.parse(item.variants) : item.variants
          if (Array.isArray(variantsList)) {
            const matchedVariant = variantsList.find((v: any) => v.name === item.selectedVariant)
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
        costPerUnit = item.price * 0.75
        missingCostProductsMap[item.productId] = {
          id: item.productId,
          name: item.name,
          price: item.price
        }
      }
      const itemCost = costPerUnit * item.quantity
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
    const totalOrders = orders.filter(o => o.deliveryMethod !== 'RETAIL').length

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

    // Process each order
    for (const order of orders) {
      const isPickup = order.deliveryMethod === 'PICKUP'
      const isRetail = order.deliveryMethod === 'RETAIL'
      const dateString = order.createdAt.toISOString().split('T')[0]
      const orderSales = isRetail ? (order.total || order.subtotal || 0) : ((order.subtotal || 0) - (order.discount || 0))
      
      // Ensure dailyData has the key (in case it fell outside initialized range due to timezone)
      if (!dailyData[dateString]) {
        dailyData[dateString] = { date: dateString, sales: 0, profit: 0, orders: 0 }
      }

      if (!isRetail) {
        dailyData[dateString].orders++
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
        const isGrocery = isPureGroceryItem(item)
        const catNameLower = (item.categoryName || '').toLowerCase().trim()

        let targetCategoryName = item.categoryName
        let targetType: 'restaurant' | 'grocery' = 'grocery'

        if (isGrocery) {
          targetCategoryName = item.categoryName
          targetType = 'grocery'
        } else if (matchedRest) {
          targetCategoryName = matchedRest.name
          targetType = 'restaurant'
        } else if (item.restaurantId || item.orderType === 'RESTAURANT' || catNameLower.includes('restaurant') || catNameLower.includes('cafe')) {
          targetType = 'restaurant'
          if (item.restaurantName) {
            targetCategoryName = item.restaurantName
          } else if (item.shopName) {
            targetCategoryName = item.shopName
          } else if (catNameLower.includes('fastkirana restaurant') || catNameLower.includes('restaurant')) {
            targetCategoryName = 'Wedson Restaurant'
          } else {
            targetCategoryName = item.categoryName
          }
        } else {
          targetCategoryName = item.categoryName
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
        categoryData[targetCategoryName].quantity += item.quantity

        // Product breakdown
        if (!productData[item.productId]) {
          productData[item.productId] = {
            productId: item.productId,
            name: item.name,
            mrp: item.mrp || item.price,
            price: item.price,
            costPrice: item.costPrice || 0,
            quantity: 0,
            sales: 0,
            profit: 0,
            categoryName: targetCategoryName,
            type: targetType
          }
        }
        productData[item.productId].quantity += item.quantity
        productData[item.productId].sales += itemRev
        productData[item.productId].profit += itemProf
      }

      // Order profit = order.total - orderCost
      const orderProfit = order.total - orderCost
      
      if (!isRetail) {
        dailyData[dateString].profit += orderProfit
        totalProfit += orderProfit
        totalCost += orderCost
      }

      if (isPickup) {
        pickupOrdersCount++
        pickupSales += orderSales
        pickupProfit += orderProfit
      } else if (isRetail) {
        retailOrdersCount++
        retailSales += orderSales
        retailProfit += orderProfit
      } else {
        deliveryOrdersCount++
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
