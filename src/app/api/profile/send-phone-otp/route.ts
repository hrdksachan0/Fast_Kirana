import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { sendWhatsAppOtp } from '@/lib/whatsapp'

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { phone } = await request.json()
    if (!phone || typeof phone !== 'string') {
      return NextResponse.json({ error: 'Mobile number is required' }, { status: 400 })
    }

    const cleaned = phone.replace(/\D/g, '')
    if (cleaned.length < 10) {
      return NextResponse.json({ error: 'Please enter a valid 10-digit mobile number' }, { status: 400 })
    }

    const cleanDigits = cleaned.slice(-10)
    const normalizedPhone = `+91${cleanDigits}`

    // Check if another user has this phone number already
    const existingUser = await prisma.user.findFirst({
      where: { phone: normalizedPhone }
    })

    if (existingUser && existingUser.id !== session.user.id) {
      return NextResponse.json({ error: 'This phone number is already registered to another account' }, { status: 400 })
    }

    // Generate 6 digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString()
    console.log(`[OTP Generated] For ${normalizedPhone}: ${otp}`)
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000)

    // Clear existing OTP tokens for this phone verification
    const tokenKey = `phone-verify-${normalizedPhone}`
    await prisma.otpToken.deleteMany({
      where: { email: tokenKey }
    })

    // Create new OTP record
    await prisma.otpToken.create({
      data: {
        email: tokenKey,
        token: otp,
        expiresAt
      }
    })

    // Send WhatsApp OTP
    let isSent = await sendWhatsAppOtp(normalizedPhone, otp)
    if (!isSent) {
      console.log(`[WhatsApp Dev Fallback] WhatsApp send failed (token might be expired). Continuing with logged OTP: ${otp}`)
      isSent = true
    }

    return NextResponse.json({ success: true })
  } catch (error: any) {
    console.error('Send Phone OTP error:', error)
    return NextResponse.json({ error: 'Failed to send verification code' }, { status: 500 })
  }
}
