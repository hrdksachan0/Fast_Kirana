import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { sendPushNotification } from '@/lib/push-notification'

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
      SELECT o.id, o."userId", o."addressId",
             o.status::text as status,
             o.subtotal, o.discount, o."deliveryFee", o.taxes, o.total,
             o."paymentMethod"::text as "paymentMethod",
             o."paymentStatus"::text as "paymentStatus",
             o."estimatedDelivery", o."createdAt", o."updatedAt",
             o."deliveryMethod", o."isB2B", o."shopName", o."shopPhone"
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

    // Fetch items
    const items = await prisma.orderItem.findMany({
      where: { orderId: id },
    })

    // Fetch address
    const address = await prisma.address.findUnique({
      where: { id: order.addressId },
    })

    return NextResponse.json({ ...order, items, address })
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
    const { status, deliveryPhoto, deliveryLat, deliveryLng } = await request.json()

    if (!status || !VALID_STATUSES.includes(status)) {
      return NextResponse.json({ error: 'Invalid order status' }, { status: 400 })
    }

    // Check order exists and ownership
    const existingOrders: any[] = await prisma.$queryRaw`
      SELECT id, "userId", status::text as status FROM orders WHERE id = ${id} LIMIT 1
    `

    if (existingOrders.length === 0) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const existingOrder = existingOrders[0]

    // Riders and admins can edit order status. Customers can only view or cancel.
    if (existingOrder.userId !== session.user.id && session.user.role !== 'ADMIN' && session.user.role !== 'DELIVERY' && session.user.role !== 'PICKER' && session.user.role !== 'CHEF') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Deduct stock if order is being PACKED (picked) and was not PACKED previously
    if (status === 'PACKED' && existingOrder.status !== 'PACKED') {
      try {
        const orderItems = await prisma.orderItem.findMany({
          where: { orderId: id },
        })
        
        for (const item of orderItems) {
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
      await prisma.$executeRaw`
        UPDATE orders 
        SET status = ${status}::"OrderStatus", 
            "deliveryPhoto" = ${finalDeliveryPhoto}, 
            "deliveryLat" = ${deliveryLat !== undefined && deliveryLat !== null ? parseFloat(deliveryLat) : null}, 
            "deliveryLng" = ${deliveryLng !== undefined && deliveryLng !== null ? parseFloat(deliveryLng) : null}, 
            "updatedAt" = NOW() 
        WHERE id = ${id}
      `
    } else if (status === 'SHIPPED') {
      await prisma.$executeRaw`
        UPDATE orders 
        SET status = ${status}::"OrderStatus", 
            "deliveryUserId" = ${session.user.id},
            "updatedAt" = NOW() 
        WHERE id = ${id}
      `
    } else {
      await prisma.$executeRaw`
        UPDATE orders SET status = ${status}::"OrderStatus", "updatedAt" = NOW() WHERE id = ${id}
      `
    }

    // Trigger PWA Push Notification for customer
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
      
      sendPushNotification(existingOrder.userId, {
        title: statusTitle,
        body: statusBody,
        data: { orderId: id }
      }).catch(err => console.error('Background sendPushNotification error:', err))
    } catch (pushErr) {
      console.error('Failed to dispatch push notification:', pushErr)
    }

    // Return updated order
    const updated: any[] = await prisma.$queryRaw`
      SELECT id, status::text as status, total, "createdAt", "updatedAt", "deliveryPhoto", "deliveryLat", "deliveryLng"
      FROM orders WHERE id = ${id} LIMIT 1
    `

    return NextResponse.json(updated[0])
  } catch (error) {
    console.error('Order status update error:', error)
    return NextResponse.json({ error: 'Failed to update order status' }, { status: 500 })
  }
}
