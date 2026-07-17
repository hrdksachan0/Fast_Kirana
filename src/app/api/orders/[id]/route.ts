import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { sendPushNotification, sendPushNotificationToRoles } from '@/lib/push-notification'
import { Role } from '@prisma/client'
import { sseEmitter } from '@/lib/sse-emitter'

const VALID_STATUSES = ['PENDING', 'CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED', 'CANCELLED']

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

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
             o."combinedId"
      FROM orders o WHERE o.id = ${id} LIMIT 1
    `

    if (orders.length === 0) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const order = orders[0]

    // Check ownership
    if (order.userId !== session.user.id && session.user.role !== 'ADMIN' && session.user.role !== 'DELIVERY' && session.user.role !== 'PICKER' && session.user.role !== 'CHEF') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const isWorker = session.user.role === 'ADMIN' || session.user.role === 'DELIVERY' || session.user.role === 'PICKER' || session.user.role === 'CHEF'

    // Fetch address
    const address = await prisma.address.findUnique({
      where: { id: order.addressId },
    })

    // Fetch delivery partner user details if assigned
    let deliveryUser = null
    const deliveryUserIdToFetch = order.deliveryUserId
    if (deliveryUserIdToFetch) {
      const riders: any[] = await prisma.$queryRaw`
        SELECT id, name, phone FROM users WHERE id = ${deliveryUserIdToFetch} LIMIT 1
      `
      if (riders.length > 0) {
        deliveryUser = {
          name: riders[0].name,
          phone: riders[0].phone
        }
      }
    }

    if (!isWorker && order.combinedId) {
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
               o."combinedId"
        FROM orders o WHERE o."combinedId" = ${order.combinedId}
      `

      const combinedOrderIds = combinedOrders.map(o => o.id)
      const allItems = await prisma.orderItem.findMany({
        where: { orderId: { in: combinedOrderIds } }
      })

      // Fetch delivery user details from any sub-order that has one assigned
      if (!deliveryUser) {
        const assignedOrder = combinedOrders.find(o => o.deliveryUserId)
        if (assignedOrder) {
          const riders: any[] = await prisma.$queryRaw`
            SELECT id, name, phone FROM users WHERE id = ${assignedOrder.deliveryUserId} LIMIT 1
          `
          if (riders.length > 0) {
            deliveryUser = {
              name: riders[0].name,
              phone: riders[0].phone
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

      const subOrders = combinedOrders.map(o => ({
        id: o.id,
        type: o.shopName === 'FastKirana Cafe Kitchen' ? 'CAFE' : o.shopName === 'FastKirana Restaurant Kitchen' ? 'RESTAURANT' : 'GROCERY',
        status: o.status,
        total: o.total,
        itemsCount: allItems.filter(item => item.orderId === o.id).length
      }))

      const mergedOrder = {
        ...order,
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
        subOrders
      }
      return NextResponse.json(mergedOrder)
    }

    // Default individual order details for workers or non-combined orders
    const items = await prisma.orderItem.findMany({
      where: { orderId: id },
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
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { id } = await params
    const { status, deliveryPhoto, deliveryLat, deliveryLng, prepTime } = await request.json()

    if (!status || !VALID_STATUSES.includes(status)) {
      return NextResponse.json({ error: 'Invalid order status' }, { status: 400 })
    }

    // Check order exists and ownership
    const existingOrders: any[] = await prisma.$queryRaw`
      SELECT id, "userId", status::text as status, "assignedPickerId", "assignedChefId", "deliveryUserId", "shopName" FROM orders WHERE id = ${id} LIMIT 1
    `

    if (existingOrders.length === 0) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const existingOrder = existingOrders[0]

    // Riders and admins can edit order status. Customers can only view or cancel.
    if (existingOrder.userId !== session.user.id && session.user.role !== 'ADMIN' && session.user.role !== 'DELIVERY' && session.user.role !== 'PICKER' && session.user.role !== 'CHEF') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Claim checks / locking mechanisms
    if (status === 'CONFIRMED') {
      if (session.user.role === 'CHEF' || existingOrder.shopName === 'FastKirana Cafe Kitchen' || existingOrder.shopName === 'FastKirana Restaurant Kitchen') {
        if (existingOrder.assignedChefId && existingOrder.assignedChefId !== session.user.id) {
          return NextResponse.json({ error: 'Order is already claimed by another chef' }, { status: 409 })
        }
      } else {
        if (existingOrder.assignedPickerId && existingOrder.assignedPickerId !== session.user.id) {
          return NextResponse.json({ error: 'Order is already claimed by another picker' }, { status: 409 })
        }
      }
    }

    if (status === 'SHIPPED') {
      if (existingOrder.deliveryUserId && existingOrder.deliveryUserId !== session.user.id) {
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
            console.log(`[Inventory Sync] Deducted ${item.quantity} units of ${product.name}. New stock: ${newStock}`)
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
            console.log(`[Cloudinary Upload] Uploading photo for order ${id} to cloud: ${cloudName}...`)
            const cloudinaryUrl = await uploadToCloudinary(deliveryPhoto, cloudName, uploadPreset)
            finalDeliveryPhoto = cloudinaryUrl
            console.log(`[Cloudinary Upload] Successfully uploaded delivery photo. URL: ${cloudinaryUrl}`)
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

      await prisma.$executeRaw`
        UPDATE orders 
        SET status = ${status}::"OrderStatus", 
            "deliveryPhoto" = ${safePhoto}, 
            "deliveryLat" = ${deliveryLat !== undefined && deliveryLat !== null ? parseFloat(deliveryLat) : null}, 
            "deliveryLng" = ${deliveryLng !== undefined && deliveryLng !== null ? parseFloat(deliveryLng) : null}, 
            "deliveredAt" = NOW(),
            "updatedAt" = NOW() 
        WHERE id = ${id}
      `
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
              "deliveryUserId" = ${session.user.id},
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

      if (session.user.role === 'CHEF' || existingOrder.shopName === 'FastKirana Cafe Kitchen' || existingOrder.shopName === 'FastKirana Restaurant Kitchen') {
        await prisma.$executeRaw`
          UPDATE orders 
          SET status = ${status}::"OrderStatus", 
              "assignedChefId" = ${session.user.id},
              "confirmedAt" = NOW(),
              "estimatedDelivery" = ${estimatedDeliveryVal},
              "updatedAt" = NOW() 
          WHERE id = ${id}
        `
      } else {
        await prisma.$executeRaw`
          UPDATE orders 
          SET status = ${status}::"OrderStatus", 
              "assignedPickerId" = ${session.user.id},
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
            console.log(`[Inventory Sync] Restored ${item.quantity} units of ${product.name} due to cancellation.`)
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
        PACKED: 'Packed & Ready to Go 📦',
        SHIPPED: 'Out for Delivery 🚴',
        DELIVERED: 'Delivered Successfully 🎉',
        CANCELLED: 'Cancelled ❌',
      }
      
      const statusTitle = `Order Update: ${statusLabels[status] || status}`
      const statusBody = `Your FastKirana order #${id.slice(-6).toUpperCase()} is now ${statusLabels[status] || status}.`
      
      const origin = request.headers.get('origin') || 'https://fastkirana.com'
      
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
        title: `Order #${id.slice(-6).toUpperCase()} Updated 🔄`,
        body: `Order status changed to ${statusLabels[status] || status}.`,
        icon: `${origin}/icons/icon-192.png`,
        badge: `${origin}/icons/icon-192.png`,
        tag: `order-${id}-update`,
        renotify: true,
        data: { orderId: id }
      }).catch(err => console.error('Background sendPushNotificationToRoles error:', err))

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
