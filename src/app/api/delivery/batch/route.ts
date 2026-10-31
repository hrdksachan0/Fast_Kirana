import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { RiderBatchingService } from '@/services/rider-batching.service'

export const dynamic = 'force-dynamic'

/**
 * GET /api/delivery/batch
 * Retrieves active batched delivery orders for the authenticated rider.
 */
export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    const headerUserId = request.headers.get('x-user-id')
    const riderId = session?.user?.id || headerUserId

    if (!riderId) {
      return NextResponse.json({ error: 'Unauthorized: Rider identity required' }, { status: 401 })
    }

    const batchedOrders = await RiderBatchingService.getActiveBatchForRider(riderId)

    // Calculate multi-drop sequence and metadata
    const stops = batchedOrders.map((order, index) => ({
      stopNumber: index + 1,
      orderId: order.id,
      readableId: order.readableId || order.id.slice(-6),
      status: order.status,
      total: order.total,
      paymentMethod: order.paymentMethod,
      paymentStatus: order.paymentStatus,
      customerName: (order.address as any)?.name || 'Customer',
      customerPhone: (order.address as any)?.phone || '',
      deliveryAddress: (order.address as any)?.formattedAddress || `${(order.address as any)?.houseNo || ''} ${(order.address as any)?.street || ''}`,
      deliveryLat: order.deliveryLat,
      deliveryLng: order.deliveryLng,
      itemsCount: order.items.length,
      notes: order.notes,
    }))

    return NextResponse.json({
      success: true,
      riderId,
      totalStops: stops.length,
      isMultiDrop: stops.length > 1,
      stops,
    })
  } catch (error) {
    console.error('[API:DeliveryBatch] Error fetching batch:', error)
    return NextResponse.json({ error: 'Failed to fetch delivery batch' }, { status: 500 })
  }
}

/**
 * POST /api/delivery/batch
 * Triggers batch evaluation for a specific order.
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { orderId } = body

    if (!orderId) {
      return NextResponse.json({ error: 'orderId is required' }, { status: 400 })
    }

    const result = await RiderBatchingService.attemptAutoBatchForOrder(orderId)
    return NextResponse.json(result)
  } catch (error) {
    console.error('[API:DeliveryBatch] Error evaluating batch:', error)
    return NextResponse.json({ error: 'Batch evaluation failed' }, { status: 500 })
  }
}
