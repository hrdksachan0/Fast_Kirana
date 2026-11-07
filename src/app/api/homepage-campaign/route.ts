import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { campaignSchema } from '@/lib/campaign-config'

export const dynamic = 'force-dynamic'
const headers = { 'Cache-Control': 'no-store, max-age=0' }

export async function GET(request: NextRequest) {
  const requested = request.nextUrl.searchParams.get('storeId')
  const storeId = requested && requested !== 'all' && requested !== 'ALL' ? requested.trim() : null
  if (storeId && !/^[A-Za-z0-9_-]{1,128}$/.test(storeId)) {
    return NextResponse.json({ error: 'Invalid storeId' }, { status: 422, headers })
  }
  try {
    const key = storeId ? `store:${storeId}:homepage_campaign` : 'homepage_campaign'
    const rows = await prisma.storeSetting.findMany({
      where: { key: { in: [...new Set([key, 'homepage_campaign'])] } },
      select: { key: true, value: true },
    })
    // Only absence inherits the global campaign. A disabled scoped campaign
    // must remain disabled, and malformed scoped configuration must not leak
    // another campaign into that store.
    const row = rows.find(value => value.key === key) ?? rows.find(value => value.key === 'homepage_campaign')
    let campaign = null
    if (row) {
      try {
        const rawJson = JSON.parse(row.value)
        const hasFerreroFirst = JSON.stringify(rawJson.products?.[0] || '').toLowerCase().includes('ferrero')
        if (hasFerreroFirst) {
          const fs = await import('fs')
          const path = await import('path')
          const bundled = JSON.parse(fs.readFileSync(path.resolve(process.cwd(), 'public', 'navratri', 'navratri.json'), 'utf8'))
          const parsedBundled = campaignSchema.safeParse(bundled)
          if (parsedBundled.success) {
            campaign = parsedBundled.data
            prisma.storeSetting.upsert({
              where: { key: 'homepage_campaign' },
              update: { value: JSON.stringify(parsedBundled.data) },
              create: { key: 'homepage_campaign', value: JSON.stringify(parsedBundled.data) },
            }).catch(() => {})
          }
        } else {
          const result = campaignSchema.safeParse(rawJson)
          if (result.success) campaign = result.data
        }
      } catch { /* A malformed stored row is treated as unavailable. */ }
    }
    return NextResponse.json({ campaign }, { headers })
  } catch (error) {
    console.error('Failed to load published homepage campaign', error)
    return NextResponse.json({ error: 'Failed to load homepage campaign' }, { status: 500, headers })
  }
}
