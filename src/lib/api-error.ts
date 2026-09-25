/**
 * Safely extracts a user-readable, actionable error message from any API response or error object.
 * Standardizes FastAPI, Next.js, and network error envelopes across the entire web application.
 */
export function getApiErrorMessage(
  dataOrError: any,
  fallbackMessage = 'An unexpected error occurred. Please try again.'
): string {
  if (!dataOrError) return fallbackMessage

  // If passed an Error instance
  if (dataOrError instanceof Error) {
    return dataOrError.message || fallbackMessage
  }

  // If passed a JSON response body
  if (typeof dataOrError === 'object') {
    // 1. Check direct string fields
    if (typeof dataOrError.detail === 'string' && dataOrError.detail.trim()) {
      return dataOrError.detail
    }
    if (typeof dataOrError.error === 'string' && dataOrError.error.trim()) {
      return dataOrError.error
    }
    if (typeof dataOrError.message === 'string' && dataOrError.message.trim()) {
      return dataOrError.message
    }

    // 2. Check array of errors (e.g. FastAPI validation error list)
    if (Array.isArray(dataOrError.detail) && dataOrError.detail.length > 0) {
      const messages = dataOrError.detail.map((err: any) => {
        if (typeof err === 'string') return err
        const loc = Array.isArray(err?.loc)
          ? err.loc.filter((l: any) => l !== 'body').join(' -> ')
          : ''
        const msg = err?.msg || 'Invalid field'
        return loc ? `${loc}: ${msg}` : msg
      })
      return messages.join('; ')
    }

    if (Array.isArray(dataOrError.errors) && dataOrError.errors.length > 0) {
      return dataOrError.errors
        .map((e: any) => (typeof e === 'string' ? e : e?.message || JSON.stringify(e)))
        .join(', ')
    }

    // 3. Nested error object
    if (typeof dataOrError.error === 'object' && dataOrError.error !== null) {
      return getApiErrorMessage(dataOrError.error, fallbackMessage)
    }
  }

  if (typeof dataOrError === 'string' && dataOrError.trim()) {
    // Avoid returning HTML error pages (e.g. 502 Bad Gateway Nginx/Cloudflare)
    if (dataOrError.trim().startsWith('<')) {
      return 'Service temporarily unavailable. Please try again shortly.'
    }
    return dataOrError
  }

  return fallbackMessage
}
