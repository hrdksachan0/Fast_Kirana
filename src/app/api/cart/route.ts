import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { syncCartSchema, validateBody } from '@/lib/validation'

async function getOrCreateCart(userId: string) {
  let cart = await prisma.cart.findUnique({
    where: { userId },
  })

  if (!cart) {
    const user = await prisma.user.findUnique({ where: { id: userId } })
    if (!user) return null

    cart = await prisma.cart.create({
      data: { userId },
    })
  }

  return cart
}

async function getOrCreateGuestUser(guestId: string) {
  const cleanId = guestId.replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 32)
  if (!cleanId) return null

  const guestEmail = `guest-${cleanId}@fastkirana.com`
  let user = await prisma.user.findUnique({
    where: { email: guestEmail },
  })

  if (!user) {
    user = await prisma.user.create({
      data: {
        email: guestEmail,
        name: `Guest Shopper (${cleanId.slice(0, 6)})`,
        role: 'USER',
        phone: null,
      },
    })
  }

  return user
}

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    const guestId = request.headers.get('x-guest-id')

    let userId = session?.user?.id || request.headers.get('x-user-id')
    const headerPhone = request.headers.get('x-user-phone')

    if (!userId && headerPhone) {
      const cleanPhone = headerPhone.replace('+91', '').replaceAll(' ', '').trim()
      let dbUser = await prisma.user.findFirst({
        where: {
          OR: [
            { phone: cleanPhone },
            { phone: `+91${cleanPhone}` },
            { phone: { contains: cleanPhone } },
          ]
        }
      })
      if (!dbUser && cleanPhone.length === 10) {
        dbUser = await prisma.user.create({
          data: {
            phone: `+91${cleanPhone}`,
            name: `Customer ${cleanPhone.slice(-4)}`,
            email: `customer_${cleanPhone}@fastkirana.in`,
            role: 'USER',
          }
        })
      }
      if (dbUser) userId = dbUser.id
    }

    if (!userId && guestId) {
      const guestUser = await getOrCreateGuestUser(guestId)
      userId = guestUser?.id
    }

    if (!userId) {
      return NextResponse.json({ success: true, items: [], subtotal: 0, count: 0 })
    }

    const cart = await prisma.cart.findUnique({
      where: { userId },
      include: {
        items: {
          include: {
            product: {
              select: {
                id: true, name: true, slug: true, imageUrl: true, mrp: true,
                price: true, discount: true, unit: true, stock: true,
                isAvailable: true, tags: true, variants: true,
              },
            },
          },
        },
      },
    })

    if (!cart) {
      return NextResponse.json({ success: true, items: [], subtotal: 0, count: 0 })
    }

    let subtotal = 0
    const items = cart.items.map((item) => {
      let price = item.product.price
      if (item.selectedVariant && Array.isArray(item.product.variants)) {
        const variant = (item.product.variants as any[]).find((v: any) => v.name === item.selectedVariant)
        if (variant && typeof variant.price === 'number') {
          price = variant.price
        }
      }

      const itemTotal = price * item.quantity
      subtotal += itemTotal

      return {
        id: item.id,
        productId: item.productId,
        quantity: item.quantity,
        selectedVariant: item.selectedVariant,
        notes: item.notes,
        product: { ...item.product, price },
        itemTotal,
      }
    })

    return NextResponse.json({
      success: true,
      cartId: cart.id,
      items,
      subtotal,
      count: items.length,
      updatedAt: cart.updatedAt,
    })
  } catch (error: any) {
    console.error('Cart GET error:', error)
    return NextResponse.json({ error: 'Failed to fetch cart' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    const guestId = request.headers.get('x-guest-id')

    const validation = await validateBody(request, syncCartSchema)
    if (!validation.success) return validation.error

    const { items: itemsData } = validation.data

    let userId = session?.user?.id || request.headers.get('x-user-id')
    const headerPhone = request.headers.get('x-user-phone')

    if (!userId && headerPhone) {
      const cleanPhone = headerPhone.replace('+91', '').trim()
      const dbUser = await prisma.user.findFirst({
        where: { phone: { contains: cleanPhone } }
      })
      if (dbUser) userId = dbUser.id
    }

    if (!userId && guestId) {
      const guestUser = await getOrCreateGuestUser(guestId)
      userId = guestUser?.id
    }

    if (!userId) {
      return NextResponse.json({ error: 'User or guest session is required' }, { status: 400 })
    }

    const cart = await getOrCreateCart(userId)
    if (!cart) {
      return NextResponse.json({ error: 'Failed to find or create cart' }, { status: 500 })
    }

    await prisma.cartItem.deleteMany({
      where: { cartId: cart.id },
    })

    if (itemsData.length > 0) {
      const productIds: string[] = itemsData.map((i: any) => String(i.productId || '')).filter(Boolean)
      const validProducts = await prisma.product.findMany({
        where: { id: { in: productIds } },
        select: { id: true },
      })
      const validProductIdSet = new Set(validProducts.map((p) => p.id))

      for (const item of itemsData) {
        if (!item.productId || !validProductIdSet.has(item.productId)) continue

        await prisma.cartItem.create({
          data: {
            cartId: cart.id,
            productId: item.productId,
            quantity: Math.max(1, parseInt(item.quantity as any) || 1),
            selectedVariant: item.selectedVariant || null,
            notes: item.notes || null,
          },
        })
      }
    }

    await prisma.cart.update({
      where: { id: cart.id },
      data: { updatedAt: new Date() },
    })

    return NextResponse.json({
      success: true,
      message: 'Cart synced to database successfully',
      itemCount: itemsData.length,
    })
  } catch (error: any) {
    console.error('Cart POST sync error:', error)
    return NextResponse.json({ error: 'Failed to sync cart' }, { status: 500 })
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const session = await auth()
    const guestId = request.headers.get('x-guest-id')

    let userId = session?.user?.id
    if (!userId && guestId) {
      const guestUser = await getOrCreateGuestUser(guestId)
      userId = guestUser?.id
    }

    if (userId) {
      const cart = await prisma.cart.findUnique({ where: { userId } })
      if (cart) {
        await prisma.cartItem.deleteMany({ where: { cartId: cart.id } })
        await prisma.cart.update({
          where: { id: cart.id },
          data: { updatedAt: new Date() },
        })
      }
    }

    return NextResponse.json({ success: true, message: 'Cart cleared' })
  } catch (error: any) {
    console.error('Cart clear error:', error)
    return NextResponse.json({ error: 'Failed to clear cart' }, { status: 500 })
  }
}
