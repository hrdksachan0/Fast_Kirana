import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export const dynamic = 'force-dynamic'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  const { searchParams } = new URL(request.url)
  const storeId = searchParams.get('storeId')

  try {
    const vendor = await (prisma as any).vendor.findUnique({
      where: { id },
      select: { id: true, name: true },
    })

    if (!vendor) {
      return NextResponse.json({ error: 'Vendor not found' }, { status: 404 })
    }

    // 1. Get all product IDs for this vendor
    const vendorProducts = await prisma.product.findMany({
      where: {
        OR: [
          { vendorId: id },
          { vendor: { equals: vendor.name, mode: 'insensitive' } },
        ],
      },
      select: { id: true, name: true, costPrice: true, price: true, unit: true, variants: true },
    })

    const productIds = vendorProducts.map((p) => p.id)
    if (productIds.length === 0) {
      return NextResponse.json({ success: true, orders: [] })
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
    const parseVars = (raw: any): any[] => {
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
    const pickVarCost = (vars: any[], target: string, itemPrice: number): number => {
      const normT = target.toLowerCase().replace(/[^a-z0-9]/g, '')
      const canonT = canonUnit(target)
      if (normT || canonT) {
        for (const v of vars) {
          const vn = String(v.name || '')
          const vu = String(v.unit || '')
          if (
            (normT && (vn.toLowerCase().replace(/[^a-z0-9]/g, '') === normT || vu.toLowerCase().replace(/[^a-z0-9]/g, '') === normT)) ||
            (canonT && (canonUnit(vn) === canonT || canonUnit(vu) === canonT))
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
    const productMap = new Map(vendorProducts.map((p) => [p.id, p]))

    // 2. Fetch today's live orders (excluding cancelled) that have items for this vendor
    const todayStart = new Date()
    todayStart.setHours(0, 0, 0, 0)

    const orderWhere: any = {
      createdAt: { gte: todayStart },
      status: { notIn: ['CANCELLED'] },
      items: {
        some: {
          productId: { in: productIds },
        },
      },
    }

    if (storeId && storeId !== 'all') {
      orderWhere.storeId = storeId
    }

    const liveOrders = await prisma.order.findMany({
      where: orderWhere,
      orderBy: { createdAt: 'desc' },
      take: 50,
      select: {
        id: true,
        readableId: true,
        status: true,
        createdAt: true,
        total: true,
        shopName: true,
        shopPhone: true,
        user: {
          select: {
            name: true,
            phone: true,
          },
        },
        address: {
          select: {
            houseNo: true,
            street: true,
            area: true,
            city: true,
            pincode: true,
            phone: true,
          },
        },
        items: {
          where: {
            productId: { in: productIds },
          },
          select: {
            id: true,
            productId: true,
            name: true,
            quantity: true,
            price: true,
            costPrice: true,
            selectedVariant: true,
            isRefunded: true,
          },
        },
      },
    })

    const formattedOrders = liveOrders.map((ord) => {
      let totalVendorValue = 0
      const activeItems = ord.items.filter((it) => !it.isRefunded)

      const resolvedItems = activeItems.map((it) => {
        const prod = it.productId ? productMap.get(it.productId) : undefined
        const liveVars = parseVars(prod?.variants)
        const targetVar = (it.selectedVariant || '').trim() || extractVarFromName(it.name)
        const itemPrice = Number(it.price || prod?.price || 0)
        let cost = liveVars.length > 0 ? pickVarCost(liveVars, targetVar, itemPrice) : 0
        if (cost <= 0) {
          const isBaseMatch =
            liveVars.length <= 1 ||
            !canonUnit(targetVar) ||
            (prod?.unit && canonUnit(targetVar) === canonUnit(prod.unit)) ||
            (Number(prod?.price || 0) > 0 && Math.abs(Number(prod?.price || 0) - itemPrice) < 0.01)
          if (isBaseMatch && prod?.costPrice && Number(prod.costPrice) > 0) {
            cost = Number(prod.costPrice)
          }
        }
        if (cost <= 0 && it.costPrice && Number(it.costPrice) > 0) {
          cost = Number(it.costPrice)
        }
        const qty = it.quantity || 1
        const itemTotal = cost > 0 ? Math.round(qty * cost * 100) / 100 : 0
        totalVendorValue += itemTotal
        return {
          id: it.id,
          name: it.name,
          quantity: qty,
          price: itemPrice,
          costPrice: cost,
          costMissing: cost <= 0,
          totalCost: itemTotal,
          selectedVariant: it.selectedVariant || null,
        }
      })

      const customerName = ord.shopName || ord.user?.name || 'Customer'
      const customerPhone = ord.shopPhone || ord.user?.phone || ord.address?.phone || ''
      const deliveryAddress = ord.address
        ? [ord.address.houseNo, ord.address.street, ord.address.area, ord.address.city, ord.address.pincode].filter(Boolean).join(', ')
        : ''

      return {
        id: ord.id,
        orderId: ord.id,
        readableId: ord.readableId ? `#${ord.readableId}` : `#${ord.id.slice(-4).toUpperCase()}`,
        status: ord.status,
        isDelivered: ord.status === 'DELIVERED',
        createdAt: ord.createdAt.toISOString(),
        total: ord.total,
        totalVendorValue: Math.round(totalVendorValue * 100) / 100,
        customerName,
        customerPhone,
        deliveryAddress,
        items: resolvedItems,
      }
    })

    return NextResponse.json({
      success: true,
      orders: formattedOrders,
    })
  } catch (error: any) {
    console.error('[VendorLiveOrders] Error:', error)
    return NextResponse.json({ success: false, error: error.message, orders: [] }, { status: 500 })
  }
}
