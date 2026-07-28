import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function POST(req: NextRequest) {
  try {
    const result = await prisma.order.deleteMany({
      where: { status: 'CANCELLED' }
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
