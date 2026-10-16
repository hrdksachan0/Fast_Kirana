import { NextRequest, NextResponse } from 'next/server'
import { sendPushNotification, sendPushNotificationToRoles, broadcastPushNotification } from '@/lib/push-notification'
import { Role } from '@prisma/client'

export async function POST(request: NextRequest) {
  try {
    const secret = process.env.AUTH_SECRET || process.env.INTERNAL_API_SECRET
    const incomingSecret =
      request.headers.get('x-api-secret') ||
      request.headers.get('x-internal-secret') ||
      request.headers.get('authorization')?.replace('Bearer ', '')

    if (!secret || incomingSecret !== secret) {
      return NextResponse.json({ error: 'Unauthorized: invalid secret' }, { status: 401 })
    }

    const body = await request.json().catch(() => ({}))
    const { title, body: contentBody, data, userId, roles, broadcast } = body

    if (!title || !contentBody) {
      return NextResponse.json({ error: 'title and body are required' }, { status: 400 })
    }

    const payload = {
      title,
      body: contentBody,
      icon: '/icons/icon-192.png',
      badge: '/icons/badge.png',
      data: data || {},
    }

    if (userId) {
      await sendPushNotification(userId, payload)
      return NextResponse.json({ success: true, message: `Push sent to user ${userId}` })
    }

    if (roles && Array.isArray(roles) && roles.length > 0) {
      await sendPushNotificationToRoles(roles as Role[], payload)
      return NextResponse.json({ success: true, message: `Push sent to roles: ${roles.join(', ')}` })
    }

    if (broadcast) {
      await broadcastPushNotification(payload)
      return NextResponse.json({ success: true, message: 'Push broadcast sent to all subscribers' })
    }

    return NextResponse.json({ error: 'Must specify userId, roles, or broadcast: true' }, { status: 400 })
  } catch (error: any) {
    console.error('Push notify bridge error:', error)
    return NextResponse.json({ error: 'Internal server error: ' + error.message }, { status: 500 })
  }
}
