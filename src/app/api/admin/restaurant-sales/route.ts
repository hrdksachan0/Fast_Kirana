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
      start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000)
      start.setHours(0, 0, 0, 0)
    }

    if (endDateParam) {
      end = new Date(`${endDateParam}T23:59:59.999`)
    } else {
      end = new Date(now.getTime())
      end.setHours(23, 59, 59, 999)
    }

    // 2. Fetch all active restaurants from DB
    const restaurants = await prisma.restaurant.findMany({
      where: { isActive: true },
      select: { id: true, name: true, slug: true, logoUrl: true, isOpen: true, commissionRate: true }
    })

    // 3. Fetch all DELIVERED orders that have a restaurantId, within the date range
    const orders = await prisma.$queryRaw<
      Array<{
        id: string
        subtotal: number
        discount: number
        deliveryFee: number
        taxes: number
        miscFee: number
        restaurantId: string
        createdAt: Date
      }>
    >`
      SELECT o.id, o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o."restaurantId", o."createdAt"
      FROM orders o
      WHERE o.status::text = 'DELIVERED'
        AND o."restaurantId" IS NOT NULL
        AND o."createdAt" >= ${start}
        AND o."createdAt" <= ${end}
    `

    // 4. Fetch order items for those orders to find top dish per restaurant
    const orderItems = await prisma.$queryRaw<
      Array<{
        orderId: string
        name: string
        quantity: number
        restaurantId: string
      }>
    >`
      SELECT oi."orderId", oi.name, oi.quantity, o."restaurantId"
      FROM order_items oi
      JOIN orders o ON oi."orderId" = o.id
      WHERE o.status::text = 'DELIVERED'
        AND o."restaurantId" IS NOT NULL
        AND o."createdAt" >= ${start}
        AND o."createdAt" <= ${end}
    `

    const grandTotal = {
      totalProductSales: 0,
      totalAdminCommission: 0,
      totalRestaurantShare: 0,
      totalOrders: 0,
      totalDeliveryFee: 0,
      totalPackaging: 0
    }

    const restaurantMap = new Map<string, any>()

    for (const r of restaurants) {
      const commRate = r.commissionRate ? parseFloat(r.commissionRate.toString()) / 100 : 0.15 // fallback to 15% if undefined? Let's assume it's stored as percentage or fraction. Wait, in DB it's usually percentage like 15 or 10. Let's look at how it's used. In reference, restaurant commission might be global setting. Here they asked to use r.commissionRate. Let's assume it's a decimal like 0.15, or maybe we just use it directly. Actually, the example in the prompt has `commissionRate: 0.15`. Let's assume it's a Decimal/float stored as fraction or we just use it directly if it's already a float. The prompt example: `"commissionRate": 0.15`. So I will use `Number(r.commissionRate) || 0`.

      restaurantMap.set(r.id, {
        id: r.id,
        name: r.name,
        slug: r.slug,
        logoUrl: r.logoUrl,
        isOpen: r.isOpen,
        commissionRate: Number(r.commissionRate) || 0,
        totalOrders: 0,
        totalProductSales: 0,
        adminCommission: 0,
        restaurantShare: 0,
        avgOrderValue: 0,
        topDish: '',
        totalDeliveryFee: 0,
        totalPackaging: 0,
        _itemCounts: new Map<string, number>()
      })
    }

    for (const o of orders) {
      const rStats = restaurantMap.get(o.restaurantId)
      if (!rStats) continue

      const productSales = (Number(o.subtotal) || 0) - (Number(o.discount) || 0)
      const commRate = rStats.commissionRate
      const adminComm = productSales * commRate
      const restShare = productSales - adminComm

      rStats.totalOrders++
      rStats.totalProductSales += productSales
      rStats.adminCommission += adminComm
      rStats.restaurantShare += restShare
      rStats.totalDeliveryFee += Number(o.deliveryFee) || 0
      rStats.totalPackaging += Number(o.miscFee) || 0
    }

    for (const oi of orderItems) {
      const rStats = restaurantMap.get(oi.restaurantId)
      if (!rStats) continue

      const count = rStats._itemCounts.get(oi.name) || 0
      rStats._itemCounts.set(oi.name, count + Number(oi.quantity))
    }

    const resultRestaurants = Array.from(restaurantMap.values()).map(r => {
      let topDish = ''
      let maxQty = 0
      for (const [name, qty] of r._itemCounts.entries()) {
        if (qty > maxQty) {
          maxQty = qty
          topDish = name
        }
      }

      const avgOrderValue = r.totalOrders > 0 ? r.totalProductSales / r.totalOrders : 0

      grandTotal.totalProductSales += r.totalProductSales
      grandTotal.totalAdminCommission += r.adminCommission
      grandTotal.totalRestaurantShare += r.restaurantShare
      grandTotal.totalOrders += r.totalOrders
      grandTotal.totalDeliveryFee += r.totalDeliveryFee
      grandTotal.totalPackaging += r.totalPackaging

      // cleanup internal state
      const { _itemCounts, ...cleanR } = r
      cleanR.avgOrderValue = avgOrderValue
      cleanR.topDish = topDish

      // round numbers
      cleanR.totalProductSales = Math.round(cleanR.totalProductSales * 100) / 100
      cleanR.adminCommission = Math.round(cleanR.adminCommission * 100) / 100
      cleanR.restaurantShare = Math.round(cleanR.restaurantShare * 100) / 100
      cleanR.avgOrderValue = Math.round(cleanR.avgOrderValue * 100) / 100
      cleanR.totalDeliveryFee = Math.round(cleanR.totalDeliveryFee * 100) / 100
      cleanR.totalPackaging = Math.round(cleanR.totalPackaging * 100) / 100

      return cleanR
    })

    resultRestaurants.sort((a, b) => b.totalProductSales - a.totalProductSales)

    // round grand totals
    grandTotal.totalProductSales = Math.round(grandTotal.totalProductSales * 100) / 100
    grandTotal.totalAdminCommission = Math.round(grandTotal.totalAdminCommission * 100) / 100
    grandTotal.totalRestaurantShare = Math.round(grandTotal.totalRestaurantShare * 100) / 100
    grandTotal.totalDeliveryFee = Math.round(grandTotal.totalDeliveryFee * 100) / 100
    grandTotal.totalPackaging = Math.round(grandTotal.totalPackaging * 100) / 100

    return NextResponse.json({
      restaurants: resultRestaurants,
      grandTotal
    })
  } catch (error: any) {
    console.error('Restaurant sales API error:', error)
    return NextResponse.json(
      { error: 'Failed to generate restaurant sales report', details: error.message || error },
      { status: 500 }
    )
  }
}
