import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

const DEFAULT_GHATAMPUR_LAT = 26.1534185
const DEFAULT_GHATAMPUR_LNG = 80.1714024

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const orderId = searchParams.get('orderId')

    if (!orderId) {
      return NextResponse.json({ error: 'Missing orderId' }, { status: 400 })
    }

    const order = await prisma.order.findUnique({
      where: { id: orderId },
      select: {
        id: true,
        deliveryUserId: true,
        deliveryLat: true,
        deliveryLng: true,
        status: true,
        restaurant: {
          select: {
            lat: true,
            lng: true,
            address: true,
          }
        },
        address: {
          select: {
            lat: true,
            lng: true,
            houseNo: true,
            street: true,
            area: true,
          }
        }
      }
    })

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    let rider: any = null
    if (order.deliveryUserId) {
      rider = await prisma.user.findUnique({
        where: { id: order.deliveryUserId },
        select: {
          liveLat: true,
          liveLng: true,
          name: true,
          phone: true,
        }
      })
    }

    const storeLat = order.restaurant?.lat || DEFAULT_GHATAMPUR_LAT
    const storeLng = order.restaurant?.lng || DEFAULT_GHATAMPUR_LNG

    const customerLat = order.address?.lat || (storeLat + 0.008)
    const customerLng = order.address?.lng || (storeLng + 0.006)

    // Accurate Rider coordinates resolution
    const lat = order.deliveryLat || rider?.liveLat || storeLat
    const lng = order.deliveryLng || rider?.liveLng || storeLng

    return NextResponse.json({
      rider: {
        name: rider?.name || 'Delivery Partner',
        phone: rider?.phone || '+918112849854',
        lat,
        lng,
      },
      restaurant: {
        lat: storeLat,
        lng: storeLng,
      },
      customer: {
        lat: customerLat,
        lng: customerLng,
      },
      status: order.status,
    })
  } catch (error) {
    console.error('Delivery location GET error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    let userId: string | null = null
    
    // 1. Session check
    const session = await auth()
    if (session?.user?.id) {
      userId = session.user.id
    }

    // 2. Header fallback for mobile / flutter app
    if (!userId) {
      const headerUserId = request.headers.get('x-user-id') || request.headers.get('x-rider-id')
      if (headerUserId) {
        userId = headerUserId
      }
    }

    const body = await request.json()
    const { lat, lng, orderId, riderId } = body

    if (lat === undefined || lng === undefined) {
      return NextResponse.json({ error: 'Missing lat or lng coordinates' }, { status: 400 })
    }

    const parsedLat = parseFloat(lat)
    const parsedLng = parseFloat(lng)
    const targetUserId = userId || riderId

    // Update rider's coordinates in User model
    if (targetUserId) {
      await prisma.user.update({
        where: { id: targetUserId },
        data: {
          liveLat: parsedLat,
          liveLng: parsedLng,
        }
      }).catch(() => {})
    }

    // Update order's live deliveryLat and deliveryLng
    if (orderId) {
      await prisma.order.update({
        where: { id: orderId },
        data: {
          deliveryLat: parsedLat,
          deliveryLng: parsedLng,
        }
      }).catch(() => {})
    }

    return NextResponse.json({ success: true, lat: parsedLat, lng: parsedLng })
  } catch (error) {
    console.error('Delivery location POST error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
