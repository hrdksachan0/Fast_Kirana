import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(request: Request) {
  try {
    const session = await auth()
    if (!session?.user || (session.user as any).role !== 'ADMIN') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Fetch active carts that have at least one item, updated in the last 12 hours
    const carts = await prisma.cart.findMany({
      where: {
        items: {
          some: {} // has at least one item
        },
        updatedAt: {
          gte: new Date(Date.now() - 12 * 60 * 60 * 1000) // last 12 hours
        }
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            phone: true,
          }
        },
        items: {
          include: {
            product: {
              select: {
                id: true,
                name: true,
                price: true,
                unit: true,
                imageUrl: true,
                variants: true,
              }
            }
          }
        }
      },
      orderBy: {
        updatedAt: 'desc'
      }
    })

    // Process carts to calculate subtotal and format items
    const processedCarts = carts.map(cart => {
      let subtotal = 0
      const items = cart.items.map(item => {
        let itemPrice = item.product.price
        
        // If a variant is selected, find its price
        if (item.selectedVariant && item.product.variants && Array.isArray(item.product.variants)) {
          const variant = (item.product.variants as any[]).find(v => v.name === item.selectedVariant)
          if (variant) {
            itemPrice = variant.price
          }
        }
        
        const itemTotal = itemPrice * item.quantity
        subtotal += itemTotal

        return {
          id: item.id,
          productId: item.productId,
          productName: item.product.name,
          imageUrl: item.product.imageUrl,
          unit: item.product.unit,
          price: itemPrice,
          quantity: item.quantity,
          selectedVariant: item.selectedVariant,
          total: itemTotal
        }
      })

      return {
        id: cart.id,
        userId: cart.userId,
        userName: cart.user.name || 'Customer',
        userEmail: cart.user.email,
        userPhone: cart.user.phone || 'N/A',
        updatedAt: cart.updatedAt,
        items,
        subtotal
      }
    })

    return NextResponse.json({
      success: true,
      carts: processedCarts,
      count: processedCarts.length
    })
  } catch (error: any) {
    console.error('Failed to fetch live carts:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
