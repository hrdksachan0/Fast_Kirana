import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    const { searchParams } = new URL(request.url)
    const storeId = searchParams.get('storeId') || (session?.user as any)?.assignedStoreId || null

    const where: any = {
      role: 'DELIVERY',
    }

    if (storeId && storeId !== 'all' && storeId !== 'ALL') {
      where.assignedStoreId = storeId
    }

    const riders = await prisma.user.findMany({
      where,
      select: {
        id: true,
        name: true,
        phone: true,
        email: true,
        role: true,
        assignedStoreId: true,
      },
      orderBy: { name: 'asc' },
    })

    return NextResponse.json({
      success: true,
      riders: riders.map((r) => ({
        id: r.id,
        name: r.name || 'Delivery Partner',
        phone: r.phone || '',
        role: r.role,
        assignedStoreId: r.assignedStoreId,
      })),
    })
  } catch (error: any) {
    console.error('Error fetching riders:', error)
    return NextResponse.json({ error: 'Failed to fetch riders' }, { status: 500 })
  }
}
