import { NextRequest, NextResponse } from 'next/server'
import { addToCartSchema, validateBody } from '@/lib/validation'

const FASTAPI = process.env.NEXT_PUBLIC_FASTAPI_URL || ''

export async function POST(request: NextRequest) {
  const validation = await validateBody(request, addToCartSchema)
  if (!validation.success) return validation.error

  const { productId, quantity, selectedVariant, notes } = validation.data

  const auth = request.headers.get('authorization') ?? ''

  try {
    const res = await fetch(`${FASTAPI}/api/cart/add`, {
      method: 'POST',
      headers: {
        Authorization: auth,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ productId, quantity, selectedVariant, notes }),
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
