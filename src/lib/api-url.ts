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
export function apiUrl(): string {
  // Always return empty string for Web frontend.
  // Same-origin relative paths ('/api/...') ensure NextAuth session cookies
  // are automatically included with every request, preventing 401 Unauthorized
  // errors on checkout addresses, admin panel, bridge-session, and order placement.
  return ''
}

/**
 * Resolves a relative API path to a full URL for client-side use.
 * Convenience wrapper around apiUrl().
 *
 * @example
 *   const res = await fetch(resolveApiPath('/api/products'))
 *   // Client: 'https://api.fastkirana.in/api/products'
 *   // Server: '/api/products'
 */
export function resolveApiPath(path: string): string {
  const base = apiUrl()
  if (!base) return path
  // Avoid double slashes
  const cleanPath = path.startsWith('/') ? path : `/${path}`
  return `${base}${cleanPath}`
}

export default apiUrl
