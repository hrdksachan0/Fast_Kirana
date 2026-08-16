import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

export async function POST(request: NextRequest) {
  try {
    const session = await auth()

    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { name } = await request.json()

    if (!name || typeof name !== 'string' || !name.trim()) {
      return NextResponse.json({ error: 'Name cannot be empty' }, { status: 400 })
    }

    const trimmedName = name.trim()
    if (trimmedName.length > 60) {
      return NextResponse.json({ error: 'Name is too long (maximum 60 characters)' }, { status: 400 })
    }

    await prisma.user.update({
      where: { id: session.user.id },
      data: {
        name: trimmedName,
      },
    })

    return NextResponse.json({
      success: true,
      name: trimmedName,
      message: 'Name updated successfully',
    })
  } catch (error) {
    console.error('Update name error:', error)
    return NextResponse.json({ error: 'Failed to update name' }, { status: 500 })
  }
}
