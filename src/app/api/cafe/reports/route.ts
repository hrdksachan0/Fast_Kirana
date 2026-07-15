import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const email = session.user.email || ''
    const isAllowed = role === 'ADMIN' || (role === 'CHEF' && !email.toLowerCase().startsWith('restaurant'))
    
    if (!isAllowed) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

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

    // 1. Fetch delivered orders for Cafe Kitchen within range
    const orders = await prisma.$queryRaw<
      Array<{
        id: string
        total: number
        subtotal: number
        discount: number
        deliveryFee: number
        taxes: number
        miscFee: number
        createdAt: Date
      }>
    >`
      SELECT id, total, subtotal, discount, "deliveryFee", taxes, "miscFee", "createdAt"
      FROM orders
      WHERE status::text = 'DELIVERED'
        AND "shopName" = 'FastKirana Cafe Kitchen'
        AND "createdAt" >= ${start}
        AND "createdAt" <= ${end}
      ORDER BY "createdAt" ASC
    `

    // 2. Fetch all order items inside delivered cafe orders with cost price
    const orderItems = await prisma.$queryRaw<
      Array<{
        orderId: string
        productId: string
        price: number
        quantity: number
        name: string
        costPrice: number
        categoryName: string
        variants: any
        selectedVariant: string | null
      }>
    >`
      SELECT oi."orderId", oi."productId", oi.price, oi.quantity, oi.name, 
             COALESCE(NULLIF(oi."costPrice", 0), p."costPrice", 0) as "costPrice", 
             c.name as "categoryName",
             COALESCE(oi.variants, p.variants) as "variants", 
             oi."selectedVariant"
      FROM order_items oi
      JOIN products p ON oi."productId" = p.id
      JOIN categories c ON p."categoryId" = c.id
      JOIN orders o ON oi."orderId" = o.id
      WHERE o.status::text = 'DELIVERED'
        AND o."shopName" = 'FastKirana Cafe Kitchen'
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

    // Helper: calculate cost and profit for an item
    const getItemMetrics = (item: typeof orderItems[0]) => {
      let costPrice = item.costPrice

      if (item.selectedVariant && item.variants) {
        try {
          const variantsList = typeof item.variants === 'string' ? JSON.parse(item.variants) : item.variants
          if (Array.isArray(variantsList)) {
            const v = variantsList.find(x => x.name === item.selectedVariant)
            if (v && v.costPrice !== undefined) {
              costPrice = parseFloat(v.costPrice) || 0
            }
          }
        } catch (e) {}
      }

      const totalItemCost = costPrice * item.quantity
      const totalItemSales = item.price * item.quantity
      const profit = totalItemSales - totalItemCost
      return { cost: totalItemCost, sales: totalItemSales, profit }
    }

    // 3. Process Financials Summary
    let totalSales = 0
    let totalCost = 0
    let totalDiscount = 0
    let totalTaxes = 0
    let totalMisc = 0

    orders.forEach(o => {
      totalSales += o.total || 0
      totalDiscount += o.discount || 0
      totalTaxes += o.taxes || 0
      totalMisc += o.miscFee || 0

      const items = itemsByOrder[o.id] || []
      items.forEach(item => {
        const metrics = getItemMetrics(item)
        totalCost += metrics.cost
      })
    })

    const netProfit = totalSales - totalCost - totalDiscount

    // 4. Daily Sales Trend
    const dailyTrendMap = new Map<string, { date: string; sales: number; profit: number; orders: number }>()
    orders.forEach(o => {
      const dateStr = new Date(o.createdAt).toLocaleDateString('en-IN', {
        day: '2-digit',
        month: 'short',
      })

      if (!dailyTrendMap.has(dateStr)) {
        dailyTrendMap.set(dateStr, { date: dateStr, sales: 0, profit: 0, orders: 0 })
      }

      const dayData = dailyTrendMap.get(dateStr)!
      dayData.orders++
      dayData.sales += o.total

      const items = itemsByOrder[o.id] || []
      let orderCost = 0
      items.forEach(item => {
        const metrics = getItemMetrics(item)
        orderCost += metrics.cost
      })
      const orderProfit = o.total - orderCost - o.discount
      dayData.profit += orderProfit
    })

    const dailySales = Array.from(dailyTrendMap.values())

    // 5. Top Selling Products
    const productStatsMap = new Map<string, { name: string; quantity: number; sales: number; profit: number }>()
    orderItems.forEach(item => {
      const metrics = getItemMetrics(item)
      const key = `${item.productId}_${item.selectedVariant || ''}`

      if (!productStatsMap.has(key)) {
        productStatsMap.set(key, {
          name: item.name + (item.selectedVariant ? ` (${item.selectedVariant})` : ''),
          quantity: 0,
          sales: 0,
          profit: 0
        })
      }

      const stats = productStatsMap.get(key)!
      stats.quantity += item.quantity
      stats.sales += metrics.sales
      stats.profit += metrics.profit
    })

    const topProducts = Array.from(productStatsMap.values())
      .sort((a, b) => b.quantity - a.quantity)
      .slice(0, 10)

    return NextResponse.json({
      summary: {
        totalSales,
        totalCost,
        totalDiscount,
        totalTaxes,
        totalMisc,
        netProfit,
        ordersCount: orders.length,
        avgOrderValue: orders.length > 0 ? totalSales / orders.length : 0,
      },
      dailySales,
      topProducts,
    })
  } catch (error: any) {
    console.error('Cafe reports API error:', error)
    return NextResponse.json({ error: error.message || 'Failed to fetch cafe reports' }, { status: 500 })
  }
}
