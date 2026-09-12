import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { sendPushNotification } from '@/lib/push-notification'
import { sseEmitter } from '@/lib/sse-emitter'
import { normalizeRestaurantId } from '@/lib/restaurant-ids'
import { requireRole } from '@/lib/auth-guard'
import { COMBINED_FREE_DELIVERY_THRESHOLD } from '@/lib/constants'

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { error: authError, session: authSession } = await requireRole(
    ['ADMIN', 'CHEF', 'PICKER', 'RESTAURANT_OWNER'],
    request
  )

  let effectiveUserId: string = authSession?.user?.id || ''
  let effectiveRole: string = authSession?.user?.role?.toUpperCase() || ''
  let assignedRestaurantId: string | null = (authSession?.user as any)?.assignedRestaurantId || null

  // Fallback for Flutter clients passing x-user-id: verify user in database and read REAL role
  if (!effectiveRole || effectiveRole === 'USER') {
    const headerUserId = request.headers.get('x-user-id')
    if (headerUserId && !headerUserId.startsWith('mock-id-')) {
      const dbUser = await prisma.user.findUnique({
        where: { id: headerUserId },
        select: { id: true, role: true, assignedRestaurantId: true, isBlocked: true }
      })
      if (dbUser && !dbUser.isBlocked) {
        effectiveUserId = dbUser.id
        effectiveRole = dbUser.role
        assignedRestaurantId = dbUser.assignedRestaurantId
      }
    }
  }

  // Only ADMIN, CHEF, PICKER, and RESTAURANT_OWNER can edit orders
  const allowedRoles = ['ADMIN', 'CHEF', 'PICKER', 'RESTAURANT_OWNER']
  if (!allowedRoles.includes(effectiveRole)) {
    return NextResponse.json({ error: 'Unauthorized: insufficient role' }, { status: 403 })
  }

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
    if (effectiveRole === 'CHEF' || effectiveRole === 'RESTAURANT_OWNER') {
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
        select: { stock: true, name: true, variants: true, restaurantId: true }
      })
      if (!product) continue

      // Skip kitchen items (restaurant dishes have restaurantId)
      if (product.restaurantId || (product as any).restaurant?.id) {
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

    // 4. Classify items into grocery vs restaurant groups BEFORE inserting
    interface ClassifiedItem {
      item: any
      product: any | null
      itemPrice: number
      itemQty: number
      itemName: string
      isRestaurant: boolean
      restaurantId: string | null
      shopName: string | null
      shopPhone: string | null
    }

    const groceryGroup: ClassifiedItem[] = []
    const restaurantGroups: Record<string, { items: ClassifiedItem[], shopName: string, shopPhone: string | null }> = {}

    for (const item of updatedItems) {
      if (!item || item.quantity <= 0) continue

      let product = null
      if (item.productId && typeof item.productId === 'string' && !item.productId.startsWith('custom_')) {
        product = await prisma.product.findUnique({
          where: { id: item.productId },
          include: { category: true, restaurant: true }
        })
      }

      let itemPrice = product?.price ?? 0
      if (effectiveRole === 'ADMIN') {
        // Only ADMIN can override catalog product prices
        if (item.price !== undefined && item.price !== null) {
          itemPrice = Math.max(0, parseFloat(String(item.price)))
        }
      } else if (!product && item.price !== undefined && item.price !== null) {
        // Custom item (not in catalog): accept staff-entered price, minimum 0
        itemPrice = Math.max(0, parseFloat(String(item.price)))
      }
      const itemName = item.name || product?.name || 'Item'
      const itemQty = parseInt(String(item.quantity ?? 1), 10) || 1

      const itemRestId = item.restaurantId ? String(item.restaurantId).trim() : null
      const itemShopName = item.shopName ? String(item.shopName).trim() : null

      let isRestaurant = false
      let resolvedRestId: string | null = null
      let resolvedShopName: string | null = null
      let resolvedShopPhone: string | null = null

      if (product) {
        // Pure ID-wise: product belongs to restaurant IF AND ONLY IF it has a restaurantId
        const rawRestId = product.restaurantId || product.restaurant?.id
        if (rawRestId) {
          isRestaurant = true
          resolvedRestId = normalizeRestaurantId(rawRestId) || rawRestId
          resolvedShopName = product.restaurant?.name || itemShopName || (resolvedRestId?.includes('101') ? 'A.S. Restaurant' : resolvedRestId?.includes('102') ? 'Wedson Restaurant' : resolvedRestId?.includes('103') ? 'Bal Udyan Restaurant' : resolvedRestId?.includes('104') ? 'Pari Milk Dairy & Sweets' : 'Restaurant')
          resolvedShopPhone = product.restaurant?.ownerPhone || (product.restaurant as any)?.phone || null
        } else {
          // No restaurantId -> 100% Dark Store GROCERY item (even if added while editing a restaurant order)
          isRestaurant = false
          resolvedRestId = null
          resolvedShopName = 'FastKirana Grocery'
          resolvedShopPhone = null
        }
      } else {
        // Custom item (off-menu / phone-in, not in catalog)
        const explicitRestId = itemRestId ? normalizeRestaurantId(itemRestId) : null
        if (explicitRestId) {
          isRestaurant = true
          resolvedRestId = explicitRestId
          resolvedShopName = itemShopName || (resolvedRestId?.includes('101') ? 'A.S. Restaurant' : resolvedRestId?.includes('102') ? 'Wedson Restaurant' : resolvedRestId?.includes('103') ? 'Bal Udyan Restaurant' : resolvedRestId?.includes('104') ? 'Pari Milk Dairy & Sweets' : 'Restaurant')
          resolvedShopPhone = order.shopPhone || null
        } else if (order.orderType === 'RESTAURANT' && order.restaurantId && (effectiveRole === 'CHEF' || effectiveRole === 'RESTAURANT_OWNER')) {
          // Off-menu item entered by restaurant chef/owner belongs to their restaurant
          isRestaurant = true
          resolvedRestId = normalizeRestaurantId(order.restaurantId) || order.restaurantId
          resolvedShopName = order.shopName || 'Restaurant'
          resolvedShopPhone = order.shopPhone || null
        } else {
          // Otherwise default custom item to grocery
          isRestaurant = false
          resolvedRestId = null
          resolvedShopName = 'FastKirana Grocery'
          resolvedShopPhone = null
        }
      }

      const classified: ClassifiedItem = {
        item, product, itemPrice, itemQty, itemName,
        isRestaurant,
        restaurantId: resolvedRestId,
        shopName: resolvedShopName,
        shopPhone: resolvedShopPhone,
      }

      if (isRestaurant) {
        const key = resolvedRestId || normalizeRestaurantId(order.restaurantId) || 'REST-101'
        if (!restaurantGroups[key]) {
          restaurantGroups[key] = { items: [], shopName: resolvedShopName || order.shopName || 'Restaurant', shopPhone: resolvedShopPhone || order.shopPhone }
        }
        restaurantGroups[key].items.push(classified)
      } else {
        groceryGroup.push(classified)
      }
    }

    const hasGroceryItems = groceryGroup.length > 0
    const restaurantKeys = Object.keys(restaurantGroups)
    const hasRestaurantItems = restaurantKeys.length > 0
    const isMixed = (hasGroceryItems && hasRestaurantItems) || restaurantKeys.length > 1

    // 5. Fetch fee settings once
    const settings = await prisma.storeSetting.findMany()
    const settingsMap = settings.reduce((acc, s) => {
      acc[s.key] = s.value
      return acc
    }, {} as Record<string, string>)

    const deliveryFeeSetting = parseFloat(settingsMap['delivery_fee'] || '25')
    const miscFeeSetting = parseFloat(settingsMap['misc_fee'] || '5')

    // Helper: Calculate delivery/misc fees for a sub-order
    const calcFees = async (subtotal: number, ordType: string, shopNm: string | null, existingOrder: { deliveryMethod?: string | null; deliveryFee?: number | null }, allCompanionIds: string[]) => {
      let calcDeliveryFee = 0
      let calcMiscFee = 0
      
      const threshold = (ordType === 'RESTAURANT' || shopNm?.includes('Cafe') || shopNm?.includes('Restaurant'))
        ? parseFloat(settingsMap['cafe_free_delivery_threshold'] || '200')
        : parseFloat(settingsMap['grocery_free_delivery_threshold'] || '200')

      if (existingOrder.deliveryMethod === 'DELIVERY') {
        let companionHasDelivery = false
        let combinedSubtotal = subtotal

        if (allCompanionIds.length > 0) {
          const companions = await prisma.order.findMany({
            where: { id: { in: allCompanionIds } },
            select: { id: true, subtotal: true, deliveryFee: true, miscFee: true }
          })
          companionHasDelivery = companions.some(c => c.deliveryFee > 0)
          combinedSubtotal = companions.reduce((sum, c) => sum + c.subtotal, 0) + subtotal
        }

        const combinedThreshold = settingsMap['combined_free_delivery_threshold']
          ? parseFloat(settingsMap['combined_free_delivery_threshold'])
          : COMBINED_FREE_DELIVERY_THRESHOLD

        if (companionHasDelivery || combinedSubtotal >= threshold || combinedSubtotal >= combinedThreshold) {
          calcDeliveryFee = 0
        } else {
          calcDeliveryFee = deliveryFeeSetting
        }

        let companionHasMisc = false
        if (allCompanionIds.length > 0) {
          const companion = await prisma.order.findFirst({
            where: { id: { in: allCompanionIds }, miscFee: { gt: 0 } }
          })
          companionHasMisc = Boolean(companion)
        }
        calcMiscFee = companionHasMisc ? 0 : miscFeeSetting
      }

      return { calcDeliveryFee, calcMiscFee }
    }

    // Helper: Insert order items and handle stock deduction for a group
    const insertItemsForOrder = async (orderId: string, items: ClassifiedItem[]) => {
      let subtotal = 0
      for (const ci of items) {
        subtotal += ci.itemPrice * ci.itemQty

        await prisma.orderItem.create({
          data: {
            orderId,
            productId: ci.product?.id || null,
            name: ci.itemName,
            price: ci.itemPrice,
            quantity: ci.itemQty,
            selectedVariant: ci.item.selectedVariant || null,
            imageUrl: ci.item.imageUrl || ci.product?.imageUrl || null,
            notes: ci.item.notes || null,
            costPrice: ci.product?.costPrice || 0
          }
        })

        // Deduct stock for grocery items only
        if (ci.product && !ci.isRestaurant) {
          if (ci.item.selectedVariant) {
            if (ci.product.variants && Array.isArray(ci.product.variants)) {
              const updatedVariants = (ci.product.variants as any[]).map((v: any) => {
                if (v.name === ci.item.selectedVariant) {
                  return { ...v, stock: Math.max(0, v.stock - ci.itemQty) }
                }
                return v
              })
              const newTotalStock = updatedVariants.reduce((sum: number, v: any) => sum + v.stock, 0)
              await prisma.product.update({
                where: { id: ci.product.id },
                data: { variants: updatedVariants, stock: newTotalStock }
              })
            }
          } else {
            await prisma.product.update({
              where: { id: ci.product.id },
              data: { stock: { decrement: ci.itemQty } }
            })
          }
        }
      }
      return subtotal
    }

    // Helper: Derive base readableId by stripping -G / -R / -R2 suffix
    const getBaseReadableId = (rid: string) => rid.replace(/-(G|R\d*)$/i, '')

    // =====================================================================
    // SINGLE-DOMAIN PATH (no splitting needed — same logic as before)
    // =====================================================================
    if (!isMixed) {
      // Delete old items from this order
      await prisma.orderItem.deleteMany({ where: { orderId: order.id } })

      const allItems = hasGroceryItems ? groceryGroup : Object.values(restaurantGroups).flatMap(g => g.items)
      const subtotalVal = await insertItemsForOrder(order.id, allItems)

      let dynamicOrderType = order.orderType
      let dynamicRestaurantId = order.restaurantId
      let dynamicShopName = order.shopName
      let dynamicShopPhone = order.shopPhone

      if (order.orderType === 'RESTAURANT') {
        dynamicOrderType = 'RESTAURANT'
        dynamicRestaurantId = normalizeRestaurantId(order.restaurantId) || (restaurantKeys[0] ? normalizeRestaurantId(restaurantKeys[0]) : 'REST-101')
        const firstGroup = dynamicRestaurantId ? restaurantGroups[dynamicRestaurantId] : Object.values(restaurantGroups)[0]
        dynamicShopName = firstGroup?.shopName || order.shopName || 'Restaurant'
        dynamicShopPhone = firstGroup?.shopPhone || order.shopPhone || null
      } else if (order.orderType === 'GROCERY') {
        dynamicOrderType = 'GROCERY'
        dynamicRestaurantId = null
        dynamicShopName = 'FastKirana Grocery'
        dynamicShopPhone = null
      } else {
        if (!hasRestaurantItems) {
          dynamicOrderType = 'GROCERY'
          dynamicRestaurantId = null
          dynamicShopName = 'FastKirana Grocery'
          dynamicShopPhone = null
        } else {
          const firstKey = restaurantKeys[0]
          const firstGroup = restaurantGroups[firstKey]
          dynamicOrderType = 'RESTAURANT'
          dynamicRestaurantId = normalizeRestaurantId(firstKey)
          dynamicShopName = firstGroup?.shopName || order.shopName || 'Restaurant'
          if (firstGroup?.shopPhone) dynamicShopPhone = firstGroup.shopPhone
        }
      }

      // Find companion order ids (exclude self)
      const companionIds: string[] = []
      if (order.combinedId) {
        const companions = await prisma.order.findMany({
          where: { combinedId: order.combinedId, id: { not: order.id } },
          select: { id: true }
        })
        companionIds.push(...companions.map(c => c.id))
      }

      const { calcDeliveryFee, calcMiscFee } = await calcFees(subtotalVal, dynamicOrderType, dynamicShopName, order, companionIds)

      const taxesVal = 0.00
      const totalVal = subtotalVal + calcDeliveryFee + taxesVal + calcMiscFee - order.discount

      await prisma.order.update({
        where: { id: order.id },
        data: {
          subtotal: subtotalVal,
          deliveryFee: calcDeliveryFee,
          miscFee: calcMiscFee,
          taxes: taxesVal,
          total: totalVal,
          orderType: dynamicOrderType,
          restaurantId: dynamicRestaurantId,
          shopName: dynamicShopName,
          shopPhone: dynamicShopPhone,
          ...(dynamicOrderType === 'GROCERY' ? { assignedChefId: null } : { assignedPickerId: null })
        }
      })

      // Sync and clean up companion orders if order was part of a combined order
      if (order.combinedId) {
        const companions = await prisma.order.findMany({
          where: { combinedId: order.combinedId, id: { not: order.id } },
          include: { items: true }
        })
        for (const comp of companions) {
          if (comp.items.length === 0) {
            await prisma.orderItem.deleteMany({ where: { orderId: comp.id } })
            await prisma.order.delete({ where: { id: comp.id } })
          } else {
            const otherIds = [order.id, ...companions.filter(c => c.id !== comp.id).map(c => c.id)]
            const compFees = await calcFees(comp.subtotal, comp.orderType, comp.shopName, comp, otherIds)
            const compTotal = comp.subtotal + compFees.calcDeliveryFee + comp.taxes + compFees.calcMiscFee - comp.discount
            await prisma.order.update({
              where: { id: comp.id },
              data: {
                deliveryFee: compFees.calcDeliveryFee,
                miscFee: compFees.calcMiscFee,
                total: compTotal
              }
            })
          }
        }
      }

      // Push notification for out of stock
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
    }

    // =====================================================================
    // MIXED-DOMAIN PATH — Split grocery + restaurant into separate orders
    // =====================================================================
    const baseReadableId = getBaseReadableId(order.readableId || '')
    const combinedId = order.combinedId || `combined_${Math.random().toString(36).substring(2, 11)}_${Date.now().toString(36)}`

    // Determine which domain the current order was (so we keep it, create companion for the other)
    const currentIsGrocery = order.orderType === 'GROCERY' || !order.restaurantId

    // Build the list of sub-orders to process: [{orderId, items, type, restaurantId, shopName, shopPhone, isNew}]
    interface SubOrderSpec {
      orderId: string | null  // null = needs creation
      items: ClassifiedItem[]
      type: 'GROCERY' | 'RESTAURANT'
      restaurantId: string | null
      shopName: string
      shopPhone: string | null
      readableId: string
      isNew: boolean
    }

    const subOrders: SubOrderSpec[] = []

    // Find all existing companion orders (if any)
    let existingCompanions: any[] = []
    if (order.combinedId) {
      existingCompanions = await prisma.order.findMany({
        where: { combinedId: order.combinedId, id: { not: order.id } },
        include: { items: true }
      })
    }

    // Grocery sub-order
    if (hasGroceryItems) {
      // Try to reuse an existing grocery companion
      const existingGrocery = currentIsGrocery
        ? order
        : existingCompanions.find(c => c.orderType === 'GROCERY')

      subOrders.push({
        orderId: existingGrocery?.id || null,
        items: groceryGroup,
        type: 'GROCERY',
        restaurantId: null,
        shopName: 'FastKirana Grocery',
        shopPhone: null,
        readableId: `${baseReadableId}-G`,
        isNew: !existingGrocery,
      })
    }

    // Restaurant sub-orders (one per restaurantId)
    let restIndex = 0
    for (const rId of restaurantKeys) {
      restIndex++
      const rGroup = restaurantGroups[rId]

      // Try to reuse existing restaurant companion with same restaurantId
      const normalizedRId = normalizeRestaurantId(rId)
      const existingRest = (!currentIsGrocery && normalizeRestaurantId(order.restaurantId) === normalizedRId)
        ? order
        : existingCompanions.find(c => c.orderType === 'RESTAURANT' && normalizeRestaurantId(c.restaurantId) === normalizedRId)

      const suffix = restIndex === 1 ? '-R' : `-R${restIndex}`
      subOrders.push({
        orderId: existingRest?.id || null,
        items: rGroup.items,
        type: 'RESTAURANT',
        restaurantId: normalizedRId,
        shopName: rGroup.shopName,
        shopPhone: rGroup.shopPhone,
        readableId: `${baseReadableId}${suffix}`,
        isNew: !existingRest,
      })
    }

    // Process each sub-order: delete old items, insert new items, compute subtotals
    interface PreparedSubOrder {
      targetOrderId: string
      spec: SubOrderSpec
      subtotalVal: number
    }

    const preparedSubOrders: PreparedSubOrder[] = []
    const allOrderIds: string[] = []
    const sseEvents: any[] = []
    let primaryTotal = 0
    let primaryOrderType = ''
    let primaryRestaurantId: string | null = null
    let primaryShopName = ''

    for (const spec of subOrders) {
      let targetOrderId = spec.orderId

      if (spec.isNew) {
        // Prevent Prisma Unique constraint violation on readableId
        const existingByReadable = await prisma.order.findFirst({
          where: { readableId: spec.readableId }
        })
        if (existingByReadable) {
          targetOrderId = existingByReadable.id
          await prisma.order.update({
            where: { id: targetOrderId },
            data: {
              combinedId,
              status: order.status,
              orderType: spec.type,
              restaurantId: spec.restaurantId,
              shopName: spec.shopName,
              shopPhone: spec.shopPhone
            }
          })
        } else {
          // Create a new companion order cloning base fields from the original
          const newOrder = await prisma.order.create({
            data: {
              userId: order.userId,
              readableId: spec.readableId,
              addressId: order.addressId,
              combinedId,
              orderType: spec.type,
              status: order.status,
              subtotal: 0,
              discount: 0,
              deliveryFee: 0,
              taxes: 0,
              miscFee: 0,
              total: 0,
              paymentMethod: order.paymentMethod,
              paymentStatus: order.paymentStatus,
              estimatedDelivery: order.estimatedDelivery,
              deliveryMethod: order.deliveryMethod,
              isB2B: order.isB2B,
              storeId: order.storeId,
              couponCode: order.couponCode,
              shopName: spec.shopName,
              shopPhone: spec.shopPhone,
              restaurantId: spec.restaurantId,
              deliveryLat: order.deliveryLat,
              deliveryLng: order.deliveryLng,
              notes: order.notes,
              ...(spec.type === 'GROCERY' ? { assignedPickerId: order.assignedPickerId } : {}),
              ...(spec.type === 'RESTAURANT' ? { assignedChefId: order.assignedChefId } : {}),
            }
          })
          targetOrderId = newOrder.id
        }
      }

      // Cleanly replace items for this targetOrderId to eliminate duplicate items
      await prisma.orderItem.deleteMany({ where: { orderId: targetOrderId! } })

      allOrderIds.push(targetOrderId!)

      // Insert exact items for this sub-order
      const subtotalVal = await insertItemsForOrder(targetOrderId!, spec.items)

      preparedSubOrders.push({
        targetOrderId: targetOrderId!,
        spec,
        subtotalVal
      })
    }

    // Rule 4: Global combined delivery fee & miscFee calculation
    const totalCombinedSubtotal = preparedSubOrders.reduce((sum, p) => sum + p.subtotalVal, 0)
    const combinedThreshold = settingsMap['combined_free_delivery_threshold']
      ? parseFloat(settingsMap['combined_free_delivery_threshold'])
      : COMBINED_FREE_DELIVERY_THRESHOLD

    const isCombinedFree = order.deliveryMethod !== 'DELIVERY' || totalCombinedSubtotal >= combinedThreshold
    let singleDeliveryFeeAssigned = isCombinedFree // If free, none will be charged
    let singleMiscFeeAssigned = order.deliveryMethod !== 'DELIVERY'

    for (const p of preparedSubOrders) {
      let calcDeliveryFee = 0
      if (!singleDeliveryFeeAssigned && p.subtotalVal > 0) {
        calcDeliveryFee = deliveryFeeSetting
        singleDeliveryFeeAssigned = true
      }

      let calcMiscFee = 0
      if (!singleMiscFeeAssigned && p.subtotalVal > 0) {
        calcMiscFee = miscFeeSetting
        singleMiscFeeAssigned = true
      }

      const taxesVal = 0.00
      const discount = p.spec.isNew ? 0 : order.discount
      const totalVal = p.subtotalVal + calcDeliveryFee + taxesVal + calcMiscFee - discount

      await prisma.order.update({
        where: { id: p.targetOrderId },
        data: {
          combinedId,
          readableId: p.spec.readableId,
          subtotal: p.subtotalVal,
          deliveryFee: calcDeliveryFee,
          miscFee: calcMiscFee,
          taxes: taxesVal,
          total: totalVal,
          orderType: p.spec.type,
          restaurantId: p.spec.restaurantId,
          shopName: p.spec.shopName,
          shopPhone: p.spec.shopPhone,
          ...(p.spec.type === 'GROCERY' ? { assignedChefId: null } : { assignedPickerId: null })
        }
      })

      sseEvents.push({
        type: 'order-edited',
        orderId: p.targetOrderId,
        shopName: p.spec.shopName,
        restaurantId: p.spec.restaurantId,
        orderType: p.spec.type
      })

      // Track primary order (the one originally edited) for the response
      if (p.targetOrderId === order.id) {
        primaryTotal = totalVal
        primaryOrderType = p.spec.type
        primaryRestaurantId = p.spec.restaurantId
        primaryShopName = p.spec.shopName
      }
    }

    // Also make sure the original order has the combinedId set
    if (!order.combinedId) {
      await prisma.order.update({
        where: { id: order.id },
        data: { combinedId }
      })
    }

    // Clean up any companion orders belonging to this combinedId that are no longer part of the edit
    if (existingCompanions.length > 0) {
      for (const ec of existingCompanions) {
        if (!allOrderIds.includes(ec.id)) {
          await prisma.orderItem.deleteMany({ where: { orderId: ec.id } })
          await prisma.order.delete({ where: { id: ec.id } })
          console.log(`[OrderEdit] Cleaned up orphaned companion sub-order: ${ec.readableId || ec.id}`)
        }
      }
    }

    // Push notification for out of stock
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

    // Broadcast SSE events for ALL affected consoles
    for (const evt of sseEvents) {
      sseEmitter.emit('message', evt)
    }

    return NextResponse.json({
      success: true,
      total: primaryTotal,
      orderType: primaryOrderType,
      restaurantId: primaryRestaurantId,
      shopName: primaryShopName,
      split: true,
      subOrders: subOrders.map(s => ({
        orderId: allOrderIds[subOrders.indexOf(s)],
        type: s.type,
        readableId: s.readableId,
        shopName: s.shopName,
        restaurantId: s.restaurantId,
        itemCount: s.items.length
      }))
    })
  } catch (err: any) {
    console.error('Order edit API error:', err)
    return NextResponse.json({ error: err?.message || 'Internal Server Error' }, { status: 500 })
  }
}
