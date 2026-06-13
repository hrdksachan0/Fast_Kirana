import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function GET(request: NextRequest) {
  const report: Record<string, any> = {
    timestamp: new Date().toISOString(),
  }

  // 1. Check environment variables
  const authSecret = process.env.AUTH_SECRET
  const nextauthUrl = process.env.NEXTAUTH_URL
  const authTrustHost = process.env.AUTH_TRUST_HOST
  const googleClientId = process.env.GOOGLE_CLIENT_ID
  const googleClientSecret = process.env.GOOGLE_CLIENT_SECRET

  report.env = {
    AUTH_SECRET_length: authSecret?.length || 0,
    AUTH_SECRET_hasQuotes: authSecret ? (authSecret.startsWith('"') || authSecret.startsWith("'")) : 'MISSING',
    AUTH_SECRET_first3: authSecret ? authSecret.substring(0, 3) : 'MISSING',
    AUTH_SECRET_last3: authSecret ? authSecret.substring(authSecret.length - 3) : 'MISSING',
    NEXTAUTH_URL: nextauthUrl || 'MISSING',
    AUTH_TRUST_HOST: authTrustHost || 'MISSING',
    GOOGLE_CLIENT_ID_length: googleClientId?.length || 0,
    GOOGLE_CLIENT_ID_hasQuotes: googleClientId ? (googleClientId.startsWith('"') || googleClientId.startsWith("'")) : 'MISSING',
    GOOGLE_CLIENT_ID_preview: googleClientId ? `${googleClientId.substring(0, 15)}...` : 'MISSING',
    GOOGLE_CLIENT_SECRET_length: googleClientSecret?.length || 0,
    GOOGLE_CLIENT_SECRET_hasQuotes: googleClientSecret ? (googleClientSecret.startsWith('"') || googleClientSecret.startsWith("'")) : 'MISSING',
    GOOGLE_CLIENT_SECRET_preview: googleClientSecret ? `${googleClientSecret.substring(0, 8)}...` : 'MISSING',
    NODE_ENV: process.env.NODE_ENV,
    VERCEL_URL: process.env.VERCEL_URL || 'NOT_SET',
    VERCEL_ENV: process.env.VERCEL_ENV || 'NOT_SET',
  }

  // 2. Check database tables
  try {
    const userCount = await prisma.user.count()
    const accountCount = await prisma.account.count()

    // Check if any Google accounts exist
    const googleAccounts = await prisma.account.findMany({
      where: { provider: 'google' },
      select: {
        id: true,
        provider: true,
        providerAccountId: true,
        userId: true,
        type: true,
        user: {
          select: { email: true, name: true }
        }
      },
      take: 5,
    })

    report.database = {
      status: 'CONNECTED',
      userCount,
      accountCount,
      googleAccounts: googleAccounts.map(a => ({
        id: a.id.substring(0, 8) + '...',
        provider: a.provider,
        providerAccountId: a.providerAccountId.substring(0, 10) + '...',
        type: a.type,
        userEmail: a.user?.email,
      })),
    }
  } catch (err: any) {
    report.database = {
      status: 'FAILED',
      error: err.message,
    }
  }

  // 3. Check what the cleaned values look like
  const cleanEnv = (key: string): string => {
    let val = process.env[key] || ''
    val = val.trim()
    if (val.startsWith('"') && val.endsWith('"')) val = val.substring(1, val.length - 1)
    if (val.startsWith("'") && val.endsWith("'")) val = val.substring(1, val.length - 1)
    return val.trim()
  }

  const cleanedGoogleId = cleanEnv('GOOGLE_CLIENT_ID')
  const cleanedGoogleSecret = cleanEnv('GOOGLE_CLIENT_SECRET')
  const cleanedAuthSecret = cleanEnv('AUTH_SECRET')

  report.cleaned = {
    GOOGLE_CLIENT_ID_cleaned_length: cleanedGoogleId.length,
    GOOGLE_CLIENT_ID_cleaned_preview: cleanedGoogleId ? `${cleanedGoogleId.substring(0, 15)}...` : 'EMPTY',
    GOOGLE_CLIENT_SECRET_cleaned_length: cleanedGoogleSecret.length,
    GOOGLE_CLIENT_SECRET_cleaned_preview: cleanedGoogleSecret ? `${cleanedGoogleSecret.substring(0, 8)}...` : 'EMPTY',
    AUTH_SECRET_cleaned_length: cleanedAuthSecret.length,
    AUTH_SECRET_cleaned_first3: cleanedAuthSecret ? cleanedAuthSecret.substring(0, 3) : 'EMPTY',
    AUTH_SECRET_cleaned_last3: cleanedAuthSecret ? cleanedAuthSecret.substring(cleanedAuthSecret.length - 3) : 'EMPTY',
    GOOGLE_CLIENT_ID_endsWith_googleusercontent: cleanedGoogleId.endsWith('.apps.googleusercontent.com'),
  }

  // 4. Compute the expected callback URL
  const baseUrl = nextauthUrl || `https://${process.env.VERCEL_URL}` || 'UNKNOWN'
  report.oauth = {
    expectedCallbackUrl: `${baseUrl}/api/auth/callback/google`,
    note: 'This URL must be registered in Google Cloud Console under Authorized redirect URIs',
  }

  // 5. Clear logs if requested
  const clear = request.nextUrl.searchParams.get('clear')
  if (clear === 'true') {
    try {
      await prisma.otpToken.deleteMany({
        where: { email: { startsWith: '[auth-log]' } }
      })
      report.logsCleared = true
    } catch (err: any) {
      report.logsClearedError = err.message
    }
  }

  // 6. Fetch recent auth logs
  try {
    const logs = await prisma.otpToken.findMany({
      where: {
        email: { startsWith: '[auth-log]' }
      },
      orderBy: {
        createdAt: 'desc'
      },
      take: 100
    })
    report.logs = logs.map(l => {
      let parsed: any = {}
      try {
        parsed = JSON.parse(l.token)
      } catch {
        parsed = { raw: l.token }
      }
      return {
        id: l.id,
        level: l.email.replace('[auth-log][', '').replace(']', ''),
        message: parsed.message,
        meta: parsed.meta,
        timestamp: parsed.timestamp || l.createdAt.toISOString()
      }
    })
  } catch (err: any) {
    report.logs = { error: err.message }
  }

  return NextResponse.json(report, {
    headers: { 'Cache-Control': 'no-store' },
  })
}
