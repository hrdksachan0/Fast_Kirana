import { NextResponse } from 'next/server'

// Disabled in production: this test endpoint allowed marking orders as PAID without payment
export async function POST() {
  return NextResponse.json({ error: 'Endpoint not found' }, { status: 404 })
}
