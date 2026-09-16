import { prisma } from '@/lib/prisma'
import { sendWhatsAppOrderAlert } from '@/lib/whatsapp'
import { sseEmitter } from '@/lib/sse-emitter'
import { logger } from '@/lib/logger'

export interface PaymentRecoverySummary {
  recoveredAlertsSent: number
  timedOutCancelled: number
  errors: string[]
}

/**
 * Enterprise Quick-Commerce Payment Recovery & Lifecycle Engine
 * Follows industry best practices (Swiggy/Zepto model):
 * 1. 2-10 min unpaid UPI attempts: Trigger automated WhatsApp recovery with direct COD / retry link.
 * 2. >10 min abandoned orders: Auto-cancel, restore reserved inventory, and notify client interfaces.
 */
export async function runPaymentRecoveryCron(): Promise<PaymentRecoverySummary> {
  const summary: PaymentRecoverySummary = {
    recoveredAlertsSent: 0,
    timedOutCancelled: 0,
    errors: [],
  }

  const now = new Date()
  const twoMinutesAgo = new Date(now.getTime() - 2 * 60 * 1000)
  const tenMinutesAgo = new Date(now.getTime() - 10 * 60 * 1000)

  // ---------------------------------------------------------------------------
  // STEP 1: WhatsApp Drop-off Recovery for Orders between 2 and 10 minutes old
  // ---------------------------------------------------------------------------
  try {
    const pendingRecoveryOrders = await prisma.order.findMany({
      where: {
        paymentMethod: 'UPI',
        paymentStatus: 'PENDING',
        status: 'PENDING',
        createdAt: {
          lte: twoMinutesAgo,
          gte: tenMinutesAgo,
        },
        OR: [
          { notes: null },
          { NOT: { notes: { contains: '[WA_RECOVERY_SENT]' } } },
        ],
      },
      include: {
        user: { select: { name: true, phone: true } },
      },
      take: 20,
    })

    for (const order of pendingRecoveryOrders) {
      const phone = order.user?.phone
      if (!phone) continue

      const cleanPhone = phone.replace(/[^0-9]/g, '')
      if (cleanPhone.length < 10) continue

      const customerName = order.user?.name || 'Customer'
      const displayId = order.readableId || order.id.slice(-6).toUpperCase()
      const totalFormatted = Math.round(order.total)
      const recoveryUrl = `https://fastkirana.com/order/${order.id}/track?action=cod`

      const messageText = 
        `🛒 *FastKirana Payment Alert*\n\n` +
        `Hi ${customerName}! Aapke order *#${displayId}* (₹${totalFormatted}) ka UPI payment pending hai.\n\n` +
        `Khana / Grocery turant dispatch karwane ke liye niche link par tap karke *Cash on Delivery (COD)* me convert karein ya payment retry karein:\n\n` +
        `👉 ${recoveryUrl}\n\n` +
        `_Kisi bhi sahayata ke liye is number par call/WhatsApp karein._`

      try {
        const sent = await sendWhatsAppOrderAlert(phone, messageText)
        if (sent) {
          summary.recoveredAlertsSent++
          // Append marker to notes to guarantee 100% deduplication
          const updatedNotes = order.notes 
            ? `${order.notes} [WA_RECOVERY_SENT]` 
            : '[WA_RECOVERY_SENT]'

          await prisma.order.update({
            where: { id: order.id },
            data: { notes: updatedNotes },
          })
          logger.info('payment-recovery', `WhatsApp recovery sent for Order #${displayId} to ${phone}`)
        }
      } catch (err: any) {
        summary.errors.push(`WhatsApp send failed for order ${order.id}: ${err?.message || err}`)
      }
    }
  } catch (err: any) {
    logger.error('payment-recovery', 'Step 1 WhatsApp recovery query error', err)
    summary.errors.push(`Recovery query failed: ${err?.message || err}`)
  }

  // ---------------------------------------------------------------------------
  // STEP 2: Auto-Timeout and Cancel Orders older than 10 minutes
  // ---------------------------------------------------------------------------
  try {
    const expiredOrders = await prisma.order.findMany({
      where: {
        paymentMethod: 'UPI',
        paymentStatus: 'PENDING',
        status: 'PENDING',
        createdAt: {
          lt: tenMinutesAgo,
        },
      },
      include: {
        items: true,
      },
      take: 50,
    })

    for (const order of expiredOrders) {
      try {
        const timeoutNotes = order.notes 
          ? `${order.notes} [PAYMENT_TIMEOUT: Auto-cancelled after 10m]`
          : '[PAYMENT_TIMEOUT: Auto-cancelled after 10m]'

        // 1. Mark order as CANCELLED in DB
        await prisma.order.update({
          where: { id: order.id },
          data: {
            status: 'CANCELLED',
            notes: timeoutNotes,
          },
        })

        // 2. Restore Grocery Stock for non-restaurant items
        for (const item of order.items) {
          if (!item.productId) continue

          const product = await prisma.product.findUnique({
            where: { id: item.productId },
            select: { id: true, stock: true, variants: true, restaurantId: true },
          })

          // Skip restaurants/cafes (they cook to order)
          if (!product || product.restaurantId) continue

          const prevStock = product.stock || 0

          if (item.selectedVariant && product.variants && Array.isArray(product.variants)) {
            const updatedVariants = (product.variants as any[]).map((v) => {
              if (v.name === item.selectedVariant) {
                return { ...v, stock: (Number(v.stock) || 0) + item.quantity }
              }
              return v
            })
            const newTotalStock = updatedVariants.reduce((sum, v) => sum + (Number(v.stock) || 0), 0)

            await prisma.product.update({
              where: { id: item.productId },
              data: { variants: updatedVariants, stock: newTotalStock },
            })

            await prisma.stockLog.create({
              data: {
                productId: item.productId,
                quantity: item.quantity,
                type: 'ORDER_CANCELLED',
                prevStock,
                newStock: newTotalStock,
              },
            }).catch(() => {})
          } else {
            const newTotalStock = prevStock + item.quantity
            await prisma.product.update({
              where: { id: item.productId },
              data: { stock: newTotalStock },
            })

            await prisma.stockLog.create({
              data: {
                productId: item.productId,
                quantity: item.quantity,
                type: 'ORDER_CANCELLED',
                prevStock,
                newStock: newTotalStock,
              },
            }).catch(() => {})
          }
        }

        // 3. Emit real-time cancellation event
        sseEmitter.emit('order', {
          type: 'order-updated',
          orderId: order.id,
          status: 'CANCELLED',
          readableId: order.readableId,
        })

        summary.timedOutCancelled++
        logger.info('payment-recovery', `Order #${order.readableId || order.id} auto-cancelled due to payment timeout.`)
      } catch (err: any) {
        summary.errors.push(`Order cancellation failed for ${order.id}: ${err?.message || err}`)
      }
    }
  } catch (err: any) {
    logger.error('payment-recovery', 'Step 2 Timeout cancellation query error', err)
    summary.errors.push(`Timeout query failed: ${err?.message || err}`)
  }

  return summary
}
