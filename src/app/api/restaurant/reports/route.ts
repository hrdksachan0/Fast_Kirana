import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { formatDate } from '@/lib/date-helpers'

import { getLast10Digits } from '@/lib/phone'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const email = session.user.email || ''
    const phone = (session.user as any).phone || ''
    const cleanPhone = phone ? getLast10Digits(phone) : ''
    let assignedRestId = (session.user as any).assignedRestaurantId

    if (!assignedRestId && cleanPhone) {
      const dbUser = await prisma.user.findFirst({
        where: {
          OR: [
            { phone: { endsWith: cleanPhone } },
            { phone: `+91${cleanPhone}` }
          ],
          assignedRestaurantId: { not: null }
        },
        select: { assignedRestaurantId: true }
      })
      if (dbUser?.assignedRestaurantId) {
        assignedRestId = dbUser.assignedRestaurantId
      } else {
        const rest = await prisma.restaurant.findFirst({
          where: { ownerPhone: { contains: cleanPhone } },
          select: { id: true }
        })
        if (rest) assignedRestId = rest.id
      }
    }

    const isAllowed = role === 'ADMIN' || role === 'RESTAURANT_OWNER' || role === 'CHEF'
    
    if (!isAllowed) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { searchParams } = new URL(request.url)
    const startDateParam = searchParams.get('startDate')
    const endDateParam = searchParams.get('endDate')
    const paramRestId = searchParams.get('restaurantId')

    const isPlatformAdmin = role === 'ADMIN'
    let effectiveRestId = (!isPlatformAdmin && assignedRestId) 
      ? assignedRestId 
      : (paramRestId || assignedRestId || null)

    if (!effectiveRestId) {
      return NextResponse.json({ error: 'No restaurant specified' }, { status: 400 })
    }
    
    const norm = (effectiveRestId || '').toLowerCase().trim()
    if (norm === 'cms2p1lap0000n0id8alldboy' || norm === 'as-restaurant' || norm === 'as-cafe' || norm === 'rest-101') effectiveRestId = 'REST-101'
    else if (norm === 'cms2p1lyx0001n0idod904lfu' || norm === 'wedson-restaurant' || norm === 'wedson' || norm === 'rest-102') effectiveRestId = 'REST-102'
    else if (norm === 'cmsbhxb6a000304if8kf1cwji' || norm === 'bal-udyan-restaurant' || norm === 'bal-udyan' || norm === 'bal udyan' || norm === 'rest-103') effectiveRestId = 'REST-103'
    else if (norm === 'cmtn66nhy000004k0fu84b7ke' || norm === 'pari-milk-dairy-sweets' || norm === 'pari-milk' || norm === 'pari' || norm === 'rest-104') effectiveRestId = 'REST-104'

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

    // 1. Fetch delivered orders strictly for the specific Restaurant within range
    type OrderRow = {
      id: string
      total: number
      subtotal: number
      discount: number
      deliveryFee: number
      taxes: number
      miscFee: number
      deliveryMethod: string
      createdAt: Date
    }

    type ItemRow = {
      orderId: string
      productId: string
      price: number
      quantity: number
      name: string
      costPrice: number
      categoryName: string
      categorySlug?: string
      restaurantId?: string | null
      variants: any
      selectedVariant: string | null
    }

    const orders = await prisma.$queryRaw<OrderRow[]>`
      SELECT id, total, subtotal, discount, "deliveryFee", taxes, "miscFee", "deliveryMethod", "createdAt"
      FROM orders
      WHERE status::text = 'DELIVERED'
        AND "restaurantId" = ${effectiveRestId}
        AND ("shopName" IS NULL OR ("shopName" != 'FastKirana Dark Store' AND "shopName" != 'FastKirana Grocery'))
        AND "createdAt" >= ${start}
        AND "createdAt" <= ${end}
      ORDER BY "createdAt" ASC
    `

    const orderItems = await prisma.$queryRaw<ItemRow[]>`
      SELECT oi."orderId", oi."productId", oi.price, oi.quantity, oi.name, 
             COALESCE(NULLIF(oi."costPrice", 0), p."costPrice", 0) as "costPrice", 
             c.name as "categoryName",
             c.slug as "categorySlug",
             p."restaurantId" as "restaurantId",
             COALESCE(oi.variants, p.variants) as "variants", 
             oi."selectedVariant"
      FROM order_items oi
      JOIN orders o ON oi."orderId" = o.id
      LEFT JOIN products p ON oi."productId" = p.id
      LEFT JOIN categories c ON p."categoryId" = c.id
      WHERE o.status::text = 'DELIVERED'
        AND o."restaurantId" = ${effectiveRestId}
        AND ("shopName" IS NULL OR ("shopName" != 'FastKirana Dark Store' AND "shopName" != 'FastKirana Grocery'))
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

    // Fetch dynamic settings from database
    const dbSettings = await prisma.storeSetting.findMany({
      where: {
        key: { in: ['restaurant_commission', 'restaurant_profit_share', 'restaurant_default_margin'] }
      }
    })
    const dbSettingsMap = new Map(dbSettings.map(s => [s.key, s.value]))
    
    // Parse rates (fallback to global setting)
    let commissionRate = parseFloat(dbSettingsMap.get('restaurant_commission') || '10') / 100
    if (effectiveRestId) {
      const restObj = await prisma.restaurant.findUnique({
        where: { id: effectiveRestId },
        select: { commissionRate: true }
      })
      if (restObj && restObj.commissionRate !== null && restObj.commissionRate !== undefined) {
        commissionRate = restObj.commissionRate > 1.0 ? restObj.commissionRate / 100 : restObj.commissionRate
      }
    }
    const profitShareRate = parseFloat(dbSettingsMap.get('restaurant_profit_share') || '15') / 100
    const restaurantDefaultMargin = parseFloat(dbSettingsMap.get('restaurant_default_margin') || '30')

    // Helper: calculate cost and profit for an item with dynamic margin
    const getItemMetrics = (item: typeof orderItems[0]) => {
      const totalItemSales = item.price * item.quantity
      const adminProfit = totalItemSales * commissionRate
      const restaurantProfit = totalItemSales - adminProfit

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

      const costPerUnit = costPrice > 0 ? costPrice : item.price * (1 - restaurantDefaultMargin / 100)
      const ingredientCost = costPerUnit * item.quantity
      const netKitchenProfit = restaurantProfit - ingredientCost

      return { cost: ingredientCost, sales: totalItemSales, profit: netKitchenProfit, restaurantProfit, adminProfit }
    }

    // Define helper to identify grocery items (cold drinks, snacks, etc.)
    const isPureGroceryItem = (item: ItemRow) => {
      if (item.restaurantId) return false
      const catNameLower = (item.categoryName || '').toLowerCase().trim()
      const catSlugLower = (item.categorySlug || '').toLowerCase().trim()
      return (
        catNameLower.includes('beverage') ||
        catNameLower.includes('drink') ||
        catNameLower.includes('cold drink') ||
        catSlugLower.includes('beverage') ||
        catNameLower.includes('ice cream') ||
        catSlugLower.includes('ice-cream') ||
        catNameLower.includes('snack') ||
        catSlugLower.includes('snacks') ||
        catNameLower.includes('grocery')
      )
    }

    // 3. Process Financials Summary (with Channel Separation)
    let totalSales = 0
    let totalCost = 0
    let totalDiscount = 0
    let totalTaxes = 0
    let totalMisc = 0
    let totalRestaurantProfit = 0
    let totalAdminProfit = 0

    let deliveryOrdersCount = 0
    let deliverySales = 0
    let deliveryRestaurantProfit = 0
    let deliveryAdminProfit = 0

    let pickupOrdersCount = 0
    let pickupSales = 0
    let pickupRestaurantProfit = 0
    let pickupAdminProfit = 0

    orders.forEach(o => {
      const isPickup = o.deliveryMethod === 'PICKUP'
      totalDiscount += o.discount || 0
      totalTaxes += o.taxes || 0
      totalMisc += o.miscFee || 0

      const items = itemsByOrder[o.id] || []
      const orderRestSalesRaw = items.length > 0
        ? items.reduce((sum, item) => {
            if (isPureGroceryItem(item)) return sum
            return sum + (item.price * item.quantity)
          }, 0)
        : (o.subtotal || o.total || 0)

      const discountShare = o.subtotal > 0 ? (o.discount * (orderRestSalesRaw / o.subtotal)) : 0
      const foodSales = Math.max(0, orderRestSalesRaw - discountShare)
      totalSales += foodSales

      let orderRestProfit = 0
      let orderAdmProfit = 0
      if (items.length > 0) {
        items.forEach(item => {
          if (isPureGroceryItem(item)) return
          
          const metrics = getItemMetrics(item)
          orderRestProfit += metrics.restaurantProfit
          orderAdmProfit += metrics.adminProfit
          totalRestaurantProfit += metrics.restaurantProfit
          totalAdminProfit += metrics.adminProfit
          totalCost += metrics.cost
        })
      } else {
        const admProfit = foodSales * commissionRate
        const restProfit = foodSales - admProfit
        orderRestProfit += restProfit
        orderAdmProfit += admProfit
        totalRestaurantProfit += restProfit
        totalAdminProfit += admProfit
        totalCost += foodSales * (1 - restaurantDefaultMargin / 100)
      }

      if (isPickup) {
        pickupOrdersCount++
        pickupSales += foodSales
        pickupRestaurantProfit += orderRestProfit
        pickupAdminProfit += orderAdmProfit
      } else {
        deliveryOrdersCount++
        deliverySales += foodSales
        deliveryRestaurantProfit += orderRestProfit
        deliveryAdminProfit += orderAdmProfit
      }
    })

    const netProfit = totalRestaurantProfit - totalCost

    // 4. Daily Sales Trend
    const dailyTrendMap = new Map<string, { date: string; sales: number; profit: number; adminProfit: number; orders: number }>()
    orders.forEach(o => {
      const dateStr = formatDate(o.createdAt, 'dd MMM')

      if (!dailyTrendMap.has(dateStr)) {
        dailyTrendMap.set(dateStr, { date: dateStr, sales: 0, profit: 0, adminProfit: 0, orders: 0 })
      }

      const dayData = dailyTrendMap.get(dateStr)!
      dayData.orders++
      
      const items = itemsByOrder[o.id] || []
      const orderRestSalesRaw = items.length > 0
        ? items.reduce((sum, item) => {
            if (isPureGroceryItem(item)) return sum
            return sum + (item.price * item.quantity)
          }, 0)
        : (o.subtotal || o.total || 0)
      const discountShare = o.subtotal > 0 ? (o.discount * (orderRestSalesRaw / o.subtotal)) : 0
      const foodSales = Math.max(0, orderRestSalesRaw - discountShare)
      dayData.sales += foodSales

      let orderRestaurantProfit = 0
      let orderAdminProfit = 0
      if (items.length > 0) {
        items.forEach(item => {
          if (isPureGroceryItem(item)) return
          const metrics = getItemMetrics(item)
          orderRestaurantProfit += metrics.restaurantProfit
          orderAdminProfit += metrics.adminProfit
        })
      } else {
        const admProfit = foodSales * commissionRate
        orderRestaurantProfit += (foodSales - admProfit)
        orderAdminProfit += admProfit
      }
      dayData.profit += orderRestaurantProfit // Restaurant Margin
      dayData.adminProfit += orderAdminProfit // FastKirana Margin
    })

    const dailySales = Array.from(dailyTrendMap.values())

    // 5. Dishes & Items Sold (Excluding general grocery products)
    const productStatsMap = new Map<string, { name: string; quantity: number; sales: number; profit: number; adminProfit: number }>()
    orderItems.forEach(item => {
      if (isPureGroceryItem(item)) return // Skip grocery/cold drinks
      
      const metrics = getItemMetrics(item)
      const key = `${item.productId}_${item.selectedVariant || ''}`

      if (!productStatsMap.has(key)) {
        productStatsMap.set(key, {
          name: item.name + (item.selectedVariant ? ` (${item.selectedVariant})` : ''),
          quantity: 0,
          sales: 0,
          profit: 0,
          adminProfit: 0
        })
      }

      const stats = productStatsMap.get(key)!
      stats.quantity += item.quantity
      stats.sales += metrics.sales
      stats.profit += metrics.restaurantProfit
      stats.adminProfit += metrics.adminProfit
    })

    const topProducts = Array.from(productStatsMap.values())
      .sort((a, b) => b.quantity - a.quantity)

    const latestPayout = await prisma.restaurantPayout.findFirst({
      where: {
        restaurantId: effectiveRestId,
        status: 'PAID'
      },
      orderBy: { paidAt: 'desc' }
    })

    return NextResponse.json({
      summary: {
        totalSales,
        totalCost,
        totalDiscount,
        totalTaxes,
        totalMisc,
        restaurantProfit: totalRestaurantProfit,
        adminProfit: totalAdminProfit,
        netProfit,
        ordersCount: orders.length,
        avgOrderValue: orders.length > 0 ? totalSales / orders.length : 0,
        commissionRate: commissionRate * 100,
        profitShareRate: profitShareRate * 100,
        lastSettledDate: latestPayout?.paidAt || latestPayout?.endDate || null,
        lastSettledAmount: latestPayout?.amount || null,
        lastSettledTxnId: latestPayout?.transactionId || null,
        delivery: {
          ordersCount: deliveryOrdersCount,
          sales: deliverySales,
          restaurantProfit: deliveryRestaurantProfit,
          adminProfit: deliveryAdminProfit,
        },
        pickup: {
          ordersCount: pickupOrdersCount,
          sales: pickupSales,
          restaurantProfit: pickupRestaurantProfit,
          adminProfit: pickupAdminProfit,
        }
      },
      dailySales,
      topProducts,
    })
  } catch (error: any) {
    console.error('Restaurant reports API error:', error)
    return NextResponse.json({ error: error.message || 'Failed to fetch restaurant reports' }, { status: 500 })
  }
}
