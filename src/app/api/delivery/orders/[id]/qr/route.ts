import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export const dynamic = 'force-dynamic'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { id } = await params
    const order = await prisma.order.findUnique({
      where: { id },
      select: {
        id: true,
        readableId: true,
        total: true,
        paymentMethod: true,
        paymentStatus: true,
        status: true,
        shopName: true
      }
    })

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    // Fetch store UPI ID setting
    const storeUpiSetting = await prisma.storeSetting.findUnique({
      where: { key: 'contact_phone' }
    })
    const upiVpaSetting = await prisma.storeSetting.findUnique({
      where: { key: 'store_upi_vpa' }
    })

    const upiVpa = upiVpaSetting?.value || '7054470303@paytm' // Default store UPI VPA
    const payeeName = encodeURIComponent('FastKirana Store')
    const note = encodeURIComponent(`Payment for Order #${order.readableId || order.id.slice(0, 8)}`)
    const amount = order.total.toFixed(2)
    const tr = `FK${order.readableId || order.id.slice(0, 8)}`

    // Standard NPCI UPI Intent URI format
    const upiUri = `upi://pay?pa=${upiVpa}&pn=${payeeName}&am=${amount}&cu=INR&tn=${note}&tr=${tr}`

    // Standard Google Chart QR Code API for high-resolution QR rendering
    const qrImageUrl = `https://api.qrserver.com/v1/create-qr-code/?size=280x280&data=${encodeURIComponent(upiUri)}`

    return NextResponse.json({
      orderId: order.id,
      readableId: order.readableId,
      amount: order.total,
      upiVpa,
      upiUri,
      qrImageUrl,
      paymentStatus: order.paymentStatus,
      paymentMethod: order.paymentMethod
    })

  } catch (err: any) {
    console.error('Error generating doorstep QR:', err)
    return NextResponse.json({ error: err.message || 'Server error' }, { status: 500 })
  }
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { id } = await params
    const { referenceId } = await request.json()

    const order = await prisma.order.findUnique({
      where: { id }
    })

    if (!order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    // Convert payment method to UPI and mark paymentStatus as PAID
    const updatedOrder = await prisma.order.update({
      where: { id },
      data: {
        paymentMethod: 'UPI',
        paymentStatus: 'PAID',
        notes: order.notes 
          ? `${order.notes} | Doorstep UPI Paid (Ref: ${referenceId || 'QR Scan'})`
          : `Doorstep UPI Paid (Ref: ${referenceId || 'QR Scan'})`
      }
    })

    return NextResponse.json({
      success: true,
      order: updatedOrder,
      message: 'Payment converted to UPI successfully!'
    })

  } catch (err: any) {
    console.error('Error converting doorstep QR payment:', err)
    return NextResponse.json({ error: err.message || 'Failed to confirm UPI payment' }, { status: 500 })
  }
}
