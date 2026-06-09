import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { auth } from '@/auth';
import { sseEmitter } from '@/lib/sse-emitter';

export async function POST(request: NextRequest) {
  const session = await auth();
  const userId = session?.user?.id;
  if (!userId) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const { orderId } = await request.json();
    if (!orderId) {
      return NextResponse.json({ error: 'Missing orderId' }, { status: 400 });
    }

    const order = await prisma.order.findUnique({
      where: { id: orderId }
    });

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 });
    }

    if (order.userId !== userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Update order status to PAID
    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        paymentStatus: 'PAID'
      }
    });

    // Emit live SSE event to pickers, chefs, and riders
    try {
      sseEmitter.emit('order', {
        type: 'status-change',
        orderId: orderId,
        status: updatedOrder.status,
        order: updatedOrder
      });
    } catch (sseErr) {
      console.error('Failed to emit SSE for paid order:', sseErr);
    }

    return NextResponse.json({ success: true });
  } catch (error: any) {
    console.error('Error in mock-success endpoint:', error);
    return NextResponse.json({ error: error.message || 'Internal server error' }, { status: 500 });
  }
}
