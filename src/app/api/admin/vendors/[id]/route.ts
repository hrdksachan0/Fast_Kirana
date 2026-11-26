import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin, getEffectiveStoreId } from '@/lib/auth-guard'
import { auth } from '@/auth'
import { isRootAdminAccount } from '@/lib/superadmin-config'

export const dynamic = 'force-dynamic'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  const { id } = await params
  const { searchParams } = new URL(request.url)

  // Date range defaults: Current Month
  const now = new Date()
  const defaultStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0]
  const defaultEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().split('T')[0]

  const startDateStr = searchParams.get('startDate') || defaultStart
  const endDateStr = searchParams.get('endDate') || defaultEnd
  const storeId = getEffectiveStoreId(session, searchParams.get('storeId'))

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

    if (vendor.storeId && (session?.user as any)?.assignedStoreId && vendor.storeId !== (session?.user as any)?.assignedStoreId) {
      return NextResponse.json({ error: 'Forbidden: Vendor belongs to another store hub' }, { status: 403 })
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

    // 3. Aggregate Itemized Sales & Payable and Daily Sales
    const itemSalesSummary: Record<
      string,
      {
        productId: string
        name: string
        unit: string
        categoryName: string
        barcode: string | null
        imageUrl: string | null
        unitsSold: number
        unitCostPrice: number
        costedUnits?: number
        costMissing?: boolean
        sellingPrice: number
        totalPayable: number
        currentStock: number
      }
    > = {}

    const dailySalesMap: Record<
      string,
      {
        date: string
        totalUnits: number
        totalPayable: number
        items: Record<
          string,
          {
            productId: string
            name: string
            unit: string
            unitCostPrice: number
            costedUnits?: number
            costMissing?: boolean
            unitsSold: number
            totalPayable: number
          }
        >
      }
    > = {}

    let totalUnitsSold = 0
    let totalPayableAmount = 0

    // Initialize item map with all products of this vendor
    for (const prod of products) {
      const currentStock = storeId && storeId !== 'all'
        ? (prod.inventories?.[0]?.stock ?? prod.stock)
        : prod.stock

      // Resolve base cost price from variants if base is 0
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
        imageUrl: prod.imageUrl || null,
        unitsSold: 0,
        unitCostPrice: initCost,
        sellingPrice: prod.price,
        totalPayable: 0,
        currentStock,
      }
    }

    const canonUnit = (raw: string | null | undefined) => {
      let t = String(raw || '').toLowerCase().replace(/[,;()\[\]]/g, ' ').replace(/\s+/g, ' ').trim()
      t = t.replace(/\b(kilograms?|kgs)\b/g, 'kg')
      t = t.replace(/\b(grams?|gms|gm)\b/g, 'g')
      t = t.replace(/\b(millilitres?|milliliters?|mls)\b/g, 'ml')
      t = t.replace(/\b(litres?|liters?|ltrs|ltr)\b/g, 'l')
      t = t.replace(/\b(pieces?|pcs)\b/g, 'pc')
      t = t.replace(/\b(packets?|pkts)\b/g, 'pkt')
      return t.replace(/[^a-z0-9]/g, '')
    }
    const extractVarFromName = (name: string | null | undefined) => {
      if (!name) return ''
      const matches = Array.from(name.matchAll(/[\(\[]([^\)\]]+)[\)\]]/g)).map((m) => (m[1] || '').trim()).filter(Boolean)
      for (const c of matches) {
        if (/\b(\d+|half|full|serving|pc|pcs|kg|g|gm|gms|ml|l|ltr|pack)\b/i.test(c)) return c
      }
      return matches[matches.length - 1] || ''
    }
    const parseVarsList = (raw: any): any[] => {
      if (!raw) return []
      try {
        const p = typeof raw === 'string' ? JSON.parse(raw) : raw
        if (Array.isArray(p)) return p.filter((v) => v && typeof v === 'object')
        if (p && typeof p === 'object') {
          if (Array.isArray(p.productVariants)) return p.productVariants
          if (Array.isArray(p.variants)) return p.variants
        }
      } catch {}
      return []
    }
    const pickVariantCost = (vars: any[], target: string, itemPrice: number): number => {
      const normTarget = target.toLowerCase().replace(/[^a-z0-9]/g, '')
      const canonTarget = canonUnit(target)
      if (normTarget || canonTarget) {
        for (const v of vars) {
          const vNameRaw = String(v.name || '')
          const vUnitRaw = String(v.unit || '')
          const vName = vNameRaw.toLowerCase().replace(/[^a-z0-9]/g, '')
          const vUnit = vUnitRaw.toLowerCase().replace(/[^a-z0-9]/g, '')
          if (
            (normTarget && (vName === normTarget || vUnit === normTarget)) ||
            (canonTarget && (canonUnit(vNameRaw) === canonTarget || canonUnit(vUnitRaw) === canonTarget))
          ) {
            const cp = Number(v.costPrice ?? v.cp ?? v.cost ?? 0)
            if (cp > 0) return cp
          }
        }
      }
      if (itemPrice > 0) {
        for (const v of vars) {
          const vp = Number(v.price || 0)
          if (vp > 0 && Math.abs(vp - itemPrice) < 0.01) {
            const cp = Number(v.costPrice ?? v.cp ?? v.cost ?? 0)
            if (cp > 0) return cp
          }
        }
      }
      return 0
    }
    const soldMultiVariantPids = new Set<string>()

    // Accumulate delivered sales with live-first canonical variant cost resolution
    for (const order of deliveredOrders) {
      const istTime = new Date(order.createdAt.getTime() + 5.5 * 60 * 60 * 1000)
      const orderDateStr = istTime.toISOString().split('T')[0]
      if (!dailySalesMap[orderDateStr]) {
        dailySalesMap[orderDateStr] = {
          date: orderDateStr,
          totalUnits: 0,
          totalPayable: 0,
          items: {},
        }
      }

      for (const item of order.items) {
        if (item.isRefunded || !item.productId) continue

        const baseProd = productMap.get(item.productId)
        const liveVariants = parseVarsList(baseProd?.variants)
        const snapVariants = parseVarsList(item.variants)
        const targetVar = (item.selectedVariant || '').trim() || extractVarFromName(item.name)
        const itemPrice = Number(item.price || baseProd?.price || 0)

        // 1. Live catalog variant cost first
        let effectiveCostPrice = liveVariants.length > 0 ? pickVariantCost(liveVariants, targetVar, itemPrice) : 0

        // 2. Live hub/product base cost (only when no multi-variant mismatch)
        const isBaseMatch =
          liveVariants.length <= 1 ||
          !canonUnit(targetVar) ||
          (baseProd?.unit && canonUnit(targetVar) === canonUnit(baseProd.unit)) ||
          (Number(baseProd?.price || 0) > 0 && Math.abs(Number(baseProd?.price || 0) - itemPrice) < 0.01)

        if (effectiveCostPrice <= 0 && isBaseMatch) {
          const hubInv = baseProd?.inventories?.[0] as any
          const hubCost = hubInv?.costPrice && Number(hubInv.costPrice) > 0 ? Number(hubInv.costPrice) : 0
          const prodCost = baseProd?.costPrice && Number(baseProd.costPrice) > 0 ? Number(baseProd.costPrice) : 0
          const preferHub =
            hubCost > 0 &&
            hubInv?.updatedAt &&
            (!baseProd?.updatedAt || new Date(hubInv.updatedAt) >= new Date(baseProd.updatedAt))
          if (preferHub) {
            effectiveCostPrice = hubCost
          } else if (prodCost > 0) {
            effectiveCostPrice = prodCost
          } else if (hubCost > 0) {
            effectiveCostPrice = hubCost
          }
        }

        // 3. Fallback to order snapshot only when live catalog has no matching cost
        if (effectiveCostPrice <= 0 && snapVariants.length > 0) {
          effectiveCostPrice = pickVariantCost(snapVariants, targetVar, itemPrice)
        }
        if (effectiveCostPrice <= 0 && item.costPrice && Number(item.costPrice) > 0) {
          effectiveCostPrice = Number(item.costPrice)
        }

        const qty = item.quantity || 0
        const itemPayable = effectiveCostPrice > 0 ? qty * effectiveCostPrice : 0

        totalUnitsSold += qty
        totalPayableAmount += itemPayable

        const pUnit = targetVar || baseProd?.unit || ''
        const pName = baseProd?.name || item.name || 'Item'
        const canonResolved = canonUnit(pUnit)
        const summaryKey = liveVariants.length > 1 && targetVar
          ? `${item.productId}::${canonResolved || targetVar.toLowerCase()}`
          : item.productId

        if (liveVariants.length > 1 && targetVar) {
          soldMultiVariantPids.add(item.productId)
          if (!itemSalesSummary[summaryKey]) {
            itemSalesSummary[summaryKey] = {
              productId: item.productId,
              name: pName,
              unit: pUnit,
              categoryName: baseProd?.category?.name || 'Uncategorized',
              barcode: baseProd?.barcode || null,
              imageUrl: baseProd?.imageUrl || null,
              unitsSold: 0,
              unitCostPrice: effectiveCostPrice,
              costedUnits: 0,
              costMissing: effectiveCostPrice <= 0,
              sellingPrice: itemPrice,
              totalPayable: 0,
              currentStock: baseProd?.inventories?.[0]?.stock ?? baseProd?.stock ?? 0,
            }
          }
        }

        // Update Itemized Sales
        const summaryEntry = itemSalesSummary[summaryKey]
        if (summaryEntry) {
          summaryEntry.unitsSold += qty
          summaryEntry.totalPayable += itemPayable
          if (effectiveCostPrice > 0) {
            summaryEntry.costedUnits = (summaryEntry.costedUnits || 0) + qty
          }
          const cu = summaryEntry.costedUnits || 0
          summaryEntry.unitCostPrice = cu > 0 ? Math.round((summaryEntry.totalPayable / cu) * 100) / 100 : 0
          summaryEntry.costMissing = cu < summaryEntry.unitsSold
        }

        // Update Daily Sales Map
        dailySalesMap[orderDateStr].totalUnits += qty
        dailySalesMap[orderDateStr].totalPayable += itemPayable

        const dayItemKey = `${item.productId}_${canonResolved || pUnit}`

        if (!dailySalesMap[orderDateStr].items[dayItemKey]) {
          dailySalesMap[orderDateStr].items[dayItemKey] = {
            productId: item.productId,
            name: pName,
            unit: pUnit,
            unitCostPrice: effectiveCostPrice,
            costedUnits: effectiveCostPrice > 0 ? qty : 0,
            costMissing: effectiveCostPrice <= 0,
            unitsSold: qty,
            totalPayable: itemPayable,
          }
        } else {
          const cur = dailySalesMap[orderDateStr].items[dayItemKey]
          cur.unitsSold += qty
          cur.totalPayable += itemPayable
          if (effectiveCostPrice > 0) {
            cur.costedUnits = (cur.costedUnits || 0) + qty
          }
          const curCosted = cur.costedUnits || 0
          cur.unitCostPrice = curCosted > 0 ? Math.round((cur.totalPayable / curCosted) * 100) / 100 : 0
          cur.costMissing = curCosted < cur.unitsSold
        }
      }
    }

    for (const pid of soldMultiVariantPids) {
      if (itemSalesSummary[pid] && itemSalesSummary[pid].unitsSold === 0) {
        delete itemSalesSummary[pid]
      }
    }
    for (const entry of Object.values(itemSalesSummary)) {
      entry.totalPayable = Math.round(entry.totalPayable * 100) / 100
      if (entry.unitsSold === 0) {
        entry.costMissing = (entry.unitCostPrice || 0) <= 0
      }
      delete entry.costedUnits
    }

    const itemizedSales = Object.values(itemSalesSummary).sort((a, b) => b.totalPayable - a.totalPayable)

    const dailySales = Object.values(dailySalesMap)
      .filter((day) => day.totalUnits > 0)
      .map((day) => ({
        date: day.date,
        totalUnits: day.totalUnits,
        totalPayable: Math.round(day.totalPayable * 100) / 100,
        items: Object.values(day.items),
      }))
      .sort((a, b) => b.date.localeCompare(a.date))

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
        const hubInv = p.inventories?.[0] as any
        const stock = storeId && storeId !== 'all'
          ? (hubInv?.stock ?? p.stock)
          : p.stock
        const minStock = p.minStock ?? 5
        const prodCost = p.costPrice && Number(p.costPrice) > 0 ? Number(p.costPrice) : 0
        const hubCost = hubInv?.costPrice && Number(hubInv.costPrice) > 0 ? Number(hubInv.costPrice) : 0
        const effectiveLowCost = hubCost > 0 ? hubCost : prodCost
        return {
          id: p.id,
          name: p.name,
          unit: p.unit || '',
          barcode: p.barcode,
          stock,
          minStock,
          costPrice: effectiveLowCost,
          costMissing: effectiveLowCost <= 0,
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
      dailySales,
      payouts: payoutsList,
      lowStockItems,
      products: products.map((p) => {
        const prodCost = p.costPrice && Number(p.costPrice) > 0 ? Number(p.costPrice) : 0
        const hubInv = p.inventories?.[0] as any
        const hubCost = hubInv?.costPrice && Number(hubInv.costPrice) > 0 ? Number(hubInv.costPrice) : 0
        const preferHub =
          hubCost > 0 &&
          hubInv?.updatedAt &&
          (!p.updatedAt || new Date(hubInv.updatedAt) >= new Date(p.updatedAt))
        const effCost = preferHub ? hubCost : (prodCost > 0 ? prodCost : hubCost)
        return {
          id: p.id,
          name: p.name,
          unit: p.unit || '',
          barcode: p.barcode,
          price: p.price,
          mrp: p.mrp,
          costPrice: effCost,
          costMissing: effCost <= 0,
          stock: storeId && storeId !== 'all' ? (p.inventories?.[0]?.stock ?? p.stock) : p.stock,
          category: p.category?.name,
          imageUrl: p.imageUrl,
          isAvailable: p.isAvailable,
        }
      }),
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
  const session = adminResult.session

  const { id } = await params

  try {
    const existing = await (prisma as any).vendor.findUnique({
      where: { id },
      select: { id: true, storeId: true }
    })
    if (!existing) {
      return NextResponse.json({ error: 'Vendor not found' }, { status: 404 })
    }
    if (existing.storeId && (session?.user as any)?.assignedStoreId && existing.storeId !== (session?.user as any)?.assignedStoreId) {
      return NextResponse.json({ error: 'Forbidden: Cannot delete vendor from another hub' }, { status: 403 })
    }

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
