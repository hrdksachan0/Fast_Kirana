import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { sendOtpEmail } from '@/lib/mail'
import { sendWhatsAppOtp } from '@/lib/whatsapp'
import { otpLimiter } from '@/lib/rate-limit'
import { normalizePhone, getLast10Digits, isValidIndianPhone } from '@/lib/phone'

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
  const limited = await otpLimiter.check(request)
  if (limited) return limited

  try {
    const body = await request.json()
    const rawEmail = (body.email || body.phone || '').toString()

    if (!rawEmail || typeof rawEmail !== 'string') {
      return NextResponse.json({ error: 'Email or mobile number is required' }, { status: 400 })
    }

    const trimmed = rawEmail.trim()
    let normalizedEmail = trimmed.toLowerCase()

    // Helper to check if it's a phone number
    const isPhoneNumber = (val: string) => isValidIndianPhone(val)

    const getNormalizedPhone = (val: string) => normalizePhone(val)

    if (isPhoneNumber(trimmed)) {
      const normalizedPhone = getNormalizedPhone(trimmed)
      const phoneDigits = getLast10Digits(trimmed)
      const existingUser = await prisma.user.findFirst({
        where: {
          OR: [
            { phone: normalizedPhone },
            { phone: phoneDigits },
            { phone: `91${phoneDigits}` },
            { phone: `+91${phoneDigits}` },
            { email: `wa-${phoneDigits}@fastkirana.com` },
            { email: trimmed.toLowerCase() }
          ]
        },
        select: { email: true }
      })
      if (existingUser) {
        normalizedEmail = existingUser.email
      } else {
        normalizedEmail = `wa-${phoneDigits}@fastkirana.com`
      }
    } else if (!trimmed.includes('@')) {
      return NextResponse.json({ error: 'Please enter a valid email address or 10-digit mobile number' }, { status: 400 })
    }

    // Check if user account is blocked
    const phoneDigits = isPhoneNumber(trimmed) ? getLast10Digits(trimmed) : null
    const existingUserRecord = await prisma.user.findFirst({
      where: {
        OR: [
          { email: normalizedEmail },
          phoneDigits ? { phone: `+91${phoneDigits}` } : null,
          phoneDigits ? { phone: phoneDigits } : null,
        ].filter(Boolean) as any
      },
      select: { isBlocked: true, blockReason: true }
    })

    if (existingUserRecord?.isBlocked) {
      return NextResponse.json({
        error: `Your account has been blocked. ${existingUserRecord.blockReason ? `Reason: ${existingUserRecord.blockReason}` : 'Please contact customer support.'}`
      }, { status: 403 })
    }

    // 1. Generate a 6-digit numeric OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString()

    // 2. Set expiry to 5 minutes from now
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000)

    // 3. Clear any existing OTP tokens for this email and phone variants
    await prisma.otpToken.deleteMany({
      where: {
        OR: [
          { email: normalizedEmail },
          phoneDigits ? { email: `wa-${phoneDigits}@fastkirana.com` } : null,
          phoneDigits ? { email: phoneDigits } : null,
          phoneDigits ? { email: `+91${phoneDigits}` } : null,
        ].filter(Boolean) as any
      }
    })

    // 4. Create new OTP record
    await prisma.otpToken.create({
      data: {
        email: normalizedEmail,
        token: otp,
        expiresAt
      }
    })

    // 5. Send OTP via Meta WhatsApp Cloud API or Email
    const recipientPhoneDigits = phoneDigits || (normalizedEmail.startsWith('wa-') ? normalizedEmail.split('@')[0].replace('wa-', '') : null)

    if (recipientPhoneDigits) {
      const recipientPhone = `+91${recipientPhoneDigits}`
      const isSent = await sendWhatsAppOtp(recipientPhone, otp)

      if (!isSent) {
        console.error('Meta WhatsApp API OTP delivery failed for:', recipientPhone)
        return NextResponse.json({ error: 'Failed to send OTP via WhatsApp. Please check mobile number and try again.' }, { status: 500 })
      }
    } else {
      try {
        await sendOtpEmail(normalizedEmail, otp)
      } catch (err) {
        console.error('Failed to send OTP email:', err)
        return NextResponse.json({ error: 'Failed to send verification email. Please try again.' }, { status: 500 })
      }
    }

    // Strict Production Response: NEVER leak OTP in response payload
    return NextResponse.json({ success: true })
  } catch (error: any) {
    console.error('OTP Send API error:', error)
    return NextResponse.json({ error: 'Failed to send OTP code' }, { status: 500 })
  }
}
