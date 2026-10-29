import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export const dynamic = 'force-dynamic'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  try {
    const payouts = await (prisma as any).vendorPayout.findMany({
      where: { vendorId: id },
      orderBy: { createdAt: 'desc' },
      take: 100,
    })
    return NextResponse.json({ success: true, payouts })
  } catch (error: any) {
    return NextResponse.json({ success: false, error: error.message, payouts: [] }, { status: 500 })
  }
}
