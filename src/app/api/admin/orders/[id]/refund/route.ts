import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth-guard'
import { sseEmitter } from '@/lib/sse-emitter'
import { createCashfreeRefund } from '@/lib/cashfree'

export async function POST(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error

  try {
    const { id } = await params
    const body = await request.json().catch(() => ({}))
    const { amount, itemId, reason } = body

    const refundValue = parseFloat(amount)
    if (isNaN(refundValue) || refundValue <= 0) {
      return NextResponse.json(
        { error: 'Valid refund amount greater than 0 is required' },
        { status: 400 }
      )
    }

    // Find the target order
    const order = await prisma.order.findFirst({
      where: {
        OR: [{ id }, { readableId: id }]
      },
      include: {
        items: true
      }
    })

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const currentRefundTotal = order.refundAmount || 0
    const remainingBalance = Math.max(0, (order.total || 0) - currentRefundTotal)
    if (refundValue > remainingBalance + 0.01) {
      return NextResponse.json(
        { error: `Refund amount (₹${refundValue}) exceeds remaining order balance of ₹${remainingBalance.toFixed(2)}` },
        { status: 400 }
      )
    }

    let refundedItemName = ''
    if (itemId) {
      const targetItem = order.items.find(i => i.id === itemId)
      if (targetItem) {
        const itemLineTotal = (targetItem.price || 0) * (targetItem.quantity || 1)
        const itemAlreadyRefunded = targetItem.refundAmount || 0
        if (itemAlreadyRefunded >= itemLineTotal) {
          return NextResponse.json(
            { error: `Item '${targetItem.name}' is already fully refunded.` },
            { status: 400 }
          )
        }

        const newItemRefund = itemAlreadyRefunded + refundValue
        refundedItemName = targetItem.name
        await prisma.orderItem.update({
          where: { id: itemId },
          data: {
            refundAmount: newItemRefund,
            isRefunded: newItemRefund >= (itemLineTotal - 0.01),
            notes: targetItem.notes
              ? `${targetItem.notes} | ₹${refundValue} Refunded`
              : `₹${refundValue} Refunded`
          }
        })
      }
    }

    // Check if order was paid online via Cashfree Payment Gateway
    let gatewayRefundNote = ''
    let isGatewayRefundInitiated = false
    const isOnlinePaid =
      (order.paymentMethod !== 'COD' && order.paymentStatus === 'PAID') ||
      Boolean(order.cfOrderId) ||
      Boolean(order.notes?.includes('Cashfree'))

    if (isOnlinePaid && (order.cfOrderId || order.id)) {
      try {
        const targetCfOrderId = order.cfOrderId || order.id
        const cfRes = await createCashfreeRefund({
          orderId: targetCfOrderId,
          amount: refundValue,
          refundNote: reason || `Refund for ${refundedItemName || `Order #${order.readableId || order.id}`}`
        })
        isGatewayRefundInitiated = true
        gatewayRefundNote = ` [Cashfree Refund Ref: ${cfRes.cf_refund_id || cfRes.refund_id}]`
      } catch (cfErr: any) {
        console.warn('Cashfree automated gateway refund call failed:', cfErr.message)
        gatewayRefundNote = ` [Manual/Offline Record: ${cfErr.message?.slice(0, 80)}]`
      }
    }

    const newRefundTotal = currentRefundTotal + refundValue
    const isFullRefund = newRefundTotal >= ((order.total || 0) - 0.01)

    const cleanReason = reason && !reason.toLowerCase().includes(refundedItemName.toLowerCase())
      ? ` - ${reason.trim()}`
      : ''
    const refundNote = `₹${refundValue.toFixed(2)} Refunded${refundedItemName ? ` (${refundedItemName})` : ''}${cleanReason}${gatewayRefundNote}`
    const updatedNotes = order.notes
      ? `${order.notes}\n${refundNote}`
      : refundNote

    const updatedOrder = await prisma.order.update({
      where: { id: order.id },
      data: {
        refundAmount: newRefundTotal,
        notes: updatedNotes,
        ...(isFullRefund ? { paymentStatus: 'REFUNDED' } : {})
      },
      include: {
        items: true
      }
    })

    // Broadcast SSE update so Admin and Customer views update in real-time
    sseEmitter.emit('order:updated', {
      orderId: updatedOrder.id,
      readableId: updatedOrder.readableId,
      refundAmount: updatedOrder.refundAmount,
      status: updatedOrder.status,
      paymentStatus: updatedOrder.paymentStatus,
      notes: updatedOrder.notes
    })

    return NextResponse.json({
      success: true,
      isGatewayRefundInitiated,
      message: isGatewayRefundInitiated
        ? `Refund of ₹${refundValue.toFixed(2)} processed via Cashfree Gateway to customer's account!`
        : `Recorded refund of ₹${refundValue.toFixed(2)} successfully (ledger updated).`,
      order: updatedOrder
    })
  } catch (error: any) {
    console.error('Error recording refund:', error)
    return NextResponse.json(
      { error: 'Failed to record refund', details: error.message || error },
      { status: 500 }
    )
  }
}
