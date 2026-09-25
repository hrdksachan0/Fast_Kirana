import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const storeId = searchParams.get('storeId')
    const session = await auth()
    const userId = session?.user?.id

    let products: any[] = []
    const orderedProductMap = new Map<string, number>()

    if (userId) {
      // Fetch user's orders using raw SQL to avoid the enum deserialization bug
      const orders: any[] = await prisma.$queryRaw`
        SELECT o.id, o."createdAt"
        FROM orders o
        WHERE o."userId" = ${userId}
          AND o.status::text IN ('CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED')
        ORDER BY o."createdAt" DESC
        LIMIT 10
      `

      if (orders.length > 0) {
        const orderIds = orders.map(o => o.id)
        
        // Fetch order items and include product information
        const orderItems = await prisma.orderItem.findMany({
          where: { orderId: { in: orderIds } },
          include: {
            product: {
              include: {
                category: true,
                restaurant: {
                  select: { id: true, name: true, isOpen: true }
                }
              }
            }
          }
        })

        // Extract unique products and calculate lastOrderedDays
        const now = new Date()
        orders.forEach(order => {
          const orderDate = new Date(order.createdAt)
          const diffTime = Math.abs(now.getTime() - orderDate.getTime())
          const diffDays = Math.max(1, Math.ceil(diffTime / (1000 * 60 * 60 * 24)))

          const items = orderItems.filter(item => item.orderId === order.id)
          items.forEach(item => {
            if (item.product && !orderedProductMap.has(item.product.id)) {
              orderedProductMap.set(item.product.id, diffDays)
              products.push(item.product)
            }
          })
        })
      }
    }

    // If we have fewer than 6 products, fill with popular items from the DB
    if (products.length < 6) {
      const existingIds = products.map(p => p.id)
      const whereCondition: any = {
        id: {
          notIn: existingIds
        },
        isAvailable: true,
      }

      if (storeId && storeId !== 'all') {
        whereCondition.OR = [
          { restaurant: { storeId } },
          {
            restaurantId: null,
            inventories: { some: { storeId, stock: { gt: 0 } } }
          },
          {
            restaurantId: null,
            stock: { gt: 0 }
          }
        ]
      } else {
        whereCondition.OR = [
          { restaurantId: { not: null } },
          { stock: { gt: 0 } }
        ]
      }

      const popularProducts = await prisma.product.findMany({
        where: whereCondition,
        include: {
          category: true,
          restaurant: {
            select: { id: true, name: true, isOpen: true }
          }
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

    // Format output with live stock, availability, and restaurant info
    const formatted = products.map(p => {
      const isRestaurant = Boolean(p.restaurantId || p.restaurant)
      const stockVal = typeof p.stock === 'number' && p.stock > 0
        ? p.stock
        : (isRestaurant ? 999 : (typeof p.stock === 'number' ? p.stock : 50))
      const isAvailableVal = p.isAvailable !== false && (isRestaurant || stockVal > 0)
      return {
        id: p.id,
        name: p.name,
        slug: p.slug,
        imageUrl: p.imageUrl,
        price: p.price,
        mrp: p.mrp || p.price,
        unit: p.unit || '',
        stock: stockVal,
        isAvailable: isAvailableVal,
        restaurantId: p.restaurantId,
        restaurantName: p.restaurant?.name,
        restaurant: p.restaurant,
        lastOrderedDays: orderedProductMap.get(p.id) || 3,
        categorySlug: p.category ? p.category.slug : 'general',
        category: p.category ? { id: p.category.id, name: p.category.name, slug: p.category.slug } : undefined,
      }
    })

    return NextResponse.json(formatted.slice(0, 8))
  } catch (error: any) {
    console.error('Error in buy-again API:', error)
    return NextResponse.json([], { status: 500 })
  }
}
