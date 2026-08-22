import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'
import { revalidateStorefront } from '@/lib/revalidate'

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
  const role = session?.user?.role
  const assignedRestaurantId = (session?.user as any)?.assignedRestaurantId
  if (!session || (role !== 'ADMIN' && role !== 'CHEF' && role !== 'RESTAURANT_OWNER')) {
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

    // Restaurant staff can only edit products belonging to their restaurant
    if ((role === 'CHEF' || role === 'RESTAURANT_OWNER') && role !== 'ADMIN') {
      if (!assignedRestaurantId || product.restaurantId !== assignedRestaurantId) {
        return NextResponse.json({ error: 'You can only edit products for your assigned restaurant' }, { status: 403 })
      }
    }

    const { name, description, imageUrl, categoryId, restaurantId, mrp, price, unit, stock, isAvailable, tags, minStock, expiryDate, costPrice, variants, location, isFlashDeal, isTopPick, isBestSeller, sortOrder, barcode } = body

    const updateData: any = {}
    if (name !== undefined && typeof name === 'string') updateData.name = name.trim()
    if (description !== undefined) updateData.description = description
    if (imageUrl !== undefined) updateData.imageUrl = imageUrl
    if (categoryId !== undefined && categoryId !== '') {
      updateData.categoryId = categoryId
    }
    if (restaurantId !== undefined) updateData.restaurantId = restaurantId || null
    if (unit !== undefined) updateData.unit = (unit && typeof unit === 'string') ? unit.trim() : ''
    
    if (stock !== undefined) {
      const parsedStock = parseInt(stock)
      updateData.stock = isNaN(parsedStock) ? product.stock : parsedStock
    }
    if (isAvailable !== undefined) updateData.isAvailable = !!isAvailable
    if (tags !== undefined) updateData.tags = Array.isArray(tags) ? tags : []
    
    if (minStock !== undefined) {
      const parsedMinStock = parseInt(minStock)
      updateData.minStock = isNaN(parsedMinStock) ? product.minStock : parsedMinStock
    }
    
    if (expiryDate !== undefined) {
      if (!expiryDate) {
        updateData.expiryDate = null
      } else {
        const time = Date.parse(expiryDate)
        updateData.expiryDate = !isNaN(time) ? new Date(time) : product.expiryDate
      }
    }
    
    if (costPrice !== undefined) {
      const parsedCostPrice = parseFloat(costPrice)
      updateData.costPrice = isNaN(parsedCostPrice) ? product.costPrice : parsedCostPrice
    }
    
    if (location !== undefined) updateData.location = location || null
    if (isFlashDeal !== undefined) updateData.isFlashDeal = !!isFlashDeal
    if (isTopPick !== undefined) updateData.isTopPick = !!isTopPick
    if (isBestSeller !== undefined) updateData.isBestSeller = !!isBestSeller
    
    if (sortOrder !== undefined) {
      const parsedSortOrder = parseInt(sortOrder)
      updateData.sortOrder = isNaN(parsedSortOrder) ? 0 : parsedSortOrder
    }
    
    if (barcode !== undefined) updateData.barcode = (barcode && typeof barcode === 'string') ? barcode.trim() : null

    let parsedMrp = mrp !== undefined ? parseFloat(mrp) : NaN
    let parsedPrice = price !== undefined ? parseFloat(price) : NaN
    let finalMrp = !isNaN(parsedMrp) ? parsedMrp : product.mrp
    let finalPrice = !isNaN(parsedPrice) ? parsedPrice : product.price
    let sortedVariants = variants

    if (variants && Array.isArray(variants) && variants.length > 0) {
      sortedVariants = [...variants].sort((a: any, b: any) => (parseFloat(a.price) || 0) - (parseFloat(b.price) || 0))
      finalPrice = parseFloat(sortedVariants[0].price) || 0
      finalMrp = parseFloat(sortedVariants[0].mrp) || finalPrice
      updateData.variants = sortedVariants
      updateData.price = finalPrice
      updateData.mrp = finalMrp
    } else if (variants !== undefined) {
      updateData.variants = variants
    }

    if (mrp !== undefined && (!variants || !Array.isArray(variants) || variants.length === 0)) {
      if (!isNaN(parsedMrp)) updateData.mrp = parsedMrp
    }
    if (price !== undefined && (!variants || !Array.isArray(variants) || variants.length === 0)) {
      if (!isNaN(parsedPrice)) updateData.price = parsedPrice
    }

    updateData.discount = finalMrp > finalPrice
      ? Math.max(0, Math.round(((finalMrp - finalPrice) / finalMrp) * 100))
      : 0

    // ── Restaurant product hardening ──
    const effectiveRestaurantId = updateData.restaurantId !== undefined
      ? updateData.restaurantId
      : product.restaurantId

    if (effectiveRestaurantId) {
      // Ensure 'restaurant' tag and remove 'cafe' tag
      let currentTags: string[] = updateData.tags || product.tags || []
      if (!currentTags.map((t: string) => t.toLowerCase()).includes('restaurant')) {
        currentTags = [...currentTags, 'restaurant']
      }
      currentTags = currentTags.filter((t: string) => t.toLowerCase() !== 'cafe')
      updateData.tags = currentTags
    }

    // Ensure categoryId is valid and not empty
    if (!updateData.categoryId) {
      updateData.categoryId = product.categoryId
    }

    const updatedProduct = await prisma.product.update({
      where: { id: product.id },
      data: updateData,
      include: {
        category: true,
      },
    })

    // Invalidate storefront cache
    revalidateStorefront(updatedProduct.category?.slug)

    return NextResponse.json(updatedProduct)
  } catch (error: any) {
    console.error('Failed to update product:', error)
    return NextResponse.json({ error: error.message || 'Failed to update product' }, { status: 500 })
  }
}

export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

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
      },
    })

    if (!product) {
      return NextResponse.json({ error: 'Product not found' }, { status: 404 })
    }

    // Disconnect order items so order history is preserved (name, price, qty stay intact)
    await prisma.orderItem.updateMany({
      where: { productId: product.id },
      data: { productId: null as any },
    })

    // Delete related product images
    await prisma.productImage.deleteMany({
      where: { productId: product.id },
    })

    // Delete related reviews
    await prisma.review.deleteMany({
      where: { productId: product.id },
    })

    // Delete related cart items if any
    try {
      await prisma.cartItem.deleteMany({
        where: { productId: product.id },
      })
    } catch (e) {
      // CartItem model may not exist, ignore
    }

    // Permanently delete the product
    await prisma.product.delete({
      where: { id: product.id },
    })

    // Invalidate storefront cache
    revalidateStorefront(product.category?.slug)

    return NextResponse.json({ message: 'Product permanently deleted' })
  } catch (error: any) {
    console.error('Failed to delete product:', error)
    return NextResponse.json({ error: 'Failed to delete product' }, { status: 500 })
  }
}
