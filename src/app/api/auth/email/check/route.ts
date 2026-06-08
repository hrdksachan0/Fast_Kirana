import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { authLimiter } from '@/lib/rate-limit'

export async function POST(request: NextRequest) {
  const limited = authLimiter.check(request)
  if (limited) return limited

  try {
    const { email } = await request.json()

    if (!email || typeof email !== 'string' || !email.includes('@')) {
      return NextResponse.json({ error: 'Please enter a valid email address' }, { status: 400 })
    }

    const normalizedEmail = email.toLowerCase().trim()

    // Query database to check user existence, role, and password status
    const user = await prisma.user.findUnique({
      where: { email: normalizedEmail },
      select: { name: true, phone: true, role: true, passwordHash: true }
    })

    if (!user) {
      // New user — treat as customer, needs OTP flow
      return NextResponse.json({
        success: true,
        exists: false,
        isWorker: false,
        hasPassword: false,
        needsProfileSetup: true,
        role: 'USER',
      })
    }

    const isWorker = user.role !== 'USER'
    const hasPassword = !!user.passwordHash
    const needsProfileSetup = !user.name || !user.phone

    return NextResponse.json({
      success: true,
      exists: true,
      isWorker,
      hasPassword,
      needsProfileSetup,
      role: user.role,
    })
  } catch (error: any) {
    console.error('Email Check API error:', error)
    return NextResponse.json({ error: 'Failed to verify email registration status' }, { status: 500 })
  }
}
