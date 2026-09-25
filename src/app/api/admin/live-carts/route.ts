import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'
import { getStoreUserFilter } from '@/lib/store-resolver'

export async function GET(request: Request) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const { searchParams } = new URL(request.url)
    const storeId = searchParams.get('storeId') || (session?.user as any)?.assignedStoreId || null

    // 1. Try FastAPI backend on Railway first
    const fastApiUrl = (
      process.env.NEXT_PUBLIC_FASTAPI_URL ||
      process.env.NEXT_PUBLIC_API_URL ||
      'https://fastkiran-backend-production.up.railway.app'
    ).replace(/\/+$/, '')

    const token =
      (session as any)?.fastapiToken ||
      request.headers.get('authorization')?.replace('Bearer ', '') ||
      ''

    const query = storeId ? `?storeId=${encodeURIComponent(storeId)}` : ''

    const incomingIfNoneMatch = request.headers.get('if-none-match') || ''

    try {
      const headers: Record<string, string> = {
        Authorization: token ? `Bearer ${token}` : '',
        'x-user-role': session?.user?.role || 'ADMIN',
        'x-user-phone': (session?.user as any)?.phone || '',
        'x-user-email': session?.user?.email || '',
        'x-user-id': session?.user?.id || '',
        'Content-Type': 'application/json',
      }
      if (incomingIfNoneMatch) {
        headers['if-none-match'] = incomingIfNoneMatch
      }

      const fastRes = await fetch(`${fastApiUrl}/api/admin/live-carts${query}`, {
        headers,
        cache: 'no-store',
      })
      if (fastRes.status === 304) {
        return new NextResponse(null, { status: 304 })
      }
      if (fastRes.ok) {
        const data = await fastRes.json()
        const resHeaders: Record<string, string> = {}
        const etag = fastRes.headers.get('etag')
        if (etag) resHeaders['ETag'] = etag
        return NextResponse.json(data, { headers: resHeaders })
      }
    } catch (fastErr) {
      console.warn('[LiveCartsProxy] FastAPI fetch failed, falling back to local DB:', fastErr)
    }

    // 2. Fallback to direct DB query if FastAPI is unreachable
    const whereClause: any = {
      items: {
        some: {} // has at least one item
      },
      updatedAt: {
        gte: new Date(Date.now() - 24 * 60 * 60 * 1000) // past 24 hours
      }
    }

    if (storeId && storeId !== 'all') {
      whereClause.user = await getStoreUserFilter(storeId)
    }

    // Fetch active carts that have at least one item, updated in the past 12 hours
    const carts = await prisma.cart.findMany({
      where: whereClause,
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
