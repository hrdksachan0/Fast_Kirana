import { NextRequest, NextResponse } from 'next/server'
import { proxy, config as proxyConfig } from './proxy'

export async function middleware(req: NextRequest) {
  const response = await proxy(req)

  // Attach standard security headers to all responses
  response.headers.set('X-Frame-Options', 'SAMEORIGIN')
  response.headers.set('X-Content-Type-Options', 'nosniff')
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin')
  response.headers.set('X-XSS-Protection', '1; mode=block')

  return response
}

export const config = proxyConfig
