import { NextResponse } from 'next/server'
import { runGuestCleanup } from '@/services/guest-cleanup.service'

export async function GET(request: Request) {
  const authHeader = request.headers.get('authorization')
  if (
    process.env.CRON_SECRET &&
    authHeader &&
    authHeader !== `Bearer ${process.env.CRON_SECRET}`
  ) {
    return new Response('Unauthorized', { status: 401 })
  }

  const { searchParams } = new URL(request.url)
  const days = parseInt(searchParams.get('days') || '2')

  try {
    const summary = await runGuestCleanup(days)
    return NextResponse.json({
      success: true,
      message: `Cleaned up ${summary.deletedUsers || 0} abandoned guest accounts older than ${days} days`,
      details: summary,
      timestamp: new Date().toISOString()
    })
  } catch (error: any) {
    console.error('Guest cleanup cron failed:', error)
    return NextResponse.json(
      {
        success: false,
        error: 'Guest cleanup failed',
        details: error?.message || error
      },
      { status: 500 }
    )
  }
}

export async function POST(request: Request) {
  return GET(request)
}
