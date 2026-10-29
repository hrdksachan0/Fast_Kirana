import { NextRequest, NextResponse } from 'next/server'
import prisma from '@/lib/prisma'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { lat, lng, orderId, readableId, riderId, idle } = body

    const numLat = typeof lat === 'number' ? lat : parseFloat(lat)
    const numLng = typeof lng === 'number' ? lng : parseFloat(lng)

    if (isNaN(numLat) || isNaN(numLng)) {
      return NextResponse.json({ error: 'Invalid coordinates' }, { status: 400 })
    }

    if (numLat < -90 || numLat > 90 || numLng < -180 || numLng > 180) {
      return NextResponse.json({ error: 'Coordinates out of bounds' }, { status: 400 })
    }

    // 1. If rider ID is provided, update live location in User table (for both idle & active dispatch)
    if (riderId && typeof riderId === 'string' && riderId.trim() !== '' && riderId !== 'rider_current') {
      try {
        await prisma.user.updateMany({
          where: { id: riderId.trim() },
          data: {
            liveLat: numLat,
            liveLng: numLng,
          },
        })
      } catch (e) {
        // Non-blocking failover
      }
    }

    // 2. If active order ID is provided, update delivery coordinates in Orders table
    if (!idle && orderId && typeof orderId === 'string') {
      const cleanOrderId = orderId.trim().replace(/^#/, '')
      try {
        await prisma.order.updateMany({
          where: {
            OR: [
              { id: cleanOrderId },
              ...(readableId ? [{ readableId: readableId.trim().replace(/^#/, '') }] : []),
            ],
          },
          data: {
            deliveryLat: numLat,
            deliveryLng: numLng,
          },
        })
      } catch (e) {
        // Non-blocking failover
      }
    }

    return NextResponse.json({ success: true, timestamp: Date.now() })
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Internal Server Error'
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
