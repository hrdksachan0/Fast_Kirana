/**
 * Lightweight structured logging utility for FastKirana.
 * Replaces empty catch blocks and provides consistent debugging context.
 */

type LogLevel = 'debug' | 'info' | 'warn' | 'error'

function formatError(error: unknown): string {
  if (error instanceof Error) {
    return error.stack || error.message
  }
  if (typeof error === 'object' && error !== null) {
    try {
      return JSON.stringify(error)
    } catch {
      return String(error)
    }
  }
  return String(error)
}

function log(level: LogLevel, context: string, message: string, error?: unknown) {
  const timestamp = new Date().toISOString()
  const tag = `[FK:${context.toUpperCase()}]`
  const errDetail = error !== undefined ? ` | Details: ${formatError(error)}` : ''

  if (level === 'error') {
    console.error(`${timestamp} ❌ ${tag} ${message}${errDetail}`)
  } else if (level === 'warn') {
    console.warn(`${timestamp} ⚠️ ${tag} ${message}${errDetail}`)
  } else if (level === 'info') {
    console.info(`${timestamp} ℹ️ ${tag} ${message}${errDetail}`)
  } else {
    if (process.env.NODE_ENV !== 'production') {
      console.debug(`${timestamp} 🔍 ${tag} ${message}${errDetail}`)
    }
  }
}

export const logger = {
  debug: (context: string, message: string, error?: unknown) => log('debug', context, message, error),
  info: (context: string, message: string, error?: unknown) => log('info', context, message, error),
  warn: (context: string, message: string, error?: unknown) => log('warn', context, message, error),
  error: (context: string, message: string, error?: unknown) => log('error', context, message, error),
}
