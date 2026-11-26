import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { auth } from '@/auth'
import { requireAdmin, getEffectiveStoreId } from '@/lib/auth-guard'

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

    // Helper to format any date to Indian Standard Time (IST) YYYY-MM-DD
    const getISTDateString = (d: Date | string | null | undefined): string => {
      if (!d) return ''
      const dt = d instanceof Date ? d : new Date(d)
      if (isNaN(dt.getTime())) return ''
      return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata' }).format(dt)
    }

    if (startDateParam) {
      start = new Date(`${startDateParam}T00:00:00.000+05:30`)
    } else {
      start = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)
      start.setHours(0, 0, 0, 0)
    }

    if (endDateParam) {
      end = new Date(`${endDateParam}T23:59:59.999+05:30`)
    } else {
      end = new Date(now.getTime())
      end.setHours(23, 59, 59, 999)
    }

    const storeId = getEffectiveStoreId(session, searchParams.get('storeId'))

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
        liveCostPrice?: number
        snapshotCostPrice?: number
        liveBasePrice?: number
        unit?: string | null
        vendor: string | null
        categoryName: string
        categorySlug: string
        parentCategoryName?: string | null
        parentCategorySlug?: string | null
        productTags: string[] | null
        variants: any
        liveVariants?: any
        snapshotVariants?: any
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
             COALESCE(NULLIF(p."costPrice", 0), oi."costPrice", 0) as "costPrice",
             COALESCE(p."costPrice", 0) as "liveCostPrice",
             COALESCE(oi."costPrice", 0) as "snapshotCostPrice",
             COALESCE(p.price, 0) as "liveBasePrice",
             p.unit as "unit",
             COALESCE(p.vendor, 'Direct / FastKirana') as "vendor",
             COALESCE(c.name, CASE WHEN p."restaurantId" IS NOT NULL THEN r.name ELSE 'General Grocery' END) as "categoryName",
             COALESCE(c.slug, CASE WHEN p."restaurantId" IS NOT NULL THEN r.slug ELSE 'general-grocery' END) as "categorySlug",
             parent_c.name as "parentCategoryName",
             parent_c.slug as "parentCategorySlug",
             p.tags as "productTags",
             COALESCE(p.variants, oi.variants) as "variants",
             p.variants as "liveVariants",
             oi.variants as "snapshotVariants",
             oi."selectedVariant",
             o."shopName" as "shopName",
             p."restaurantId" as "prodRestaurantId",
             o."restaurantId" as "orderRestaurantId",
             r.name as "restaurantName",
             r."commissionRate" as "restaurantCommissionRate",
             o."orderType"::text as "orderType",
             COALESCE(oi."refundAmount", 0)::float as "refundAmount",
             COALESCE(oi."isRefunded", false) as "isRefunded",
             CASE
               WHEN (p.id IS NOT NULL AND p."restaurantId" IS NULL)
                 OR (p.id IS NULL AND o."restaurantId" IS NULL AND COALESCE(o."orderType"::text, 'GROCERY') = 'GROCERY')
               THEN true ELSE false
             END as "isGroceryProduct"
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

    const canonicalizeUnit = (s: string | null | undefined): string => {
      let t = (s || '').toLowerCase().replace(/[,;()\[\]]/g, ' ').replace(/\s+/g, ' ').trim()
      t = t.replace(/\b(kilograms?|kgs)\b/g, 'kg')
      t = t.replace(/\b(grams?|gms|gm)\b/g, 'g')
      t = t.replace(/\b(millilitres?|milliliters?|mls)\b/g, 'ml')
      t = t.replace(/\b(litres?|liters?|ltrs|ltr)\b/g, 'l')
      t = t.replace(/\b(pieces?|pcs)\b/g, 'pc')
      t = t.replace(/\b(packets?|pkts)\b/g, 'pkt')
      return t.replace(/[^a-z0-9]/g, '')
    }

    const extractVariantFromName = (name: string | null | undefined): string => {
      if (!name) return ''
      const matches = [...name.matchAll(/[\(\[]([^\)\]]+)[\)\]]/g)].map(m => m[1].trim()).filter(Boolean)
      if (matches.length === 0) return ''
      const withUnit = matches.find(c => /\b(\d+|half|full|serving|pc|pcs|kg|g|gm|gms|ml|l|ltr|pack)\b/i.test(c))
      return withUnit || matches[matches.length - 1]
    }

    const parseVariantsList = (rawVariants: any): any[] => {
      if (!rawVariants) return []
      try {
        const parsed = typeof rawVariants === 'string' ? JSON.parse(rawVariants) : rawVariants
        if (Array.isArray(parsed)) return parsed
        if (parsed && typeof parsed === 'object') {
          if (Array.isArray(parsed.productVariants)) return parsed.productVariants
          if (Array.isArray(parsed.variants)) return parsed.variants
        }
      } catch {}
      return []
    }

    const extractVariantCost = (variantsList: any[], targetVariant: string, itemPrice: number): number => {
      if (!Array.isArray(variantsList) || variantsList.length === 0) return 0
      if (targetVariant) {
        const normTarget = normalizeText(targetVariant)
        const canonTarget = canonicalizeUnit(targetVariant)
        // 1. Exact or unit-canonical match (never substring-match "50g" inside "250g")
        const matched = variantsList.find((v: any) => {
          if (!v) return false
          const vNameRaw = String(v.name || '')
          const vUnitRaw = String(v.unit || '')
          return (
            normalizeText(vNameRaw) === normTarget ||
            normalizeText(vUnitRaw) === normTarget ||
            (canonTarget && (canonicalizeUnit(vNameRaw) === canonTarget || canonicalizeUnit(vUnitRaw) === canonTarget))
          )
        })
        const matchedCp = Number(matched?.costPrice ?? matched?.cp ?? matched?.cost ?? 0)
        if (matchedCp > 0) return matchedCp
      }
      // 2. Fallback to exact selling price match against variants
      if (itemPrice > 0) {
        const priceMatched = variantsList.find((v: any) => v && Number(v.price) > 0 && Math.abs(Number(v.price) - itemPrice) < 0.01)
        const priceCp = Number(priceMatched?.costPrice ?? priceMatched?.cp ?? priceMatched?.cost ?? 0)
        if (priceCp > 0) return priceCp
      }
      return 0
    }

    const resolveItemCostPrice = (item: typeof orderItems[0]): { costPerUnit: number; isMissing: boolean } => {
      const targetVariant = (item.selectedVariant || '').trim() || extractVariantFromName(item.name)
      const liveVariants = parseVariantsList(item.liveVariants)
      const snapshotVariants = parseVariantsList(item.snapshotVariants)
      const itemPrice = Number(item.price || 0)
      const liveCost = Number(item.liveCostPrice || 0)
      const snapshotCost = Number(item.snapshotCostPrice || 0)
      const liveBasePrice = Number(item.liveBasePrice || 0)
      const prodUnitCanon = canonicalizeUnit(item.unit)
      const targetVarCanon = canonicalizeUnit(targetVariant)

      // 1. Always prefer live updated catalog variant cost first
      let resolved = extractVariantCost(liveVariants, targetVariant, itemPrice)

      // 2. Live base product cost (when single/no variants, or matches base unit/price)
      const isBaseMatch =
        liveVariants.length <= 1 ||
        !targetVarCanon ||
        (prodUnitCanon && targetVarCanon === prodUnitCanon) ||
        (liveBasePrice > 0 && Math.abs(liveBasePrice - itemPrice) < 0.01)
      if (resolved <= 0 && isBaseMatch && liveCost > 0) {
        resolved = liveCost
      }

      // 3. Fallback to order-item snapshot only when live catalog has no cost set
      if (resolved <= 0) {
        resolved = extractVariantCost(snapshotVariants, targetVariant, itemPrice)
      }
      if (resolved <= 0 && snapshotCost > 0) {
        resolved = snapshotCost
      }

      if (resolved > 0) {
        return { costPerUnit: resolved, isMissing: false }
      }
      return { costPerUnit: 0, isMissing: true }
    }

    const getItemMetrics = (item: typeof orderItems[0]) => {
      const grossRevenue = (item.price || 0) * (item.quantity || 1)
      const itemRevenue = Math.max(0, grossRevenue - (item.refundAmount || 0))
      if (item.isRefunded && itemRevenue === 0) {
        return { cost: 0, revenue: 0, profit: 0, matchedRest: null, unitCost: 0, hasCost: true }
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
        return { cost: itemCost, revenue: itemRevenue, profit: itemProfit, matchedRest, unitCost, hasCost: true }
      }

      const { costPerUnit, isMissing } = resolveItemCostPrice(item)
      if (isMissing) {
        const prodKey = item.productId || `manual_${(item.name || 'item').toLowerCase().replace(/[^a-z0-9]/g, '_')}`
        missingCostProductsMap[prodKey] = {
          id: prodKey,
          name: item.name || 'Unnamed Product',
          price: item.price || 0
        }
        return { cost: 0, revenue: itemRevenue, profit: 0, matchedRest: null, unitCost: 0, hasCost: false }
      }

      const itemCost = costPerUnit * (item.quantity || 1)
      const itemProfit = itemRevenue - itemCost
      
      return { cost: itemCost, revenue: itemRevenue, profit: itemProfit, matchedRest: null, unitCost: costPerUnit, hasCost: true }
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
      const dateString = getISTDateString(currentDate)
      if (dateString && !dailyData[dateString]) {
        dailyData[dateString] = { date: dateString, sales: 0, profit: 0, orders: 0 }
      }
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
        costedQty?: number;
        costMissing?: boolean;
      }
    > = {}

    // Date-wise product breakdown for vendor & supplier payouts
    type DailyProductSale = {
      date: string
      productId: string
      baseProductId?: string
      name: string
      variantName?: string
      categoryName: string
      parentCategoryName?: string
      vendor: string
      type: 'restaurant' | 'grocery'
      quantity: number
      price: number
      costPrice: number
      totalCost: number
      totalSales: number
      profit: number
      sales?: number
      costedQty?: number
      costMissing?: boolean
    }
    const dailyProductData: Record<string, DailyProductSale> = {}

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
      const dateString = getISTDateString(order.createdAt)
      const rawSales = isRetail ? (order.total || order.subtotal || 0) : ((order.subtotal || 0) - (order.discount || 0))
      const orderSales = Math.max(0, rawSales - (order.refundAmount || 0))
      
      // Ensure dailyData has the key (in case it fell outside initialized range due to timezone)
      if (dateString && !dailyData[dateString]) {
        dailyData[dateString] = { date: dateString, sales: 0, profit: 0, orders: 0 }
      }

      if (!isRetail && dateString) {
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
      let orderUncostedRev = 0

      for (const item of items) {
        const { cost, revenue: itemRev, profit: itemProf, matchedRest, unitCost, hasCost } = getItemMetrics(item)
        orderCost += cost
        if (!hasCost) {
          orderUncostedRev += itemRev
        }

        if (isRetail) continue // Skip adding retail items to category and product breakdown
        if (item.isRefunded && itemRev === 0) continue // Skip fully refunded items from sold breakdown

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

        // Robust variant resolution for order items (handles explicit variant, name parsing, and deduplication)
        let resolvedVariant = (item.selectedVariant || '').trim()
        if (!resolvedVariant && item.name) {
          const match = item.name.match(/[\(\[]([^\)\]]+)[\)\]]/)
          if (match) resolvedVariant = match[1].trim()
        }

        const rawItemName = (item.name || 'Unnamed Product').trim()
        const baseNameWithoutParen = rawItemName.replace(/\s*[\(\[][^\)\]]*[\)\]]\s*$/g, '').trim()
        const displayName = resolvedVariant
          ? (rawItemName.toLowerCase().includes(resolvedVariant.toLowerCase())
              ? rawItemName
              : `${baseNameWithoutParen} (${resolvedVariant})`)
          : rawItemName
        
        const normVar = resolvedVariant ? normalizeText(resolvedVariant) : ''
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
            costPrice: hasCost ? itemUnitCost : 0,
            costedQty: 0,
            costMissing: false,
            totalCost: 0,
            quantity: 0,
            sales: 0,
            profit: 0,
            categoryName: targetCategoryName,
            parentCategoryName: (item.parentCategoryName || '').trim(),
            vendor: (item.vendor || 'Direct / FastKirana').trim(),
            type: targetType,
            variantName: resolvedVariant || undefined,
            minPrice: itemSellingPrice,
            maxPrice: itemSellingPrice,
            minCost: hasCost ? itemUnitCost : 0,
            maxCost: hasCost ? itemUnitCost : 0,
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
          if (hasCost && itemUnitCost > 0) {
            if ((productData[prodKey].minCost ?? 0) === 0 || itemUnitCost < (productData[prodKey].minCost ?? itemUnitCost)) {
              productData[prodKey].minCost = itemUnitCost
            }
            if (itemUnitCost > (productData[prodKey].maxCost ?? itemUnitCost)) {
              productData[prodKey].maxCost = itemUnitCost
            }
          }
        }
        const qtyInt = item.quantity || 1
        productData[prodKey].quantity += qtyInt
        if (hasCost) {
          productData[prodKey].costedQty = (productData[prodKey].costedQty || 0) + qtyInt
        }
        productData[prodKey].sales += itemRev
        productData[prodKey].totalCost += cost
        productData[prodKey].profit += itemProf

        // Date-wise product tracking for vendor/supplier payout reconciliation
        const dailyProdKey = `${dateString}__${prodKey}`
        if (!dailyProductData[dailyProdKey]) {
          dailyProductData[dailyProdKey] = {
            date: dateString,
            productId: prodKey,
            baseProductId: item.productId,
            name: displayName,
            variantName: resolvedVariant || undefined,
            categoryName: targetCategoryName,
            parentCategoryName: (item.parentCategoryName || '').trim(),
            vendor: (item.vendor || 'Direct / FastKirana').trim(),
            type: targetType,
            quantity: qtyInt,
            price: itemSellingPrice,
            costPrice: hasCost ? itemUnitCost : 0,
            costedQty: hasCost ? qtyInt : 0,
            costMissing: false,
            totalCost: cost,
            totalSales: itemRev,
            profit: itemProf,
          }
        } else {
          dailyProductData[dailyProdKey].quantity += qtyInt
          if (hasCost) {
            dailyProductData[dailyProdKey].costedQty = (dailyProductData[dailyProdKey].costedQty || 0) + qtyInt
          }
          dailyProductData[dailyProdKey].totalSales += itemRev
          dailyProductData[dailyProdKey].totalCost += cost
          dailyProductData[dailyProdKey].profit += itemProf
          if (hasCost && dailyProductData[dailyProdKey].costPrice === 0 && itemUnitCost > 0) {
            dailyProductData[dailyProdKey].costPrice = itemUnitCost
          }
        }
      }

      // Order profit = order.total - orderCost - uncosted revenue
      const orderProfit = (order.total || 0) - orderCost - orderUncostedRev
      
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
      const costedQty = p.costedQty || 0
      p.costMissing = costedQty === 0 && p.type !== 'restaurant'
      if (p.quantity > 0) {
        p.costPrice = costedQty > 0 ? Math.round((p.totalCost / costedQty) * 100) / 100 : 0
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
            costMissing: !(resolvedCatalogCost > 0),
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

    const dailyProductList = Object.values(dailyProductData)
      .map(p => {
        const qty = p.quantity || 1
        const costedQty = p.costedQty || 0
        const costMissing = costedQty === 0 && p.type !== 'restaurant'
        return {
          ...p,
          costMissing,
          costPrice: costedQty > 0 ? Math.round((p.totalCost / costedQty) * 100) / 100 : 0,
          price: Math.round((p.totalSales / qty) * 100) / 100,
          totalCost: Math.round(p.totalCost * 100) / 100,
          totalSales: Math.round(p.totalSales * 100) / 100,
          profit: Math.round(p.profit * 100) / 100,
        }
      })
      .sort((a, b) => b.date.localeCompare(a.date) || b.totalCost - a.totalCost)

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
      dailyProductSales: dailyProductList,
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
