/**
 * Auth bypass configuration — centralizes all dev/bypass environment checks.
 *
 * ALL bypass logic must go through this module. No file should directly
 * reference ENABLE_DEV_BYPASS or DEV_BYPASS_PASSWORD.
 *
 * In production (NODE_ENV === 'production'), bypass is ALWAYS disabled
 * regardless of environment variables.
 */

/**
 * Whether the dev authentication bypass is enabled.
 *
 * Requires BOTH conditions:
 *   1. NODE_ENV !== 'production'
 *   2. ENABLE_DEV_BYPASS=1
 */
export function isDevBypassEnabled(): boolean {
  if (process.env.NODE_ENV === 'production') return false
  return process.env.ENABLE_DEV_BYPASS === '1'
}

/**
 * The dev bypass password, or null if not configured.
 */
export function getDevBypassPassword(): string | null {
  const raw = process.env.DEV_BYPASS_PASSWORD
  if (!raw || raw.trim() === '') return null
  return raw.trim()
}

/**
 * Whether the dev bypass is active AND has a password configured.
 */
export function isDevBypassActive(): boolean {
  return isDevBypassEnabled() && getDevBypassPassword() !== null
}
