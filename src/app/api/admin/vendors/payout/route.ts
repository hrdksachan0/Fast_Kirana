import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth-guard'

export const dynamic = 'force-dynamic'

export async function POST(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error

  try {
    const body = await request.json()
    const {
      vendorId,
      amount,
      startDate,
      endDate,
      paymentMethod = 'UPI',
      transactionId,
      notes,
      storeId,
    } = body

    if (!vendorId) {
      return NextResponse.json({ error: 'Vendor ID is required' }, { status: 400 })
    }

    const numAmount = parseFloat(amount)
    if (isNaN(numAmount) || numAmount <= 0) {
      return NextResponse.json({ error: 'Valid payment amount is required' }, { status: 400 })
    }

    const vendor = await (prisma as any).vendor.findUnique({
      where: { id: vendorId },
    })

    if (!vendor) {
      return NextResponse.json({ error: 'Vendor not found' }, { status: 404 })
    }

    const start = startDate ? new Date(startDate) : new Date()
    const end = endDate ? new Date(endDate) : new Date()

    const payout = await (prisma as any).vendorPayout.create({
      data: {
        vendorId,
        amount: numAmount,
        startDate: start,
        endDate: end,
        paymentMethod: paymentMethod.toUpperCase(),
        transactionId: transactionId?.trim() || null,
        notes: notes?.trim() || null,
        paidAt: new Date(),
        status: 'PAID',
        storeId: storeId || null,
      },
    })

    return NextResponse.json({ success: true, payout }, { status: 201 })
  } catch (error: any) {
    console.error('Error recording vendor payout:', error)
    return NextResponse.json({ error: error.message || 'Failed to record payout' }, { status: 500 })
  }
}

export async function DELETE(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error

  const { searchParams } = new URL(request.url)
  const payoutId = searchParams.get('payoutId')

  if (!payoutId) {
    return NextResponse.json({ error: 'Payout ID is required' }, { status: 400 })
  }

  try {
    await (prisma as any).vendorPayout.delete({
      where: { id: payoutId },
    })

    return NextResponse.json({ success: true, message: 'Payout deleted successfully' })
  } catch (error: any) {
    console.error('Error deleting payout:', error)
    return NextResponse.json({ error: error.message || 'Failed to delete payout' }, { status: 500 })
  }
}
