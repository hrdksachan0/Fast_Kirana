import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth-guard'

export const dynamic = 'force-dynamic'
export const revalidate = 0

export async function GET(request: NextRequest) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error

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

    // Fetch all delivered orders in range with customer name, phone, payment info
    const orders = await prisma.$queryRaw<
      Array<{
        id: string
        readableId: string | null
        status: string
        total: number
        subtotal: number
        discount: number
        deliveryFee: number
        taxes: number
        miscFee: number
        deliveryMethod: string
        paymentMethod: string
        paymentStatus: string
        combinedId: string | null
        orderType: string | null
        restaurantId: string | null
        shopName: string | null
        notes: string | null
        couponCode: string | null
        createdAt: Date
        deliveredAt: Date | null
        customerName: string | null
        customerPhone: string | null
        customerEmail: string | null
        restaurantName: string | null
        deliveryUserId: string | null
        deliveredByName: string | null
        deliveredByRole: string | null
        deliveredByPhone: string | null
      }>
    >`
      SELECT o.id, o."readableId", o.status::text as status, 
             o.total, o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee",
             o."deliveryMethod", o."paymentMethod"::text as "paymentMethod", 
             o."paymentStatus"::text as "paymentStatus",
             o."combinedId", o."orderType"::text as "orderType",
             o."restaurantId", o."shopName", o.notes, o."couponCode",
             o."createdAt", o."deliveredAt", o."deliveryUserId",
             u.name as "customerName", u.phone as "customerPhone", u.email as "customerEmail",
             r.name as "restaurantName",
             du.name as "deliveredByName", du.role::text as "deliveredByRole", du.phone as "deliveredByPhone"
      FROM orders o
      LEFT JOIN users u ON o."userId" = u.id
      LEFT JOIN restaurants r ON o."restaurantId" = r.id
      LEFT JOIN users du ON o."deliveryUserId" = du.id
      WHERE o.status::text = 'DELIVERED'
        AND o."createdAt" >= ${start}
        AND o."createdAt" <= ${end}
      ORDER BY o."createdAt" ASC
    `

    // Fetch all order items for these orders
    const orderIds = orders.map(o => o.id)
    
    const orderItems = orderIds.length > 0 ? await prisma.$queryRaw<
      Array<{
        orderId: string
        name: string
        price: number
        quantity: number
        costPrice: number
        restaurantId: string | null
        restaurantName: string | null
        categoryName: string | null
      }>
    >`
      SELECT oi."orderId", oi.name, oi.price, oi.quantity, 
             COALESCE(NULLIF(oi."costPrice", 0), p."costPrice", 0) as "costPrice",
             COALESCE(p."restaurantId", o."restaurantId") as "restaurantId",
             r.name as "restaurantName",
             c.name as "categoryName"
      FROM order_items oi
      JOIN products p ON oi."productId" = p.id
      JOIN categories c ON p."categoryId" = c.id
      JOIN orders o ON oi."orderId" = o.id
      LEFT JOIN restaurants r ON COALESCE(p."restaurantId", o."restaurantId") = r.id
      WHERE oi."orderId" = ANY(${orderIds}::text[])
    ` : []

    // Group items by order
    const itemsByOrder: Record<string, typeof orderItems> = {}
    for (const item of orderItems) {
      if (!itemsByOrder[item.orderId]) {
        itemsByOrder[item.orderId] = []
      }
      itemsByOrder[item.orderId].push(item)
    }

    // Build order-wise rows
    const orderRows = orders.map(o => {
      const items = itemsByOrder[o.id] || []
      const itemNames = items.map(i => `${i.name} x${i.quantity}`).join(', ')
      const totalCost = items.reduce((sum, i) => sum + (i.costPrice * i.quantity), 0)
      const profit = o.total - totalCost
      const restaurantItems = items.filter(i => i.restaurantId)
      const groceryItems = items.filter(i => !i.restaurantId)
      const restaurantNames = [...new Set(restaurantItems.map(i => i.restaurantName).filter(Boolean))]

      const isSelfPick = o.deliveryMethod === 'PICKUP' || o.deliveryMethod === 'RETAIL'
      const fulfillmentType = o.deliveryMethod === 'PICKUP' 
        ? 'Self Pickup' 
        : o.deliveryMethod === 'RETAIL' 
          ? 'Counter / Retail' 
          : 'Doorstep Delivery'

      const deliveredBy = isSelfPick
        ? 'Customer (Self Pickup)'
        : o.deliveredByName
          ? `${o.deliveredByRole === 'ADMIN' ? 'Admin' : 'Rider'}: ${o.deliveredByName}`
          : 'Admin / Direct Store'

      return {
        readableId: o.readableId || o.id.slice(0, 8),
        customerName: o.customerName || '-',
        customerPhone: o.customerPhone || '-',
        orderDate: o.createdAt,
        deliveredAt: o.deliveredAt,
        deliveryMethod: o.deliveryMethod,
        fulfillmentType,
        deliveredBy,
        deliveredByName: o.deliveredByName || '-',
        deliveredByRole: o.deliveredByRole || (isSelfPick ? 'CUSTOMER' : 'ADMIN'),
        deliveredByPhone: o.deliveredByPhone || '-',
        paymentMethod: o.paymentMethod,
        paymentStatus: o.paymentStatus,
        orderType: o.orderType || 'GROCERY',
        restaurantName: o.restaurantName || restaurantNames.join(', ') || '-',
        shopName: o.shopName || '-',
        items: itemNames,
        itemCount: items.reduce((sum, i) => sum + i.quantity, 0),
        subtotal: o.subtotal,
        discount: o.discount,
        deliveryFee: o.deliveryFee,
        taxes: o.taxes,
        miscFee: o.miscFee,
        total: o.total,
        totalCost: Math.round(totalCost * 100) / 100,
        profit: Math.round(profit * 100) / 100,
        couponCode: o.couponCode || '-',
        notes: o.notes || '-',
        combinedId: o.combinedId || '-',
        // For restaurant-wise grouping
        _restaurantItems: restaurantItems,
        _groceryItems: groceryItems,
        _restaurantNames: restaurantNames,
      }
    })

    return NextResponse.json({
      success: true,
      orders: orderRows,
      totalOrders: orderRows.length,
      totalRevenue: Math.round(orderRows.reduce((s, o) => s + o.total, 0) * 100) / 100,
      totalProfit: Math.round(orderRows.reduce((s, o) => s + o.profit, 0) * 100) / 100,
    })
  } catch (error: any) {
    console.error('Order-wise reports API error:', error)
    return NextResponse.json(
      { error: 'Failed to generate order-wise report', details: error.message || error },
      { status: 500 }
    )
  }
}
