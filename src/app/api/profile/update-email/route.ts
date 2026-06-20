import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { email, otp } = await request.json()
    if (!email || !otp) {
      return NextResponse.json({ error: 'Email and verification code are required' }, { status: 400 })
    }

    const normalizedEmail = email.trim().toLowerCase()

    // 1. Find and verify the OTP
    const otpRecord = await prisma.otpToken.findFirst({
      where: {
        email: normalizedEmail,
        token: otp,
        expiresAt: { gt: new Date() }
      }
    })

    if (!otpRecord) {
      return NextResponse.json({ error: 'Invalid or expired verification code' }, { status: 400 })
    }

    // Double check that the email is not taken by another user
    const existingUser = await prisma.user.findUnique({
      where: { email: normalizedEmail }
    })

    if (existingUser && existingUser.id !== session.user.id) {
      return NextResponse.json({ error: 'This email is already registered to another account' }, { status: 400 })
    }

    // 2. Update user's email in the database
    await prisma.user.update({
      where: { id: session.user.id },
      data: { email: normalizedEmail }
    })

    // 3. Delete the OTP record
    await prisma.otpToken.delete({
      where: { id: otpRecord.id }
    })

    return NextResponse.json({
      success: true,
      message: 'Email address updated successfully'
    })
  } catch (error: any) {
    console.error('Update Email error:', error)
    return NextResponse.json({ error: 'Failed to update email address' }, { status: 500 })
  }
}
