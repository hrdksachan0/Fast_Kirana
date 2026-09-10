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
    const stockMap: Record<string, { price: number; mrp: number; stock: number; isAvailable: boolean }> = {}
    const uncachedIds: string[] = []

    // 1. Check in-memory cache first
    ids.forEach((id: string) => {
      const cached = memoryStockCache.get(id)
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

    const products = await prisma.product.findMany({
      where: { id: { in: baseIds } },
      select: {
        id: true,
        price: true,
        mrp: true,
        stock: true,
        isAvailable: true,
        variants: true,
      },
    })

    uncachedIds.forEach((id: string) => {
      const isVariant = id.includes('_')
      const [productId, variantName] = isVariant ? id.split('_') : [id, null]
      
      const dbProduct = products.find((p) => p.id === productId)
      if (!dbProduct) return
      
      if (isVariant && dbProduct.variants && Array.isArray(dbProduct.variants)) {
        const variant = (dbProduct.variants as any[]).find((v) => v.name === variantName)
        if (variant) {
          stockMap[id] = {
            price: variant.price,
            mrp: variant.mrp,
            stock: variant.stock,
            isAvailable: dbProduct.isAvailable && variant.stock > 0,
          }
          memoryStockCache.set(id, {
            value: stockMap[id],
            expiresAt: now + 20000,
          })
          return
        }
      }
      
      stockMap[id] = {
        price: dbProduct.price,
        mrp: dbProduct.mrp,
        stock: dbProduct.stock,
        isAvailable: dbProduct.isAvailable,
      }

      // Save into cache for 20 seconds
      memoryStockCache.set(id, {
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
