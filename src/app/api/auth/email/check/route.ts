import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { authLimiter } from '@/lib/rate-limit'

export async function POST(request: NextRequest) {
  const limited = authLimiter.check(request)
  if (limited) return limited

  try {
    const { email: rawEmail } = await request.json()

    if (!rawEmail || typeof rawEmail !== 'string') {
      return NextResponse.json({ error: 'Identifier is required' }, { status: 400 })
    }

    const trimmed = rawEmail.trim()
    let normalizedEmail = trimmed.toLowerCase()
    let isPhone = false
    let normalizedPhone = ''

    // Helper to check if it's a phone number
    const isPhoneNumber = (val: string) => {
      const cleaned = val.replace(/\D/g, '')
      return cleaned.length === 10 || (cleaned.length === 12 && cleaned.startsWith('91'))
    }

    const getNormalizedPhone = (val: string) => {
      const cleaned = val.replace(/\D/g, '')
      if (cleaned.length === 10) return `+91${cleaned}`
      if (cleaned.length === 12 && cleaned.startsWith('91')) return `+${cleaned}`
      return val
    }

    if (isPhoneNumber(trimmed)) {
      isPhone = true
      normalizedPhone = getNormalizedPhone(trimmed)
      
      // Check if user exists with this phone number
      const existingUser = await prisma.user.findFirst({
        where: { phone: normalizedPhone },
        select: { email: true, name: true, phone: true, role: true, passwordHash: true }
      })

      if (existingUser) {
        return NextResponse.json({
          success: true,
          exists: true,
          isWorker: existingUser.role !== 'USER',
          hasPassword: !!existingUser.passwordHash,
          needsProfileSetup: !existingUser.name || !existingUser.phone,
          role: existingUser.role,
          email: existingUser.email,
        })
      } else {
        // Generate placeholder email for the phone number
        const phoneDigits = normalizedPhone.replace(/\D/g, '').replace(/^91/, '')
        normalizedEmail = `wa-${phoneDigits}@fastkirana.com`
      }
    } else {
      // Validate email format
      if (!trimmed.includes('@')) {
        return NextResponse.json({ error: 'Please enter a valid email address or 10-digit WhatsApp number' }, { status: 400 })
      }
    }

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
        email: normalizedEmail,
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
      email: normalizedEmail,
    })
  } catch (error: any) {
    console.error('Email Check API error:', error)
    return NextResponse.json({ error: 'Failed to verify email registration status' }, { status: 500 })
  }
}
