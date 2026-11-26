import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
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
    const storeId = getEffectiveStoreId(session, searchParams.get('storeId'))

    const now = new Date()
    let start: Date
    let end: Date

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

    const storeWhere = storeId && storeId !== 'all'
      ? Prisma.sql`AND o."storeId" = ${storeId}`
      : Prisma.empty

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
        ${storeWhere}
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
        liveCostPrice?: number
        snapshotCostPrice?: number
        liveBasePrice?: number
        restaurantId: string | null
        restaurantName: string | null
        restaurantCommissionRate: number | null
        categoryName: string | null
        variants: any
        liveVariants?: any
        snapshotVariants?: any
        selectedVariant: string | null
        isGroceryProduct: boolean
      }>
    >`
      SELECT oi."orderId", oi.name, oi.price, oi.quantity, 
             COALESCE(NULLIF(p."costPrice", 0), oi."costPrice", 0) as "costPrice",
             COALESCE(p."costPrice", 0) as "liveCostPrice",
             COALESCE(oi."costPrice", 0) as "snapshotCostPrice",
             COALESCE(p.price, 0) as "liveBasePrice",
             COALESCE(p."restaurantId", o."restaurantId") as "restaurantId",
             r.name as "restaurantName",
             r."commissionRate" as "restaurantCommissionRate",
             c.name as "categoryName",
             COALESCE(p.variants, oi.variants) as "variants",
             p.variants as "liveVariants",
             oi.variants as "snapshotVariants",
             oi."selectedVariant",
             CASE
               WHEN (p.id IS NOT NULL AND p."restaurantId" IS NULL)
                 OR (p.id IS NULL AND o."restaurantId" IS NULL AND COALESCE(o."orderType"::text, 'GROCERY') = 'GROCERY')
               THEN true ELSE false
             END as "isGroceryProduct"
      FROM order_items oi
      JOIN orders o ON oi."orderId" = o.id
      LEFT JOIN products p ON oi."productId" = p.id
      LEFT JOIN categories c ON p."categoryId" = c.id
      LEFT JOIN restaurants r ON COALESCE(p."restaurantId", o."restaurantId") = r.id
      WHERE o.status::text = 'DELIVERED'
        AND o."createdAt" >= ${start}
        AND o."createdAt" <= ${end}
        ${storeWhere}
    ` : []

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
      if (itemPrice > 0) {
        const priceMatched = variantsList.find((v: any) => v && Number(v.price) > 0 && Math.abs(Number(v.price) - itemPrice) < 0.01)
        const priceCp = Number(priceMatched?.costPrice ?? priceMatched?.cp ?? priceMatched?.cost ?? 0)
        if (priceCp > 0) return priceCp
      }
      return 0
    }

    const resolveItemCost = (item: typeof orderItems[0]): { totalCost: number; unitCost: number } => {
      const qty = Number(item.quantity) || 1
      let unitCost = 0

      // If restaurant item: cost is based on restaurant commission payout
      if (!item.isGroceryProduct && item.restaurantId) {
        const commRate = item.restaurantCommissionRate ? (Number(item.restaurantCommissionRate) > 1 ? Number(item.restaurantCommissionRate) / 100 : Number(item.restaurantCommissionRate)) : 0.10
        const itemRevenue = (Number(item.price) || 0) * qty
        const total = Math.round(itemRevenue * (1 - commRate) * 100) / 100
        return { totalCost: total, unitCost: qty > 0 ? Math.round((total / qty) * 100) / 100 : total }
      }

      let targetVariant = (item.selectedVariant || '').trim()
      if (!targetVariant && item.name) {
        const match = item.name.match(/[\(\[]([^\)\]]+)[\)\]]/)
        if (match) targetVariant = match[1].trim()
      }

      const liveVariants = parseVariantsList(item.liveVariants)
      const snapshotVariants = parseVariantsList(item.snapshotVariants)
      const itemPrice = Number(item.price || 0)
      const liveCost = Number(item.liveCostPrice || 0)
      const snapshotCost = Number(item.snapshotCostPrice || 0)
      const liveBasePrice = Number(item.liveBasePrice || 0)

      unitCost = extractVariantCost(liveVariants, targetVariant, itemPrice)
      const isBaseMatch = liveVariants.length <= 1 || !targetVariant || (liveBasePrice > 0 && Math.abs(liveBasePrice - itemPrice) < 0.01)
      if (unitCost <= 0 && isBaseMatch && liveCost > 0) {
        unitCost = liveCost
      }
      if (unitCost <= 0) {
        unitCost = extractVariantCost(snapshotVariants, targetVariant, itemPrice)
      }
      if (unitCost <= 0 && snapshotCost > 0) {
        unitCost = snapshotCost
      }

      if (unitCost > 0) {
        return { totalCost: Math.round(unitCost * qty * 100) / 100, unitCost }
      }

      // Cost not set: return 0 rather than a 25% default estimate
      return { totalCost: 0, unitCost: 0 }
    }

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
      const itemNames = items.map(i => {
        const vSuffix = (i.selectedVariant || '').trim()
        const iName = (i.name || '').trim()
        const cleanDisplayName = vSuffix && !iName.toLowerCase().includes(vSuffix.toLowerCase())
          ? `${iName} (${vSuffix})`
          : iName
        return `${cleanDisplayName} x${i.quantity}`
      }).join(', ')
      let totalCost = 0
      const detailedItems = items.map(i => {
        const { totalCost: iCost, unitCost: iUnitCost } = resolveItemCost(i)
        totalCost += iCost
        const qty = Number(i.quantity) || 1
        const price = Number(i.price) || 0
        const iSales = Math.round(price * qty * 100) / 100
        const iProfit = Math.round((iSales - iCost) * 100) / 100
        return {
          name: i.name,
          selectedVariant: i.selectedVariant || null,
          categoryName: i.categoryName || 'General',
          quantity: qty,
          price,
          unitCost: iUnitCost,
          totalSales: iSales,
          totalCost: iCost,
          profit: iProfit
        }
      })
      const profit = Math.max(0, o.total - totalCost)
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
        detailedItems,
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
