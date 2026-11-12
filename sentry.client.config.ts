import * as Sentry from '@sentry/nextjs'

const SENTRY_DSN = process.env.NEXT_PUBLIC_SENTRY_DSN || process.env.SENTRY_DSN

if (SENTRY_DSN) {
  // Check user consent before enabling non-essential session replays
  let hasAnalyticsConsent = false
  if (typeof window !== 'undefined') {
    try {
      const saved = localStorage.getItem('fastminute_consent_v1')
      if (saved) {
        const parsed = JSON.parse(saved)
        hasAnalyticsConsent = Boolean(parsed.analytics)
      }
    } catch {}
  }

  Sentry.init({
    dsn: SENTRY_DSN,
    tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.05 : 1.0,
    // Session replays strictly gated behind explicit user consent (DPDP & GDPR compliant)
    replaysSessionSampleRate: hasAnalyticsConsent ? (process.env.NODE_ENV === 'production' ? 0.1 : 1.0) : 0,
    replaysOnErrorSampleRate: hasAnalyticsConsent ? 1.0 : 0,
    debug: false,
    environment: process.env.NODE_ENV || 'development',
    // Strict privacy masking: never capture keystrokes, personal details, passwords, or payment cards
    integrations: [
      Sentry.replayIntegration({
        maskAllText: true,
        blockAllMedia: true,
      }),
    ],
  })
}
