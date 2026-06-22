import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

// GET: Check if user already has profile data (used by setup-profile page to detect stale JWT)
export async function GET() {
  try {
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const user = await prisma.user.findUnique({
      where: { id: session.user.id },
      select: { name: true, phone: true },
    })

    return NextResponse.json({ name: user?.name || null, phone: user?.phone || null })
  } catch (error) {
    console.error('Profile setup GET error:', error)
    return NextResponse.json({ error: 'Failed to fetch profile' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await auth()

    if (!session || !session.user || !session.user.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { name, phone } = await request.json()

    if (!name || typeof name !== 'string' || !name.trim()) {
      return NextResponse.json({ error: 'Full name is required' }, { status: 400 })
    }

    if (!phone || typeof phone !== 'string' || phone.trim().length < 10) {
      return NextResponse.json({ error: 'Please enter a valid mobile number (at least 10 digits)' }, { status: 400 })
    }

    const userId = session.user.id
    const trimmedName = name.trim()
    const cleaned = phone.replace(/\D/g, '')
    const cleanDigits = cleaned.slice(-10)
    const normalizedPhone = `+91${cleanDigits}`

    // Update the user record
    await prisma.user.update({
      where: { id: userId },
      data: {
        name: trimmedName,
        phone: normalizedPhone,
      }
    })

    return NextResponse.json({
      success: true,
      message: 'Profile updated successfully'
    })
  } catch (error: any) {
    console.error('Profile setup API error:', error)
    return NextResponse.json({ error: 'Failed to save profile details' }, { status: 500 })
  }
}
