import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params

    const product = await prisma.product.findFirst({
      where: {
        OR: [
          { id },
          { slug: id },
        ],
      },
      include: {
        category: true,
        images: true,
        reviews: {
          include: {
            user: {
              select: {
                name: true,
                image: true,
              },
            },
          },
          orderBy: {
            createdAt: 'desc',
          },
        },
      },
    })

    if (!product) {
      return NextResponse.json({ error: 'Product not found' }, { status: 404 })
    }

    return NextResponse.json(product)
  } catch (error: any) {
    console.error('Product API Error:', error)
    return NextResponse.json({ error: 'Failed to fetch product' }, { status: 500 })
  }
}

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { id } = await params
    const body = await request.json()

    // Find the product first
    const product = await prisma.product.findFirst({
      where: {
        OR: [
          { id },
          { slug: id },
        ],
      },
    })

    if (!product) {
      return NextResponse.json({ error: 'Product not found' }, { status: 404 })
    }

    const { name, description, imageUrl, categoryId, mrp, price, unit, stock, isAvailable, tags, minStock, expiryDate, costPrice } = body

    const updateData: any = {}
    if (name !== undefined) updateData.name = name
    if (description !== undefined) updateData.description = description
    if (imageUrl !== undefined) updateData.imageUrl = imageUrl
    if (categoryId !== undefined) updateData.categoryId = categoryId
    if (unit !== undefined) updateData.unit = unit
    if (stock !== undefined) updateData.stock = parseInt(stock)
    if (isAvailable !== undefined) updateData.isAvailable = !!isAvailable
    if (tags !== undefined) updateData.tags = Array.isArray(tags) ? tags : []
    if (minStock !== undefined) updateData.minStock = parseInt(minStock)
    if (expiryDate !== undefined) updateData.expiryDate = expiryDate ? new Date(expiryDate) : null
    if (costPrice !== undefined) updateData.costPrice = parseFloat(costPrice)

    const finalMrp = mrp !== undefined ? parseFloat(mrp) : product.mrp
    const finalPrice = price !== undefined ? parseFloat(price) : product.price

    if (mrp !== undefined) updateData.mrp = parseFloat(mrp)
    if (price !== undefined) updateData.price = parseFloat(price)

    if (mrp !== undefined || price !== undefined) {
      updateData.discount = finalMrp > finalPrice
        ? Math.max(0, Math.round(((finalMrp - finalPrice) / finalMrp) * 100))
        : 0
    }

    const updatedProduct = await prisma.product.update({
      where: { id: product.id },
      data: updateData,
      include: {
        category: true,
      },
    })

    return NextResponse.json(updatedProduct)
  } catch (error: any) {
    console.error('Failed to update product:', error)
    return NextResponse.json({ error: 'Failed to update product' }, { status: 500 })
  }
}

export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { id } = await params

    const product = await prisma.product.findFirst({
      where: {
        OR: [
          { id },
          { slug: id },
        ],
      },
    })

    if (!product) {
      return NextResponse.json({ error: 'Product not found' }, { status: 404 })
    }

    // Check if product is in any order items
    const orderItemCount = await prisma.orderItem.count({
      where: { productId: product.id },
    })

    if (orderItemCount > 0) {
      // Soft delete by making it unavailable
      const updated = await prisma.product.update({
        where: { id: product.id },
        data: { isAvailable: false },
      })
      return NextResponse.json({
        message: 'Product is associated with existing orders. Soft deleted by disabling it.',
        product: updated,
      })
    }

    await prisma.product.delete({
      where: { id: product.id },
    })

    return NextResponse.json({ message: 'Product deleted successfully' })
  } catch (error: any) {
    console.error('Failed to delete product:', error)
    return NextResponse.json({ error: 'Failed to delete product' }, { status: 500 })
  }
}
