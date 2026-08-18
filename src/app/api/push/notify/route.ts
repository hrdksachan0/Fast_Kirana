import { NextRequest, NextResponse } from 'next/server'
import { sendPushNotification, sendPushNotificationToRoles } from '@/lib/push-notification'
import { Role } from '@prisma/client'

export async function POST(request: NextRequest) {
  try {
    const authHeader = request.headers.get('x-api-secret')
    const secret = process.env.AUTH_SECRET

    if (!authHeader || authHeader !== secret) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { userId, roles, title, body, data } = await request.json()

    if (!title || !body) {
      return NextResponse.json({ error: 'Missing title or body' }, { status: 400 })
    }

    if (userId) {
      await sendPushNotification(userId, {
        title,
        body,
        data: data || {}
      })
    } else if (roles && Array.isArray(roles)) {
      const parsedRoles = roles.map(r => r as Role)
      await sendPushNotificationToRoles(parsedRoles, {
        title,
        body,
        data: data || {}
      })
    } else {
      return NextResponse.json({ error: 'Must provide either userId or roles' }, { status: 400 })
    }

    return NextResponse.json({ success: true })
  } catch (error: any) {
    console.error('Push notify bridge error:', error)
    return NextResponse.json({ error: 'Internal Server Error: ' + error.message }, { status: 500 })
  }
}
