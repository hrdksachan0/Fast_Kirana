import { prisma } from '@/lib/prisma'

export async function dbLog(level: 'ERROR' | 'WARN' | 'DEBUG' | 'INFO', message: string, meta?: any) {
  try {
    // We run this as a non-blocking background promise
    await prisma.otpToken.create({
      data: {
        email: `[auth-log][${level}]`,
        token: JSON.stringify({
          message,
          meta: meta ? (meta instanceof Error ? { name: meta.name, message: meta.message, stack: meta.stack } : meta) : null,
          timestamp: new Date().toISOString()
        }),
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000) // Expires in 24 hours
      }
    })
  } catch (err) {
    console.error('dbLog failed:', err)
  }
}
