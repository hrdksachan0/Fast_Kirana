import { NextResponse } from 'next/server'
import { revalidateStorefront } from '@/lib/revalidate'
import { revalidateTag } from 'next/cache'

export async function POST(request: Request) {
  try {
    const authHeader = request.headers.get('x-api-secret')
    if (authHeader !== process.env.AUTH_SECRET) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()
    const { categorySlug, restaurantSlug } = body

    revalidateTag('categories', 'max')
    revalidateStorefront(categorySlug, restaurantSlug)

    return NextResponse.json({ success: true })
  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
}
