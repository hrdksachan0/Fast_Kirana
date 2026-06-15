import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { apiReadLimiter } from '@/lib/rate-limit'
import { isCafeProduct } from '@/lib/utils'

export async function POST(request: NextRequest) {
  const limited = await apiReadLimiter.check(request)
  if (limited) return limited

  try {
    const { items } = await request.json()
    if (!items || !Array.isArray(items)) {
      return NextResponse.json({ error: 'Invalid cart items' }, { status: 400 })
    }

    const productIds = items.map((item: any) => item.product?.id ? item.product.id.split('_')[0] : null).filter(Boolean)
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
        variants: true,
        category: true,
        tags: true,
      },
    })

    const updates: any[] = []

    for (const item of items) {
      const clientProduct = item.product
      const clientQty = item.quantity
      if (!clientProduct?.id) continue

      const isVariant = clientProduct.id.includes('_')
      const [productId, variantName] = isVariant ? clientProduct.id.split('_') : [clientProduct.id, null]

      const dbProduct = dbProducts.find((p) => p.id === productId)

      // 1. Check if product exists and is available
      if (!dbProduct || !dbProduct.isAvailable) {
        updates.push({
          type: 'OUT_OF_STOCK',
          productId: clientProduct.id,
          name: clientProduct.name || 'Product',
        })
        continue
      }

      // Resolve variant price, mrp, and stock
      let dbPrice = dbProduct.price
      let dbMrp = dbProduct.mrp
      let dbStock = dbProduct.stock

      if (isVariant && dbProduct.variants && Array.isArray(dbProduct.variants)) {
        const variant = (dbProduct.variants as any[]).find((v) => v.name === variantName)
        if (variant) {
          dbPrice = variant.price
          dbMrp = variant.mrp
          dbStock = variant.stock
        }
      }

      if (dbStock <= 0) {
        updates.push({
          type: 'OUT_OF_STOCK',
          productId: clientProduct.id,
          name: clientProduct.name || 'Product',
        })
        continue
      }

      // 2. Check if requested quantity exceeds stock or dynamic limit
      const limit = isCafeProduct(dbProduct) ? 10 : 5
      const maxAllowed = Math.min(dbStock, limit)
      if (clientQty > maxAllowed) {
        updates.push({
          type: 'QUANTITY_CAP',
          productId: clientProduct.id,
          name: clientProduct.name,
          oldVal: clientQty,
          newVal: maxAllowed,
        })
      }

      // 3. Check for price changes
      if (clientProduct.price !== dbPrice) {
        updates.push({
          type: 'PRICE_UPDATE',
          productId: clientProduct.id,
          name: clientProduct.name,
          oldVal: clientProduct.price,
          newVal: dbPrice,
        })
      }

      // 4. Check for MRP changes
      if (clientProduct.mrp !== dbMrp) {
        updates.push({
          type: 'MRP_UPDATE',
          productId: clientProduct.id,
          name: clientProduct.name,
          oldVal: clientProduct.mrp,
          newVal: dbMrp,
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
