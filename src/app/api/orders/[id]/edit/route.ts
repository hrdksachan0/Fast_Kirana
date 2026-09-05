import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { sendPushNotification } from '@/lib/push-notification'
import { sseEmitter } from '@/lib/sse-emitter'
import { normalizeRestaurantId } from '@/lib/restaurant-ids'

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  const headerUserId = request.headers.get('x-user-id')
  const headerUserRole = (request.headers.get('x-user-role') || '').toUpperCase()
  const headerUserPhone = request.headers.get('x-user-phone')
  const headerUserEmail = request.headers.get('x-user-email')
  const headerRestaurantId = request.headers.get('x-restaurant-id') || request.headers.get('x-assigned-restaurant-id')

  const isSuperPhone = Boolean(headerUserPhone && (
    headerUserPhone.includes('7054470303') ||
    headerUserPhone.includes('8112849854') ||
    headerUserPhone.includes('9250138656') ||
    headerUserPhone.includes('7991488783')
  ))
  const isSuperEmail = Boolean(headerUserEmail && (headerUserEmail.startsWith('admin') || headerUserEmail.includes('hrdk')))
  const isAdminHeader = headerUserRole === 'ADMIN'

  const effectiveUserId = session?.user?.id || headerUserId || 'admin'
  let effectiveRole = (isSuperPhone || isSuperEmail || isAdminHeader)
    ? 'ADMIN'
    : ((session?.user as any)?.role || headerUserRole || 'USER')

  if (['CHEF', 'RESTAURANT_OWNER', 'PICKER', 'ADMIN'].includes(headerUserRole)) {
    effectiveRole = headerUserRole
  } else if ((headerRestaurantId || isSuperPhone) && effectiveRole === 'USER') {
    effectiveRole = 'CHEF'
  }

  // Only ADMIN, CHEF, PICKER, and RESTAURANT_OWNER can edit orders
  const allowedRoles = ['ADMIN', 'CHEF', 'PICKER', 'RESTAURANT_OWNER']
  if (!allowedRoles.includes(effectiveRole)) {
    return NextResponse.json({ error: 'Unauthorized: insufficient role' }, { status: 403 })
  }

  const assignedRestaurantId = (session?.user as any)?.assignedRestaurantId || headerRestaurantId

  try {
    const { id } = await params
    const { updatedItems, outOfStockProductIds } = await request.json()

    if (!Array.isArray(updatedItems)) {
      return NextResponse.json({ error: 'updatedItems must be an array' }, { status: 400 })
    }

    // 1. Fetch current order by id or readableId
    let order = await prisma.order.findUnique({
      where: { id },
      include: { items: true, user: true }
    })

    if (!order) {
      order = await prisma.order.findFirst({
        where: { readableId: id },
        include: { items: true, user: true }
      })
    }

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    // Restaurant staff can only edit orders for their assigned restaurant
    if ((effectiveRole === 'CHEF' || effectiveRole === 'RESTAURANT_OWNER') && effectiveRole !== 'ADMIN') {
      if (assignedRestaurantId && order.restaurantId) {
        const normAssigned = normalizeRestaurantId(assignedRestaurantId)
        const normOrderRest = normalizeRestaurantId(order.restaurantId)
        if (normAssigned && normOrderRest && normAssigned !== normOrderRest) {
          return NextResponse.json({ error: 'You can only edit orders for your assigned restaurant' }, { status: 403 })
        }
      }
    }

    // Constraint: Non-admin can only edit before PACKED / SHIPPED / DELIVERED. Admin has superpower to edit even if PACKED or CANCELLED.
    if (effectiveRole !== 'ADMIN') {
      if (order.status === 'PACKED' || order.status === 'SHIPPED' || order.status === 'DELIVERED' || order.status === 'CANCELLED') {
        return NextResponse.json({ error: `Order is already ${order.status} and cannot be edited` }, { status: 400 })
      }
    } else {
      if (order.status === 'DELIVERED') {
        return NextResponse.json({ error: `Delivered order cannot be edited` }, { status: 400 })
      }
    }

    // 2. Perform out of stock adjustments if provided
    if (Array.isArray(outOfStockProductIds) && outOfStockProductIds.length > 0) {
      for (const prodId of outOfStockProductIds) {
        await prisma.product.update({
          where: { id: prodId },
          data: { isAvailable: false, stock: 0 }
        })
      }
    }

    // 3. Revert stock of current items
    for (const item of order.items) {
      if (!item.productId) continue
      
      const product = await prisma.product.findUnique({
        where: { id: item.productId },
        select: { stock: true, name: true, variants: true, category: true, tags: true }
      })
      if (!product) continue

      // Skip kitchen items
      if (product.category?.slug === 'cafe' || product.category?.slug === 'restaurant' || product.tags?.includes('cafe') || product.tags?.includes('restaurant')) {
        continue
      }

      if (item.selectedVariant) {
        if (product.variants && Array.isArray(product.variants)) {
          const updatedVariants = (product.variants as any[]).map((v) => {
            if (v.name === item.selectedVariant) {
              return { ...v, stock: v.stock + item.quantity }
            }
            return v
          })
          const newTotalStock = updatedVariants.reduce((sum, v) => sum + v.stock, 0)
          await prisma.product.update({
            where: { id: item.productId },
            data: { variants: updatedVariants, stock: newTotalStock }
          })
        }
      } else {
        const batches = await prisma.productBatch.findMany({
          where: { productId: item.productId },
          orderBy: { expiryDate: 'asc' }
        })
        if (batches.length > 0) {
          await prisma.productBatch.update({
            where: { id: batches[0].id },
            data: { quantity: { increment: item.quantity } }
          })
          const activeBatches = await prisma.productBatch.findMany({
            where: { productId: item.productId, quantity: { gt: 0 } }
          })
          const newTotalStock = activeBatches.reduce((sum, b) => sum + b.quantity, 0)
          await prisma.product.update({
            where: { id: item.productId },
            data: { stock: newTotalStock }
          })
        } else {
          await prisma.product.update({
            where: { id: item.productId },
            data: { stock: { increment: item.quantity } }
          })
        }
      }
    }

    // 4. Delete old OrderItems
    await prisma.orderItem.deleteMany({
      where: { orderId: order.id }
    })

    // 5. Create new OrderItems and deduct stock (Supports both catalog products and custom items)
    let subtotalVal = 0
    let hasRestaurantItems = false
    let hasGroceryItems = false
    let detectedRestaurantId: string | null = null
    let detectedShopName: string | null = null
    let detectedShopPhone: string | null = null

    for (const item of updatedItems) {
      if (!item || item.quantity <= 0) continue // Skip removed items
      
      let product = null
      if (item.productId && typeof item.productId === 'string' && !item.productId.startsWith('custom_')) {
        product = await prisma.product.findUnique({
          where: { id: item.productId },
          include: { category: true, restaurant: true }
        })
      }

      const itemPrice = (item.price !== undefined && item.price !== null)
        ? parseFloat(String(item.price))
        : (product?.price ?? 0)
      const itemName = item.name || product?.name || 'Item'
      const itemQty = parseInt(String(item.quantity ?? 1), 10) || 1

      subtotalVal += itemPrice * itemQty

      await prisma.orderItem.create({
        data: {
          orderId: order.id,
          productId: product?.id || null,
          name: itemName,
          price: itemPrice,
          quantity: itemQty,
          selectedVariant: item.selectedVariant || null,
          imageUrl: item.imageUrl || product?.imageUrl || null,
          notes: item.notes || null,
          costPrice: product?.costPrice || 0
        }
      })

      if (product) {
        const isRestaurantItem = Boolean(
          product.restaurantId ||
          product.restaurant?.id ||
          product.category?.slug === 'cafe' ||
          product.category?.slug === 'restaurant' ||
          product.category?.slug === 'restaurant-food' ||
          product.tags?.some(t => ['restaurant', 'cafe', 'cooked', 'dish', 'wedson', 'as-restaurant', 'bal-udyan'].includes(t.toLowerCase()))
        )

        if (isRestaurantItem) {
          hasRestaurantItems = true
          if (!detectedRestaurantId) {
            detectedRestaurantId = product.restaurantId || product.restaurant?.id || null
            detectedShopName = product.restaurant?.name || null
            detectedShopPhone = product.restaurant?.ownerPhone || (product.restaurant as any)?.phone || null
          }
        } else {
          hasGroceryItems = true
        }

        // Skip kitchen items for stock deduction
        if (isRestaurantItem) {
          continue
        }

        // Deduct stock for grocery items
        if (item.selectedVariant) {
          if (product.variants && Array.isArray(product.variants)) {
            const updatedVariants = (product.variants as any[]).map((v) => {
              if (v.name === item.selectedVariant) {
                return { ...v, stock: Math.max(0, v.stock - itemQty) }
              }
              return v
            })
            const newTotalStock = updatedVariants.reduce((sum, v) => sum + v.stock, 0)
            await prisma.product.update({
              where: { id: product.id },
              data: { variants: updatedVariants, stock: newTotalStock }
            })
          }
        } else {
          await prisma.product.update({
            where: { id: product.id },
            data: { stock: { decrement: itemQty } }
          })
        }
      } else {
        // Custom items default to grocery unless specified
        hasGroceryItems = true
      }
    }

    // Dynamic order type, restaurant, and shop routing based on edited items
    let dynamicOrderType = order.orderType
    let dynamicRestaurantId = order.restaurantId
    let dynamicShopName = order.shopName
    let dynamicShopPhone = order.shopPhone

    if (!hasRestaurantItems) {
      // 100% Grocery items now -> move order from Restaurant to Picker!
      dynamicOrderType = 'GROCERY'
      dynamicRestaurantId = null
      dynamicShopName = 'FastKirana Grocery'
      dynamicShopPhone = null
    } else {
      // Order has restaurant items -> assign to restaurant kitchen
      dynamicOrderType = 'RESTAURANT'
      dynamicRestaurantId = normalizeRestaurantId(detectedRestaurantId || order.restaurantId)
      dynamicShopName = detectedShopName || order.shopName || 'Restaurant'
      if (detectedShopPhone) dynamicShopPhone = detectedShopPhone
    }

    // 6. Recalculate Order totals
    const settings = await prisma.storeSetting.findMany()
    const settingsMap = settings.reduce((acc, s) => {
      acc[s.key] = s.value
      return acc
    }, {} as Record<string, string>)

    const taxPercent = parseFloat(settingsMap['tax_rate'] || '0')
    const deliveryFeeSetting = parseFloat(settingsMap['delivery_fee'] || '25')
    const miscFeeSetting = parseFloat(settingsMap['misc_fee'] || '5')
    
    let threshold = 200
    if (dynamicOrderType === 'RESTAURANT' || dynamicShopName?.includes('Cafe') || dynamicShopName?.includes('Restaurant')) {
      threshold = parseFloat(settingsMap['cafe_free_delivery_threshold'] || '200')
    } else {
      threshold = parseFloat(settingsMap['grocery_free_delivery_threshold'] || '200')
    }

    let calculatedDeliveryFee = 0
    let calculatedMiscFee = 0

    if (order.deliveryMethod === 'DELIVERY') {
      calculatedDeliveryFee = subtotalVal < threshold ? deliveryFeeSetting : 0
      
      let companionHasMisc = false
      if (order.combinedId) {
        const companion = await prisma.order.findFirst({
          where: {
            combinedId: order.combinedId,
            id: { not: order.id }
          }
        })
        if (companion && companion.miscFee > 0) {
          companionHasMisc = true
        }
      } else {
        const companion = await prisma.order.findFirst({
          where: {
            userId: order.userId,
            id: { not: order.id },
            createdAt: {
              gte: new Date(new Date(order.createdAt).getTime() - 5000),
              lte: new Date(new Date(order.createdAt).getTime() + 5000),
            }
          }
        })
        if (companion && companion.miscFee > 0) {
          companionHasMisc = true
        }
      }
      calculatedMiscFee = companionHasMisc ? 0 : miscFeeSetting
    }

    const taxesVal = 0.00
    const totalVal = subtotalVal + calculatedDeliveryFee + taxesVal + calculatedMiscFee - order.discount

    await prisma.order.update({
      where: { id: order.id },
      data: {
        subtotal: subtotalVal,
        deliveryFee: calculatedDeliveryFee,
        miscFee: calculatedMiscFee,
        taxes: taxesVal,
        total: totalVal,
        orderType: dynamicOrderType,
        restaurantId: dynamicRestaurantId,
        shopName: dynamicShopName,
        shopPhone: dynamicShopPhone,
        ...(dynamicOrderType === 'GROCERY' ? { assignedChefId: null } : { assignedPickerId: null })
      }
    })

    // 7. Send Push Notification if items were marked out of stock
    if (Array.isArray(outOfStockProductIds) && outOfStockProductIds.length > 0) {
      try {
        const outOfStockProducts = await prisma.product.findMany({
          where: { id: { in: outOfStockProductIds } },
          select: { name: true }
        })
        const names = outOfStockProducts.map(p => p.name).join(', ')
        
        const origin = request.headers.get('origin') || 'https://fastkirana.com'
        sendPushNotification(order.userId, {
          title: 'Order Items Modified ⚠️',
          body: `Due to unavailability, "${names}" has been removed from order #${(order.readableId || order.id).slice(-6).toUpperCase()}. Your bill total has been adjusted.`,
          icon: `${origin}/icons/icon-192.png`,
          badge: `${origin}/icons/icon-192.png`,
          tag: `order-${order.id}`,
          renotify: true,
          data: { orderId: order.id }
        }).catch(err => console.error('Push notification error:', err))
      } catch (notifyErr) {
        console.error('Failed to send out of stock notification:', notifyErr)
      }
    }

    // 8. Broadcast update to SSE clients
    sseEmitter.emit('message', {
      type: 'order-edited',
      orderId: order.id,
      shopName: dynamicShopName,
      restaurantId: dynamicRestaurantId,
      orderType: dynamicOrderType
    })

    return NextResponse.json({
      success: true,
      total: totalVal,
      orderType: dynamicOrderType,
      restaurantId: dynamicRestaurantId,
      shopName: dynamicShopName
    })
  } catch (err: any) {
    console.error('Order edit API error:', err)
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 })
  }
}
