import NextAuth from 'next-auth'
import { authConfig } from '@/auth.config'
import { NextResponse } from 'next/server'

const { auth } = NextAuth(authConfig)

export const proxy = auth((req) => {
  const isLoggedIn = !!req.auth
  const { nextUrl } = req

  const isApiAuthRoute = nextUrl.pathname.startsWith('/api/auth')
  const isAuthRoute = nextUrl.pathname === '/login' || nextUrl.pathname === '/signup'
  const isAdminRoute = nextUrl.pathname.startsWith('/admin')

  // Redirect B2B wholesale route away since B2B is disabled as of now
  if (nextUrl.pathname.startsWith('/wholesale')) {
    return NextResponse.redirect(new URL('/', nextUrl))
  }

  // Allow API auth routes to go through
  if (isApiAuthRoute) return NextResponse.next()

  // Redirect logged-in users away from /login and /signup
  if (isAuthRoute) {
    if (isLoggedIn) {
      return NextResponse.redirect(new URL('/', nextUrl))
    }
    return NextResponse.next()
  }

  // Redirect authenticated users who lack a mobile number to /setup-profile
  const isSetupProfileRoute = nextUrl.pathname === '/setup-profile'
  if (isLoggedIn && !isSetupProfileRoute) {
    const userPhone = req.auth?.user?.phone
    if (!userPhone) {
      return NextResponse.redirect(new URL('/setup-profile', nextUrl))
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
    return NextResponse.redirect(new URL(`/login?callbackUrl=${encodedCallbackUrl}`, nextUrl))
  }

  // Protect delivery routes
  const isDeliveryRoute = nextUrl.pathname.startsWith('/delivery')
  if (isDeliveryRoute) {
    if (!isLoggedIn) {
      const callbackUrl = encodeURIComponent(nextUrl.pathname + nextUrl.search)
      return NextResponse.redirect(new URL(`/login?callbackUrl=${callbackUrl}`, nextUrl))
    }
    const userRole = req.auth?.user?.role
    if (userRole !== 'DELIVERY' && userRole !== 'ADMIN') {
      return NextResponse.redirect(new URL('/', nextUrl))
    }
  }

  // Protect picker routes
  const isPickerRoute = nextUrl.pathname.startsWith('/picker')
  if (isPickerRoute) {
    if (!isLoggedIn) {
      const callbackUrl = encodeURIComponent(nextUrl.pathname + nextUrl.search)
      return NextResponse.redirect(new URL(`/login?callbackUrl=${callbackUrl}`, nextUrl))
    }
    const userRole = req.auth?.user?.role
    if (userRole !== 'PICKER' && userRole !== 'ADMIN') {
      return NextResponse.redirect(new URL('/', nextUrl))
    }
  }

  // Protect cafe-kitchen routes
  const isCafeRoute = nextUrl.pathname.startsWith('/cafe-kitchen')
  if (isCafeRoute) {
    if (!isLoggedIn) {
      const callbackUrl = encodeURIComponent(nextUrl.pathname + nextUrl.search)
      return NextResponse.redirect(new URL(`/login?callbackUrl=${callbackUrl}`, nextUrl))
    }
    const userRole = req.auth?.user?.role
    if (userRole !== 'CHEF' && userRole !== 'ADMIN') {
      return NextResponse.redirect(new URL('/', nextUrl))
    }
  }

  // Protect admin routes
  if (isAdminRoute) {
    if (!isLoggedIn) {
      const callbackUrl = encodeURIComponent(nextUrl.pathname + nextUrl.search)
      return NextResponse.redirect(new URL(`/login?callbackUrl=${callbackUrl}`, nextUrl))
    }
    const userRole = req.auth?.user?.role
    if (userRole !== 'ADMIN') {
      return NextResponse.redirect(new URL('/', nextUrl))
    }
  }

  return NextResponse.next()
})

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|products/|categories/|icons/).*)'],
}
