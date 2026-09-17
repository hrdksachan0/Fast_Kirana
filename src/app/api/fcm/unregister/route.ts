import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json().catch(() => ({}))
    const { token } = body

    if (!token || typeof token !== 'string') {
      return NextResponse.json({ error: 'FCM token is required' }, { status: 400 })
    }

    // Delete token from fcmToken table so no further staff/admin/customer pushes target this token
    await prisma.fcmToken.deleteMany({
      where: { token }
    }).catch(() => {})

    // Also delete from pushSubscription table
    await prisma.pushSubscription.deleteMany({
      where: { endpoint: token }
    }).catch(() => {})

    return NextResponse.json({ success: true, message: 'FCM token unregistered successfully' })
  } catch (error: any) {
    console.error('FCM unregister error:', error)
    return NextResponse.json({ error: 'Internal server error: ' + error.message }, { status: 500 })
  }
}
