/**
 * Production-aware logger.
 * Suppresses verbose logs (log, warn, info) in production to reduce Vercel Observability Events costs.
 * console.error is ALWAYS preserved so real errors are never hidden.
 */

const isProd = process.env.NODE_ENV === 'production'

const noop = (..._args: any[]) => {}

export const logger = {
  /** Always logs — use for real errors only */
  error: console.error.bind(console),

  /** Suppressed in production */
  warn: isProd ? noop : console.warn.bind(console),

  /** Suppressed in production */
  log: isProd ? noop : console.log.bind(console),

  /** Suppressed in production */
  info: isProd ? noop : console.info.bind(console),

  /** Suppressed in production */
  debug: isProd ? noop : console.debug.bind(console),
}
