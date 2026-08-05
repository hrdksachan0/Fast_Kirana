import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth-guard'

export async function GET() {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const users = await prisma.user.findMany({
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        role: true,
        assignedRestaurantId: true,
        image: true,
      },
      orderBy: {
        name: 'asc',
      },
    })

    return NextResponse.json(users)
  } catch (error: any) {
    console.error('Failed to fetch assignable users:', error)
    return NextResponse.json({ error: 'Failed to fetch users' }, { status: 500 })
  }
}
