import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { DEFAULT_BAKERY_CONFIG, bakeryStoreConfigSchema } from '@/lib/bakery-store-config'

export const dynamic = 'force-dynamic'
export const revalidate = 60 // Cache for 60 seconds

const headers = {
  'Content-Type': 'application/json',
  'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=120',
  'Access-Control-Allow-Origin': '*',
}

export async function GET() {
  try {
    const row = await prisma.storeSetting.findUnique({
      where: { key: 'bakery_store_config' },
      select: { value: true },
    })

    if (!row || !row.value) {
      return NextResponse.json(DEFAULT_BAKERY_CONFIG, { headers })
    }

    try {
      const parsed = JSON.parse(row.value)
      const result = bakeryStoreConfigSchema.safeParse(parsed)
      if (result.success) {
        return NextResponse.json(result.data, { headers })
      }
    } catch (_) {}

    return NextResponse.json(DEFAULT_BAKERY_CONFIG, { headers })
  } catch (error) {
    console.error('[API] /api/bakery-store GET error:', error)
    return NextResponse.json(DEFAULT_BAKERY_CONFIG, { headers })
  }
}
