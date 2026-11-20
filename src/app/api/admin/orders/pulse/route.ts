import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin, getEffectiveStoreId } from '@/lib/auth-guard'

export const dynamic = 'force-dynamic'

const headers = {
  'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0',
}

export async function GET(request: Request) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  const { searchParams } = new URL(request.url)
  const paramStoreId = searchParams.get('storeId')
  const effectiveStoreId = getEffectiveStoreId(session, paramStoreId)

  try {
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000)
    const statusCondition = [
      { status: { in: ['PENDING', 'ADMIN_PENDING'] } },
      { status: 'CONFIRMED', createdAt: { gte: twentyFourHoursAgo } },
    ]
    const where: any = effectiveStoreId
      ? { storeId: effectiveStoreId, OR: statusCondition }
      : { OR: statusCondition }

    // Ultra-lightweight: single indexed fetch for the latest pending order
    const [latestOrder, pendingCount] = await Promise.all([
      prisma.order.findFirst({
        where,
        select: {
          id: true,
          readableId: true,
          total: true,
          status: true,
          paymentStatus: true,
          paymentMethod: true,
          createdAt: true,
          storeId: true,
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.order.count({ where }),
    ])

    return NextResponse.json(
      {
        latestOrder,
        pendingCount,
        timestamp: Date.now(),
      },
      { headers }
    )
  } catch (error) {
    console.error('Failed to fetch orders pulse:', error)
    return NextResponse.json({ error: 'Failed to fetch pulse' }, { status: 500, headers })
  }
}
