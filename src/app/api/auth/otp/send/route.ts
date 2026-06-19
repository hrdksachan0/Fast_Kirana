import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { sendOtpEmail } from '@/lib/mail'
import { sendWhatsAppOtp } from '@/lib/whatsapp'
import { otpLimiter } from '@/lib/rate-limit'

export async function POST(request: NextRequest) {
  const limited = await otpLimiter.check(request)
  if (limited) return limited

  try {
    const { email: rawEmail } = await request.json()

    if (!rawEmail || typeof rawEmail !== 'string') {
      return NextResponse.json({ error: 'Email or mobile number is required' }, { status: 400 })
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
    } else if (!trimmed.includes('@')) {
      return NextResponse.json({ error: 'Please enter a valid email address or 10-digit mobile number' }, { status: 400 })
    }

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

    // 5. Send OTP via Fast2SMS with WhatsApp fallback
    let isSent = false
    if (normalizedEmail.startsWith('wa-')) {
      const phoneDigits = normalizedEmail.split('@')[0].replace('wa-', '')
      const recipientPhone = `+91${phoneDigits}`
      isSent = await sendWhatsAppOtp(recipientPhone, otp)
      if (!isSent) {
        return NextResponse.json({ error: 'Failed to send OTP via WhatsApp. Please check your number or try again later.' }, { status: 500 })
      }
    } else {
      return NextResponse.json({ error: 'Email OTP is not supported. Please log in using a Mobile Number or Google Sign-In.' }, { status: 400 })
    }

    // Do not return the OTP in the response payload for security
    const responseData: Record<string, any> = { success: true }

    return NextResponse.json(responseData)
  } catch (error: any) {
    console.error('OTP Send API error:', error)
    return NextResponse.json({ error: 'Failed to send OTP code' }, { status: 500 })
  }
}
