import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

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
        deliveryUserId: true,
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
          }
        }
      }
    })

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    if (!order.deliveryUserId) {
      return NextResponse.json({ error: 'No delivery agent assigned' }, { status: 400 })
    }

    // Fetch active delivery coordinates from User model
    const rider = await prisma.user.findUnique({
      where: { id: order.deliveryUserId },
      select: {
        liveLat: true,
        liveLng: true,
        name: true,
        phone: true,
      }
    })

    // If rider doesn't have live coordinates yet, default to restaurant coordinates
    const lat = rider?.liveLat || (order.restaurant as any)?.lat || 26.13 // Ghatampur default lat
    const lng = rider?.liveLng || (order.restaurant as any)?.lng || 79.91 // Ghatampur default lng

    return NextResponse.json({
      rider: {
        name: rider?.name || 'Rider',
        phone: rider?.phone,
        lat,
        lng,
      },
      restaurant: {
        lat: (order.restaurant as any)?.lat || 26.13,
        lng: (order.restaurant as any)?.lng || 79.91,
      },
      customer: {
        lat: order.address?.lat || 26.14,
        lng: order.address?.lng || 79.92,
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
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    if (role !== 'DELIVERY' && role !== 'ADMIN') {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const body = await request.json()
    const { lat, lng } = body

    if (lat === undefined || lng === undefined) {
      return NextResponse.json({ error: 'Missing lat or lng coordinates' }, { status: 400 })
    }

    // Update rider's coordinates in User model
    await prisma.user.update({
      where: { id: session.user.id },
      data: {
        liveLat: parseFloat(lat),
        liveLng: parseFloat(lng),
      }
    })

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Delivery location POST error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
