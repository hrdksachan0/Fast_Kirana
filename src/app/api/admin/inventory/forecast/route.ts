import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(request: NextRequest) {
  const session = await auth()
  if (!session?.user || (session.user as any).role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const now = new Date()
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000)

    // Query aggregate quantities sold for all products in the last 30 days for DELIVERED orders
    const salesData = await prisma.orderItem.groupBy({
      by: ['productId'],
      _sum: {
        quantity: true,
      },
      where: {
        order: {
          status: 'DELIVERED',
          createdAt: {
            gte: thirtyDaysAgo,
          },
        },
      },
    })

    const salesMap = new Map<string, number>()
    salesData.forEach((item) => {
      if (item.productId) {
        salesMap.set(item.productId, item._sum.quantity || 0)
      }
    })

    // Fetch all products with their categories
    const products = await prisma.product.findMany({
      where: {
        isAvailable: true,
      },
      select: {
        id: true,
        name: true,
        slug: true,
        stock: true,
        minStock: true,
        price: true,
        costPrice: true,
        imageUrl: true,
        category: {
          select: {
            id: true,
            name: true,
            slug: true,
          },
        },
      },
    })

    const forecast = products.map((product) => {
      const isCafe = product.category?.slug === 'cafe'
      const totalSold = salesMap.get(product.id) || 0
      const velocity = totalSold / 30.0 // Units per day
      
      let daysToDepletion: number | null = null
      if (velocity > 0) {
        daysToDepletion = product.stock / velocity
      } else if (product.stock === 0) {
        daysToDepletion = 0
      }

      // Recommend restocking to cover 30 days of sales, or at least minStock
      let suggestedRestock = 0
      if (velocity > 0) {
        suggestedRestock = Math.max(0, Math.ceil(velocity * 30 - product.stock))
      } else if (product.stock <= product.minStock) {
        suggestedRestock = Math.max(0, product.minStock * 2 - product.stock)
      }

      // Urgent if running out in 7 days or already out of stock
      const isUrgent = daysToDepletion !== null && daysToDepletion <= 7

      return {
        id: product.id,
        name: product.name,
        slug: product.slug,
        stock: product.stock,
        minStock: product.minStock,
        price: product.price,
        costPrice: product.costPrice || product.price * 0.75,
        imageUrl: product.imageUrl,
        category: product.category,
        totalSold,
        velocity,
        daysToDepletion,
        suggestedRestock,
        isUrgent,
        isCafe,
      }
    })

    // Sort: Cafe items last, urgent items first, then by daysToDepletion (ascending)
    const sortedForecast = forecast.sort((a, b) => {
      if (a.isCafe && !b.isCafe) return 1
      if (!a.isCafe && b.isCafe) return -1
      
      if (a.isUrgent && !b.isUrgent) return -1
      if (!a.isUrgent && b.isUrgent) return 1

      const aDays = a.daysToDepletion === null ? 999999 : a.daysToDepletion
      const bDays = b.daysToDepletion === null ? 999999 : b.daysToDepletion
      return aDays - bDays
    })

    return NextResponse.json({
      success: true,
      forecast: sortedForecast,
    })
  } catch (error: any) {
    console.error('Forecast API error:', error)
    return NextResponse.json({ error: 'Failed to generate stock forecast', details: error.message }, { status: 500 })
  }
}
