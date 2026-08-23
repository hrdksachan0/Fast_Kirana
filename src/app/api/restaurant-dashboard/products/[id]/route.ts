import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'
import { invalidateProductCache } from '@/lib/search-cache'

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const assignedRestaurantId = (session.user as any).assignedRestaurantId
    const userEmail = session.user.email || ''

    const isAllowed =
      role === 'ADMIN' ||
      role === 'RESTAURANT_OWNER' ||
      role === 'CHEF' ||
      userEmail.toLowerCase().startsWith('restaurant') ||
      !!assignedRestaurantId

    if (!isAllowed) {
      return NextResponse.json({ error: 'Forbidden: Insufficient permissions to edit menu items' }, { status: 403 })
    }

    const { id } = await params

    const existing = await prisma.product.findUnique({ where: { id } })
    if (!existing) {
      return NextResponse.json({ error: 'Menu item not found' }, { status: 404 })
    }

    if (
      role !== 'ADMIN' &&
      assignedRestaurantId &&
      existing.restaurantId &&
      existing.restaurantId !== assignedRestaurantId
    ) {
      return NextResponse.json({ error: 'Forbidden: You can only edit items for your assigned restaurant' }, { status: 403 })
    }

    const body = await request.json()
    const updateData: any = {}

    if (body.name !== undefined && typeof body.name === 'string') updateData.name = body.name.trim()
    if (body.description !== undefined) updateData.description = body.description || null
    if (body.imageUrl !== undefined) updateData.imageUrl = body.imageUrl || null
    if (body.unit !== undefined) updateData.unit = (body.unit && typeof body.unit === 'string') ? body.unit.trim() : '1 Serving'
    if (body.tags !== undefined) updateData.tags = Array.isArray(body.tags) ? body.tags : []
    if (body.isAvailable !== undefined) updateData.isAvailable = !!body.isAvailable
    if (body.variants !== undefined) updateData.variants = body.variants
    if (body.availableStartTime !== undefined) updateData.availableStartTime = body.availableStartTime || null
    if (body.availableEndTime !== undefined) updateData.availableEndTime = body.availableEndTime || null

    if (body.categoryId !== undefined && body.categoryId !== '' && typeof body.categoryId === 'string') {
      updateData.categoryId = body.categoryId
    }

    if (body.stock !== undefined) {
      const parsedStock = parseInt(body.stock)
      updateData.stock = isNaN(parsedStock) ? existing.stock : parsedStock
    }

    let parsedPrice = body.price !== undefined ? parseFloat(body.price) : NaN
    let parsedMrp = body.mrp !== undefined ? parseFloat(body.mrp) : NaN

    if (!isNaN(parsedPrice)) updateData.price = parsedPrice
    if (!isNaN(parsedMrp)) updateData.mrp = parsedMrp

    const finalPrice = updateData.price !== undefined ? updateData.price : existing.price
    const finalMrp = updateData.mrp !== undefined ? updateData.mrp : existing.mrp

    if (finalMrp > 0 && finalPrice >= 0) {
      updateData.discount = finalMrp > finalPrice ? Math.max(0, Math.round(((finalMrp - finalPrice) / finalMrp) * 100)) : 0
    }

    if (!existing.restaurantId && assignedRestaurantId) {
      updateData.restaurantId = assignedRestaurantId
    }

    const product = await prisma.product.update({
      where: { id },
      data: updateData,
      include: { category: true },
    })

    try {
      revalidateStorefront(product.category?.slug)
      await invalidateProductCache()
    } catch (e) {}

    return NextResponse.json({ product, success: true })
  } catch (error: any) {
    console.error('Restaurant dashboard product PATCH error:', error)
    return NextResponse.json({ error: error?.message || 'Failed to update menu item' }, { status: 500 })
  }
}

export async function DELETE(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const role = session.user.role
    const assignedRestaurantId = (session.user as any).assignedRestaurantId
    const userEmail = session.user.email || ''

    const isAllowed =
      role === 'ADMIN' ||
      role === 'RESTAURANT_OWNER' ||
      role === 'CHEF' ||
      userEmail.toLowerCase().startsWith('restaurant') ||
      !!assignedRestaurantId

    if (!isAllowed) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const { id } = await params

    const existing = await prisma.product.findUnique({ where: { id } })
    if (!existing) {
      return NextResponse.json({ error: 'Menu item not found' }, { status: 404 })
    }

    if (
      role !== 'ADMIN' &&
      assignedRestaurantId &&
      existing.restaurantId &&
      existing.restaurantId !== assignedRestaurantId
    ) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    await prisma.product.update({
      where: { id },
      data: { isAvailable: false },
    })

    await invalidateProductCache()

    return NextResponse.json({ success: true })
  } catch (error: any) {
    console.error('Restaurant dashboard product DELETE error:', error)
    return NextResponse.json({ error: error?.message || 'Failed to remove menu item' }, { status: 500 })
  }
}
