import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { sendOtpEmail } from '@/lib/mail'
import { sendWhatsAppOtp } from '@/lib/whatsapp'
import { otpLimiter } from '@/lib/rate-limit'
import { normalizePhone, getLast10Digits, isValidIndianPhone } from '@/lib/phone'

export async function OPTIONS(request: NextRequest) {
  const origin = request.headers.get('origin') || ''
  const isAllowed = 
    origin.endsWith('fastkirana.in') ||
    origin.endsWith('fastkirana.com') ||
    origin.startsWith('http://localhost:') ||
    origin.startsWith('capacitor://') ||
    origin.startsWith('ionic://')

  return new NextResponse(null, {
    status: 200,
    headers: {
      'Access-Control-Allow-Origin': isAllowed ? origin : 'https://www.fastkirana.in',
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

    if (normalizedEmail === 'superadmin') normalizedEmail = 'superadmin@fastkirana.com'
    if (normalizedEmail === 'admin') normalizedEmail = 'admin@fastkirana.com'

    const phoneDigits = isPhoneNumber(trimmed) ? getLast10Digits(trimmed) : null

    if (phoneDigits) {
      if (phoneDigits === '9170942500') {
        normalizedEmail = 'superadmin@fastkirana.com'
      } else if (phoneDigits === '7054470303') {
        normalizedEmail = 'admin@fastkirana.com'
      } else if (phoneDigits === '9696678006') {
        normalizedEmail = 'admin.hub-224122@fastkirana.in'
      } else {
        normalizedEmail = `phone:${phoneDigits}`
      }

      // Check if user account is blocked
      const blockedUser = await prisma.user.findFirst({
        where: {
          OR: [
            { phone: `+91${phoneDigits}` },
            { phone: phoneDigits },
            { email: normalizedEmail },
          ],
          isBlocked: true,
        },
        select: { blockReason: true }
      })

      if (blockedUser) {
        return NextResponse.json({
          error: `Your account has been blocked. ${blockedUser.blockReason ? `Reason: ${blockedUser.blockReason}` : 'Please contact customer support.'}`
        }, { status: 403 })
      }
    } else if (!normalizedEmail.includes('@')) {
      return NextResponse.json({ error: 'Please enter a valid email address or 10-digit mobile number' }, { status: 400 })
    }

    // 1. Generate a 6-digit numeric OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString()

    // 2. Set expiry to 5 minutes from now
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000)

    // 3. Clear existing tokens and create new OTP record in parallel/batch
    const emailVariants = new Set<string>([normalizedEmail])
    if (phoneDigits) {
      emailVariants.add(`phone:${phoneDigits}`)
      emailVariants.add(phoneDigits)
      emailVariants.add(`+91${phoneDigits}`)
      emailVariants.add(`wa-${phoneDigits}@fastkirana.com`)
    }

    const variantsArray = Array.from(emailVariants)

    await prisma.$transaction([
      prisma.otpToken.deleteMany({
        where: {
          email: { in: variantsArray }
        }
      }),
      prisma.otpToken.createMany({
        data: variantsArray.map(variant => ({
          email: variant,
          token: otp,
          expiresAt
        }))
      })
    ])

    // 5. Send OTP via Meta WhatsApp Cloud API or Email
    const recipientPhoneDigits = phoneDigits || (normalizedEmail.startsWith('phone:') ? normalizedEmail.replace('phone:', '') : null)

    if (recipientPhoneDigits) {
      const recipientPhone = `+91${recipientPhoneDigits}`
      const isSent = await sendWhatsAppOtp(recipientPhone, otp).catch((err) => {
        console.warn('sendWhatsAppOtp exception:', err)
        return false
      })

      if (!isSent) {
        console.warn('Meta WhatsApp API OTP delivery failed or unavailable for:', recipientPhone)
        // Token is safely stored in database; do not return 500 so user can proceed
      }
    } else {
      try {
        await sendOtpEmail(normalizedEmail, otp)
      } catch (err) {
        console.error('Failed to send OTP email:', err)
        return NextResponse.json({ error: 'Failed to send verification email. Please try again.' }, { status: 500 })
      }
    }

    return NextResponse.json({
      success: true,
      ...(process.env.NODE_ENV !== 'production' ? { otp } : {})
    })
  } catch (error: any) {
    console.error('OTP Send API error:', error)
    return NextResponse.json({ error: 'Failed to send OTP code' }, { status: 500 })
  }
}
