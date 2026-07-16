import { NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { sendPushNotification } from '@/lib/push-notification'
import { sseEmitter } from '@/lib/sse-emitter'

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { id } = await params
    const { updatedItems, outOfStockProductIds } = await request.json()

    if (!Array.isArray(updatedItems)) {
      return NextResponse.json({ error: 'updatedItems must be an array' }, { status: 400 })
    }

    // 1. Fetch current order
    const order = await prisma.order.findUnique({
      where: { id },
      include: { items: true, user: true }
    })

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    // Strict constraint: Can only edit before confirmation (status must be PENDING)
    if (order.status !== 'PENDING') {
      return NextResponse.json({ error: 'Order is already confirmed and cannot be edited' }, { status: 400 })
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
      where: { orderId: id }
    })

    // 5. Create new OrderItems and deduct stock
    let subtotalVal = 0

    for (const item of updatedItems) {
      if (item.quantity <= 0) continue // Skip removed items
      
      const product = await prisma.product.findUnique({
        where: { id: item.productId },
        include: { category: true }
      })

      if (!product) continue

      subtotalVal += product.price * item.quantity

      await prisma.orderItem.create({
        data: {
          orderId: id,
          productId: item.productId,
          name: product.name,
          price: product.price,
          quantity: item.quantity,
          selectedVariant: item.selectedVariant || null,
          imageUrl: product.imageUrl,
          notes: item.notes || null,
          costPrice: product.costPrice || 0
        }
      })

      // Skip kitchen items for stock deduction
      if (product.category?.slug === 'cafe' || product.category?.slug === 'restaurant' || product.tags?.includes('cafe') || product.tags?.includes('restaurant')) {
        continue
      }

      // Deduct stock for grocery/medical items
      if (item.selectedVariant) {
        if (product.variants && Array.isArray(product.variants)) {
          const updatedVariants = (product.variants as any[]).map((v) => {
            if (v.name === item.selectedVariant) {
              return { ...v, stock: Math.max(0, v.stock - item.quantity) }
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
          where: { productId: item.productId, quantity: { gt: 0 } },
          orderBy: { expiryDate: 'asc' }
        })
        let remaining = item.quantity
        for (const b of batches) {
          if (remaining <= 0) break
          const deduct = Math.min(b.quantity, remaining)
          await prisma.productBatch.update({
            where: { id: b.id },
            data: { quantity: { decrement: deduct } }
          })
          remaining -= deduct
        }
        const activeBatches = await prisma.productBatch.findMany({
          where: { productId: item.productId, quantity: { gt: 0 } }
        })
        const newTotalStock = activeBatches.reduce((sum, b) => sum + b.quantity, 0)
        await prisma.product.update({
          where: { id: item.productId },
          data: { stock: newTotalStock }
        })
      }
    }

    // 6. Recalculate Order totals
    const taxesVal = parseFloat((subtotalVal * 0.05).toFixed(2)) // 5% taxes
    const totalVal = subtotalVal + order.deliveryFee + taxesVal - order.discount

    await prisma.order.update({
      where: { id },
      data: {
        subtotal: subtotalVal,
        taxes: taxesVal,
        total: totalVal
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
          body: `Due to unavailability, "${names}" has been removed from order #${id.slice(-6).toUpperCase()}. Your bill total has been adjusted.`,
          icon: `${origin}/icons/icon-192.png`,
          badge: `${origin}/icons/icon-192.png`,
          tag: `order-${id}`,
          renotify: true,
          data: { orderId: id }
        }).catch(err => console.error('Push notification error:', err))
      } catch (notifyErr) {
        console.error('Failed to send out of stock notification:', notifyErr)
      }
    }

    // 8. Broadcast update to SSE clients
    sseEmitter.emit('message', {
      type: 'order-edited',
      orderId: id,
      shopName: order.shopName
    })

    return NextResponse.json({ success: true, total: totalVal })
  } catch (err: any) {
    console.error('Order edit API error:', err)
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 })
  }
}
