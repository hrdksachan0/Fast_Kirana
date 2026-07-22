import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function PATCH(request: Request) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized. Admin access required.' }, { status: 401 })
  }

  try {
    const { userId, isBlocked, blockReason } = await request.json()

    if (!userId || typeof isBlocked !== 'boolean') {
      return NextResponse.json({ error: 'Missing required parameters: userId and isBlocked boolean' }, { status: 400 })
    }

    const targetUser = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, name: true, email: true, role: true, isBlocked: true }
    })

    if (!targetUser) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 })
    }

    if (targetUser.role === 'ADMIN') {
      return NextResponse.json({ error: 'Administrator accounts cannot be blocked.' }, { status: 400 })
    }

    if (targetUser.id === session.user.id) {
      return NextResponse.json({ error: 'You cannot block your own admin account.' }, { status: 400 })
    }

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: {
        isBlocked,
        blockReason: isBlocked ? (blockReason?.trim() || 'Blocked by administrator') : null,
        blockedAt: isBlocked ? new Date() : null,
      },
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        role: true,
        isBlocked: true,
        blockReason: true,
        blockedAt: true,
      }
    })

    return NextResponse.json({
      success: true,
      message: isBlocked
        ? `Account for ${updatedUser.name || updatedUser.email} has been blocked.`
        : `Account for ${updatedUser.name || updatedUser.email} has been unblocked.`,
      user: updatedUser
    })
  } catch (error: any) {
    console.error('Failed to update customer block status:', error)
    return NextResponse.json({ error: 'Failed to update customer block status' }, { status: 500 })
  }
}
