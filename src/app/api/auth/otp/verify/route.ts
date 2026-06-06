import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function POST(request: NextRequest) {
  try {
    const { email, otp } = await request.json()

    if (!email || !otp) {
      return NextResponse.json({ error: 'Email and OTP are required' }, { status: 400 })
    }

    const normalizedEmail = email.toLowerCase().trim()

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
