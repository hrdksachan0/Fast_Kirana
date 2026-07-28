import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const isOwner = role === 'RESTAURANT_OWNER' || role === 'ADMIN' || role === 'CHEF'
    if (!isOwner) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const restaurantId = (session.user as any).assignedRestaurantId
    if (!restaurantId && role !== 'ADMIN') {
      return NextResponse.json({ error: 'No restaurant assigned' }, { status: 400 })
    }

    const { searchParams } = new URL(request.url)
    const status = searchParams.get('status')

    const where: any = {}
    if (role !== 'ADMIN') {
      where.restaurantId = restaurantId
    }
    if (status) {
      where.status = status
    }

    const orders = await prisma.order.findMany({
      where,
      include: {
        items: true,
        user: { select: { id: true, name: true, phone: true } },
        address: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    })

    return NextResponse.json({ orders })
  } catch (error) {
    console.error('Restaurant dashboard orders GET error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

export async function PATCH(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const isOwner = role === 'RESTAURANT_OWNER' || role === 'ADMIN' || role === 'CHEF'
    if (!isOwner) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const restaurantId = (session.user as any).assignedRestaurantId
    const body = await request.json()
    const { orderId, action } = body

    if (!orderId || !action) {
      return NextResponse.json({ error: 'Missing orderId or action' }, { status: 400 })
    }

    const order = await prisma.order.findUnique({ where: { id: orderId } })
    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }
    if (role !== 'ADMIN' && order.restaurantId !== restaurantId) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    let updateData: any = {}

    switch (action) {
      case 'accept':
        if (order.status !== 'PENDING') {
          return NextResponse.json({ error: 'Can only accept PENDING orders' }, { status: 400 })
        }
        updateData = { status: 'CONFIRMED', confirmedAt: new Date() }
        break

      case 'pack':
        if (order.status !== 'CONFIRMED') {
          return NextResponse.json({ error: 'Can only pack CONFIRMED orders' }, { status: 400 })
        }
        updateData = { status: 'PACKED', packedAt: new Date() }
        break

      case 'reject':
        if (!['PENDING', 'CONFIRMED'].includes(order.status)) {
          return NextResponse.json({ error: 'Cannot reject this order' }, { status: 400 })
        }
        updateData = { status: 'CANCELLED' }
        break

      default:
        return NextResponse.json({ error: 'Invalid action. Use: accept, pack, reject' }, { status: 400 })
    }

    const updated = await prisma.order.update({
      where: { id: orderId },
      data: updateData,
      include: { items: true },
    })

    return NextResponse.json({ order: updated })
  } catch (error) {
    console.error('Restaurant dashboard orders PATCH error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
