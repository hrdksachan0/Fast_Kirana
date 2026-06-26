import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

export async function POST(request: Request) {
  const session = await auth()
  
  if (!session?.user?.id) {
    return NextResponse.json({ success: false, error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { items } = await request.json()

    if (!items || !Array.isArray(items)) {
      return NextResponse.json({ success: false, error: 'Invalid items array' }, { status: 400 })
    }

    // 1. Upsert the Cart for the user to ensure it exists and update the updatedAt timestamp
    const cart = await prisma.cart.upsert({
      where: { userId: session.user.id },
      create: { userId: session.user.id },
      update: { updatedAt: new Date() }
    })

    // 2. Delete existing cart items
    await prisma.cartItem.deleteMany({
      where: { cartId: cart.id }
    })

    // 3. Create the new cart items if any exist
    if (items.length > 0) {
      await prisma.cartItem.createMany({
        data: items.map((item: any) => ({
          cartId: cart.id,
          productId: item.productId,
          quantity: item.quantity,
          selectedVariant: item.selectedVariant || null
        }))
      })
    }

    return NextResponse.json({ success: true, count: items.length })
  } catch (error) {
    console.error('Error syncing cart to database:', error)
    return NextResponse.json({ success: false, error: 'Failed to sync cart' }, { status: 500 })
  }
}
