import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { sendOtpEmail } from '@/lib/mail'

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { email } = await request.json()
    if (!email || typeof email !== 'string' || !email.includes('@')) {
      return NextResponse.json({ error: 'Please enter a valid email address' }, { status: 400 })
    }

    const normalizedEmail = email.trim().toLowerCase()

    // Check if another user has this email already
    const existingUser = await prisma.user.findUnique({
      where: { email: normalizedEmail }
    })

    if (existingUser && existingUser.id !== session.user.id) {
      return NextResponse.json({ error: 'This email is already registered to another account' }, { status: 400 })
    }

    // Generate 6 digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString()
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000)

    // Clear existing OTP tokens for this email
    await prisma.otpToken.deleteMany({
      where: { email: normalizedEmail }
    })

    // Create new OTP record
    await prisma.otpToken.create({
      data: {
        email: normalizedEmail,
        token: otp,
        expiresAt
      }
    })

    // Send the OTP
    await sendOtpEmail(normalizedEmail, otp)

    return NextResponse.json({ success: true })
  } catch (error: any) {
    console.error('Send Email OTP error:', error)
    return NextResponse.json({ error: 'Failed to send verification code' }, { status: 500 })
  }
}
