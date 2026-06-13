import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { broadcastPushNotification } from '@/lib/push-notification'
import { apiWriteLimiter } from '@/lib/rate-limit'

export async function GET(request: NextRequest) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const notifications = await prisma.pushNotification.findMany({
      orderBy: { sentAt: 'desc' },
    })

    const subscriptionCount = await prisma.pushSubscription.count()

    return NextResponse.json({ notifications, subscriptionCount })
  } catch (error) {
    console.error('Failed to fetch notifications:', error)
    return NextResponse.json({ error: 'Failed to fetch notifications' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  const limitResponse = apiWriteLimiter.check(request)
  if (limitResponse) return limitResponse

  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const body = await request.json()
    const { title, body: contentBody, imageUrl, linkUrl } = body

    if (!title || !contentBody) {
      return NextResponse.json({ error: 'Title and body are required' }, { status: 400 })
    }

    // Build the payload matching Web Push standards
    const payload = {
      title,
      body: contentBody,
      icon: imageUrl || '/favicon.ico',
      badge: '/favicon.ico',
      data: {
        url: linkUrl || '/',
      },
    }

    // Broadcast message to all active subscriptions
    const stats = await broadcastPushNotification(payload)

    // Save notification log in database
    const notification = await prisma.pushNotification.create({
      data: {
        title,
        body: contentBody,
        imageUrl: imageUrl || null,
        linkUrl: linkUrl || null,
        successCount: stats.successCount,
        failureCount: stats.failureCount,
      },
    })

    return NextResponse.json(notification, { status: 201 })
  } catch (error) {
    console.error('Failed to broadcast push notification:', error)
    return NextResponse.json({ error: 'Failed to send push notification' }, { status: 500 })
  }
}
