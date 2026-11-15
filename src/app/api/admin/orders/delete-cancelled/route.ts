import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin, getEffectiveStoreId } from '@/lib/auth-guard'

export async function POST(req: NextRequest) {
  const adminResult = await requireAdmin(req)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  const { searchParams } = new URL(req.url)
  const effectiveStoreId = getEffectiveStoreId(session, searchParams.get('storeId'))

  try {
    const where: any = { status: 'CANCELLED' }
    if (effectiveStoreId) {
      where.storeId = effectiveStoreId
    }

    const cancelledOrders = await prisma.order.findMany({
      where,
      select: { id: true },
    })

    if (cancelledOrders.length === 0) {
      return NextResponse.json({
        success: true,
        message: 'No cancelled orders found.',
        count: 0
      })
    }

    const idsToDelete = cancelledOrders.map(o => o.id)

    await prisma.orderItem.deleteMany({
      where: { orderId: { in: idsToDelete } }
    })

    const result = await prisma.order.deleteMany({
      where: { id: { in: idsToDelete } }
    })

    return NextResponse.json({
      success: true,
      message: `Successfully deleted ${result.count} cancelled orders.`,
      count: result.count
    })
  } catch (error: any) {
    console.error('Error deleting cancelled orders:', error)
    return NextResponse.json(
      { error: error.message || 'Failed to delete cancelled orders' },
      { status: 500 }
    )
  }
}
