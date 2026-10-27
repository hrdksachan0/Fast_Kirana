import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { runPaymentRecoveryCron } from '@/services/payment-recovery.service'
import { runGuestCleanup } from '@/services/guest-cleanup.service'

export async function GET(request: Request) {
  // If CRON_SECRET is set in environment, check it; otherwise allow keep-alive ping
  const authHeader = request.headers.get('authorization')
  if (
    process.env.CRON_SECRET &&
    authHeader &&
    authHeader !== `Bearer ${process.env.CRON_SECRET}`
  ) {
    return new Response('Unauthorized', { status: 401 })
  }

  try {
    // Run a light ping query to keep Prisma & serverless PostgreSQL connection pool warm
    await prisma.$queryRaw`SELECT 1`

    // Run automated payment recovery & timeout lifecycle
    const recoverySummary = await runPaymentRecoveryCron()

    // Run 2-day-old inactive anonymous guest device purge
    const guestCleanupSummary = await runGuestCleanup(2)

    return NextResponse.json({
      success: true,
      message: 'Database kept warm, payment recovery executed & abandoned guests cleaned',
      recovery: recoverySummary,
      guestCleanup: guestCleanupSummary,
      timestamp: new Date().toISOString()
    })
  } catch (error: any) {
    console.error('Keep-alive ping failed:', error)
    return NextResponse.json(
      {
        success: false,
        error: 'Database connection failed',
        details: error?.message || error
      },
      { status: 500 }
    )
  }
}
