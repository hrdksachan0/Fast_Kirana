import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'

export const dynamic = 'force-dynamic'

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const product = await prisma.product.findFirst({
      where: {
        OR: [{ id }, { slug: id }]
      },
      include: {
        category: true,
        restaurant: true,
      }
    })

    if (!product) {
      return NextResponse.json({ error: 'Dish not found' }, { status: 404 })
    }

    return NextResponse.json({ product })
  } catch (err: any) {
    return NextResponse.json({ error: err.message || 'Error fetching dish' }, { status: 500 })
  }
}

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized: Please log in' }, { status: 401 })
    }

    const { id } = await params
    const product = await prisma.product.findFirst({
      where: {
        OR: [{ id }, { slug: id }]
      },
      include: {
        restaurant: true
      }
    })

    if (!product) {
      return NextResponse.json({ error: 'Dish not found' }, { status: 404 })
    }

    const userRole = (session.user.role || '').toUpperCase()
    const isAdmin = userRole === 'ADMIN' || userRole === 'SUPER_ADMIN'
    const userAssignedRestId = (session.user as any)?.assignedRestaurantId || null

    if (!isAdmin && product.restaurantId) {
      if (userAssignedRestId !== product.restaurantId) {
        return NextResponse.json({ error: 'Access denied: You do not manage this restaurant' }, { status: 403 })
      }
    }

    const body = await request.json()
    const updateData: any = {}

    if (body.name !== undefined) updateData.name = String(body.name).trim()
    if (body.description !== undefined) updateData.description = body.description ? String(body.description).trim() : null
    if (body.imageUrl !== undefined) updateData.imageUrl = body.imageUrl ? String(body.imageUrl).trim() : null
    if (body.unit !== undefined) updateData.unit = body.unit ? String(body.unit).trim() : product.unit

    if (body.isAvailable !== undefined) updateData.isAvailable = !!body.isAvailable
    if (body.stock !== undefined) {
      const parsedStock = parseInt(String(body.stock), 10)
      updateData.stock = isNaN(parsedStock) ? product.stock : parsedStock
    }

    let parsedPrice = body.price !== undefined ? parseFloat(String(body.price)) : product.price
    let parsedMrp = body.mrp !== undefined ? parseFloat(String(body.mrp)) : product.mrp
    if (parsedMrp < parsedPrice) parsedMrp = parsedPrice

    if (body.price !== undefined) updateData.price = parsedPrice
    if (body.mrp !== undefined) updateData.mrp = parsedMrp

    if (body.price !== undefined || body.mrp !== undefined) {
      updateData.discount = parsedMrp > parsedPrice ? Math.max(0, Math.round(((parsedMrp - parsedPrice) / parsedMrp) * 100)) : 0
    }

    if (body.tags !== undefined && Array.isArray(body.tags)) {
      updateData.tags = body.tags.map((t: any) => String(t).trim()).filter(Boolean)
    }

    if (body.variants !== undefined) {
      updateData.variants = body.variants && typeof body.variants === 'object' ? body.variants : null
    }

    const updated = await prisma.product.update({
      where: { id: product.id },
      data: updateData,
      include: {
        category: true,
        restaurant: true
      }
    })

    // Sync storeInventory
    if (product.restaurant?.storeId) {
      try {
        await prisma.storeInventory.upsert({
          where: {
            productId_storeId: {
              productId: product.id,
              storeId: product.restaurant.storeId
            }
          },
          create: {
            productId: product.id,
            storeId: product.restaurant.storeId,
            stock: updated.stock,
            isAvailable: updated.isAvailable,
          },
          update: {
            stock: updated.stock,
            isAvailable: updated.isAvailable,
          }
        })
      } catch (invErr) {
        console.warn('Could not update storeInventory in PATCH:', invErr)
      }
    }

    if (product.restaurant?.slug) {
      revalidateStorefront(product.restaurant.slug)
    }

    return NextResponse.json({
      success: true,
      message: 'Dish updated successfully',
      product: {
        id: updated.id,
        name: updated.name,
        slug: updated.slug,
        price: Number(updated.price),
        mrp: Number(updated.mrp),
        discount: Number(updated.discount),
        stock: updated.stock,
        isAvailable: updated.isAvailable,
        restaurantId: updated.restaurantId,
        imageUrl: updated.imageUrl,
        tags: updated.tags,
      }
    })
  } catch (err: any) {
    console.error('Error in PATCH /api/restaurant-dashboard/products/[id]:', err)
    return NextResponse.json({ error: err.message || 'Failed to update dish' }, { status: 500 })
  }
}

export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized: Please log in' }, { status: 401 })
    }

    const { id } = await params
    const product = await prisma.product.findFirst({
      where: {
        OR: [{ id }, { slug: id }]
      },
      include: {
        restaurant: true
      }
    })

    if (!product) {
      return NextResponse.json({ error: 'Dish not found' }, { status: 404 })
    }

    const userRole = (session.user.role || '').toUpperCase()
    const isAdmin = userRole === 'ADMIN' || userRole === 'SUPER_ADMIN'
    const userAssignedRestId = (session.user as any)?.assignedRestaurantId || null

    if (!isAdmin && product.restaurantId) {
      if (userAssignedRestId !== product.restaurantId) {
        return NextResponse.json({ error: 'Access denied: You do not manage this restaurant' }, { status: 403 })
      }
    }

    // 1. Decouple past order history to preserve customer order receipts
    try {
      await prisma.orderItem.updateMany({
        where: { productId: product.id },
        data: { productId: null as any }
      })
    } catch (ordErr) {
      console.warn('Could not decouple order items on delete:', ordErr)
    }

    // 2. Remove auxiliary dependent rows
    try {
      await Promise.all([
        prisma.cartItem.deleteMany({ where: { productId: product.id } }),
        prisma.review.deleteMany({ where: { productId: product.id } }),
        prisma.storeInventory.deleteMany({ where: { productId: product.id } }),
        prisma.productImage.deleteMany({ where: { productId: product.id } }),
      ])
    } catch (auxErr) {
      console.warn('Error cleaning auxiliary relations on delete:', auxErr)
    }

    // 3. Delete the dish permanently
    await prisma.product.delete({
      where: { id: product.id }
    })

    if (product.restaurant?.slug) {
      revalidateStorefront(product.restaurant.slug)
    }

    return NextResponse.json({
      success: true,
      message: `Dish "${product.name}" deleted successfully from menu`
    })
  } catch (err: any) {
    console.error('Error in DELETE /api/restaurant-dashboard/products/[id]:', err)
    return NextResponse.json({ error: err.message || 'Failed to delete dish' }, { status: 500 })
  }
}
