import { prisma } from '@/lib/prisma'
import { formatDate } from '@/lib/date-helpers'

export interface OrderRow {
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

export interface ItemRow {
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

export interface RestaurantReportSummary {
  totalSales: number
  totalCost: number
  totalDiscount: number
  totalTaxes: number
  totalMisc: number
  restaurantProfit: number
  adminProfit: number
  netProfit: number
  ordersCount: number
  avgOrderValue: number
  commissionRate: number
  profitShareRate: number
  lastSettledDate: Date | null
  lastSettledAmount: number | null
  lastSettledTxnId: string | null
  delivery: {
    ordersCount: number
    sales: number
    restaurantProfit: number
    adminProfit: number
  }
  pickup: {
    ordersCount: number
    sales: number
    restaurantProfit: number
    adminProfit: number
  }
}

export interface DailySalesTrend {
  date: string
  sales: number
  profit: number
  adminProfit: number
  orders: number
}

export interface TopProductMetric {
  name: string
  quantity: number
  sales: number
  profit: number
  adminProfit: number
}

export interface RestaurantReportData {
  summary: RestaurantReportSummary
  dailySales: DailySalesTrend[]
  topProducts: TopProductMetric[]
}

export class RestaurantReportService {
  /**
   * Fetches and calculates financial reports, commission splits, and sales trends
   * strictly scoped to a given restaurant ID and date range.
   */
  async getReports(
    restaurantId: string,
    start: Date,
    end: Date
  ): Promise<RestaurantReportData> {
    // 1. Fetch delivered orders strictly for the specific Restaurant within range
    const orders = await prisma.$queryRaw<OrderRow[]>`
      SELECT id, total, subtotal, discount, "deliveryFee", taxes, "miscFee", "deliveryMethod", "createdAt"
      FROM orders
      WHERE status::text = 'DELIVERED'
        AND ("restaurantId" = ${restaurantId} OR id IN (
          SELECT oi."orderId" FROM order_items oi
          JOIN products p ON oi."productId" = p.id
          WHERE p."restaurantId" = ${restaurantId}
        ))
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
             COALESCE(p."restaurantId", o."restaurantId") as "restaurantId",
             COALESCE(oi.variants, p.variants) as "variants", 
             oi."selectedVariant"
      FROM order_items oi
      JOIN orders o ON oi."orderId" = o.id
      LEFT JOIN products p ON oi."productId" = p.id
      LEFT JOIN categories c ON p."categoryId" = c.id
      WHERE o.status::text = 'DELIVERED'
        AND (o."restaurantId" = ${restaurantId} OR p."restaurantId" = ${restaurantId})
        AND ("shopName" IS NULL OR ("shopName" != 'FastKirana Dark Store' AND "shopName" != 'FastKirana Grocery'))
        AND o."createdAt" >= ${start}
        AND o."createdAt" <= ${end}
    `

    // Map order items by order ID for easier processing
    const itemsByOrder: Record<string, ItemRow[]> = {}
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
    if (restaurantId) {
      const restObj = await prisma.restaurant.findUnique({
        where: { id: restaurantId },
        select: { commissionRate: true }
      })
      if (restObj && restObj.commissionRate !== null && restObj.commissionRate !== undefined) {
        commissionRate = restObj.commissionRate > 1.0 ? restObj.commissionRate / 100 : restObj.commissionRate
      }
    }
    const profitShareRate = parseFloat(dbSettingsMap.get('restaurant_profit_share') || '15') / 100
    const restaurantDefaultMargin = parseFloat(dbSettingsMap.get('restaurant_default_margin') || '30')

    // Helper: calculate cost and profit for an item with dynamic margin
    const getItemMetrics = (item: ItemRow) => {
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
        } catch {
          // Fallback to item cost price
        }
      }

      const costPerUnit = costPrice > 0 ? costPrice : item.price * (1 - restaurantDefaultMargin / 100)
      const ingredientCost = costPerUnit * item.quantity
      const netKitchenProfit = restaurantProfit - ingredientCost

      return { cost: ingredientCost, sales: totalItemSales, profit: netKitchenProfit, restaurantProfit, adminProfit }
    }

    // Helper to identify grocery items (cold drinks, snacks, etc.)
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

    // Process Financials Summary
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
            if (item.restaurantId && item.restaurantId !== restaurantId) return sum
            return sum + (item.price * item.quantity)
          }, 0)
        : (o.subtotal || o.total || 0)

      if (orderRestSalesRaw <= 0) return

      const discountShare = o.subtotal > 0 ? (o.discount * (orderRestSalesRaw / o.subtotal)) : 0
      const foodSales = Math.max(0, orderRestSalesRaw - discountShare)
      totalSales += foodSales

      let orderRestProfit = 0
      let orderAdmProfit = 0
      if (items.length > 0) {
        items.forEach(item => {
          if (isPureGroceryItem(item)) return
          if (item.restaurantId && item.restaurantId !== restaurantId) return
          
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

    // Daily Sales Trend
    const dailyTrendMap = new Map<string, DailySalesTrend>()
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
      dayData.profit += orderRestaurantProfit
      dayData.adminProfit += orderAdminProfit
    })

    const dailySales = Array.from(dailyTrendMap.values())

    // Dishes & Items Sold
    const productStatsMap = new Map<string, TopProductMetric>()
    orderItems.forEach(item => {
      if (isPureGroceryItem(item)) return
      
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
        restaurantId,
        status: 'PAID'
      },
      orderBy: { paidAt: 'desc' }
    })

    return {
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
    }
  }
}

export const restaurantReportService = new RestaurantReportService()
