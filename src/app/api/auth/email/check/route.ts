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
    if (normalizedEmail === 'superadmin') normalizedEmail = 'superadmin@fastkirana.com'
    if (normalizedEmail === 'admin') normalizedEmail = 'admin@fastkirana.com'
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
            { phone: `91${phoneDigits}` },
            { phone: `+91${phoneDigits}` },
            { email: `wa-${phoneDigits}@fastkirana.com` },
            { email: trimmed.toLowerCase() }
          ]
        },
        select: { email: true, name: true, phone: true, role: true, passwordHash: true, assignedRestaurantId: true }
      })

      // Dynamically prioritize canonical staff and restaurant owner accounts
      const canonicalUser = matchingUsers.find(u => 
        (phoneDigits === '9170942500' && u.email === 'superadmin@fastkirana.com') ||
        (phoneDigits === '7054470303' && u.email === 'admin@fastkirana.com') ||
        u.role === 'RESTAURANT_OWNER' ||
        u.role === 'CHEF' ||
        u.role === 'ADMIN' ||
        !!u.assignedRestaurantId
      )
      const existingUser = canonicalUser || matchingUsers.find(u => u.role !== 'USER' || !!u.passwordHash) || matchingUsers[0]

      if (existingUser) {
        const isMasterAdmin =
          phoneDigits === '7054470303' ||
          phoneDigits === '9170942500' ||
          existingUser.email === 'admin@fastkirana.com' ||
          existingUser.email === 'superadmin@fastkirana.com'
        const effectiveRole = isMasterAdmin ? 'ADMIN' : existingUser.role

        return ApiResponder.success({
          exists: true,
          isWorker: effectiveRole !== 'USER',
          hasPassword: !!existingUser.passwordHash,
          needsProfileSetup: !existingUser.name || !existingUser.phone,
          role: effectiveRole,
          email: existingUser.email,
          phone: existingUser.phone || normalizedPhone,
        })
      } else {
        const phoneDigits = getLast10Digits(normalizedPhone)
        return ApiResponder.success({
          exists: false,
          isWorker: false,
          hasPassword: false,
          needsProfileSetup: true,
          role: 'USER',
          email: `phone:${phoneDigits}`,
          phone: normalizedPhone,
        })
      }
    } else {
      // Validate email format
      if (!normalizedEmail.includes('@')) {
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

    const isMasterAdmin =
      normalizedEmail === 'admin@fastkirana.com' ||
      normalizedEmail === 'superadmin@fastkirana.com' ||
      user.phone?.includes('7054470303') ||
      user.phone?.includes('9170942500')
    const effectiveRole = isMasterAdmin ? 'ADMIN' : user.role
    const isWorker = effectiveRole !== 'USER'
    const hasPassword = !!user.passwordHash
    const needsProfileSetup = !user.name || !user.phone

    return ApiResponder.success({
      exists: true,
      isWorker,
      hasPassword,
      needsProfileSetup,
      role: effectiveRole,
      email: normalizedEmail,
    })
  } catch (error: any) {
    console.error('Email Check API error:', error)
    return ApiResponder.error('Failed to verify email registration status', 500)
  }
}
