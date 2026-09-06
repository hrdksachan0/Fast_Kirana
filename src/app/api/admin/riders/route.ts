import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function GET() {
  try {
    const riders = await prisma.user.findMany({
      where: {
        role: 'DELIVERY',
      },
      select: {
        id: true,
        name: true,
        phone: true,
        email: true,
        role: true,
      },
      orderBy: { name: 'asc' },
    })

    return NextResponse.json({
      success: true,
      riders: riders.map((r) => ({
        id: r.id,
        name: r.name || 'Delivery Partner',
        phone: r.phone || '+919696503759',
        role: r.role,
      })),
    })
  } catch (error: any) {
    console.error('Error fetching riders:', error)
    return NextResponse.json({ error: 'Failed to fetch riders' }, { status: 500 })
  }
}
