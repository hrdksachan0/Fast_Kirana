import { NextRequest, NextResponse } from 'next/server'

const FASTAPI = process.env.NEXT_PUBLIC_FASTAPI_URL || ''

/**
 * POST /api/cart/add - Proxy to FastAPI
 * Body: { productId, quantity, selectedVariant, notes }
 */
export async function POST(request: NextRequest) {
  const auth = request.headers.get('authorization') ?? ''
  const body = await request.json()

  try {
    const res = await fetch(`${FASTAPI}/api/cart/add`, {
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
    console.error('Cart add proxy error:', error)
    return NextResponse.json(
      { error: 'Failed to add to cart' },
      { status: 502 }
    )
  }
}