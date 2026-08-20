import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth-guard'

export async function POST() {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error

  try {
    const cancelledOrders = await prisma.order.findMany({
      where: { status: 'CANCELLED' },
      select: { id: true },
    })

    if (cancelledOrders.length === 0) {
      return NextResponse.json({
        success: true,
        message: 'No cancelled orders found.',
        count: 0,
      })
    }

    const idsToDelete = cancelledOrders.map((o) => o.id)

    // Delete items first
    await prisma.orderItem.deleteMany({
      where: { orderId: { in: idsToDelete } },
    })

    // Delete orders
    const deletedOrders = await prisma.order.deleteMany({
      where: { id: { in: idsToDelete } },
    })

    return NextResponse.json({
      success: true,
      message: `Successfully deleted ${deletedOrders.count} cancelled orders!`,
      count: deletedOrders.count,
    })
  } catch (error: any) {
    console.error('Error cleaning cancelled orders:', error)
    return NextResponse.json(
      { error: error.message || 'Failed to delete cancelled orders' },
      { status: 500 }
    )
  }
}
