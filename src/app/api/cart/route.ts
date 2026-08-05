import { NextRequest, NextResponse } from 'next/server'

const FASTAPI = process.env.NEXT_PUBLIC_FASTAPI_URL || ''

/**
 * GET /api/cart - Proxy to FastAPI
 * Returns user's cart with items and product details
 */
export async function GET(request: NextRequest) {
  const auth = request.headers.get('authorization') ?? ''

  try {
    const res = await fetch(`${FASTAPI}/api/cart`, {
      headers: { Authorization: auth },
      cache: 'no-store',
    })
    const data = await res.json().catch(() => ({}))
    return NextResponse.json(data, { status: res.status })
  } catch (error) {
    console.error('Cart proxy GET error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch cart' },
      { status: 502 }
    )
  }
}

/**
 * POST /api/cart - Proxy to FastAPI (full cart sync)
 * Body: { items: [{ productId, quantity, selectedVariant, notes }] }
 */
export async function POST(request: NextRequest) {
  const auth = request.headers.get('authorization') ?? ''
  const body = await request.json()

  try {
    const res = await fetch(`${FASTAPI}/api/cart`, {
      method: 'POST',
      headers: {
        Authorization: auth,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    })
    const data = await res.json().catch(() => ({}))
    return NextResponse.json(data, { status: res.status })
  } catch (error) {
    console.error('Cart sync proxy error:', error)
    return NextResponse.json(
      { error: 'Failed to sync cart' },
      { status: 502 }
    )
  }
}

/**
 * DELETE /api/cart - Proxy to FastAPI (clear cart)
 */
export async function DELETE(request: NextRequest) {
  const auth = request.headers.get('authorization') ?? ''

  try {
    const res = await fetch(`${FASTAPI}/api/cart`, {
      method: 'DELETE',
      headers: { Authorization: auth },
    })
    const data = await res.json().catch(() => ({}))
    return NextResponse.json(data, { status: res.status })
  } catch (error) {
    console.error('Cart clear proxy error:', error)
    return NextResponse.json(
      { error: 'Failed to clear cart' },
      { status: 502 }
    )
  }
}