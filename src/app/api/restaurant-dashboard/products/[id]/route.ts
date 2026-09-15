import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'
import { invalidateProductCache } from '@/lib/search-cache'
import { normalizeRestaurantId } from '@/lib/restaurant-ids'
import { logger } from '@/lib/logger'
import { Prisma } from '@prisma/client'

export async function PATCH(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params

    const existing = await prisma.product.findFirst({
      where: {
        OR: [
          { id },
          { slug: id }
        ]
      }
    })

    if (!existing) {
      return NextResponse.json({ error: 'Menu item not found' }, { status: 404 })
    }

    let session = null
    try {
      session = await auth()
    } catch (authErr) {
      logger.warn('auth', 'Session check failed in product PATCH', authErr)
    }

    const role = session?.user?.role || request.headers.get('x-user-role') || 'RESTAURANT_OWNER'
    const userPhone = (session?.user?.phone || request.headers.get('x-user-phone') || '').trim()
    const userEmail = (session?.user?.email || request.headers.get('x-user-email') || '').toLowerCase().trim()
    const assignedRestaurantId = session?.user?.assignedRestaurantId || request.headers.get('x-restaurant-id') || null

    const body = await request.json()
    const updateData: Prisma.ProductUpdateInput = {}

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
      updateData.category = { connect: { id: body.categoryId } }
    }

    if (body.stock !== undefined) {
      const parsedStock = parseInt(body.stock)
      updateData.stock = isNaN(parsedStock) ? existing.stock : parsedStock
    }

    let parsedPrice = body.price !== undefined ? parseFloat(body.price) : NaN
    let parsedMrp = body.mrp !== undefined ? parseFloat(body.mrp) : NaN

    if (!isNaN(parsedPrice)) updateData.price = parsedPrice
    if (!isNaN(parsedMrp)) updateData.mrp = parsedMrp

    const finalPrice = typeof updateData.price === 'number' ? updateData.price : existing.price
    const finalMrp = typeof updateData.mrp === 'number' ? updateData.mrp : existing.mrp

    if (finalMrp > 0 && finalPrice >= 0) {
      updateData.discount = finalMrp > finalPrice ? Math.max(0, Math.round(((finalMrp - finalPrice) / finalMrp) * 100)) : 0
    }

    if (body.restaurantId) {
      const normRest = normalizeRestaurantId(body.restaurantId)
      if (normRest) updateData.restaurant = { connect: { id: normRest } }
    } else if (!existing.restaurantId && assignedRestaurantId) {
      const normRest = normalizeRestaurantId(assignedRestaurantId)
      if (normRest) updateData.restaurant = { connect: { id: normRest } }
    }

    const product = await prisma.product.update({
      where: { id: existing.id },
      data: updateData,
      include: { category: true, restaurant: true },
    })

    try {
      revalidateStorefront(product.category?.slug, product.restaurant?.slug)
      await invalidateProductCache()
    } catch (e) {
      logger.warn('cache', 'Cache revalidation failed in product PATCH', e)
    }

    return NextResponse.json({ product, success: true })
  } catch (error: unknown) {
    logger.error('restaurant-product', 'Restaurant dashboard product PATCH error', error)
    const message = error instanceof Error ? error.message : 'Failed to update menu item'
    return NextResponse.json({ error: message }, { status: 500 })
  }
}

export async function DELETE(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params

    const existing = await prisma.product.findFirst({
      where: {
        OR: [
          { id },
          { slug: id }
        ]
      },
      include: { category: true }
    })

    if (!existing) {
      return NextResponse.json({ error: 'Menu item not found' }, { status: 404 })
    }

    await prisma.product.update({
      where: { id: existing.id },
      data: { isAvailable: false },
    })

    try {
      revalidateStorefront(existing.category?.slug)
      await invalidateProductCache()
    } catch (e) {
      logger.warn('cache', 'Cache revalidation failed in product DELETE', e)
    }

    return NextResponse.json({ success: true })
  } catch (error: unknown) {
    logger.error('restaurant-product', 'Restaurant dashboard product DELETE error', error)
    const message = error instanceof Error ? error.message : 'Failed to remove menu item'
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
