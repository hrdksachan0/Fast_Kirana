import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { validateCartSchema, validateBody } from '@/lib/validation'
import { isCafeProduct, getProductLimit } from '@/lib/utils'

export async function POST(request: NextRequest) {
  const limited = await (await import('@/lib/rate-limit')).apiReadLimiter.check(request)
  if (limited) return limited

  const validation = await validateBody(request, validateCartSchema)
  if (!validation.success) return validation.error

  const { items } = validation.data

  try {
    const productIds = items.map((item: any) => item.product?.id ? item.product.id.split('_')[0] : null).filter(Boolean)
    if (productIds.length === 0) {
      return NextResponse.json({ hasChanges: false, updates: [] })
    }

    const dbProducts = await prisma.product.findMany({
      where: { id: { in: productIds } },
      select: {
        id: true, name: true, price: true, mrp: true, stock: true,
        isAvailable: true, variants: true, category: true, tags: true,
      },
    })

    const updates: any[] = []

    for (const item of items) {
      const clientProduct = item.product
      const clientQty = item.quantity
      if (!clientProduct?.id) continue

      const isVariant = clientProduct.id.includes('_')
      const [productId, variantName] = isVariant ? clientProduct.id.split('_') : [clientProduct.id, null]

      const dbProduct = dbProducts.find((p: any) => p.id === productId)

      if (!dbProduct || !dbProduct.isAvailable) {
        updates.push({
          type: 'OUT_OF_STOCK',
          productId: clientProduct.id,
          name: clientProduct.name || 'Product',
        })
        continue
      }

      let dbPrice = dbProduct.price
      let dbMrp = dbProduct.mrp
      let dbStock = dbProduct.stock

      if (isVariant && dbProduct.variants && Array.isArray(dbProduct.variants)) {
        const variant = (dbProduct.variants as any[]).find((v: any) => v.name === variantName)
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

      const limit = getProductLimit(dbProduct)
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

      if (clientProduct.price !== dbPrice) {
        updates.push({
          type: 'PRICE_UPDATE',
          productId: clientProduct.id,
          name: clientProduct.name,
          oldVal: clientProduct.price,
          newVal: dbPrice,
        })
      }

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
