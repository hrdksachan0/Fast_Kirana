import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { phone, otp } = await request.json()
    if (!phone || !otp) {
      return NextResponse.json({ error: 'Phone number and verification code are required' }, { status: 400 })
    }

    const cleaned = phone.replace(/\D/g, '')
    if (cleaned.length < 10) {
      return NextResponse.json({ error: 'Invalid mobile number' }, { status: 400 })
    }

    const cleanDigits = cleaned.slice(-10)
    const normalizedPhone = `+91${cleanDigits}`
    const tokenKey = `phone-verify-${normalizedPhone}`

    // 1. Find and verify the OTP
    const otpRecord = await prisma.otpToken.findFirst({
      where: {
        email: tokenKey,
        token: otp,
        expiresAt: { gt: new Date() }
      }
    })

    if (!otpRecord) {
      return NextResponse.json({ error: 'Invalid or expired verification code' }, { status: 400 })
    }

    // Double check that the phone is not taken by another user
    const existingUser = await prisma.user.findFirst({
      where: { phone: normalizedPhone }
    })

    if (existingUser && existingUser.id !== session.user.id) {
      return NextResponse.json({ error: 'This phone number is already registered to another account' }, { status: 400 })
    }

    // 2. Update user's phone in the database
    await prisma.user.update({
      where: { id: session.user.id },
      data: { phone: normalizedPhone }
    })

    // 3. Delete the OTP record
    await prisma.otpToken.delete({
      where: { id: otpRecord.id }
    })

    return NextResponse.json({
      success: true,
      message: 'Phone number updated successfully'
    })
  } catch (error: any) {
    console.error('Update Phone error:', error)
    return NextResponse.json({ error: 'Failed to update phone number' }, { status: 500 })
  }
}
