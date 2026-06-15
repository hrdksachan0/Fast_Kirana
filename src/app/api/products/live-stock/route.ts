import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { apiReadLimiter } from '@/lib/rate-limit'

export async function POST(request: NextRequest) {
  const limited = await apiReadLimiter.check(request)
  if (limited) return limited

  try {
    const { ids } = await request.json()
    if (!ids || !Array.isArray(ids)) {
      return NextResponse.json({ error: 'Invalid product IDs list' }, { status: 400 })
    }

    if (ids.length === 0) {
      return NextResponse.json({})
    }

    const baseIds = ids.map((id: string) => id.includes('_') ? id.split('_')[0] : id)

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

    const stockMap: Record<string, { price: number; mrp: number; stock: number; isAvailable: boolean }> = {}
    
    ids.forEach((id: string) => {
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
          return
        }
      }
      
      stockMap[id] = {
        price: dbProduct.price,
        mrp: dbProduct.mrp,
        stock: dbProduct.stock,
        isAvailable: dbProduct.isAvailable,
      }
    })

    return NextResponse.json(stockMap)
  } catch (error: any) {
    console.error('Live stock API error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
