import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { apiReadLimiter } from '@/lib/rate-limit'

export async function POST(request: NextRequest) {
  const limited = apiReadLimiter.check(request)
  if (limited) return limited

  try {
    const { ids } = await request.json()
    if (!ids || !Array.isArray(ids)) {
      return NextResponse.json({ error: 'Invalid product IDs list' }, { status: 400 })
    }

    if (ids.length === 0) {
      return NextResponse.json({})
    }

    const products = await prisma.product.findMany({
      where: { id: { in: ids } },
      select: {
        id: true,
        price: true,
        mrp: true,
        stock: true,
        isAvailable: true,
      },
    })

    const stockMap: Record<string, { price: number; mrp: number; stock: number; isAvailable: boolean }> = {}
    products.forEach((p) => {
      stockMap[p.id] = {
        price: p.price,
        mrp: p.mrp,
        stock: p.stock,
        isAvailable: p.isAvailable,
      }
    })

    return NextResponse.json(stockMap)
  } catch (error: any) {
    console.error('Live stock API error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
