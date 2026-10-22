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
        parentCategoryName?: string | null
        parentCategorySlug?: string | null
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
             parent_c.name as "parentCategoryName",
             parent_c.slug as "parentCategorySlug",
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
      LEFT JOIN categories parent_c ON c."parentId" = parent_c.id
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
    const restaurantById = new Map<string, { id: string; name: string; slug: string; commissionRate: any }>(allRestaurants.map(r => [r.id, r]))
    const restaurantByName = new Map<string, { id: string; name: string; slug: string; commissionRate: any }>(allRestaurants.map(r => [r.name.toLowerCase().trim(), r]))
    const restaurantBySlug = new Map<string, { id: string; name: string; slug: string; commissionRate: any }>(allRestaurants.map(r => [r.slug.toLowerCase().trim(), r]))

    // Fetch dynamic settings
    const settingsList = await prisma.storeSetting.findMany({
      where: { key: { in: ['restaurant_commission', 'restaurant_default_margin', 'cafe_default_margin'] } }
    })
    const settingsMap = new Map<string, string>(settingsList.map(s => [s.key, String(s.value ?? '')]))
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

    const normalizeText = (s: string | null | undefined): string => {
      return (s || '').toLowerCase().replace(/[^a-z0-9]/g, '')
    }

    const resolveItemCostPrice = (item: typeof orderItems[0]): { costPerUnit: number; isEstimated: boolean } => {
      // 1. Explicit costPrice on order item if > 0
      if (item.costPrice && Number(item.costPrice) > 0) {
        return { costPerUnit: Number(item.costPrice), isEstimated: false }
      }

      // 2. Parse variants
      const rawVariants = item.variants
      let variantsList: any[] = []
      if (rawVariants) {
        try {
          variantsList = typeof rawVariants === 'string' ? JSON.parse(rawVariants) : rawVariants
        } catch {}
      }

      let targetVariant = item.selectedVariant
      if (!targetVariant && item.name && item.name.includes('(')) {
        const match = item.name.match(/\(([^)]+)\)/)
        if (match) targetVariant = match[1]
      }

      if (Array.isArray(variantsList) && variantsList.length > 0) {
        if (targetVariant) {
          const normTarget = normalizeText(targetVariant)
          const matched = variantsList.find((v: any) => {
            if (!v) return false
            const vName = normalizeText(v.name)
            const vUnit = normalizeText(v.unit)
            return vName === normTarget || vUnit === normTarget || normTarget.includes(vName) || vName.includes(normTarget)
          })
          if (matched && Number(matched.costPrice) > 0) {
            return { costPerUnit: Number(matched.costPrice), isEstimated: false }
          }
        }

        // Try price match fallback against variants
        const priceMatched = variantsList.find((v: any) => v && Number(v.price) === Number(item.price))
        if (priceMatched && Number(priceMatched.costPrice) > 0) {
          return { costPerUnit: Number(priceMatched.costPrice), isEstimated: false }
        }

        // Check if any variant has costPrice
        const anyWithCost = variantsList.find((v: any) => v && Number(v.costPrice) > 0 && Number(v.price) > 0)
        if (anyWithCost && Number(item.price) > 0) {
          const marginRatio = Number(anyWithCost.costPrice) / Number(anyWithCost.price)
          if (marginRatio > 0 && marginRatio < 1) {
            return { costPerUnit: Math.round(Number(item.price) * marginRatio * 100) / 100, isEstimated: false }
          }
        }
      }

      // 3. Fallback to base product costPrice if > 0
      if (item.costPrice && Number(item.costPrice) > 0) {
        return { costPerUnit: Number(item.costPrice), isEstimated: false }
      }

      // 4. Default 25% margin estimate (75% cost)
      const estimatedCost = Math.round(Number(item.price || 0) * 0.75 * 100) / 100
      return { costPerUnit: estimatedCost, isEstimated: true }
    }

    const getItemMetrics = (item: typeof orderItems[0]) => {
      const grossRevenue = (item.price || 0) * (item.quantity || 1)
      const itemRevenue = Math.max(0, grossRevenue - (item.refundAmount || 0))
      if (item.isRefunded && itemRevenue === 0) {
        return { cost: 0, revenue: 0, profit: 0, matchedRest: null, unitCost: 0 }
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
        const unitCost = (item.quantity || 1) > 0 ? (itemCost / (item.quantity || 1)) : itemCost
        return { cost: itemCost, revenue: itemRevenue, profit: itemProfit, matchedRest, unitCost }
      }

      const { costPerUnit, isEstimated } = resolveItemCostPrice(item)
      if (isEstimated) {
        const prodKey = item.productId || `manual_${(item.name || 'item').toLowerCase().replace(/[^a-z0-9]/g, '_')}`
        missingCostProductsMap[prodKey] = {
          id: prodKey,
          name: item.name || 'Unnamed Product',
          price: item.price || 0
        }
      }

      const itemCost = costPerUnit * (item.quantity || 1)
      const itemProfit = itemRevenue - itemCost
      
      return { cost: itemCost, revenue: itemRevenue, profit: itemProfit, matchedRest: null, unitCost: costPerUnit }
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
        baseProductId?: string;
        name: string; 
        mrp: number; 
        price: number; 
        costPrice: number; 
        totalCost: number;
        quantity: number; 
        sales: number; 
        profit: number; 
        categoryName: string; 
        parentCategoryName?: string;
        vendor: string;
        type: 'restaurant' | 'grocery';
        stock?: number;
        readableId?: string | number;
        variantName?: string;
        minPrice?: number;
        maxPrice?: number;
        minCost?: number;
        maxCost?: number;
        hasPriceVaried?: boolean;
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
        const { cost, revenue: itemRev, profit: itemProf, matchedRest, unitCost } = getItemMetrics(item)
        orderCost += cost

        if (isRetail) continue // Skip adding retail items to category and product breakdown

        // Strict Category Resolution
        const isGrocery = Boolean(item.isGroceryProduct)

        let targetCategoryName = item.categoryName || 'General Store'
        let targetType: 'restaurant' | 'grocery' = 'grocery'

        if (isGrocery) {
          targetCategoryName = (item.categoryName || 'Grocery Essentials').trim()
          targetType = 'grocery'
        } else if (matchedRest) {
          targetCategoryName = (matchedRest.name || 'Restaurant').trim()
          targetType = 'restaurant'
        } else if (item.prodRestaurantId) {
          const rObj = restaurantById.get(item.prodRestaurantId)
          targetCategoryName = (rObj?.name || item.restaurantName || 'Restaurant Food').trim()
          targetType = 'restaurant'
        } else {
          targetCategoryName = (item.categoryName || 'General Store').trim()
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

        // Product breakdown with distinct variant tracking
        const variantSuffix = item.selectedVariant && item.selectedVariant.trim() ? item.selectedVariant.trim() : null
        const cleanName = (item.name || 'Unnamed Product').trim()
        const displayName = variantSuffix && !cleanName.toLowerCase().includes(variantSuffix.toLowerCase())
          ? `${cleanName} (${variantSuffix})`
          : cleanName
        
        const normVar = variantSuffix ? normalizeText(variantSuffix) : ''
        const prodKey = item.productId
          ? `${item.productId}${normVar ? `_${normVar}` : ''}`
          : `manual_${normalizeText(displayName)}`

        const itemSellingPrice = item.price || 0
        const itemUnitCost = unitCost || 0

        if (!productData[prodKey]) {
          productData[prodKey] = {
            productId: prodKey,
            baseProductId: item.productId,
            name: displayName,
            mrp: item.mrp || item.price || 0,
            price: itemSellingPrice,
            costPrice: itemUnitCost,
            totalCost: 0,
            quantity: 0,
            sales: 0,
            profit: 0,
            categoryName: targetCategoryName,
            parentCategoryName: (item.parentCategoryName || '').trim(),
            vendor: (item.vendor || 'Direct / FastKirana').trim(),
            type: targetType,
            variantName: variantSuffix || undefined,
            minPrice: itemSellingPrice,
            maxPrice: itemSellingPrice,
            minCost: itemUnitCost,
            maxCost: itemUnitCost,
            hasPriceVaried: false,
          }
        } else {
          if (itemSellingPrice > 0) {
            if ((productData[prodKey].minPrice ?? 0) === 0 || itemSellingPrice < (productData[prodKey].minPrice ?? itemSellingPrice)) {
              productData[prodKey].minPrice = itemSellingPrice
            }
            if (itemSellingPrice > (productData[prodKey].maxPrice ?? itemSellingPrice)) {
              productData[prodKey].maxPrice = itemSellingPrice
            }
          }
          if (itemUnitCost > 0) {
            if ((productData[prodKey].minCost ?? 0) === 0 || itemUnitCost < (productData[prodKey].minCost ?? itemUnitCost)) {
              productData[prodKey].minCost = itemUnitCost
            }
            if (itemUnitCost > (productData[prodKey].maxCost ?? itemUnitCost)) {
              productData[prodKey].maxCost = itemUnitCost
            }
          }
        }
        productData[prodKey].quantity += (item.quantity || 1)
        productData[prodKey].sales += itemRev
        productData[prodKey].totalCost += cost
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

    // Compute accurate weighted unit cost and unit selling price for sold products
    for (const prodKey in productData) {
      const p = productData[prodKey]
      if (p.quantity > 0) {
        p.costPrice = Math.round((p.totalCost / p.quantity) * 100) / 100
        p.price = Math.round((p.sales / p.quantity) * 100) / 100
        if (p.minPrice !== undefined && p.maxPrice !== undefined && p.minPrice !== p.maxPrice) {
          p.hasPriceVaried = true
        }
        if (p.minCost !== undefined && p.maxCost !== undefined && p.minCost !== p.maxCost) {
          p.hasPriceVaried = true
        }
      }
    }

    // Merge full grocery catalog to ensure 100% complete grocery coverage (including unsold items with qty=0)
    try {
      const allGroceryProducts = await prisma.product.findMany({
        where: {
          restaurantId: null,
          isAvailable: true,
        },
        select: {
          id: true,
          readableId: true,
          name: true,
          mrp: true,
          price: true,
          costPrice: true,
          stock: true,
          vendor: true,
          variants: true,
          category: {
            select: {
              name: true,
              parent: {
                select: {
                  name: true
                }
              }
            }
          }
        }
      })

      for (const gp of allGroceryProducts) {
        // Resolve a fallback cost for products whose base costPrice is 0 but have variants with cost
        let resolvedCatalogCost = gp.costPrice || 0
        if (!resolvedCatalogCost && gp.variants) {
          try {
            const vList = typeof gp.variants === 'string' ? JSON.parse(gp.variants as string) : gp.variants
            if (Array.isArray(vList) && vList.length > 0) {
              const firstWithCost = vList.find((v: any) => v && Number(v.costPrice) > 0)
              if (firstWithCost) resolvedCatalogCost = Number(firstWithCost.costPrice)
            }
          } catch {}
        }
        if (!resolvedCatalogCost && gp.price > 0) {
          resolvedCatalogCost = Math.round(gp.price * 0.75 * 100) / 100
        }

        // Check if any variant or base entry of this product was sold
        const matchingKeys = Object.keys(productData).filter(k => 
          k === gp.id || productData[k].baseProductId === gp.id
        )

        if (matchingKeys.length > 0) {
          for (const mk of matchingKeys) {
            (productData[mk] as any).stock = gp.stock
            if (gp.readableId) (productData[mk] as any).readableId = gp.readableId
          }
        } else {
          // Unsold product: add to catalog listing
          const catName = (gp.category?.name || 'Grocery Essentials').trim()
          const parentCatName = (gp.category?.parent?.name || '').trim()
          productData[gp.id] = {
            productId: gp.id,
            baseProductId: gp.id,
            name: gp.name.trim(),
            mrp: gp.mrp || gp.price || 0,
            price: gp.price || 0,
            costPrice: resolvedCatalogCost,
            totalCost: 0,
            quantity: 0,
            sales: 0,
            profit: 0,
            categoryName: catName,
            parentCategoryName: parentCatName,
            vendor: (gp.vendor || 'Direct / FastKirana').trim(),
            type: 'grocery',
            stock: gp.stock ?? 0,
            readableId: gp.readableId,
          } as any
        }
      }
    } catch (catErr) {
      console.warn('Failed to merge grocery catalog into reports:', catErr)
    }

    // Convert grouped records to arrays without arbitrary slice limits (100% complete data)
    const dailyList = Object.values(dailyData).sort((a, b) => a.date.localeCompare(b.date))
    const categoryList = Object.values(categoryData).sort((a, b) => b.sales - a.sales)
    const productList = Object.values(productData).sort((a, b) => {
      if (b.sales !== a.sales) return b.sales - a.sales
      return (b.quantity || 0) - (a.quantity || 0)
    })

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
