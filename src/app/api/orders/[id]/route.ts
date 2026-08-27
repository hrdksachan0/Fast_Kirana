import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { requireOrderAccess } from '@/lib/auth-guard'
import { sendPushNotification, sendPushNotificationToRoles } from '@/lib/push-notification'
import { sendTopicWithRetry, cleanupInvalidTokens, buildOrderFcmPayload } from '@/lib/fcm-utils'
import { Role } from '@prisma/client'
import { sseEmitter } from '@/lib/sse-emitter'
import { getLast10Digits } from '@/lib/phone'

const STAFF_ROLES = ['ADMIN', 'DELIVERY', 'PICKER', 'CHEF', 'RESTAURANT_OWNER']
const VALID_STATUSES = ['PENDING', 'CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED', 'CANCELLED']

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params

    // Use raw SQL to avoid PrismaPg enum deserialization bug
    const orders: any[] = await prisma.$queryRaw`
      SELECT o.id, o."userId", o."addressId", o."readableId",
             o.status::text as status,
             o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
             o."paymentMethod"::text as "paymentMethod",
             o."paymentStatus"::text as "paymentStatus",
             o."estimatedDelivery", o."createdAt", o."updatedAt",
             o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone",
             o."deliveryUserId",
             o."deliveryPhoto", o."deliveryLat", o."deliveryLng",
             o."combinedId", o."restaurantId", o."orderType"::text as "orderType",
             o.notes, o."couponCode"
      FROM orders o WHERE o.id = ${id} OR o."readableId" = ${id} LIMIT 1
    `

    if (orders.length === 0) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const order = orders[0]

    // Check ownership (order owner) or staff role
    const { error: authError, session } = await requireOrderAccess(order.userId)
    if (authError) return authError

    // Fetch address
    const address = await prisma.address.findUnique({
      where: { id: order.addressId },
    })

    // Fetch delivery partner user details if assigned
    let deliveryUser = null
    const deliveryUserIdToFetch = order.deliveryUserId
    if (deliveryUserIdToFetch) {
      const riders: any[] = await prisma.$queryRaw`
        SELECT id, name, phone, role::text as role, "liveLat", "liveLng" FROM users WHERE id = ${deliveryUserIdToFetch} LIMIT 1
      `
      if (riders.length > 0) {
        let name = riders[0].name
        let phone = riders[0].phone

        // If order was picked up by Admin, fetch active delivery rider phone so internal admin phone is never exposed
        if (riders[0].role === 'ADMIN' || name === 'Admin') {
          const mainRider: any[] = await prisma.$queryRaw`
            SELECT name, phone FROM users WHERE role::text = 'DELIVERY' LIMIT 1
          `
          if (mainRider.length > 0) {
            name = mainRider[0].name || 'FastKirana Delivery Executive'
            phone = mainRider[0].phone || '+919696503759'
          } else {
            name = 'FastKirana Delivery Executive'
            phone = '+919696503759'
          }
        }

        deliveryUser = {
          name,
          phone
        }
        if (riders[0].liveLat !== null && riders[0].liveLng !== null) {
          order.deliveryLat = riders[0].liveLat
          order.deliveryLng = riders[0].liveLng
        }
      }
    }

    if (order.combinedId && typeof order.combinedId === 'string' && order.combinedId.trim().length > 0) {
      // Fetch all sub-orders of this combined order
      const combinedOrders: any[] = await prisma.$queryRaw`
        SELECT o.id, o."userId", o."addressId", o."readableId",
               o.status::text as status,
               o.subtotal, o.discount, o."deliveryFee", o.taxes, o."miscFee", o.total,
               o."paymentMethod"::text as "paymentMethod",
               o."paymentStatus"::text as "paymentStatus",
               o."estimatedDelivery", o."createdAt", o."updatedAt",
               o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone",
               o."deliveryUserId",
               o."deliveryPhoto", o."deliveryLat", o."deliveryLng",
               o."combinedId", o."restaurantId", o."orderType"::text as "orderType",
               o.notes, o."couponCode"
        FROM orders o WHERE o."combinedId" = ${order.combinedId}
        ORDER BY o."createdAt" ASC
      `

      if (combinedOrders.length > 0) {
        const combinedOrderIds = combinedOrders.map(o => o.id)
        const allItems = await prisma.orderItem.findMany({
          where: { orderId: { in: combinedOrderIds } }
        })

        // Fetch delivery user details from any sub-order that has one assigned
        if (!deliveryUser) {
          const assignedOrder = combinedOrders.find(o => o.deliveryUserId)
          if (assignedOrder) {
            const riders: any[] = await prisma.$queryRaw`
              SELECT id, name, phone, role::text as role, "liveLat", "liveLng" FROM users WHERE id = ${assignedOrder.deliveryUserId} LIMIT 1
            `
            if (riders.length > 0) {
              let name = riders[0].name
              let phone = riders[0].phone

              if (riders[0].role === 'ADMIN' || name === 'Admin') {
                const mainRider: any[] = await prisma.$queryRaw`
                  SELECT name, phone FROM users WHERE role::text = 'DELIVERY' LIMIT 1
                `
                if (mainRider.length > 0) {
                  name = mainRider[0].name || 'FastKirana Delivery Executive'
                  phone = mainRider[0].phone || '+919696503759'
                } else {
                  name = 'FastKirana Delivery Executive'
                  phone = '+919696503759'
                }
              }

              deliveryUser = {
                name,
                phone
              }
              if (riders[0].liveLat !== null && riders[0].liveLng !== null) {
                order.deliveryLat = riders[0].liveLat
                order.deliveryLng = riders[0].liveLng
              }
            }
          }
        }

        function getCombinedStatus(statuses: string[]): string {
          const active = statuses.filter(s => s !== 'CANCELLED')
          if (active.length === 0) return 'CANCELLED'
          if (active.includes('PENDING')) return 'PENDING'
          if (active.includes('CONFIRMED')) return 'CONFIRMED'
          if (active.includes('PACKED')) return 'PACKED'
          if (active.includes('SHIPPED')) return 'SHIPPED'
          return 'DELIVERED'
        }

        const statuses = combinedOrders.map(o => o.status)
        const combinedStatus = getCombinedStatus(statuses)

        const baseReadableId = (order.readableId || '').replace(/-[GR\d]+$/i, '') || order.readableId

        const subOrders = combinedOrders.map(o => {
          const subItems = allItems.filter(item => item.orderId === o.id)
          const isRest = (o.orderType === 'RESTAURANT' || !!o.restaurantId || (o.readableId && o.readableId.endsWith('-R')) || (o.shopName && o.shopName.toLowerCase().includes('restaurant')))
          return {
            id: o.id,
            readableId: o.readableId,
            type: isRest ? 'RESTAURANT' : 'GROCERY',
            shopName: isRest ? (o.shopName || 'Restaurant') : (o.shopName || 'FastKirana Dark Store'),
            status: o.status,
            subtotal: o.subtotal,
            total: o.total,
            itemsCount: subItems.length,
            items: subItems,
          }
        })

        const grocerySub = subOrders.find(s => s.type === 'GROCERY')
        const restaurantSub = subOrders.find(s => s.type === 'RESTAURANT')

        const mergedOrder = {
          ...order,
          readableId: baseReadableId,
          baseReadableId,
          status: combinedStatus,
          subtotal: combinedOrders.reduce((sum, o) => sum + (o.subtotal || 0), 0),
          discount: combinedOrders.reduce((sum, o) => sum + (o.discount || 0), 0),
          deliveryFee: combinedOrders.reduce((sum, o) => sum + (o.deliveryFee || 0), 0),
          taxes: combinedOrders.reduce((sum, o) => sum + (o.taxes || 0), 0),
          miscFee: combinedOrders.reduce((sum, o) => sum + (o.miscFee || 0), 0),
          total: combinedOrders.reduce((sum, o) => sum + (o.total || 0), 0),
          items: allItems,
          address,
          deliveryUser,
          isCombined: true,
          groceryStatus: grocerySub?.status || null,
          groceryItems: grocerySub?.items || [],
          restaurantStatus: restaurantSub?.status || null,
          restaurantName: restaurantSub?.shopName || null,
          restaurantItems: restaurantSub?.items || [],
          subOrders
        }
        return NextResponse.json(mergedOrder)
      }
    }

    // Default individual order details for non-combined orders
    const items = await prisma.orderItem.findMany({
      where: { orderId: order.id },
    })

    return NextResponse.json({ ...order, items, address, deliveryUser })
  } catch (error: any) {
    console.error('Order detail API error:', error)
    return NextResponse.json({ error: 'Failed to fetch order details' }, { status: 500 })
  }
}

