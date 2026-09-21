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
        isAvailable: true, variants: true, addons: true, category: true, tags: true,
        restaurantId: true,
        restaurant: {
          select: {
            id: true,
            name: true,
            slug: true,
            lat: true,
            lng: true,
            deliveryRadiusKm: true,
            isOpen: true,
            openTime: true,
            closeTime: true,
          }
        }
      },
    })

    const updates: any[] = []

    for (const item of items) {
      const clientProduct = item.product
      const clientQty = item.quantity
      if (!clientProduct?.id) continue

      const rawId = clientProduct.id
      const isVariant = rawId.includes('_')
      let productId = rawId
      let variantName: string | null = null

      if (isVariant) {
        const parts = rawId.split('_')
        productId = parts[0]
        // If has _addons_, the variant name is parts[1] (if not 'addons')
        if (parts[1] && parts[1] !== 'addons') {
          variantName = parts[1]
        }
      }

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

      if (variantName && dbProduct.variants && Array.isArray(dbProduct.variants)) {
        const variant = (dbProduct.variants as any[]).find((v: any) => v.name === variantName)
        if (variant) {
          dbPrice = variant.price
          dbMrp = variant.mrp
          dbStock = variant.stock
        }
      }

      // Add verified addon pricing from DB if item has selectedAddons
      const selectedAddons = (clientProduct as any).selectedAddons || (item as any).selectedAddons
      if (Array.isArray(selectedAddons) && selectedAddons.length > 0) {
        let addonSum = 0
        // If DB has addons, verify price from DB, otherwise trust client addon price
        const dbAddons = Array.isArray(dbProduct.addons) ? (dbProduct.addons as any[]) : []
        selectedAddons.forEach((sa: any) => {
          let foundPrice = parseFloat(sa.price) || 0
          for (const g of dbAddons) {
            if (Array.isArray(g.items)) {
              const matched = g.items.find((i: any) => i.name === sa.name)
              if (matched) {
                foundPrice = parseFloat(matched.price) || 0
                break
              }
            }
          }
          addonSum += foundPrice
        })
        dbPrice += addonSum
        dbMrp += addonSum
      }

      if (dbStock <= 0) {
        updates.push({
          type: 'OUT_OF_STOCK',
          productId: clientProduct.id,
          name: clientProduct.name || 'Product',
        })
        continue
      }

      if (dbStock > 0 && clientQty > dbStock) {
        updates.push({
          type: 'QUANTITY_CAP',
          productId: clientProduct.id,
          name: clientProduct.name,
          oldVal: clientQty,
          newVal: dbStock,
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

      const clientRest = (clientProduct as any).restaurant
      if (dbProduct.restaurant && (!clientRest?.lat || !clientRest?.deliveryRadiusKm)) {
        updates.push({
          type: 'RESTAURANT_UPDATE',
          productId: clientProduct.id,
          name: clientProduct.name,
          newVal: dbProduct.restaurant,
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
