import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth-guard'
import { logger } from '@/lib/logger'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error

  try {
    const { searchParams } = new URL(request.url)
    const search = (searchParams.get('search') || '').trim()
    const limit = Math.min(Math.max(parseInt(searchParams.get('limit') || '50', 10), 1), 200)
    const page = Math.max(parseInt(searchParams.get('page') || '1', 10), 1)
    const skip = (page - 1) * limit
    const changeType = searchParams.get('type') // 'VENDOR_UPDATE' | 'ADMIN_UPDATE' | null

    const whereClause: any = {}

    if (changeType && changeType !== 'ALL') {
      whereClause.changeType = changeType
    }

    if (search) {
      whereClause.OR = [
        { changedBy: { contains: search, mode: 'insensitive' } },
        { product: { name: { contains: search, mode: 'insensitive' } } },
        { product: { restaurant: { name: { contains: search, mode: 'insensitive' } } } },
      ]
    }

    const [totalCount, records, recent24hCount] = await Promise.all([
      prisma.priceHistory.count({ where: whereClause }),
      prisma.priceHistory.findMany({
        where: whereClause,
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
        include: {
          product: {
            select: {
              id: true,
              name: true,
              slug: true,
              imageUrl: true,
              price: true,
              mrp: true,
              costPrice: true,
              restaurant: {
                select: {
                  id: true,
                  name: true,
                  slug: true,
                },
              },
              category: {
                select: {
                  id: true,
                  name: true,
                },
              },
            },
          },
        },
      }),
      prisma.priceHistory.count({
        where: {
          createdAt: {
            gte: new Date(Date.now() - 24 * 60 * 60 * 1000),
          },
        },
      }),
    ])

    // Calculate quick stats from records
    let totalIncreases = 0
    let totalDecreases = 0

    const formattedRecords = records.map((r) => {
      const priceDiff = r.newPrice - r.oldPrice
      if (priceDiff > 0) totalIncreases++
      else if (priceDiff < 0) totalDecreases++

      const percentChange = r.oldPrice > 0 ? ((priceDiff / r.oldPrice) * 100).toFixed(1) : '0'

      return {
        id: r.id,
        productId: r.productId,
        productName: r.product?.name || 'Unknown Item',
        productImage: r.product?.imageUrl || null,
        restaurantName: r.product?.restaurant?.name || null,
        categoryName: r.product?.category?.name || null,
        currentPrice: r.product?.price ?? r.newPrice,
        oldPrice: r.oldPrice,
        newPrice: r.newPrice,
        oldMrp: r.oldMrp,
        newMrp: r.newMrp,
        priceDiff,
        percentChange: Number(percentChange),
        changeType: r.changeType,
        changedBy: r.changedBy || 'VENDOR',
        createdAt: r.createdAt.toISOString(),
      }
    })

    return NextResponse.json({
      success: true,
      records: formattedRecords,
      pagination: {
        page,
        limit,
        total: totalCount,
        totalPages: Math.ceil(totalCount / limit),
      },
      stats: {
        totalRecords: totalCount,
        recent24hCount,
        totalIncreases,
        totalDecreases,
      },
    })
  } catch (error: any) {
    logger.error('admin-price-history', 'Failed to fetch price history', error)
    return NextResponse.json(
      { error: error?.message || 'Failed to fetch price history' },
      { status: 500 }
    )
  }
}
