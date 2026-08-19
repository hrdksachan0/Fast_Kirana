import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function GET() {
  const startTime = Date.now()
  try {
    // Quick database ping
    await prisma.$queryRaw`SELECT 1`
    const dbLatencyMs = Date.now() - startTime

    return NextResponse.json(
      {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV,
        database: {
          status: 'connected',
          latencyMs: dbLatencyMs,
        },
      },
      { status: 200 }
    )
  } catch (error: any) {
    return NextResponse.json(
      {
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        error: error?.message || 'Database ping failed',
      },
      { status: 503 }
    )
  }
}
