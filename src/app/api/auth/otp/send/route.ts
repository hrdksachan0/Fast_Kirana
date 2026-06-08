import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { sendOtpEmail } from '@/lib/mail'
import { otpLimiter } from '@/lib/rate-limit'

export async function POST(request: NextRequest) {
  const limited = otpLimiter.check(request)
  if (limited) return limited

  try {
    const { email } = await request.json()

    if (!email || typeof email !== 'string' || !email.includes('@')) {
      return NextResponse.json({ error: 'Please enter a valid email address' }, { status: 400 })
    }

    const normalizedEmail = email.toLowerCase().trim()

    // 1. Generate a 6-digit numeric OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString()

    // 2. Set expiry to 5 minutes from now
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000)

    // 3. Clear any existing OTP tokens for this email
    await prisma.otpToken.deleteMany({
      where: { email: normalizedEmail }
    })

    // 4. Create new OTP record
    await prisma.otpToken.create({
      data: {
        email: normalizedEmail,
        token: otp,
        expiresAt
      }
    })

    // 5. Send OTP Email
    await sendOtpEmail(normalizedEmail, otp)

    // Return the OTP in development mode for easy testing without checking console logs
    const responseData: Record<string, any> = { success: true }
    if (process.env.NODE_ENV !== 'production') {
      responseData.otp = otp
    }

    return NextResponse.json(responseData)
  } catch (error: any) {
    console.error('OTP Send API error:', error)
    return NextResponse.json({ error: 'Failed to send OTP code' }, { status: 500 })
  }
}
