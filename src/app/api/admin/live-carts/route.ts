import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'

export async function GET(request: Request) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    // Fetch all active carts that have at least one item
    const carts = await prisma.cart.findMany({
      where: {
        items: {
          some: {} // has at least one item
        }
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            phone: true,
            addresses: {
              select: {
                id: true,
                label: true,
                houseNo: true,
                street: true,
                area: true,
                city: true,
                pincode: true,
                lat: true,
                lng: true,
                isDefault: true
              }
            }
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

      const userAddresses = cart.user?.addresses || []
      const defaultAddress = userAddresses.find((a: any) => a.isDefault) || userAddresses[0] || null

      let formattedName = 'Guest Shopper'
      if (cart.user?.name) {
        formattedName = cart.user.name.includes('Guest') ? cart.user.name : cart.user.name
      } else {
        formattedName = `Guest Shopper (${cart.id.slice(-6)})`
      }

      return {
        id: cart.id,
        userId: cart.userId,
        userName: formattedName,
        userEmail: cart.user?.email || 'guest@fastkirana.in',
        userPhone: cart.user?.phone || 'Guest Shopper',
        updatedAt: cart.updatedAt,
        items,
        subtotal,
        address: defaultAddress ? `${defaultAddress.houseNo || ''}, ${defaultAddress.street || ''}, ${defaultAddress.area || ''}, ${defaultAddress.city || ''} - ${defaultAddress.pincode || ''}` : 'Location Pending (Browsing In-App Cart)',
        lat: defaultAddress ? defaultAddress.lat : null,
        lng: defaultAddress ? defaultAddress.lng : null
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
