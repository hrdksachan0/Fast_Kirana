import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET() {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const users = await prisma.user.findMany({
      orderBy: {
        createdAt: 'desc',
      },
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        role: true,
        createdAt: true,
        _count: {
          select: { orders: true },
        },
      },
    })
    return NextResponse.json(users)
  } catch (error: any) {
    console.error('Failed to fetch users:', error)
    return NextResponse.json({ error: 'Failed to fetch users' }, { status: 500 })
  }
}

export async function PATCH(request: Request) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const { userId, role } = await request.json()

    if (!userId || !role) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    if (role !== 'USER' && role !== 'DELIVERY' && role !== 'ADMIN' && role !== 'PICKER' && role !== 'CHEF') {
      return NextResponse.json({ error: 'Invalid role' }, { status: 400 })
    }

    // Update using raw SQL to bypass PrismaPg enum casting issue
    await prisma.$executeRaw`
      UPDATE users SET role = ${role}::"Role", "updatedAt" = NOW() WHERE id = ${userId}
    `

    return NextResponse.json({ success: true, message: 'User role updated successfully' })
  } catch (error: any) {
    console.error('Failed to update user role:', error)
    return NextResponse.json({ error: 'Failed to update user role' }, { status: 500 })
  }
}