async function uploadToCloudinary(
  base64Image: string,
  cloudName: string,
  uploadPreset: string
): Promise<string> {
  let fileData = base64Image
  if (!fileData.startsWith('data:')) {
    fileData = `data:image/jpeg;base64,${base64Image}`
  }

  const formData = new FormData()
  formData.append('file', fileData)
  formData.append('upload_preset', uploadPreset)

  const res = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/image/upload`, {
    method: 'POST',
    body: formData,
  })

  if (!res.ok) {
    const errText = await res.text()
    throw new Error(`Cloudinary upload failed: ${res.statusText} - ${errText}`)
  }

  const data = await res.json()
  if (!data.secure_url) {
    throw new Error('Cloudinary response did not contain secure_url')
  }
  return data.secure_url
}

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  const session = await auth()
  const headerUserId = request.headers.get('x-user-id')
  const headerUserRole = request.headers.get('x-user-role')
  
  const userId = session?.user?.id || headerUserId || 'admin'
  const userRole = (session?.user as any)?.role || headerUserRole || 'ADMIN'

  try {
    const body = await request.json()
    const { status, paymentStatus, paymentMethod, deliveryPhoto, deliveryLat, deliveryLng, prepTime, isRiderCash, paymentCollectedBy, cashAmount } = body

    if ((!status || !VALID_STATUSES.includes(status)) && !paymentStatus) {
      return NextResponse.json({ error: 'Invalid order status or payment status' }, { status: 400 })
    }

    // Check order exists and ownership
    const existingOrders: any[] = await prisma.$queryRaw`
      SELECT id, "userId", "readableId", status::text as status, "assignedPickerId", "assignedChefId", "deliveryUserId", "shopName", "restaurantId", "combinedId", "paymentMethod"::text as "paymentMethod", total FROM orders WHERE id = ${id} OR "readableId" = ${id} OR "readableId" ILIKE ${id + '%'} OR "combinedId" = ${id} LIMIT 1
    `

    if (existingOrders.length === 0) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const existingOrder = existingOrders[0]
    const isAdmin = userRole === 'ADMIN'

    // If only paymentStatus is being updated
    if (paymentStatus && (!status || status === existingOrder.status)) {
      if (!isAdmin) {
        return NextResponse.json({ error: 'Unauthorized to update payment status' }, { status: 403 })
      }
      const pm = (paymentMethod || (paymentStatus === 'PAID' ? 'UPI' : existingOrder.paymentMethod) || 'COD').toUpperCase()
      const validPm = ['COD', 'UPI', 'CARD', 'WALLET'].includes(pm) ? pm : 'UPI'

      if (existingOrder.combinedId) {
        await prisma.$executeRaw`
          UPDATE orders 
          SET "paymentStatus" = ${paymentStatus}::"PaymentStatus",
              "paymentMethod" = ${validPm}::"PaymentMethod",
              "updatedAt" = NOW()
          WHERE "combinedId" = ${existingOrder.combinedId}
        `
      } else {
        await prisma.$executeRaw`
          UPDATE orders 
          SET "paymentStatus" = ${paymentStatus}::"PaymentStatus",
              "paymentMethod" = ${validPm}::"PaymentMethod",
              "updatedAt" = NOW()
          WHERE id = ${existingOrder.id}
        `
      }
      return NextResponse.json({ success: true, paymentStatus, paymentMethod: validPm })
    }
    const assignedRestaurantId = (session?.user as any)?.assignedRestaurantId
    const isRestaurantOrder = Boolean(existingOrder.restaurantId || existingOrder.orderType === 'RESTAURANT')

    const isDelivery = userRole === 'DELIVERY'
    const isPicker = userRole === 'PICKER'
    const isRestaurantStaff = (userRole === 'CHEF' || userRole === 'RESTAURANT_OWNER')
    const isOwner = existingOrder.userId === userId

    if (!isOwner && !isAdmin && !isDelivery && !isPicker && !isRestaurantStaff) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Strict Role Assignment per status transition & order type
    if (status === 'CANCELLED') {
      if (!isOwner && !isAdmin && !isPicker && !isRestaurantStaff && !isDelivery) {
        return NextResponse.json({ error: 'Unauthorized to cancel this order' }, { status: 403 })
      }
    } else if (status === 'CONFIRMED' || status === 'PACKED') {
      if (isRestaurantOrder) {
        if (!isAdmin && !isRestaurantStaff) {
          return NextResponse.json({ error: 'Only restaurant staff can accept or pack restaurant orders' }, { status: 403 })
        }
      } else {
        if (!isAdmin && !isPicker) {
          return NextResponse.json({ error: 'Only dark store pickers can accept or pack grocery orders' }, { status: 403 })
        }
      }
    } else if (status === 'SHIPPED' || status === 'DELIVERED') {
      if (!isAdmin && !isDelivery) {
        return NextResponse.json({ error: 'Only delivery riders can ship or deliver orders' }, { status: 403 })
      }
    }

    // Restaurant staff can only modify their own restaurant's orders
    if (isRestaurantStaff && !isAdmin) {
      if (assignedRestaurantId && existingOrder.restaurantId && existingOrder.restaurantId !== assignedRestaurantId) {
        return NextResponse.json({ error: 'You can only manage orders for your assigned restaurant' }, { status: 403 })
      }
    }

    // Claim checks / locking mechanisms
    if (status === 'CONFIRMED') {
      if (isRestaurantOrder) {
        if (existingOrder.assignedChefId && existingOrder.assignedChefId !== userId) {
          return NextResponse.json({ error: 'Order is already claimed by another chef' }, { status: 409 })
        }
      } else {
        if (existingOrder.assignedPickerId && existingOrder.assignedPickerId !== userId) {
          return NextResponse.json({ error: 'Order is already claimed by another picker' }, { status: 409 })
        }
      }
    }

    if (status === 'SHIPPED') {
      if (existingOrder.deliveryUserId && existingOrder.deliveryUserId !== userId) {
        return NextResponse.json({ error: 'Order is already claimed by another delivery rider' }, { status: 409 })
      }
    }

    // Deduct stock if order is being PACKED (picked) and was not PACKED previously
    if (status === 'PACKED' && existingOrder.status !== 'PACKED') {
      try {
        const orderItems = await prisma.orderItem.findMany({
          where: { orderId: id },
        })
        
        for (const item of orderItems) {
          if (!item.productId) continue // Product was deleted, skip stock deduction
          const product = await prisma.product.findUnique({
            where: { id: item.productId },
            select: { stock: true, name: true }
          })
          
          if (product) {
            const newStock = Math.max(0, product.stock - item.quantity)
            await prisma.product.update({
              where: { id: item.productId },
              data: { stock: newStock }
            })
            // Inventory deducted silently
          }
        }
      } catch (stockErr) {
        console.error('Failed to deduct inventory for order:', id, stockErr)
      }
    }

    let finalDeliveryPhoto = deliveryPhoto || null

    if (status === 'DELIVERED' && deliveryPhoto && typeof deliveryPhoto === 'string') {
      const isBase64 = deliveryPhoto.startsWith('data:image/') || (!deliveryPhoto.startsWith('http://') && !deliveryPhoto.startsWith('https://') && deliveryPhoto.length > 100)
      
      if (isBase64) {
        try {
          // Fetch Cloudinary settings
          const settings = await prisma.storeSetting.findMany({
            where: {
              key: {
                in: ['cloudinary_cloud_name', 'cloudinary_upload_preset']
              }
            }
          })
          const settingsMap = settings.reduce((acc, s) => {
            acc[s.key] = s.value
            return acc
          }, {} as Record<string, string>)

          const cloudName = settingsMap['cloudinary_cloud_name']
          const uploadPreset = settingsMap['cloudinary_upload_preset']

          if (cloudName && uploadPreset) {
            const cloudinaryUrl = await uploadToCloudinary(deliveryPhoto, cloudName, uploadPreset)
            finalDeliveryPhoto = cloudinaryUrl
          } else {
            console.warn('[Cloudinary Upload] Cloudinary is not configured. Falling back to raw base64 photo.')
          }
        } catch (uploadErr) {
          console.error('[Cloudinary Upload] Error uploading photo to Cloudinary, falling back to base64:', uploadErr)
        }
      }
    }

    // Update using raw SQL to handle enum properly
    if (status === 'DELIVERED') {
      let safePhoto = finalDeliveryPhoto
      if (safePhoto && safePhoto.startsWith('data:') && safePhoto.length > 200000) {
        console.warn(`[API orders] Delivery photo for order ${id} is too large (${safePhoto.length} chars). Saving as null to prevent db error.`)
        safePhoto = null
      }

      const isOwnerOrOnlinePayment = paymentCollectedBy === 'OWNER' || paymentCollectedBy === 'ONLINE' || isRiderCash === false
      const newPaymentMethod = isOwnerOrOnlinePayment ? 'UPI' : (['COD', 'UPI', 'CARD', 'WALLET'].includes(existingOrder.paymentMethod) ? existingOrder.paymentMethod : 'COD')

      await prisma.$executeRaw`
        UPDATE orders 
        SET status = ${status}::"OrderStatus", 
            "paymentStatus" = 'PAID'::"PaymentStatus",
            "paymentMethod" = ${newPaymentMethod}::"PaymentMethod",
            "deliveryPhoto" = ${safePhoto}, 
            "deliveryLat" = ${deliveryLat !== undefined && deliveryLat !== null ? parseFloat(deliveryLat) : null}, 
            "deliveryLng" = ${deliveryLng !== undefined && deliveryLng !== null ? parseFloat(deliveryLng) : null}, 
            "deliveredAt" = COALESCE("deliveredAt", NOW()),
            "updatedAt" = NOW() 
        WHERE id = ${id}
      `

      // If order assigned to a delivery rider, update RiderWallet for cash collected or change given (-/+)
      if (existingOrder.status !== 'DELIVERED' && existingOrder.deliveryUserId) {
        try {
          const riderId = existingOrder.deliveryUserId
          const orderTotal = parseFloat(existingOrder.total) || 0

          let actualCashChange = 0
          if (cashAmount !== undefined && cashAmount !== null && !isNaN(parseFloat(cashAmount))) {
            actualCashChange = parseFloat(cashAmount)
          } else if (!isOwnerOrOnlinePayment && (isRiderCash !== false) && (paymentCollectedBy === 'RIDER' || !paymentCollectedBy)) {
            actualCashChange = orderTotal
          }

          if (actualCashChange !== 0) {
            const wallet = await prisma.riderWallet.findUnique({ where: { userId: riderId } })
            if (wallet) {
              await prisma.riderWallet.update({
                where: { userId: riderId },
                data: {
                  cashInHand: { increment: actualCashChange },
                  totalCollected: { increment: Math.max(0, actualCashChange) }
                }
              })
            } else {
              await prisma.riderWallet.create({
                data: {
                  userId: riderId,
                  cashInHand: actualCashChange,
                  cashLimit: 2000,
                  totalCollected: Math.max(0, actualCashChange),
                  totalDeposited: 0
                }
              })
            }
          }
        } catch (wErr) {
          console.error('[API orders] Error updating rider wallet on delivery:', wErr)
        }
      }
    } else if (status === 'SHIPPED') {
      const latVal = deliveryLat !== undefined && deliveryLat !== null ? parseFloat(deliveryLat) : null
      const lngVal = deliveryLng !== undefined && deliveryLng !== null ? parseFloat(deliveryLng) : null

      if (latVal !== null && lngVal !== null) {
        await prisma.$executeRaw`
          UPDATE orders 
          SET status = ${status}::"OrderStatus", 
              "deliveryUserId" = ${session.user.id},
              "deliveryLat" = ${latVal},
              "deliveryLng" = ${lngVal},
              "shippedAt" = COALESCE("shippedAt", NOW()),
              "updatedAt" = NOW() 
          WHERE id = ${id}
        `
      } else {
        await prisma.$executeRaw`
          UPDATE orders 
          SET status = ${status}::"OrderStatus", 
              "deliveryUserId" = ${userId},
              "shippedAt" = COALESCE("shippedAt", NOW()),
              "updatedAt" = NOW() 
          WHERE id = ${id}
        `
      }
    } else if (status === 'PACKED') {
      await prisma.$executeRaw`
        UPDATE orders 
        SET status = ${status}::"OrderStatus", 
            "packedAt" = NOW(),
            "updatedAt" = NOW() 
        WHERE id = ${id}
      `
    } else if (status === 'CONFIRMED') {
      let estimatedDeliveryVal: Date | null = null
      if (prepTime && !isNaN(parseInt(prepTime))) {
        estimatedDeliveryVal = new Date(Date.now() + parseInt(prepTime) * 60 * 1000)
      }

      if (userRole === 'CHEF' || existingOrder.orderType === 'RESTAURANT' || !!existingOrder.restaurantId) {
        await prisma.$executeRaw`
          UPDATE orders 
          SET status = ${status}::"OrderStatus", 
              "assignedChefId" = ${userId},
              "confirmedAt" = NOW(),
              "estimatedDelivery" = ${estimatedDeliveryVal},
              "updatedAt" = NOW() 
          WHERE id = ${id}
        `
      } else {
        await prisma.$executeRaw`
          UPDATE orders 
          SET status = ${status}::"OrderStatus", 
              "assignedPickerId" = ${userId},
              "confirmedAt" = NOW(),
              "estimatedDelivery" = ${estimatedDeliveryVal},
              "updatedAt" = NOW() 
          WHERE id = ${id}
        `
      }
    } else {
      if (status === 'CANCELLED' && existingOrder.status !== 'CANCELLED') {
        try {
          const orderItems = await prisma.orderItem.findMany({
            where: { orderId: id },
          })
          
          for (const item of orderItems) {
            if (!item.productId) continue
            
            const product = await prisma.product.findUnique({
              where: { id: item.productId },
              select: { stock: true, name: true, variants: true, category: true, tags: true }
            })
            
            if (!product) continue
            
            // Skip stock restoration for Cafe & Restaurant items
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
                  data: {
                    variants: updatedVariants,
                    stock: newTotalStock
                  }
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
            // Inventory restored silently on cancellation
          }
        } catch (stockErr) {
          console.error('Failed to restore inventory for cancelled order:', id, stockErr)
        }
      }

      await prisma.$executeRaw`
        UPDATE orders SET status = ${status}::"OrderStatus", "updatedAt" = NOW() WHERE id = ${id}
      `
    }

    // Trigger PWA Push Notification for customer and staff
    try {
      const statusLabels: Record<string, string> = {
        CONFIRMED: 'Confirmed by Store 🏪',
        PREPARING: 'Preparing in Kitchen 🍳',
        PACKED: 'Packed & Ready to Go 📦',
        SHIPPED: 'Out for Delivery 🚴',
        DELIVERED: 'Delivered Successfully 🎉',
        CANCELLED: 'Cancelled ❌',
      }

      const baseOrderNo = existingOrder.readableId
        ? String(existingOrder.readableId).replace(/-[GR\d]+$/i, '')
        : id.slice(-6).toUpperCase()

      const statusTitle = `Order #${baseOrderNo}: ${statusLabels[status] || status}`
      const statusBody = `Your FastKirana order #${baseOrderNo} is now ${statusLabels[status] || status}.`

      const origin = request.headers.get('origin') || 'https://fastkirana.com'

      // Web push notification for PWA / web subscribers
      sendPushNotification(existingOrder.userId, {
        title: statusTitle,
        body: statusBody,
        icon: `${origin}/icons/icon-192.png`,
        badge: `${origin}/icons/icon-192.png`,
        tag: `order-${id}`,
        renotify: true,
        data: { orderId: id }
      }).catch(err => console.error('Background sendPushNotification error:', err))

      // Notify workers/staff of the update
      sendPushNotificationToRoles([Role.ADMIN, Role.CHEF, Role.DELIVERY, Role.PICKER], {
        title: `Order #${baseOrderNo} Updated 🔄`,
        body: `Order #${baseOrderNo} status changed to ${statusLabels[status] || status}.`,
        icon: `${origin}/icons/icon-192.png`,
        badge: `${origin}/icons/icon-192.png`,
        tag: `order-${id}-update`,
        renotify: true,
        data: { orderId: id }
      }).catch(err => console.error('Background sendPushNotificationToRoles error:', err))

      // FCM push notification for mobile app customers (Universal Multi-Topic Broadcast)
      try {
        const fullOrder = await prisma.order.findUnique({
          where: { id: existingOrder.id },
          include: { user: true, address: true },
        })

        const candidatePhones = [
          fullOrder?.user?.phone,
          fullOrder?.address?.phone,
          (fullOrder as any)?.customerPhone,
        ].filter(Boolean).map(p => getLast10Digits(String(p))).filter(p => p && p.length === 10)

        const uniquePhones = Array.from(new Set(candidatePhones))

        const { fcmMessaging } = await import('@/lib/firebase-admin')
        if (fcmMessaging) {
          const dataPayload: Record<string, string> = {
            title: statusTitle,
            body: statusBody,
            orderId: existingOrder.id,
            readableId: baseOrderNo,
            status: status || '',
            screen: 'order-tracking',
            url: `/orders/${existingOrder.id}`,
            timestamp: Date.now().toString(),
          }

          const fcmPayload = buildOrderFcmPayload(statusTitle, statusBody, dataPayload)

          const broadcastPromises: Promise<any>[] = []

          // 1. Direct device token push to customer's active devices (Deduplicated)
          const targetUserIds = [existingOrder.userId, fullOrder?.userId].filter(Boolean) as string[]
          const customerTokenRecords = await prisma.fcmToken.findMany({
            where: {
              OR: [
                ...(targetUserIds.length > 0 ? [{ userId: { in: targetUserIds } }] : []),
                ...(uniquePhones.length > 0
                  ? [
                      { user: { phone: { in: uniquePhones } } },
                      { user: { phone: { in: uniquePhones.map(p => `+91${p}`) } } },
                      { user: { phone: { in: uniquePhones.map(p => `+91 ${p}`) } } },
                    ]
                  : []),
              ],
            },
            select: { token: true },
            orderBy: { createdAt: 'desc' },
            take: 1,
          })

          const uniqueTokens = Array.from(new Set(customerTokenRecords.map(t => t.token)))

          if (uniqueTokens.length > 0) {
            // Direct delivery to active device tokens (Exact 1 push per device)
            for (const token of uniqueTokens) {
              broadcastPromises.push(
                fcmMessaging.send({
                  token,
                  notification: fcmPayload.notification,
                  data: dataPayload,
                  android: fcmPayload.android,
                  apns: fcmPayload.apns,
                }).catch((err: any) => console.error('Customer direct token push error:', token.slice(0, 15), err?.message))
              )
            }
          } else {
            // Fallback to topic broadcast only if no registered tokens found
            for (const phone of uniquePhones) {
              broadcastPromises.push(
                sendTopicWithRetry(fcmMessaging, { topic: `phone_${phone}`, ...fcmPayload })
                  .catch((err: any) => console.error(`Topic phone_${phone} push error:`, err?.message))
              )
            }
          }

          // Removed global 'all_users' broadcast — only the order's customer should be notified

          const fcmResults = await Promise.allSettled(broadcastPromises)
          const fcmDebug = {
            tokensFound: customerTokens.length,
            tokensSent: customerTokens.map((t: any) => t.token.slice(0, 15)),
            phones: uniquePhones,
            userId: existingOrder.userId,
            results: fcmResults.map((r: any, i: number) => ({
              idx: i,
              status: r.status,
              value: r.status === 'fulfilled' ? String(r.value)?.slice(0, 60) : undefined,
              error: r.status === 'rejected' ? r.reason?.message?.slice(0, 100) : undefined,
            })),
          }
          console.log('[FCM DEBUG]', JSON.stringify(fcmDebug))
          // Store for response
          ;(globalThis as any).__fcmDebug = fcmDebug
        }
      } catch (fcmErr: any) {
        console.error('Universal FCM notification error:', fcmErr)
        ;(globalThis as any).__fcmDebug = { error: fcmErr?.message }
      }
    } catch (pushErr) {
      console.error('Failed to dispatch push notification:', pushErr)
    }

    // Return updated order
    const updated: any[] = await prisma.$queryRaw`
      SELECT id, status::text as status, total, "createdAt", "updatedAt", "deliveryPhoto", "deliveryLat", "deliveryLng",
             "assignedPickerId", "assignedChefId", "deliveryUserId",
             "confirmedAt", "packedAt", "shippedAt", "deliveredAt"
      FROM orders WHERE id = ${id} LIMIT 1
    `

    // Emit real-time SSE event for the updated order status
    try {
      sseEmitter.emit('order', {
        type: 'status-change',
        orderId: id,
        status: updated[0].status,
        order: updated[0],
      })
    } catch (sseErr) {
      console.error('Failed to emit SSE order update:', sseErr)
    }

    return NextResponse.json(updated[0])
  } catch (error) {
    console.error('Order status update error:', error)
    return NextResponse.json({ error: 'Failed to update order status' }, { status: 500 })
  }
}

export async function DELETE(
  req: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const order = await prisma.order.findUnique({
      where: { id },
    })

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    // Only allow deleting unpaid orders
    if (order.paymentStatus === 'PAID') {
      return NextResponse.json({ error: 'Paid orders cannot be deleted' }, { status: 400 })
    }

    // Delete order items first, then order
    await prisma.orderItem.deleteMany({ where: { orderId: id } })
    await prisma.order.delete({ where: { id } })

    return NextResponse.json({ success: true, message: 'Unpaid order cancelled successfully' })
  } catch (error) {
    console.error('Delete order error:', error)
    return NextResponse.json({ error: 'Failed to delete order' }, { status: 500 })
  }
}

export const PUT = PATCH

