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

    // Fetch order from database using raw SQL to avoid the enum deserialization bug
    const orders: any[] = await prisma.$queryRaw`
      SELECT o.id, o."userId", o.status::text as status
      FROM orders o WHERE o.id = ${orderId} LIMIT 1
    `

    if (orders.length === 0) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 });
    }

    const order = orders[0];

    if (order.userId !== userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    // Update order status to PAID using raw SQL
    await prisma.$executeRaw`
      UPDATE orders 
      SET "paymentStatus" = 'PAID'::"PaymentStatus",
          "updatedAt" = NOW()
      WHERE id = ${orderId}
    `

    const updatedOrders: any[] = await prisma.$queryRaw`
      SELECT o.id, o.status::text as status, o.total, o."createdAt", o."updatedAt"
      FROM orders o WHERE o.id = ${orderId} LIMIT 1
    `
    const updatedOrder = updatedOrders[0];

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
