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
      select: { id: true, name: true, costPrice: true, price: true },
    })

    const productIds = vendorProducts.map((p) => p.id)
    if (productIds.length === 0) {
      return NextResponse.json({ success: true, orders: [] })
    }

    const costPriceMap = new Map(vendorProducts.map((p) => [p.id, p.costPrice || (p.price * 0.75)]))

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
        customerName: true,
        customerPhone: true,
        deliveryAddress: true,
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

      for (const it of activeItems) {
        const cost = (it.costPrice && it.costPrice > 0)
          ? Number(it.costPrice)
          : (costPriceMap.get(it.productId || '') || (it.price * 0.75))
        totalVendorValue += (it.quantity || 1) * cost
      }

      return {
        id: ord.id,
        orderId: ord.id,
        readableId: ord.readableId ? `#${ord.readableId}` : `#${ord.id.slice(-4).toUpperCase()}`,
        status: ord.status,
        isDelivered: ord.status === 'DELIVERED',
        createdAt: ord.createdAt.toISOString(),
        total: ord.total,
        totalVendorValue: Math.round(totalVendorValue * 100) / 100,
        customerName: ord.customerName || 'Customer',
        customerPhone: ord.customerPhone || '',
        deliveryAddress: ord.deliveryAddress || '',
        items: activeItems.map((it) => ({
          id: it.id,
          name: it.name,
          quantity: it.quantity,
          price: it.price,
          costPrice: it.costPrice,
          selectedVariant: it.selectedVariant || null,
        })),
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
