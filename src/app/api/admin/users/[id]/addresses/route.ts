import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { id } = await params
    const addresses = await prisma.address.findMany({
      where: { 
        userId: id,
        label: { notIn: ['STORE_PICKUP', 'STORE_PICKUP_RESTAURANT', 'STORE_PICKUP_CAFE'] }
      },
      orderBy: { isDefault: 'desc' }
    })
    return NextResponse.json(addresses)
  } catch (error) {
    console.error('Failed to fetch user addresses:', error)
    return NextResponse.json({ error: 'Failed to fetch addresses' }, { status: 500 })
  }
}
