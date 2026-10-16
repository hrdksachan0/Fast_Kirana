import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

async function getOrCreateGuestUser(guestId: string) {
  const cleanId = guestId.replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 32)
  if (!cleanId) return null

  const guestEmail = `guest-${cleanId}@fastkirana.com`
  let user = await prisma.user.findUnique({
    where: { email: guestEmail },
  })

  if (!user) {
    user = await prisma.user.create({
      data: {
        email: guestEmail,
        name: `Guest Shopper (${cleanId.slice(0, 6)})`,
        role: 'USER',
        phone: null,
      },
    })
  }

  return user
}

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    const body = await request.json().catch(() => ({}))

    const subscription = body.subscription || body
    const endpoint = subscription?.endpoint
    const keys = subscription?.keys
    const p256dh = keys?.p256dh
    const authKey = keys?.auth

    if (!endpoint || !p256dh || !authKey) {
      return NextResponse.json(
        { error: 'Invalid subscription payload. Must include endpoint, keys.p256dh, and keys.auth.' },
        { status: 400 }
      )
    }

    // Resolve user ID
    let userId = session?.user?.id || body.userId || request.headers.get('x-user-id') || null

    if (userId) {
      // Ensure user exists in database
      const existingUser = await prisma.user.findUnique({
        where: { id: userId },
        select: { id: true },
      })
      if (!existingUser) {
        userId = null
      }
    }

    // Fallback: look up by phone if provided
    const phoneInput = body.phone || request.headers.get('x-user-phone')
    if (!userId && phoneInput) {
      const cleanPhone = String(phoneInput).replace(/\D/g, '').slice(-10)
      if (cleanPhone.length === 10) {
        const userByPhone = await prisma.user.findFirst({
          where: { phone: { contains: cleanPhone } },
          select: { id: true },
        })
        if (userByPhone) {
          userId = userByPhone.id
        }
      }
    }

    // Fallback: Guest user via guestId
    const guestId = body.guestId || request.headers.get('x-guest-id')
    if (!userId && guestId) {
      const guestUser = await getOrCreateGuestUser(String(guestId))
      if (guestUser) {
        userId = guestUser.id
      }
    }

    // Final fallback: Create an anonymous web push user if still unassigned
    if (!userId) {
      const anonEndpointHash = Buffer.from(endpoint).toString('base64').replace(/[^a-zA-Z0-9]/g, '').slice(-12)
      const anonEmail = `anon-push-${anonEndpointHash}@fastkirana.com`
      let anonUser = await prisma.user.findUnique({
        where: { email: anonEmail },
        select: { id: true },
      })
      if (!anonUser) {
        anonUser = await prisma.user.create({
          data: {
            email: anonEmail,
            name: `Anonymous Web Shopper`,
            role: 'USER',
            phone: null,
          },
          select: { id: true },
        })
      }
      userId = anonUser.id
    }

    // Upsert subscription into database
    await prisma.pushSubscription.upsert({
      where: { endpoint },
      update: {
        userId,
        p256dh,
        auth: authKey,
        updatedAt: new Date(),
      },
      create: {
        userId,
        endpoint,
        p256dh,
        auth: authKey,
      },
    })

    return NextResponse.json({
      success: true,
      message: 'Push subscription registered successfully',
      userId,
    })
  } catch (error: any) {
    console.error('Failed to register push subscription:', error)
    return NextResponse.json(
      { error: 'Internal server error: ' + (error?.message || error) },
      { status: 500 }
    )
  }
}

export async function DELETE(request: NextRequest) {
  try {
    const body = await request.json().catch(() => ({}))
    const endpoint = body.endpoint || body.subscription?.endpoint

    if (!endpoint) {
      return NextResponse.json({ error: 'Endpoint required' }, { status: 400 })
    }

    await prisma.pushSubscription.deleteMany({
      where: { endpoint },
    })

    return NextResponse.json({ success: true, message: 'Push subscription removed successfully' })
  } catch (error: any) {
    console.error('Failed to remove push subscription:', error)
    return NextResponse.json(
      { error: 'Internal server error: ' + (error?.message || error) },
      { status: 500 }
    )
  }
}
