/**
 * Centralized API URL resolver for FastKirana Web Frontend.
 *
 * PURPOSE: Eliminate Vercel Fast Origin Transfer (FOT) bandwidth charges by
 * routing client-side API calls directly to the FastAPI backend on Railway,
 * bypassing Vercel's proxy/rewrite layer entirely.
 *
 * BEFORE (expensive):
 *   Browser → Vercel CDN (rewrite) → Railway FastAPI → back through Vercel → Browser
 *   (Every byte of response is billed as Fast Origin Transfer)
 *
 * AFTER (free):
 *   Browser → Railway FastAPI (direct) → Browser
 *   (Zero FOT charges — Vercel never touches the API response)
 *
 * Server-side code (SSR, API routes, Server Actions) continues to use
 * relative paths so Next.js internal routing still works for any remaining
 * Vercel-hosted API route handlers.
 */

const FASTAPI_DIRECT_URL = (
  process.env.NEXT_PUBLIC_FASTAPI_URL ||
  process.env.NEXT_PUBLIC_API_URL ||
  'https://api.fastkirana.in'
).replace(/\/+$/, '')

/**
 * Returns the correct base URL prefix for an API path.
 *
 * - **Client-side (browser)**: returns the direct Railway FastAPI URL
 *   so requests bypass Vercel entirely → zero FOT charges.
 * - **Server-side (SSR/API routes)**: returns empty string so relative
 *   paths resolve internally within Vercel's network.
 *
 * @example
 *   // In a client component:
 *   fetch(`${apiUrl()}/api/products?limit=50`)
 *
 *   // In a server component or API route:
 *   fetch(`${apiUrl()}/api/products?limit=50`)
 *   // → on server this becomes '/api/products?limit=50' (relative, internal)
 */
export function catalogApiUrl(): string {
  if (typeof window === 'undefined') return ''
  return FASTAPI_DIRECT_URL
}

/**
 * Returns the correct base URL prefix for an API path.
 *
 * - **Public Catalog / Store reads (browser)**: returns direct Railway FastAPI URL
 *   (`https://api.fastkirana.in`) bypassing Vercel proxy completely (Zero Fast Origin Transfer).
 * - **Session/Cookie sensitive routes (addresses, orders, auth, admin)**: returns empty string
 *   so same-origin NextAuth session cookies are preserved.
 * - **Server-side (SSR/API routes)**: returns empty string.
 */
export function apiUrl(path?: string): string {
  if (typeof window === 'undefined') {
    return ''
  }

  if (path) {
    const cleanPath = path.startsWith('/') ? path : `/${path}`
    // Routes requiring same-origin NextAuth session cookies or local Next.js route handlers
    if (
      cleanPath.startsWith('/api/auth') ||
      cleanPath.startsWith('/api/addresses') ||
      cleanPath.startsWith('/api/orders') ||
      cleanPath.startsWith('/api/payment') ||
      cleanPath.startsWith('/api/payments') ||
      cleanPath.startsWith('/api/admin') ||
      cleanPath.startsWith('/api/revalidate')
    ) {
      return ''
    }
    // Catalog, category, restaurant, banner, store, settings, search
    return FASTAPI_DIRECT_URL
  }

  // Default: return empty string so unspecified routes preserve cookies safely.
  // Use catalogApiUrl() for explicit high-bandwidth public catalog routes.
  return ''
}

/**
 * Resolves a relative API path to a full URL.
 * Automatically selects direct FastAPI URL for catalog routes or relative URL for auth routes.
 */
export function resolveApiPath(path: string): string {
  const base = apiUrl(path)
  if (!base) return path
  const cleanPath = path.startsWith('/') ? path : `/${path}`
  return `${base}${cleanPath}`
}

export default apiUrl

