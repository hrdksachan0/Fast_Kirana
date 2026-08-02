/**
 * FastKirana API Client Router Configuration
 * Dynamically switches requests between Python FastAPI Microservice & Next.js Local Server
 */

export const FASTAPI_BASE_URL = process.env.NEXT_PUBLIC_FASTAPI_URL || 'http://localhost:8000'

export async function fetchFromFastAPI(endpoint: string, options: RequestInit = {}) {
  const url = `${FASTAPI_BASE_URL}${endpoint.startsWith('/') ? endpoint : `/${endpoint}`}`

  const defaultHeaders: Record<string, string> = {
    'Content-Type': 'application/json',
  }

  try {
    const res = await fetch(url, {
      ...options,
      headers: {
        ...defaultHeaders,
        ...(options.headers || {}),
      },
    })
    if (!res.ok) {
      const errBody = await res.json().catch(() => ({}))
      throw new Error(errBody.detail || errBody.error || `FastAPI error ${res.status}`)
    }
    return await res.json()
  } catch (err: any) {
    console.warn(`[FastAPI Client] Request to ${endpoint} failed, falling back to Next.js API:`, err.message)
    // Seamless fallback to Next.js API route if FastAPI service is unreachable
    const fallbackRes = await fetch(endpoint, options)
    if (!fallbackRes.ok) {
      throw new Error(`API error ${fallbackRes.status}`)
    }
    return await fallbackRes.json()
  }
}
