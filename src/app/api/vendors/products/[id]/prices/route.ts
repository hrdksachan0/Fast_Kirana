import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'
import { invalidateProductCache } from '@/lib/search-cache'
import { logger } from '@/lib/logger'
import { Prisma } from '@prisma/client'

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params

    const existing = await prisma.product.findFirst({
      where: {
        OR: [
          { id },
          { slug: id },
        ],
      },
      include: {
        restaurant: true,
        category: true,
        vendorRel: true,
      },
    })

    if (!existing) {
      return NextResponse.json({ error: 'Product not found' }, { status: 404 })
    }

    let session = null
    try {
      session = await auth()
    } catch (e) {
      logger.warn('auth', 'Session check failed in vendor product prices PATCH', e)
    }

    const role = session?.user?.role || request.headers.get('x-user-role') || 'VENDOR'
    const userPhone = (session?.user?.phone || request.headers.get('x-user-phone') || '').trim()
    const userEmail = (session?.user?.email || request.headers.get('x-user-email') || '').toLowerCase().trim()

    const body = await request.json()
    const updateData: Prisma.ProductUpdateInput = {}

    let parsedPrice = body.price !== undefined ? parseFloat(body.price) : NaN
    let parsedMrp = body.mrp !== undefined ? parseFloat(body.mrp) : NaN
    let parsedCostPrice = body.costPrice !== undefined ? parseFloat(body.costPrice) : NaN

    if (!isNaN(parsedPrice)) updateData.price = parsedPrice
    if (!isNaN(parsedMrp)) updateData.mrp = parsedMrp
    if (!isNaN(parsedCostPrice)) updateData.costPrice = parsedCostPrice

    const finalPrice = typeof updateData.price === 'number' ? updateData.price : existing.price
    const finalMrp = typeof updateData.mrp === 'number' ? updateData.mrp : existing.mrp

    if (finalMrp > 0 && finalPrice >= 0) {
      updateData.discount =
        finalMrp > finalPrice
          ? Math.max(0, Math.round(((finalMrp - finalPrice) / finalMrp) * 100))
          : 0
    }

    if (body.stock !== undefined) {
      const parsedStock = parseInt(body.stock)
      if (!isNaN(parsedStock)) updateData.stock = parsedStock
    }

    const updatedProduct = await prisma.product.update({
      where: { id: existing.id },
      data: updateData,
      include: {
        category: true,
        restaurant: true,
        vendorRel: true,
      },
    })

    // Record price change history if price or MRP was modified
    if (updatedProduct.price !== existing.price || updatedProduct.mrp !== existing.mrp) {
      try {
        const vendorName = updatedProduct.vendorRel?.name || updatedProduct.vendor || updatedProduct.restaurant?.name || 'Vendor'
        const changer = userPhone || userEmail || session?.user?.name || vendorName
        await prisma.priceHistory.create({
          data: {
            productId: existing.id,
            oldPrice: existing.price,
            newPrice: updatedProduct.price,
            oldMrp: existing.mrp,
            newMrp: updatedProduct.mrp,
            changeType: role === 'ADMIN' ? 'ADMIN_UPDATE' : 'VENDOR_UPDATE',
            changedBy: `${changer} (${vendorName})`,
          },
        })
      } catch (histErr) {
        logger.warn('price-history', 'Failed to log price change in vendor prices PATCH', histErr)
      }
    }

    try {
      revalidateStorefront(updatedProduct.category?.slug, updatedProduct.restaurant?.slug)
      await invalidateProductCache()
    } catch (e) {
      logger.warn('cache', 'Cache revalidation failed in vendor product prices PATCH', e)
    }

    return NextResponse.json({
      success: true,
      product: updatedProduct,
      message: 'Rates updated successfully',
    })
  } catch (error: any) {
    logger.error('vendor-price', 'Failed to update vendor product price', error)
    return NextResponse.json(
      { error: error?.message || 'Failed to update rates' },
      { status: 500 }
    )
  }
}
