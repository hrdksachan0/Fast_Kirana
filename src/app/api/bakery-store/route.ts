import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { DEFAULT_BAKERY_CONFIG, bakeryStoreConfigSchema } from '@/lib/bakery-store-config'

export const dynamic = 'force-dynamic'
export const revalidate = 60

const headers = {
  'Content-Type': 'application/json',
  'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=120',
  'Access-Control-Allow-Origin': '*',
}

export async function GET(request: NextRequest) {
  try {
    const requested = request.nextUrl.searchParams.get('storeId') || request.headers.get('x-store-id')
    const storeId = requested && requested !== 'all' && requested !== 'ALL' ? requested.trim() : null

    const key = storeId ? `store:${storeId}:bakery_store_config` : 'bakery_store_config'
    const rows = await prisma.storeSetting.findMany({
      where: { key: { in: [...new Set([key, 'bakery_store_config'])] } },
      select: { key: true, value: true },
    })

    const row = rows.find(r => r.key === key) ?? rows.find(r => r.key === 'bakery_store_config')

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
