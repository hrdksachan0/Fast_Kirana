import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'
import { getToken } from 'next-auth/jwt'

const secret = process.env.AUTH_SECRET || process.env.NEXTAUTH_SECRET

export async function proxy(req: NextRequest) {
  const token = await getToken({ req, secret: secret || undefined })
  const isLoggedIn = !!token
  const userRole = token?.role as string | undefined
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

  // Helper to get target console URL for staff roles
  const getStaffConsoleUrl = (role?: string) => {
    if (role === 'RESTAURANT_OWNER' || role === 'CHEF') return '/restaurant-kitchen'
    if (role === 'DELIVERY') return '/delivery'
    if (role === 'PICKER') return '/picker'
    return null
  }
  const staffConsoleUrl = getStaffConsoleUrl(userRole)

  // Redirect logged-in users away from /login and /signup to their console or callbackUrl
  if (isAuthRoute) {
    if (isLoggedIn) {
      const callbackUrl = nextUrl.searchParams.get('callbackUrl')
      if (callbackUrl && callbackUrl.startsWith('/') && !callbackUrl.startsWith('//')) {
        return NextResponse.redirect(new URL(callbackUrl, baseUrl))
      }
      const roleUpper = userRole?.toUpperCase()
      if (roleUpper === 'ADMIN') {
        return NextResponse.redirect(new URL('/admin', baseUrl))
      }
      if (staffConsoleUrl) {
        return NextResponse.redirect(new URL(staffConsoleUrl, baseUrl))
      }
      return NextResponse.redirect(new URL('/', baseUrl))
    }
    return NextResponse.next()
  }

  // If a staff user visits home page '/', redirect them directly to their console
  if (nextUrl.pathname === '/' && isLoggedIn && staffConsoleUrl) {
    return NextResponse.redirect(new URL(staffConsoleUrl, baseUrl))
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
    if (userRole?.toUpperCase() !== 'ADMIN') {
      return NextResponse.redirect(new URL('/', baseUrl))
    }
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|products/|categories/|icons/).*)'],
}
