export interface TelemetryContext {
  severity?: 'INFO' | 'WARN' | 'ERROR' | 'CRITICAL'
  route?: string
  metadata?: Record<string, any>
}

/**
 * Reports client-side runtime errors and unhandled exceptions to FastKirana backend telemetry.
 * Uses navigator.sendBeacon when available for non-blocking asynchronous transmission.
 */
export function reportClientError(
  error: unknown,
  context: TelemetryContext = {}
): void {
  if (typeof window === 'undefined') return

  try {
    const message =
      error instanceof Error
        ? error.message
        : typeof error === 'string'
        ? error
        : JSON.stringify(error)

    const stack = error instanceof Error ? error.stack : undefined
    const route = context.route || window.location.pathname
    const severity = context.severity || 'ERROR'

    const payload = JSON.stringify({
      message,
      stack,
      route,
      severity,
      metadata: context.metadata,
      timestamp: new Date().toISOString(),
      userAgent: navigator.userAgent,
      screenWidth: window.innerWidth,
      screenHeight: window.innerHeight,
    })

    const endpoint = '/api/telemetry/errors'

    if (typeof navigator.sendBeacon === 'function') {
      const blob = new Blob([payload], { type: 'application/json' })
      const sent = navigator.sendBeacon(endpoint, blob)
      if (sent) return
    }

    // Fallback if sendBeacon returns false or is not supported
    fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: payload,
      keepalive: true,
    }).catch(() => {
      // Avoid recursive error logging
    })
  } catch (_e) {
    // Fail-safe: telemetry should never throw or break user experience
  }
}
