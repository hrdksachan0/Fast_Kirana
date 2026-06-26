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
      // Merge duplicate items (same product & variant) to prevent unique constraint violations
      const mergedItemsMap = new Map<string, any>()
      for (const item of items) {
        const key = `${item.productId}_${item.selectedVariant || ''}`
        if (mergedItemsMap.has(key)) {
          const existing = mergedItemsMap.get(key)
          existing.quantity += item.quantity
          // Concatenate cooking notes if both have notes
          if (item.notes) {
            existing.notes = existing.notes ? `${existing.notes}; ${item.notes}` : item.notes
          }
        } else {
          mergedItemsMap.set(key, {
            cartId: cart.id,
            productId: item.productId,
            quantity: item.quantity,
            selectedVariant: item.selectedVariant || null,
            notes: item.notes || null
          })
        }
      }

      await prisma.cartItem.createMany({
        data: Array.from(mergedItemsMap.values())
      })
    }

    return NextResponse.json({ success: true, count: items.length })
  } catch (error) {
    console.error('Error syncing cart to database:', error)
    return NextResponse.json({ success: false, error: 'Failed to sync cart' }, { status: 500 })
  }
}
