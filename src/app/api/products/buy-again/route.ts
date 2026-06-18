import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    const userId = session?.user?.id

    let products: any[] = []
    const orderedProductMap = new Map<string, number>()

    if (userId) {
      // Fetch user's orders
      const orders = await prisma.order.findMany({
        where: {
          userId,
          status: {
            in: ['CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED']
          }
        },
        orderBy: {
          createdAt: 'desc'
        },
        include: {
          items: {
            include: {
              product: {
                include: {
                  category: true
                }
              }
            }
          }
        },
        take: 10
      })

      // Extract unique products and calculate lastOrderedDays
      const now = new Date()
      orders.forEach(order => {
        const orderDate = new Date(order.createdAt)
        const diffTime = Math.abs(now.getTime() - orderDate.getTime())
        const diffDays = Math.max(1, Math.ceil(diffTime / (1000 * 60 * 60 * 24)))

        order.items.forEach(item => {
          if (item.product && !orderedProductMap.has(item.product.id)) {
            orderedProductMap.set(item.product.id, diffDays)
            products.push(item.product)
          }
        })
      })
    }

    // If we have fewer than 6 products, fill with popular items from the DB
    if (products.length < 6) {
      const existingIds = products.map(p => p.id)
      const popularProducts = await prisma.product.findMany({
        where: {
          id: {
            notIn: existingIds
          },
          isAvailable: true,
          stock: {
            gt: 0
          }
        },
        include: {
          category: true
        },
        take: 8 - products.length
      })

      // Seed mock days for popular fallback products
      const mockDays = [2, 5, 7, 12, 15, 9, 4, 6]
      popularProducts.forEach((p, idx) => {
        orderedProductMap.set(p.id, mockDays[idx % mockDays.length])
        products.push(p)
      })
    }

    // Format output
    const formatted = products.map(p => {
      return {
        id: p.id,
        name: p.name,
        slug: p.slug,
        imageUrl: p.imageUrl,
        price: p.price,
        mrp: p.mrp,
        unit: p.unit,
        lastOrderedDays: orderedProductMap.get(p.id) || 3,
        categorySlug: p.category ? p.category.slug : 'general'
      }
    })

    return NextResponse.json(formatted.slice(0, 8))
  } catch (error: any) {
    console.error('Error in buy-again API:', error)
    return NextResponse.json([], { status: 500 })
  }
}
