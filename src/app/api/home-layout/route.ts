import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { DEFAULT_HOME_LAYOUT, homeLayoutConfigSchema } from '@/lib/home-layout-config'

export const dynamic = 'force-dynamic'
const headers = { 'Cache-Control': 'no-store, max-age=0' }

export async function GET(request: NextRequest) {
  try {
    const requested = request.nextUrl.searchParams.get('storeId') || request.headers.get('x-store-id')
    const storeId = requested && requested !== 'all' && requested !== 'ALL' ? requested.trim() : null

    const key = storeId ? `store:${storeId}:home_sections_layout` : 'home_sections_layout'
    const rows = await prisma.storeSetting.findMany({
      where: { key: { in: [...new Set([key, 'home_sections_layout'])] } },
      select: { key: true, value: true },
    })

    const row = rows.find(r => r.key === key) ?? rows.find(r => r.key === 'home_sections_layout')

    if (!row || !row.value) {
      return NextResponse.json(DEFAULT_HOME_LAYOUT, { headers })
    }

    try {
      const parsed = JSON.parse(row.value)
      const result = homeLayoutConfigSchema.safeParse(parsed)
      if (result.success) {
        const sorted = [...result.data.sections].sort((a, b) => a.sortOrder - b.sortOrder)
        return NextResponse.json({ sections: sorted }, { headers })
      }
    } catch (_) {}

    return NextResponse.json(DEFAULT_HOME_LAYOUT, { headers })
  } catch (error) {
    console.error('[API] /api/home-layout fetch error:', error)
    return NextResponse.json(DEFAULT_HOME_LAYOUT, { headers })
  }
}
