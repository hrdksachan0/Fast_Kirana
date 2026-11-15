import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin, getEffectiveStoreId } from '@/lib/auth-guard'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const { searchParams } = new URL(request.url)
    const effectiveStoreId = getEffectiveStoreId(session, searchParams.get('storeId'))

    const where: any = {
      role: 'DELIVERY',
    }

    if (effectiveStoreId && effectiveStoreId !== 'all' && effectiveStoreId !== 'ALL') {
      where.assignedStoreId = effectiveStoreId
    }

    const riders = await prisma.user.findMany({
      where,
      select: {
        id: true,
        name: true,
        phone: true,
        email: true,
        role: true,
        assignedStoreId: true,
        deliveryOrders: {
          where: {
            status: { notIn: ['DELIVERED', 'CANCELLED'] },
          },
          select: { id: true },
        },
      },
      orderBy: { name: 'asc' },
    })

    return NextResponse.json({
      success: true,
      riders: riders.map((r) => ({
        id: r.id,
        name: r.name || 'Delivery Partner',
        phone: r.phone || '',
        role: r.role,
        assignedStoreId: r.assignedStoreId,
        activeOrdersCount: r.deliveryOrders?.length || 0,
      })),
    })
  } catch (error: any) {
    console.error('Error fetching riders:', error)
    return NextResponse.json({ error: 'Failed to fetch riders' }, { status: 500 })
  }
}
