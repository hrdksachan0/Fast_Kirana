import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { DEFAULT_GIFTING_CONFIG, giftingStoreConfigSchema } from '@/lib/gifting-store-config'

export const dynamic = 'force-dynamic'
const headers = { 'Cache-Control': 'no-store, max-age=0' }

export async function GET(request: NextRequest) {
  try {
    const requested = request.nextUrl.searchParams.get('storeId') || request.headers.get('x-store-id')
    const storeId = requested && requested !== 'all' && requested !== 'ALL' ? requested.trim() : null

    const key = storeId ? `store:${storeId}:gifting_store_config` : 'gifting_store_config'
    const rows = await prisma.storeSetting.findMany({
      where: { key: { in: [...new Set([key, 'gifting_store_config'])] } },
      select: { key: true, value: true },
    })

    const row = rows.find(r => r.key === key) ?? rows.find(r => r.key === 'gifting_store_config')

    if (!row || !row.value) {
      return NextResponse.json(DEFAULT_GIFTING_CONFIG, { headers })
    }

    try {
      const parsed = JSON.parse(row.value)
      const result = giftingStoreConfigSchema.safeParse(parsed)
      if (result.success) {
        return NextResponse.json(result.data, { headers })
      }
    } catch (_) {}

    return NextResponse.json(DEFAULT_GIFTING_CONFIG, { headers })
  } catch (error) {
    console.error('[API] /api/gifting-store fetch error:', error)
    return NextResponse.json(DEFAULT_GIFTING_CONFIG, { headers })
  }
}
