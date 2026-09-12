import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth-guard'

export const dynamic = 'force-dynamic'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error

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

      itemSalesSummary[prod.id] = {
        productId: prod.id,
        name: prod.name,
        categoryName: prod.category?.name || 'Uncategorized',
        barcode: prod.barcode || null,
        unitsSold: 0,
        unitCostPrice: prod.costPrice || 0,
        sellingPrice: prod.price,
        totalPayable: 0,
        currentStock,
      }
    }

    // Accumulate delivered sales
    for (const order of deliveredOrders) {
      for (const item of order.items) {
        if (item.isRefunded || !item.productId) continue

        const effectiveCostPrice = item.costPrice && item.costPrice > 0
          ? item.costPrice
          : (productMap.get(item.productId)?.costPrice || 0)

        const qty = item.quantity || 0
        const itemPayable = qty * effectiveCostPrice

        totalUnitsSold += qty
        totalPayableAmount += itemPayable

        if (itemSalesSummary[item.productId]) {
          itemSalesSummary[item.productId].unitsSold += qty
          itemSalesSummary[item.productId].totalPayable += itemPayable
          // Keep most accurate cost price
          if (effectiveCostPrice > 0) {
            itemSalesSummary[item.productId].unitCostPrice = effectiveCostPrice
          }
        }
      }
    }

    const itemizedSales = Object.values(itemSalesSummary).sort((a, b) => b.totalPayable - a.totalPayable)

    // 4. Calculate Payouts & Balances
    const payoutsList = vendor.payouts || []
    const totalPaidLifetime = payoutsList
      .filter((p: any) => p.status === 'PAID')
      .reduce((sum: number, p: any) => sum + (p.amount || 0), 0)

    // Filter payouts relevant to this date range
    const periodPayouts = payoutsList.filter((p: any) => {
      const pDate = new Date(p.paidAt || p.createdAt)
      return pDate >= startUtc && pDate <= endUtc
    })

    const totalPaidInPeriod = periodPayouts
      .filter((p: any) => p.status === 'PAID')
      .reduce((sum: number, p: any) => sum + (p.amount || 0), 0)

    const pendingBalance = Math.max(0, totalPayableAmount - totalPaidInPeriod)

    // 5. Low stock items for WhatsApp PO
    const lowStockItems = products
      .map((p) => {
        const stock = storeId && storeId !== 'all'
          ? (p.inventories?.[0]?.stock ?? p.stock)
          : p.stock
        const minStock = p.minStock ?? 5
        return {
          id: p.id,
          name: p.name,
          barcode: p.barcode,
          stock,
          minStock,
          costPrice: p.costPrice || 0,
          isLow: stock <= minStock,
        }
      })
      .filter((item) => item.isLow)

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
      payouts: payoutsList,
      lowStockItems,
      products: products.map((p) => ({
        id: p.id,
        name: p.name,
        barcode: p.barcode,
        price: p.price,
        mrp: p.mrp,
        costPrice: p.costPrice || 0,
        stock: storeId && storeId !== 'all' ? (p.inventories?.[0]?.stock ?? p.stock) : p.stock,
        category: p.category?.name,
        imageUrl: p.imageUrl,
        isAvailable: p.isAvailable,
      })),
    })
  } catch (error: any) {
    console.error('Error fetching vendor details:', error)
    return NextResponse.json({ error: error.message || 'Failed to fetch vendor details' }, { status: 500 })
  }
}

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error

  const { id } = await params

  try {
    const body = await request.json()
    const {
      name,
      phone,
      email,
      companyName,
      gstin,
      upiId,
      bankName,
      accountNo,
      ifscCode,
      address,
      isActive,
      storeId,
    } = body

    if (!name || !name.trim()) {
      return NextResponse.json({ error: 'Name is required' }, { status: 400 })
    }

    const cleanName = name.trim()

    const updated = await (prisma as any).vendor.update({
      where: { id },
      data: {
        name: cleanName,
        phone: phone?.trim() || null,
        email: email?.trim() || null,
        companyName: companyName?.trim() || null,
        gstin: gstin?.trim() || null,
        upiId: upiId?.trim() || null,
        bankName: bankName?.trim() || null,
        accountNo: accountNo?.trim() || null,
        ifscCode: ifscCode?.trim() || null,
        address: address?.trim() || null,
        isActive: isActive !== undefined ? Boolean(isActive) : true,
        storeId: storeId || null,
      },
    })

    // Also sync vendor string on linked products
    await prisma.product.updateMany({
      where: { vendorId: id },
      data: { vendor: cleanName },
    })

    return NextResponse.json({ success: true, vendor: updated })
  } catch (error: any) {
    console.error('Error updating vendor:', error)
    return NextResponse.json({ error: error.message || 'Failed to update vendor' }, { status: 500 })
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error

  const { id } = await params

  try {
    // Unlink products before deleting vendor
    await prisma.product.updateMany({
      where: { vendorId: id },
      data: { vendorId: null },
    })

    await (prisma as any).vendor.delete({
      where: { id },
    })

    return NextResponse.json({ success: true, message: 'Vendor deleted successfully' })
  } catch (error: any) {
    console.error('Error deleting vendor:', error)
    return NextResponse.json({ error: error.message || 'Failed to delete vendor' }, { status: 500 })
  }
}
