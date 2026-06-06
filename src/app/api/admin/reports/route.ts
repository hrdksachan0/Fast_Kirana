import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user || (session.user as any).role !== 'ADMIN') {
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

    // 1. Fetch delivered orders within range
    const orders = await prisma.$queryRaw<
      Array<{
        id: string
        total: number
        subtotal: number
        discount: number
        createdAt: Date
      }>
    >`
      SELECT id, total, subtotal, discount, "createdAt"
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
        quantity: number
        name: string
        costPrice: number
        categoryName: string
      }>
    >`
      SELECT oi."orderId", oi."productId", oi.price, oi.quantity, oi.name, 
             COALESCE(p."costPrice", 0) as "costPrice", c.name as "categoryName"
      FROM order_items oi
      JOIN products p ON oi."productId" = p.id
      JOIN categories c ON p."categoryId" = c.id
      JOIN orders o ON oi."orderId" = o.id
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

    // Helper: calculate cost and profit for an item
    const getItemMetrics = (item: typeof orderItems[0]) => {
      // Fallback: if cost price is 0, assume 25% margin (cost is 75% of sale price)
      const costPerUnit = item.costPrice > 0 ? item.costPrice : item.price * 0.75
      const itemCost = costPerUnit * item.quantity
      const itemRevenue = item.price * item.quantity
      const itemProfit = itemRevenue - itemCost
      return { cost: itemCost, revenue: itemRevenue, profit: itemProfit }
    }

    // Calculate aggregated metrics
    let totalRevenue = 0
    let totalProfit = 0
    let totalCost = 0
    const totalOrders = orders.length

    // Group by Date (YYYY-MM-DD)
    const dailyData: Record<string, { date: string; sales: number; profit: number; orders: number }> = {}
    
    // Initialize days in range with 0 to ensure continuous charts
    const currentDate = new Date(start)
    while (currentDate <= end) {
      const dateString = currentDate.toISOString().split('T')[0]
      dailyData[dateString] = { date: dateString, sales: 0, profit: 0, orders: 0 }
      currentDate.setDate(currentDate.getDate() + 1)
    }

    // Category breakdown
    const categoryData: Record<string, { categoryName: string; sales: number; profit: number }> = {}

    // Product performance
    const productData: Record<
      string,
      { productId: string; name: string; quantity: number; sales: number; profit: number }
    > = {}

    // Process each order
    for (const order of orders) {
      const dateString = order.createdAt.toISOString().split('T')[0]
      
      // Ensure dailyData has the key (in case it fell outside initialized range due to timezone)
      if (!dailyData[dateString]) {
        dailyData[dateString] = { date: dateString, sales: 0, profit: 0, orders: 0 }
      }

      dailyData[dateString].orders++
      dailyData[dateString].sales += order.total
      totalRevenue += order.total

      // Process items for profit calculation
      const items = itemsByOrder[order.id] || []
      let orderCost = 0

      for (const item of items) {
        const { cost, revenue: itemRev, profit: itemProf } = getItemMetrics(item)
        orderCost += cost

        // Category breakdown
        if (!categoryData[item.categoryName]) {
          categoryData[item.categoryName] = { categoryName: item.categoryName, sales: 0, profit: 0 }
        }
        categoryData[item.categoryName].sales += itemRev
        categoryData[item.categoryName].profit += itemProf

        // Product breakdown
        if (!productData[item.productId]) {
          productData[item.productId] = {
            productId: item.productId,
            name: item.name,
            quantity: 0,
            sales: 0,
            profit: 0,
          }
        }
        productData[item.productId].quantity += item.quantity
        productData[item.productId].sales += itemRev
        productData[item.productId].profit += itemProf
      }

      // Order profit = order.total - orderCost (takes discounts, taxes, delivery fee into account in proportion)
      // For simplicity, we can do: orderProfit = order.total - orderCost
      // Note: orderCost is raw product cost, order.total includes deliveryFee, minus discount.
      // So order profit is a true reflection of net earnings.
      const orderProfit = order.total - orderCost
      dailyData[dateString].profit += orderProfit
      totalProfit += orderProfit
      totalCost += orderCost
    }

    // Convert grouped records to arrays
    const dailyList = Object.values(dailyData).sort((a, b) => a.date.localeCompare(b.date))
    const categoryList = Object.values(categoryData).sort((a, b) => b.sales - a.sales)
    const productList = Object.values(productData)
      .sort((a, b) => b.sales - a.sales)
      .slice(0, 10) // Top 10 selling products

    const averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0
    const profitMargin = totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0

    return NextResponse.json({
      success: true,
      summary: {
        totalSales: Math.round(totalRevenue * 100) / 100,
        totalProfit: Math.round(totalProfit * 100) / 100,
        totalCost: Math.round(totalCost * 100) / 100,
        totalOrders,
        averageOrderValue: Math.round(averageOrderValue * 100) / 100,
        profitMargin: Math.round(profitMargin * 10) / 10,
      },
      dailySales: dailyList,
      categorySales: categoryList,
      topProducts: productList,
    })
  } catch (error: any) {
    console.error('Reports API error:', error)
    return NextResponse.json(
      { error: 'Failed to generate reports', details: error.message || error },
      { status: 500 }
    )
  }
}
