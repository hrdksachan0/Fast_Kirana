import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { authLimiter } from '@/lib/rate-limit'

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
      const normalizedPhone = getNormalizedPhone(trimmed)
      const existingUser = await prisma.user.findFirst({
        where: { phone: normalizedPhone },
        select: { email: true }
      })
      if (existingUser) {
        normalizedEmail = existingUser.email
      } else {
        const phoneDigits = normalizedPhone.replace(/\D/g, '').replace(/^91/, '')
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
    const user = await prisma.user.findUnique({
      where: { email: normalizedEmail },
      select: { name: true, phone: true }
    })

    const needsProfileSetup = !user || !user.name || !user.phone

    return NextResponse.json({
      success: true,
      needsProfileSetup
    })
  } catch (error: any) {
    console.error('OTP Verify API error:', error)
    return NextResponse.json({ error: 'Failed to verify OTP code' }, { status: 500 })
  }
}
