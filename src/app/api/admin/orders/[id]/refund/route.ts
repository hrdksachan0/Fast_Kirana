import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth-guard'
import { sseEmitter } from '@/lib/sse-emitter'

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

    let refundedItemName = ''
    if (itemId) {
      const targetItem = order.items.find(i => i.id === itemId)
      if (targetItem) {
        refundedItemName = targetItem.name
        await prisma.orderItem.update({
          where: { id: itemId },
          data: {
            refundAmount: { increment: refundValue },
            isRefunded: true,
            notes: targetItem.notes
              ? `${targetItem.notes} | ₹${refundValue} Refunded`
              : `₹${refundValue} Refunded`
          }
        })
      }
    }

    const newRefundTotal = (order.refundAmount || 0) + refundValue
    const isFullRefund = newRefundTotal >= (order.total || 0)

    const refundNote = `₹${refundValue} Refunded${refundedItemName ? ` (${refundedItemName})` : ''}${reason ? ` - ${reason.trim()}` : ''}`
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
      message: `Recorded refund of ₹${refundValue} successfully`,
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
