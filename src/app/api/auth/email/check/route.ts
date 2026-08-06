import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { authLimiter } from '@/lib/rate-limit'
import { ApiResponder } from '@/lib/api-response'
import { isValidIndianPhone, normalizePhone, getLast10Digits } from '@/lib/phone'

export async function POST(request: NextRequest) {
  const limited = await authLimiter.check(request)
  if (limited) return limited

  try {
    const { email: rawEmail } = await request.json()

    if (!rawEmail || typeof rawEmail !== 'string') {
      return ApiResponder.error('Identifier is required', 400)
    }

    const trimmed = rawEmail.trim()
    let normalizedEmail = trimmed.toLowerCase()
    let isPhone = false
    let normalizedPhone = ''

    if (isValidIndianPhone(trimmed)) {
      isPhone = true
      normalizedPhone = normalizePhone(trimmed)

      // Check if user exists with this phone number (matching both +91 and 10-digit formats)
      const phoneDigits = getLast10Digits(normalizedPhone)
      const matchingUsers = await prisma.user.findMany({
        where: {
          OR: [
            { phone: normalizedPhone },
            { phone: phoneDigits },
            { phone: `+91${phoneDigits}` },
            { email: `wa-${phoneDigits}@fastkirana.com` }
          ]
        },
        select: { email: true, name: true, phone: true, role: true, passwordHash: true }
      })

      const existingUser = matchingUsers.find(u => u.role !== 'USER' || !!u.passwordHash) || matchingUsers[0]

      if (existingUser) {
        return ApiResponder.success({
          exists: true,
          isWorker: existingUser.role !== 'USER',
          hasPassword: !!existingUser.passwordHash,
          needsProfileSetup: !existingUser.name || !existingUser.phone,
          role: existingUser.role,
          email: existingUser.email,
        })
      } else {
        // Generate placeholder email for the phone number
        const phoneDigits = getLast10Digits(normalizedPhone)
        normalizedEmail = `wa-${phoneDigits}@fastkirana.com`
      }
    } else {
      // Validate email format
      if (!trimmed.includes('@')) {
        return ApiResponder.error('Please enter a valid email address or 10-digit mobile number', 400)
      }
    }

    // Query database to check user existence, role, and password status
    const user = await prisma.user.findUnique({
      where: { email: normalizedEmail },
      select: { name: true, phone: true, role: true, passwordHash: true }
    })

    if (!user) {
      // New user — treat as customer, needs OTP flow
      return ApiResponder.success({
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

    return ApiResponder.success({
      exists: true,
      isWorker,
      hasPassword,
      needsProfileSetup,
      role: user.role,
      email: normalizedEmail,
    })
  } catch (error: any) {
    console.error('Email Check API error:', error)
    return ApiResponder.error('Failed to verify email registration status', 500)
  }
}
