import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const isOwner = role === 'RESTAURANT_OWNER' || role === 'ADMIN'
    if (!isOwner) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const { id } = await params
    const restaurantId = (session.user as any).assignedRestaurantId

    // Verify product belongs to owner's restaurant
    const existing = await prisma.product.findUnique({ where: { id } })
    if (!existing) {
      return NextResponse.json({ error: 'Product not found' }, { status: 404 })
    }
    if (role !== 'ADMIN' && existing.restaurantId !== restaurantId) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const body = await request.json()
    const updateData: any = {}

    if (body.name !== undefined) updateData.name = body.name
    if (body.description !== undefined) updateData.description = body.description
    if (body.imageUrl !== undefined) updateData.imageUrl = body.imageUrl
    if (body.price !== undefined) updateData.price = parseFloat(body.price)
    if (body.mrp !== undefined) updateData.mrp = parseFloat(body.mrp)
    if (body.unit !== undefined) updateData.unit = body.unit
    if (body.stock !== undefined) updateData.stock = parseInt(body.stock)
    if (body.tags !== undefined) updateData.tags = body.tags
    if (body.isAvailable !== undefined) updateData.isAvailable = body.isAvailable
    if (body.variants !== undefined) updateData.variants = body.variants
    if (body.categoryId !== undefined) updateData.categoryId = body.categoryId

    // Recalculate discount if price or mrp changed
    if (updateData.price || updateData.mrp) {
      const finalMrp = updateData.mrp || existing.mrp
      const finalPrice = updateData.price || existing.price
      updateData.discount = finalMrp > finalPrice ? Math.round(((finalMrp - finalPrice) / finalMrp) * 100) : 0
    }

    const product = await prisma.product.update({
      where: { id },
      data: updateData,
      include: { category: true },
    })

    return NextResponse.json({ product })
  } catch (error) {
    console.error('Restaurant dashboard product PATCH error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

export async function DELETE(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const isOwner = role === 'RESTAURANT_OWNER' || role === 'ADMIN'
    if (!isOwner) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const { id } = await params
    const restaurantId = (session.user as any).assignedRestaurantId

    const existing = await prisma.product.findUnique({ where: { id } })
    if (!existing) {
      return NextResponse.json({ error: 'Product not found' }, { status: 404 })
    }
    if (role !== 'ADMIN' && existing.restaurantId !== restaurantId) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    // Soft delete - mark unavailable
    await prisma.product.update({
      where: { id },
      data: { isAvailable: false },
    })

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Restaurant dashboard product DELETE error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
