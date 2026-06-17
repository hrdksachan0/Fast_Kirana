import NextAuth from 'next-auth'
import { authConfig } from '@/auth.config'
import { NextResponse } from 'next/server'

// Clean environment variables (removes quotes if copy-pasted with quotes)
const getCleanSecret = (key: string): string => {
  let val = process.env[key] || ''
  val = val.trim()
  if (val.startsWith('"') && val.endsWith('"')) {
    val = val.substring(1, val.length - 1)
  }
  if (val.startsWith("'") && val.endsWith("'")) {
    val = val.substring(1, val.length - 1)
  }
  return val.trim()
}

const cleanSecret = getCleanSecret('AUTH_SECRET')

const { auth } = NextAuth({
  ...authConfig,
  secret: cleanSecret || undefined,
})

export const proxy = auth((req) => {
  const isLoggedIn = !!req.auth
  const { nextUrl } = req

  // Reconstruct original request domain to bypass NextAuth NEXTAUTH_URL localhost overrides
  const host = req.headers.get('x-forwarded-host') || req.headers.get('host') || nextUrl.host
  const proto = req.headers.get('x-forwarded-proto') || (nextUrl.protocol ? nextUrl.protocol.replace(':', '') : 'https')
  const baseUrl = `${proto}://${host}`

  const isApiAuthRoute = nextUrl.pathname.startsWith('/api/auth')
  const isAuthRoute = nextUrl.pathname === '/login' || nextUrl.pathname === '/signup'
  const isAdminRoute = nextUrl.pathname.startsWith('/admin')


  // Allow API auth routes to go through
  if (isApiAuthRoute) return NextResponse.next()

  // Redirect logged-in users away from /login and /signup
  if (isAuthRoute) {
    if (isLoggedIn) {
      return NextResponse.redirect(new URL('/', baseUrl))
    }
    return NextResponse.next()
  }

  // Redirect authenticated users who lack a mobile number to /setup-profile
  const isSetupProfileRoute = nextUrl.pathname === '/setup-profile'
  if (isLoggedIn && !isSetupProfileRoute) {
    const userPhone = req.auth?.user?.phone
    if (!userPhone) {
      return NextResponse.redirect(new URL('/setup-profile', baseUrl))
    }
  }

  // Protect account, checkout, and order routes
  const isProtectedRoute =
    nextUrl.pathname.startsWith('/account') ||
    nextUrl.pathname.startsWith('/checkout') ||
    nextUrl.pathname.startsWith('/order')

  if (isProtectedRoute && !isLoggedIn) {
    let callbackUrl = nextUrl.pathname
    if (nextUrl.search) {
      callbackUrl += nextUrl.search
    }
    const encodedCallbackUrl = encodeURIComponent(callbackUrl)
    return NextResponse.redirect(new URL(`/login?callbackUrl=${encodedCallbackUrl}`, baseUrl))
  }

  // Protect delivery routes
  const isDeliveryRoute = nextUrl.pathname.startsWith('/delivery')
  if (isDeliveryRoute) {
    if (!isLoggedIn) {
      const callbackUrl = encodeURIComponent(nextUrl.pathname + nextUrl.search)
      return NextResponse.redirect(new URL(`/login?callbackUrl=${callbackUrl}`, baseUrl))
    }
    const userRole = req.auth?.user?.role
    if (userRole !== 'DELIVERY' && userRole !== 'ADMIN') {
      return NextResponse.redirect(new URL('/', baseUrl))
    }
  }

  // Protect picker routes
  const isPickerRoute = nextUrl.pathname.startsWith('/picker')
  if (isPickerRoute) {
    if (!isLoggedIn) {
      const callbackUrl = encodeURIComponent(nextUrl.pathname + nextUrl.search)
      return NextResponse.redirect(new URL(`/login?callbackUrl=${callbackUrl}`, baseUrl))
    }
    const userRole = req.auth?.user?.role
    if (userRole !== 'PICKER' && userRole !== 'ADMIN') {
      return NextResponse.redirect(new URL('/', baseUrl))
    }
  }

  // Protect cafe-kitchen routes
  const isCafeRoute = nextUrl.pathname.startsWith('/cafe-kitchen')
  if (isCafeRoute) {
    if (!isLoggedIn) {
      const callbackUrl = encodeURIComponent(nextUrl.pathname + nextUrl.search)
      return NextResponse.redirect(new URL(`/login?callbackUrl=${callbackUrl}`, baseUrl))
    }
    const userRole = req.auth?.user?.role
    if (userRole !== 'CHEF' && userRole !== 'ADMIN') {
      return NextResponse.redirect(new URL('/', baseUrl))
    }
  }

  // Protect admin routes
  if (isAdminRoute) {
    if (!isLoggedIn) {
      const callbackUrl = encodeURIComponent(nextUrl.pathname + nextUrl.search)
      return NextResponse.redirect(new URL(`/login?callbackUrl=${callbackUrl}`, baseUrl))
    }
    const userRole = req.auth?.user?.role
    if (userRole !== 'ADMIN') {
      return NextResponse.redirect(new URL('/', baseUrl))
    }
  }

  return NextResponse.next()
})

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|products/|categories/|icons/).*)'],
}
