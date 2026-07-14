import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

export async function GET() {
  const session = await auth()
  
  if (!session?.user?.id) {
    return NextResponse.json({ success: false, error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const cart = await prisma.cart.findUnique({
      where: { userId: session.user.id },
      include: {
        items: {
          include: {
            product: {
              include: {
                category: true
              }
            }
          }
        }
      }
    })

    if (!cart || !cart.items) {
      return NextResponse.json({ success: true, items: [] })
    }

    const mappedItems = cart.items.map((item) => {
      const prod = item.product
      
      let price = prod.price
      let mrp = prod.mrp
      let stock = prod.stock
      let unit = prod.unit
      let name = prod.name
      let discount = prod.discount

      if (item.selectedVariant && prod.variants) {
        try {
          const variants = typeof prod.variants === 'string'
            ? JSON.parse(prod.variants)
            : prod.variants
          
          if (Array.isArray(variants)) {
            const foundVariant = variants.find((v: any) => v.name === item.selectedVariant)
            if (foundVariant) {
              price = foundVariant.price ?? prod.price
              mrp = foundVariant.mrp ?? prod.mrp
              stock = foundVariant.stock ?? prod.stock
              unit = foundVariant.name ?? item.selectedVariant
              name = `${prod.name} (${item.selectedVariant})`
              discount = mrp > price ? Math.max(0, Math.round(((mrp - price) / mrp) * 100)) : 0
            }
          }
        } catch (e) {
          console.error('Failed to parse product variants in GET /api/cart:', e)
        }
      }

      const clientProductId = item.selectedVariant 
        ? `${prod.id}_${item.selectedVariant}` 
        : prod.id

      return {
        product: {
          id: clientProductId,
          name,
          slug: prod.slug,
          imageUrl: prod.imageUrl,
          mrp,
          price,
          discount,
          unit,
          stock,
          isAvailable: prod.isAvailable,
          category: prod.category ? {
            id: prod.category.id,
            name: prod.category.name,
            slug: prod.category.slug,
            imageUrl: prod.category.imageUrl || null,
            parentId: prod.category.parentId || null,
            sortOrder: prod.category.sortOrder || 0
          } : null,
          tags: prod.tags || []
        },
        quantity: item.quantity,
        notes: item.notes || undefined
      }
    })

    return NextResponse.json({ success: true, items: mappedItems })
  } catch (error) {
    console.error('Error fetching cart from database:', error)
    return NextResponse.json({ success: false, error: 'Failed to fetch cart' }, { status: 500 })
  }
}

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
