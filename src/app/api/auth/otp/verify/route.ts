import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { authLimiter } from '@/lib/rate-limit'
import { isValidIndianPhone, normalizePhone, getLast10Digits } from '@/lib/phone'

export async function OPTIONS() {
  return new NextResponse(null, {
    status: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    },
  })
}

export async function POST(request: NextRequest) {
  const limited = await authLimiter.check(request)
  if (limited) return limited

  try {
    const { email: rawEmail, otp } = await request.json()

    if (!rawEmail || !otp) {
      return NextResponse.json({ error: 'Email/phone and OTP are required' }, { status: 400 })
    }

    const trimmed = rawEmail.trim()
    let normalizedEmail = trimmed.toLowerCase()

    if (isValidIndianPhone(trimmed)) {
      const normalizedPhone = normalizePhone(trimmed)
      const existingUser = await prisma.user.findFirst({
        where: { phone: normalizedPhone },
        select: { email: true }
      })
      if (existingUser) {
        normalizedEmail = existingUser.email
      } else {
        const phoneDigits = getLast10Digits(normalizedPhone)
        normalizedEmail = `wa-${phoneDigits}@fastkirana.com`
      }
    }

    // 1. Find the OTP token
    const otpRecord = await prisma.otpToken.findFirst({
      where: {
        email: normalizedEmail,
        token: otp,
        expiresAt: { gt: new Date() }
      }
    })

    if (!otpRecord) {
      return NextResponse.json({ error: 'Invalid or expired OTP code' }, { status: 400 })
    }

    // 2. Check if user exists and has name and phone
    let user = await prisma.user.findFirst({
      where: {
        OR: [
          { email: normalizedEmail },
          isValidIndianPhone(trimmed) ? { phone: normalizePhone(trimmed) } : null
        ].filter(Boolean) as any
      }
    })

    if (!user) {
      const phoneDigits = isValidIndianPhone(trimmed) ? getLast10Digits(trimmed) : null
      user = await prisma.user.create({
        data: {
          email: normalizedEmail,
          phone: isValidIndianPhone(trimmed) ? normalizePhone(trimmed) : null,
          name: phoneDigits ? `User ${phoneDigits.slice(-4)}` : 'Customer',
          role: 'USER',
        }
      })
    }

    const needsProfileSetup = !user || !user.name || !user.phone

    // Delete used OTP token
    await prisma.otpToken.deleteMany({
      where: { email: normalizedEmail }
    })

    return NextResponse.json({
      success: true,
      needsProfileSetup,
      token: `token_${user.id}_${Date.now()}`,
      user: {
        id: user.id,
        name: user.name || 'Customer',
        email: user.email,
        phone: user.phone || trimmed,
        role: user.role,
        isBlocked: user.isBlocked,
      }
    })
  } catch (error: any) {
    console.error('OTP Verify API error:', error)
    return NextResponse.json({ error: 'Failed to verify OTP code' }, { status: 500 })
  }
}
