import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import nodemailer from 'nodemailer'

export async function GET(request: NextRequest) {
  const report: Record<string, any> = {
    timestamp: new Date().toISOString(),
    env: {
      NODE_ENV: process.env.NODE_ENV,
      NEXTAUTH_URL: process.env.NEXTAUTH_URL || 'MISSING',
      NEXT_PUBLIC_APP_URL: process.env.NEXT_PUBLIC_APP_URL || 'MISSING',
      AUTH_SECRET: process.env.AUTH_SECRET 
        ? (process.env.AUTH_SECRET.startsWith('"') ? 'PRESENT_WITH_QUOTES' : 'PRESENT')
        : 'MISSING',
    },
    googleOAuth: {
      GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID 
        ? `${process.env.GOOGLE_CLIENT_ID.substring(0, 10)}...${process.env.GOOGLE_CLIENT_ID.substring(process.env.GOOGLE_CLIENT_ID.length - 15)}`
        : 'MISSING',
      GOOGLE_CLIENT_SECRET: process.env.GOOGLE_CLIENT_SECRET 
        ? `${process.env.GOOGLE_CLIENT_SECRET.substring(0, 6)}...${process.env.GOOGLE_CLIENT_SECRET.substring(process.env.GOOGLE_CLIENT_SECRET.length - 6)}`
        : 'MISSING',
    },
    database: {
      status: 'unknown',
      error: null,
      userCount: 0,
    },
    smtp: {
      status: 'unknown',
      error: null,
      config: {
        host: process.env.SMTP_HOST || 'NOT SET',
        port: process.env.SMTP_PORT || 'NOT SET',
        user: process.env.SMTP_USER ? 'PRESENT' : 'MISSING',
        pass: process.env.SMTP_PASS ? 'PRESENT' : 'MISSING',
        from: process.env.EMAIL_FROM || 'NOT SET',
      }
    },
    resend: {
      status: process.env.RESEND_API_KEY ? 'CONFIGURED' : 'NOT_CONFIGURED',
    }
  }

  // 1. Test Database
  try {
    const userCount = await prisma.user.count()
    let accountCount = 0
    let sessionCount = 0
    let prismaTablesError = null

    try {
      accountCount = await prisma.account.count()
      sessionCount = await prisma.session.count()
    } catch (tblErr: any) {
      prismaTablesError = tblErr.message || String(tblErr)
    }

    report.database.status = 'CONNECTED'
    report.database.userCount = userCount
    report.database.accountCount = accountCount
    report.database.sessionCount = sessionCount
    report.database.tablesError = prismaTablesError
  } catch (err: any) {
    report.database.status = 'FAILED'
    report.database.error = err.message || String(err)
  }

  // 2. Test SMTP Connection
  const smtpHost = process.env.SMTP_HOST
  const smtpPort = process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT) : 587
  const smtpUser = process.env.SMTP_USER
  const smtpPass = process.env.SMTP_PASS

  if (smtpHost && smtpUser && smtpPass) {
    try {
      const transporter = nodemailer.createTransport({
        host: smtpHost,
        port: smtpPort,
        secure: smtpPort === 465,
        auth: {
          user: smtpUser,
          pass: smtpPass,
        },
        connectionTimeout: 4000, // 4 seconds timeout
      })
      
      await transporter.verify()
      report.smtp.status = 'CONNECTED'
    } catch (err: any) {
      report.smtp.status = 'FAILED'
      report.smtp.error = err.message || String(err)
    }
  } else {
    report.smtp.status = 'NOT_CONFIGURED'
  }

  return NextResponse.json(report)
}
