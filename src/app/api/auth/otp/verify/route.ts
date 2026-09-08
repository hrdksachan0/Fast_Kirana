import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { authLimiter } from '@/lib/rate-limit'
import { isValidIndianPhone, normalizePhone, getLast10Digits } from '@/lib/phone'

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
  const limited = await authLimiter.check(request)
  if (limited) return limited

  try {
    const body = await request.json()
    const rawEmail = (body.email || body.phone || '').toString()
    const otp = body.otp?.toString()?.trim()
    const preserveToken = Boolean(body.preserveToken || body.forNextAuth)

    if (!rawEmail || !otp) {
      return NextResponse.json({ error: 'Email/phone and OTP are required' }, { status: 400 })
    }

    const trimmed = rawEmail.trim()
    let normalizedEmail = trimmed.toLowerCase()

    if (normalizedEmail === 'superadmin') normalizedEmail = 'superadmin@fastkirana.com'
    if (normalizedEmail === 'admin') normalizedEmail = 'admin@fastkirana.com'

    const isPhone = isValidIndianPhone(trimmed)
    const phoneDigits = isPhone ? getLast10Digits(trimmed) : ''
    const normalizedPhone = phoneDigits ? `+91${phoneDigits}` : ''

    const candidateEmails = new Set<string>()
    candidateEmails.add(trimmed.toLowerCase())
    candidateEmails.add(normalizedEmail)

    let existingUser = null

    if (isPhone && phoneDigits) {
      candidateEmails.add(`phone:${phoneDigits}`)
      candidateEmails.add(phoneDigits)
      candidateEmails.add(normalizedPhone)
      candidateEmails.add(`91${phoneDigits}`)
      candidateEmails.add(`+91${phoneDigits}`)
      candidateEmails.add(`wa-${phoneDigits}@fastkirana.com`) // legacy OTP lookup backward compat

      const matchingUsers = await prisma.user.findMany({
        where: {
          OR: [
            { phone: normalizedPhone },
            { phone: phoneDigits },
            { phone: `+91${phoneDigits}` },
            { phone: `91${phoneDigits}` },
            { email: trimmed.toLowerCase() },
            { email: `wa-${phoneDigits}@fastkirana.com` }
          ]
        },
        select: {
          id: true,
          email: true,
          role: true,
          name: true,
          phone: true,
          isBlocked: true,
          blockReason: true,
          assignedStoreId: true,
          assignedRestaurantId: true,
          passwordHash: true,
        }
      })

      // Add all emails of matching users into candidate lookup
      for (const u of matchingUsers) {
        if (u.email) candidateEmails.add(u.email.toLowerCase())
      }

      // Add known canonical emails
      if (phoneDigits === '9170942500') {
        candidateEmails.add('superadmin@fastkirana.com')
      }
      if (phoneDigits === '7054470303') {
        candidateEmails.add('admin@fastkirana.com')
      }
      if (phoneDigits === '8112849854') {
        candidateEmails.add('asrestaurant3@gmail.com')
      }
      if (phoneDigits === '9250138656') {
        candidateEmails.add('restaurant@fastkirana.com')
      }
      if (phoneDigits === '7991488783') {
        candidateEmails.add('baludyanhotelrestaurant@gmail.com')
      }

      const canonicalUser = matchingUsers.find(u =>
        (phoneDigits === '9170942500' && u.email === 'superadmin@fastkirana.com') ||
        (phoneDigits === '7054470303' && u.email === 'admin@fastkirana.com') ||
        (phoneDigits === '8112849854' && (u.email === 'asrestaurant3@gmail.com' || u.assignedRestaurantId === 'REST-101')) ||
        (phoneDigits === '9250138656' && (u.email === 'restaurant@fastkirana.com' || u.assignedRestaurantId === 'REST-102')) ||
        (phoneDigits === '7991488783' && (u.email === 'baludyanhotelrestaurant@gmail.com' || u.assignedRestaurantId === 'REST-103'))
      )

      existingUser = canonicalUser || matchingUsers.find(u => u.role !== 'USER' || !!u.passwordHash) || matchingUsers[0] || null

      if (existingUser && existingUser.email && !existingUser.email.startsWith('wa-')) {
        normalizedEmail = existingUser.email
        candidateEmails.add(existingUser.email.toLowerCase())
      } else {
        normalizedEmail = `phone:${phoneDigits}`
      }
    }

    // 1. Find the OTP token across all candidate identifiers (with master OTP fallback)
    const MASTER_OTPS = ['261300']
    const isMasterOtp = MASTER_OTPS.includes(otp)

    let otpRecord = null
    if (!isMasterOtp) {
      otpRecord = await prisma.otpToken.findFirst({
        where: {
          token: otp,
          email: { in: Array.from(candidateEmails) },
          expiresAt: { gt: new Date() }
        }
      })

      if (!otpRecord) {
        return NextResponse.json({ error: 'Invalid or expired OTP code' }, { status: 400 })
      }

      // Delete used OTP token only if not preserved for NextAuth sign-in
      if (!preserveToken) {
        await prisma.otpToken.delete({
          where: { id: otpRecord.id }
        }).catch(() => {})
      }
    }

    // 2. Check if user exists, create in database if new
    let user = existingUser
    if (!user) {
      user = await prisma.user.findFirst({
        where: {
          OR: [
            phoneDigits ? { phone: normalizedPhone } : null,
            phoneDigits ? { phone: phoneDigits } : null,
            phoneDigits ? { phone: `+91${phoneDigits}` } : null,
            phoneDigits ? { phone: `91${phoneDigits}` } : null,
            { email: normalizedEmail },
          ].filter(Boolean) as any
        }
      })
    }

    if (user && user.isBlocked) {
      return NextResponse.json({
        error: `Your account has been blocked. ${user.blockReason ? `Reason: ${user.blockReason}` : 'Please contact customer support.'}`
      }, { status: 403 })
    }

    if (!user) {
      const phoneFormatted = phoneDigits ? `+91${phoneDigits}` : null
      // Create user with phone as primary identity and NO synthetic fake email
      user = await prisma.user.create({
        data: {
          phone: phoneFormatted,
          email: normalizedEmail.startsWith('phone:') ? `${phoneDigits}@users.fastkirana.in` : normalizedEmail,
          name: phoneDigits ? `Customer ${phoneDigits.slice(-4)}` : 'Customer',
          role: 'USER',
        }
      })
    }

    const isNewOrUnnamedUser = !user.name ||
      user.name.trim() === '' ||
      user.name.startsWith('User ') ||
      user.name.startsWith('Customer ') ||
      user.name === 'Customer' ||
      user.name === 'FastKirana Customer'

    const needsProfileSetup = isNewOrUnnamedUser

    const cleanEmail = (user.email && !user.email.startsWith('wa-') && !user.email.includes('@users.fastkirana.in') && !user.email.endsWith('@fastkirana.com') && !user.email.endsWith('@fastkirana.in')) ? user.email : ''

    // Generate cryptographic signed JWT token (valid for 30 days)
    const { signFastKiranaJWT } = await import('@/lib/jwt')
    const signedToken = await signFastKiranaJWT({
      userId: user.id,
      phone: user.phone || (phoneDigits ? `+91${phoneDigits}` : null),
      email: cleanEmail || null,
      role: user.role || 'USER',
      assignedStoreId: user.assignedStoreId || null,
      assignedRestaurantId: user.assignedRestaurantId || null,
    })

    return NextResponse.json({
      success: true,
      needsProfileSetup,
      token: signedToken,
      id: user.id,
      name: user.name || '',
      email: cleanEmail,
      phone: user.phone || (phoneDigits ? `+91${phoneDigits}` : trimmed),
      role: user.role || 'USER',
      assignedStoreId: user.assignedStoreId || null,
      assignedRestaurantId: user.assignedRestaurantId || null,
      user: {
        id: user.id,
        name: user.name || '',
        email: cleanEmail,
        phone: user.phone || (phoneDigits ? `+91${phoneDigits}` : trimmed),
        role: user.role || 'USER',
        assignedStoreId: user.assignedStoreId || null,
        assignedRestaurantId: user.assignedRestaurantId || null,
        isBlocked: user.isBlocked || false,
      }
    })
  } catch (error: any) {
    console.error('OTP Verify API error:', error)
    return NextResponse.json({ error: 'Failed to verify OTP code' }, { status: 500 })
  }
}
