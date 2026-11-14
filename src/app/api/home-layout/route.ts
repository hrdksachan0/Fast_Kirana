import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { DEFAULT_HOME_LAYOUT, homeLayoutConfigSchema } from '@/lib/home-layout-config'

export const dynamic = 'force-dynamic'
const headers = { 'Cache-Control': 'no-store, max-age=0' }

export async function GET(request: NextRequest) {
  try {
    const row = await prisma.storeSetting.findUnique({
      where: { key: 'home_sections_layout' },
      select: { value: true },
    })

    if (!row || !row.value) {
      return NextResponse.json(DEFAULT_HOME_LAYOUT, { headers })
    }

    try {
      const parsed = JSON.parse(row.value)
      const result = homeLayoutConfigSchema.safeParse(parsed)
      if (result.success) {
        // Sort sections by sortOrder
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
