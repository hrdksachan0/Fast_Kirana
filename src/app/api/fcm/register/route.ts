import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    const body = await request.json().catch(() => ({}))
    const { token, deviceType, userId: bodyUserId, phone } = body

    if (!token) {
      return NextResponse.json({ error: 'FCM Token is required' }, { status: 400 })
    }

    let userId = session?.user?.id || bodyUserId || request.headers.get('x-user-id') || null

    if (userId) {
      const existingUser = await prisma.user.findUnique({
        where: { id: userId },
        select: { id: true },
      })
      if (!existingUser) userId = null
    }

    if (!userId && phone) {
      const cleanPhone = String(phone).replace(/\D/g, '').slice(-10)
      if (cleanPhone.length === 10) {
        const userByPhone = await prisma.user.findFirst({
          where: { phone: { contains: cleanPhone } },
          select: { id: true },
        })
        if (userByPhone) userId = userByPhone.id
      }
    }

    if (!userId) {
      // Create or find an anonymous device user record for FCM token
      const tokenHash = Buffer.from(token).toString('base64').replace(/[^a-zA-Z0-9]/g, '').slice(-12)
      const anonEmail = `anon-fcm-${tokenHash}@fastkirana.com`
      let anonUser = await prisma.user.findUnique({
        where: { email: anonEmail },
        select: { id: true },
      })
      if (!anonUser) {
        anonUser = await prisma.user.create({
          data: {
            email: anonEmail,
            name: `Mobile App User`,
            role: 'USER',
            phone: phone || null,
          },
          select: { id: true },
        })
      }
      userId = anonUser.id
    }

    // Upsert FCM token
    const existing = await prisma.fcmToken.findUnique({
      where: { token },
    })

    if (existing) {
      await prisma.fcmToken.update({
        where: { id: existing.id },
        data: {
          userId,
          deviceType: deviceType || 'android',
        },
      })
    } else {
      await prisma.fcmToken.create({
        data: {
          userId,
          token,
          deviceType: deviceType || 'android',
        },
      })
    }

    return NextResponse.json({
      success: true,
      message: 'FCM token registered successfully',
      userId,
    })
  } catch (error: any) {
    console.error('FCM register error:', error)
    return NextResponse.json({ error: 'Internal server error: ' + error.message }, { status: 500 })
  }
}
