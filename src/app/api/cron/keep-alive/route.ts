import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function GET(request: Request) {
  // Verify authorization in production to prevent abuse
  const authHeader = request.headers.get('authorization')
  if (
    process.env.NODE_ENV === 'production' &&
    authHeader !== `Bearer ${process.env.CRON_SECRET}`
  ) {
    return new Response('Unauthorized', { status: 401 })
  }

  try {
    // Run a simple query to keep the database connection pool warm
    await prisma.$queryRaw`SELECT 1`
    
    return NextResponse.json({
      success: true,
      message: 'Database kept warm successfully',
      timestamp: new Date().toISOString()
    })
  } catch (error: any) {
    console.error('Keep-alive cron database query failed:', error)
    return NextResponse.json(
      {
        success: false,
        error: 'Database connection failed',
        details: error.message || error
      },
      { status: 500 }
    )
  }
}
