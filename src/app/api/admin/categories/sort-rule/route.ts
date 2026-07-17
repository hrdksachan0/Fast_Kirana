import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'

// GET: Fetch sorting rule for a category
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const categorySlug = searchParams.get('categorySlug')
    if (!categorySlug) {
      return NextResponse.json({ error: 'categorySlug is required' }, { status: 400 })
    }

    const setting = await prisma.storeSetting.findUnique({
      where: { key: `category_sort_${categorySlug}` }
    })

    return NextResponse.json({ rule: setting?.value || 'manual' })
  } catch (error: any) {
    console.error('Failed to get category sort rule:', error)
    return NextResponse.json({ error: 'Failed to fetch sorting rule' }, { status: 500 })
  }
}

// POST: Save sorting rule for a category
export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user || (session.user as any).role !== 'ADMIN') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { categorySlug, rule } = await request.json()
    if (!categorySlug || !rule) {
      return NextResponse.json({ error: 'categorySlug and rule are required' }, { status: 400 })
    }

    // Upsert key-value pair in storeSettings
    const setting = await prisma.storeSetting.upsert({
      where: { key: `category_sort_${categorySlug}` },
      update: { value: rule },
      create: { key: `category_sort_${categorySlug}`, value: rule }
    })

    try {
      await revalidateStorefront()
    } catch (e) {
      console.warn('Revalidation failed:', e)
    }

    return NextResponse.json({ success: true, setting })
  } catch (error: any) {
    console.error('Failed to save category sort rule:', error)
    return NextResponse.json({ error: 'Failed to save sorting rule' }, { status: 500 })
  }
}
