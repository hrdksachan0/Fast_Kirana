import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function POST(request: NextRequest) {
  try {
    const { email } = await request.json()

    if (!email || typeof email !== 'string' || !email.includes('@')) {
      return NextResponse.json({ error: 'Please enter a valid email address' }, { status: 400 })
    }

    const normalizedEmail = email.toLowerCase().trim()

    // Query database to see if the user exists and has a complete name and phone
    const user = await prisma.user.findUnique({
      where: { email: normalizedEmail },
      select: { name: true, phone: true }
    })

    const needsProfileSetup = !user || !user.name || !user.phone

    return NextResponse.json({
      success: true,
      needsProfileSetup
    })
  } catch (error: any) {
    console.error('Email Check API error:', error)
    return NextResponse.json({ error: 'Failed to verify email registration status' }, { status: 500 })
  }
}
