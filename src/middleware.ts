import { auth } from "@/auth"
import { NextResponse } from "next/server"

export default auth((req: any) => {
  const requestHeaders = new Headers(req.headers)

  if (req.auth?.user) {
    const u = req.auth.user as any
    if (u.id) {
      requestHeaders.set("x-user-id", u.id)
    }
    if (u.role) {
      requestHeaders.set("x-user-role", u.role)
    }
    if (u.assignedRestaurantId) {
      requestHeaders.set("x-user-restaurant-id", u.assignedRestaurantId)
    }
  }

  return NextResponse.next({
    request: {
      headers: requestHeaders,
    },
  })
})

export const config = {
  matcher: ["/api/:path*"],
}
