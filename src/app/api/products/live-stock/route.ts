import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { apiReadLimiter } from '@/lib/rate-limit'

// Short in-memory cache (20s) to absorb concurrent/repeated stock check spikes
const memoryStockCache = new Map<string, { value: any; expiresAt: number }>()

export async function POST(request: NextRequest) {
  const limited = await apiReadLimiter.check(request)
  if (limited) return limited

  try {
    let body: any
    try {
      body = await request.json()
    } catch {
      return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 })
    }

    const ids = body?.ids
    if (!ids || !Array.isArray(ids)) {
      return NextResponse.json({ error: 'Invalid product IDs list' }, { status: 400 })
    }

    if (ids.length === 0) {
      return NextResponse.json({})
    }

    const now = Date.now()
    const targetStoreId = body?.storeId || 'hub-209206'
    const stockMap: Record<string, { price: number; mrp: number; stock: number; isAvailable: boolean }> = {}
    const uncachedIds: string[] = []

    // 1. Check in-memory cache first
    ids.forEach((id: string) => {
      const cacheKey = `${id}:${targetStoreId}`
      const cached = memoryStockCache.get(cacheKey)
      if (cached && cached.expiresAt > now) {
        stockMap[id] = cached.value
      } else {
        uncachedIds.push(id)
      }
    })

    // If all requested IDs are in cache, return immediately with zero database hit!
    if (uncachedIds.length === 0) {
      return NextResponse.json(stockMap)
    }

    const baseIds = Array.from(new Set(uncachedIds.map((id: string) => id.includes('_') ? id.split('_')[0] : id)))

    const [products, inventories] = await Promise.all([
      prisma.product.findMany({
        where: { id: { in: baseIds } },
        select: {
          id: true,
          price: true,
          mrp: true,
          stock: true,
          isAvailable: true,
          variants: true,
          restaurantId: true,
        },
      }),
      prisma.storeInventory.findMany({
        where: {
          storeId: targetStoreId,
          productId: { in: baseIds },
        },
        select: {
          productId: true,
          stock: true,
          isAvailable: true,
          priceOverride: true,
        },
      }),
    ])

    const invMap = new Map(inventories.map((inv) => [inv.productId, inv]))

    uncachedIds.forEach((id: string) => {
      const isVariant = id.includes('_')
      const [productId, variantName] = isVariant ? id.split('_') : [id, null]
      
      const dbProduct = products.find((p) => p.id === productId)
      if (!dbProduct) return
      
      const inv = invMap.get(productId)
      const isRest = Boolean(dbProduct.restaurantId)
      const baseStock = isRest ? (dbProduct.stock ?? 999) : (inv ? inv.stock : (dbProduct.stock ?? 0))
      const baseAvailable = isRest ? dbProduct.isAvailable : (inv ? (inv.isAvailable && inv.stock > 0) : (dbProduct.isAvailable && baseStock > 0))
      const basePrice = (inv && typeof inv.priceOverride === 'number') ? inv.priceOverride : dbProduct.price
      
      if (isVariant && dbProduct.variants && Array.isArray(dbProduct.variants)) {
        const variant = (dbProduct.variants as any[]).find((v) => v.name === variantName)
        if (variant) {
          stockMap[id] = {
            price: variant.price,
            mrp: variant.mrp,
            stock: variant.stock,
            isAvailable: baseAvailable && variant.stock > 0,
          }
          memoryStockCache.set(`${id}:${targetStoreId}`, {
            value: stockMap[id],
            expiresAt: now + 20000,
          })
          return
        }
      }
      
      let effectiveStock = baseStock
      if (dbProduct.variants && Array.isArray(dbProduct.variants) && dbProduct.variants.length > 0) {
        const variantSum = (dbProduct.variants as any[]).reduce((sum, v) => sum + (Number(v.stock) || 0), 0)
        if (variantSum > 0 || effectiveStock === 0) {
          effectiveStock = variantSum
        }
      }

      stockMap[id] = {
        price: basePrice,
        mrp: dbProduct.mrp,
        stock: effectiveStock,
        isAvailable: baseAvailable && effectiveStock > 0,
      }

      // Save into cache for 20 seconds
      memoryStockCache.set(`${id}:${targetStoreId}`, {
        value: stockMap[id],
        expiresAt: now + 20000,
      })
    })

    // Prevent unbounded memory growth in long-running container
    if (memoryStockCache.size > 1000) {
      memoryStockCache.forEach((entry, k) => {
        if (entry.expiresAt <= now) memoryStockCache.delete(k)
      })
    }

    return NextResponse.json(stockMap)
  } catch (error: any) {
    console.error('Live stock API error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
