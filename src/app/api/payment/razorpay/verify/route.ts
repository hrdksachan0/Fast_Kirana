import { NextRequest, NextResponse } from 'next/server'
import { apiWriteLimiter } from '@/lib/rate-limit'

const FASTAPI_URL = (
  process.env.NEXT_PUBLIC_FASTAPI_URL ||
  process.env.NEXT_PUBLIC_API_URL ||
  'https://api.fastminute.in'
).replace(/\/+$/, '')

export async function POST(req: NextRequest) {
  const limited = await apiWriteLimiter.check(req)
  if (limited) return limited

  try {
    const body = await req.json()

    const res = await fetch(`${FASTAPI_URL}/api/payment/razorpay/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    })

    const data = await res.json()
    return NextResponse.json(data, { status: res.status })
  } catch (err: any) {
    console.error('Error proxying Razorpay verify:', err)
    return NextResponse.json(
      { error: err?.message || 'Failed to verify Razorpay payment' },
      { status: 500 }
    )
  }
}
