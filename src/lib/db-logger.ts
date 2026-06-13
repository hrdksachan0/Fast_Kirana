import { prisma } from '@/lib/prisma'

function serializeError(err: any): any {
  if (!err) return null
  if (err instanceof Error) {
    const obj: any = {}
    Object.getOwnPropertyNames(err).forEach(key => {
      const val = (err as any)[key]
      if (key === 'stack') {
        obj[key] = typeof val === 'string' ? val.split('\n').slice(0, 10) : val
      } else if (key === 'cause') {
        obj[key] = val instanceof Error ? serializeError(val) : val
      } else {
        obj[key] = val
      }
    })
    return obj
  }
  return err
}

export async function dbLog(level: 'ERROR' | 'WARN' | 'DEBUG' | 'INFO', message: string, meta?: any) {
  try {
    await prisma.otpToken.create({
      data: {
        email: `[auth-log][${level}]`,
        token: JSON.stringify({
          message,
          meta: meta ? serializeError(meta) : null,
          timestamp: new Date().toISOString()
        }),
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000) // Expires in 24 hours
      }
    })
  } catch (err) {
    console.error('dbLog failed:', err)
  }
}
