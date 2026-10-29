import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export const dynamic = 'force-dynamic'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  const { searchParams } = new URL(request.url)

  // Date range defaults: Current Month
  const now = new Date()
  const defaultStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0]
  const defaultEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().split('T')[0]

  const startDateStr = searchParams.get('startDate') || defaultStart
  const endDateStr = searchParams.get('endDate') || defaultEnd
  const storeId = searchParams.get('storeId')

  const startUtc = new Date(`${startDateStr}T00:00:00.000Z`)
  const endUtc = new Date(`${endDateStr}T23:59:59.999Z`)

  try {
    const vendor = await (prisma as any).vendor.findUnique({
      where: { id },
      include: {
        payouts: {
          orderBy: { createdAt: 'desc' },
        },
      },
    })

    if (!vendor) {
      return NextResponse.json({ error: 'Vendor not found' }, { status: 404 })
    }

    // 1. Fetch all products assigned to this vendor
    const products = await prisma.product.findMany({
      where: {
        OR: [
          { vendorId: id },
          { vendor: { equals: vendor.name, mode: 'insensitive' } },
        ],
      },
      include: {
        category: {
          select: { id: true, name: true },
        },
        inventories: storeId && storeId !== 'all' ? {
          where: { storeId },
        } : true,
      },
      orderBy: { name: 'asc' },
    })

    const productIds = products.map((p) => p.id)
    const productMap = new Map(products.map((p) => [p.id, p]))

    // 2. Fetch delivered orders in the specified date range
    let orderWhereClause: any = {
      status: 'DELIVERED',
      createdAt: {
        gte: startUtc,
        lte: endUtc,
      },
    }

    if (storeId && storeId !== 'all') {
      orderWhereClause.storeId = storeId
    }

    const deliveredOrders = await prisma.order.findMany({
      where: orderWhereClause,
      select: {
        id: true,
        readableId: true,
        createdAt: true,
        storeId: true,
        items: {
          where: {
            productId: { in: productIds.length > 0 ? productIds : ['__non_existent__'] },
          },
          select: {
            id: true,
            productId: true,
            name: true,
            quantity: true,
            price: true,
            costPrice: true,
            refundAmount: true,
            isRefunded: true,
            selectedVariant: true,
            variants: true,
          },
        },
      },
    })

    // 3. Aggregate Itemized Sales & Payable
    const itemSalesSummary: Record<
      string,
      {
        productId: string
        name: string
        unit: string
        categoryName: string
        barcode: string | null
        unitsSold: number
        unitCostPrice: number
        sellingPrice: number
        totalPayable: number
        currentStock: number
      }
    > = {}

    let totalUnitsSold = 0
    let totalPayableAmount = 0

    // Initialize item map with all products of this vendor
    for (const prod of products) {
      const currentStock = storeId && storeId !== 'all'
        ? (prod.inventories?.[0]?.stock ?? prod.stock)
        : prod.stock

      let initCost = prod.costPrice || 0
      if (!initCost && prod.variants) {
        try {
          const vList = typeof prod.variants === 'string' ? JSON.parse(prod.variants as string) : prod.variants
          if (Array.isArray(vList) && vList.length > 0) {
            const first = vList.find((v: any) => v && Number(v.costPrice) > 0)
            if (first) initCost = Number(first.costPrice)
          }
        } catch {}
      }

      itemSalesSummary[prod.id] = {
        productId: prod.id,
        name: prod.name,
        unit: prod.unit || '',
        categoryName: prod.category?.name || 'Uncategorized',
        barcode: prod.barcode || null,
        unitsSold: 0,
        unitCostPrice: initCost,
        sellingPrice: prod.price,
        totalPayable: 0,
        currentStock,
      }
    }

    // Daily sales map (date -> { date, unitsSold, payableAmount, ordersCount })
    const dailySalesMap: Record<string, { date: string; unitsSold: number; payableAmount: number; ordersCount: number }> = {}

    // Accumulate delivered sales
    for (const order of deliveredOrders) {
      const orderDateStr = order.createdAt.toISOString().split('T')[0]
      if (!dailySalesMap[orderDateStr]) {
        dailySalesMap[orderDateStr] = { date: orderDateStr, unitsSold: 0, payableAmount: 0, ordersCount: 0 }
      }
      let orderHasVendorItems = false

      for (const item of order.items) {
        if (item.isRefunded || !item.productId) continue

        const baseProd = productMap.get(item.productId)
        let effectiveCostPrice = item.costPrice && item.costPrice > 0 ? Number(item.costPrice) : 0

        if (!effectiveCostPrice && baseProd?.costPrice && Number(baseProd.costPrice) > 0) {
          effectiveCostPrice = Number(baseProd.costPrice)
        }
        if (!effectiveCostPrice && item.price > 0) {
          effectiveCostPrice = Math.round(Number(item.price) * 0.75 * 100) / 100
        }

        const qty = item.quantity || 0
        const itemPayable = qty * effectiveCostPrice

        totalUnitsSold += qty
        totalPayableAmount += itemPayable
        orderHasVendorItems = true

        dailySalesMap[orderDateStr].unitsSold += qty
        dailySalesMap[orderDateStr].payableAmount += itemPayable

        if (itemSalesSummary[item.productId]) {
          itemSalesSummary[item.productId].unitsSold += qty
          itemSalesSummary[item.productId].totalPayable += itemPayable
          if (itemSalesSummary[item.productId].unitsSold > 0) {
            itemSalesSummary[item.productId].unitCostPrice = Math.round(
              (itemSalesSummary[item.productId].totalPayable / itemSalesSummary[item.productId].unitsSold) * 100
            ) / 100
          }
        }
      }

      if (orderHasVendorItems) {
        dailySalesMap[orderDateStr].ordersCount += 1
      }
    }

    const itemizedSales = Object.values(itemSalesSummary).sort((a, b) => b.totalPayable - a.totalPayable)
    const dailySales = Object.values(dailySalesMap).sort((a, b) => b.date.localeCompare(a.date))

    // 4. Calculate Payouts & Balances
    const payoutsList = vendor.payouts || []
    const totalPaidLifetime = payoutsList
      .filter((p: any) => p.status === 'PAID')
      .reduce((sum: number, p: any) => sum + (p.amount || 0), 0)

    const periodPayouts = payoutsList.filter((p: any) => {
      const pDate = new Date(p.paidAt || p.createdAt)
      return pDate >= startUtc && pDate <= endUtc
    })

    const totalPaidInPeriod = periodPayouts
      .filter((p: any) => p.status === 'PAID')
      .reduce((sum: number, p: any) => sum + (p.amount || 0), 0)

    const pendingBalance = Math.max(0, totalPayableAmount - totalPaidInPeriod)

    // 5. Low stock items
    const lowStockItems = products
      .map((p) => {
        const stock = storeId && storeId !== 'all'
          ? (p.inventories?.[0]?.stock ?? p.stock)
          : p.stock
        const minStock = p.minStock ?? 5
        return {
          id: p.id,
          name: p.name,
          unit: p.unit || '',
          barcode: p.barcode,
          stock,
          minStock,
          costPrice: p.costPrice || 0,
          isLow: stock <= minStock,
        }
      })
      .filter((item) => item.isLow)

    const formattedProducts = products.map((p) => {
      const stock = storeId && storeId !== 'all'
        ? (p.inventories?.[0]?.stock ?? p.stock)
        : p.stock
      return {
        id: p.id,
        name: p.name,
        price: p.price,
        costPrice: p.costPrice || 0,
        mrp: p.mrp || p.price,
        stock,
        minStock: p.minStock ?? 5,
        unit: p.unit || '',
        category: p.category?.name || 'General',
        imageUrl: p.imageUrl || '',
        isAvailable: p.isAvailable,
      }
    })

    return NextResponse.json({
      success: true,
      vendor: {
        id: vendor.id,
        vendorCode: vendor.vendorCode || `VND-${vendor.id.slice(-4).toUpperCase()}`,
        name: vendor.name,
        phone: vendor.phone,
        email: vendor.email,
        companyName: vendor.companyName,
        gstin: vendor.gstin,
        upiId: vendor.upiId,
        bankName: vendor.bankName,
        accountNo: vendor.accountNo,
        ifscCode: vendor.ifscCode,
        address: vendor.address,
        isActive: vendor.isActive,
      },
      period: {
        startDate: startDateStr,
        endDate: endDateStr,
      },
      kpis: {
        totalProducts: products.length,
        totalUnitsSold,
        totalPayableAmount: Math.round(totalPayableAmount * 100) / 100,
        totalPaidInPeriod: Math.round(totalPaidInPeriod * 100) / 100,
        pendingBalance: Math.round(pendingBalance * 100) / 100,
        totalPaidLifetime: Math.round(totalPaidLifetime * 100) / 100,
        lowStockCount: lowStockItems.length,
      },
      itemizedSales,
      dailySales,
      products: formattedProducts,
      payouts: payoutsList,
      lowStockItems,
    })
  } catch (error: any) {
    console.error('[VendorDetails] Error:', error)
    return NextResponse.json({ error: error.message || 'Failed to fetch vendor details' }, { status: 500 })
  }
}
