import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { apiReadLimiter } from '@/lib/rate-limit'

export async function POST(request: NextRequest) {
  const limited = apiReadLimiter.check(request)
  if (limited) return limited

  try {
    const { items } = await request.json()
    if (!items || !Array.isArray(items)) {
      return NextResponse.json({ error: 'Invalid cart items' }, { status: 400 })
    }

    const productIds = items.map((item: any) => item.product?.id).filter(Boolean)
    if (productIds.length === 0) {
      return NextResponse.json({ hasChanges: false, updates: [] })
    }

    const dbProducts = await prisma.product.findMany({
      where: { id: { in: productIds } },
      select: {
        id: true,
        name: true,
        price: true,
        mrp: true,
        stock: true,
        isAvailable: true,
      },
    })

    const updates: any[] = []

    for (const item of items) {
      const clientProduct = item.product
      const clientQty = item.quantity
      if (!clientProduct?.id) continue

      const dbProduct = dbProducts.find((p) => p.id === clientProduct.id)

      // 1. Check if product exists and is available
      if (!dbProduct || !dbProduct.isAvailable || dbProduct.stock <= 0) {
        updates.push({
          type: 'OUT_OF_STOCK',
          productId: clientProduct.id,
          name: clientProduct.name || 'Product',
        })
        continue
      }

      // 2. Check if requested quantity exceeds stock
      if (clientQty > dbProduct.stock) {
        updates.push({
          type: 'QUANTITY_CAP',
          productId: clientProduct.id,
          name: dbProduct.name,
          oldVal: clientQty,
          newVal: dbProduct.stock,
        })
      }

      // 3. Check for price changes
      if (clientProduct.price !== dbProduct.price) {
        updates.push({
          type: 'PRICE_UPDATE',
          productId: clientProduct.id,
          name: dbProduct.name,
          oldVal: clientProduct.price,
          newVal: dbProduct.price,
        })
      }

      // 4. Check for MRP changes
      if (clientProduct.mrp !== dbProduct.mrp) {
        updates.push({
          type: 'MRP_UPDATE',
          productId: clientProduct.id,
          name: dbProduct.name,
          oldVal: clientProduct.mrp,
          newVal: dbProduct.mrp,
        })
      }
    }

    return NextResponse.json({
      hasChanges: updates.length > 0,
      updates,
    })
  } catch (error: any) {
    console.error('Validate cart API error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
