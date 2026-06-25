import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { sendPushNotification } from '@/lib/push-notification'
import { prisma } from '@/lib/prisma'

export async function POST(request: NextRequest) {
  const session = await auth()
  if (!session || (session.user as any).role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const body = await request.json()
    const { userId, title, body: contentBody } = body

    if (!userId || !title || !contentBody) {
      return NextResponse.json({ error: 'Missing required fields: userId, title, body' }, { status: 400 })
    }

    // Verify user exists and check push subscriptions
    const subCount = await prisma.pushSubscription.count({
      where: { userId }
    })

    if (subCount === 0) {
      return NextResponse.json({ 
        success: false, 
        error: 'Customer has not enabled push notifications on their device.' 
      }, { status: 400 })
    }

    // Send push notification to the user
    await sendPushNotification(userId, {
      title,
      body: contentBody,
      icon: '/favicon.ico',
      badge: '/favicon.ico',
      data: {
        url: '/cart'
      }
    })

    return NextResponse.json({ success: true, message: 'Push notification sent successfully!' })
  } catch (error: any) {
    console.error('Failed to send live cart push notification:', error)
    return NextResponse.json({ error: 'Internal server error: ' + error.message }, { status: 500 })
  }
}
