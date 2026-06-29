import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { id } = await params

    const cart = await prisma.cart.findUnique({
      where: { userId: id },
      include: {
        items: {
          include: {
            product: {
              include: {
                category: {
                  select: {
                    id: true,
                    name: true,
                    slug: true,
                  },
                },
              },
            },
          },
        },
      },
    })

    if (!cart || !cart.items) {
      return NextResponse.json({ items: [] })
    }

    const formattedItems = cart.items.map((item: any) => ({
      id: item.selectedVariant ? `${item.product.id}_${item.selectedVariant}` : item.product.id,
      productId: item.product.id,
      quantity: item.quantity,
      selectedVariant: item.selectedVariant,
      notes: item.notes,
      product: {
        id: item.product.id,
        name: item.product.name,
        slug: item.product.slug,
        price: item.product.price,
        mrp: item.product.mrp,
        stock: item.product.stock,
        imageUrl: item.product.imageUrl,
        variants: item.product.variants || [],
        category: item.product.category,
        categorySlug: item.product.category?.slug || 'groceries',
      },
    }))

    return NextResponse.json({ items: formattedItems, updatedAt: cart.updatedAt })
  } catch (error) {
    console.error('Failed to fetch user active cart:', error)
    return NextResponse.json({ error: 'Failed to fetch user cart' }, { status: 500 })
  }
}
