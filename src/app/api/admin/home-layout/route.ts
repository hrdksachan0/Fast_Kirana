import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin, getEffectiveStoreId } from '@/lib/auth-guard'
import { DEFAULT_HOME_LAYOUT, homeLayoutConfigSchema } from '@/lib/home-layout-config'

export const dynamic = 'force-dynamic'
const headers = { 'Cache-Control': 'no-store, max-age=0' }

export async function GET(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const requested = request.nextUrl.searchParams.get('storeId')
    const effectiveStoreId = getEffectiveStoreId(session, requested)

    const key = effectiveStoreId ? `store:${effectiveStoreId}:home_sections_layout` : 'home_sections_layout'
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
    console.error('[API] /api/admin/home-layout GET error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500, headers })
  }
}

export async function POST(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const body = await request.json()
    const requested = request.nextUrl.searchParams.get('storeId') || body.storeId
    const effectiveStoreId = getEffectiveStoreId(session, requested)

    const result = homeLayoutConfigSchema.safeParse(body)
    if (!result.success) {
      return NextResponse.json(
        { error: 'Invalid configuration payload', issues: result.error.issues },
        { status: 422, headers }
      )
    }

    const payloadString = JSON.stringify(result.data)
    const key = effectiveStoreId ? `store:${effectiveStoreId}:home_sections_layout` : 'home_sections_layout'

    await prisma.storeSetting.upsert({
      where: { key },
      update: { value: payloadString },
      create: { key, value: payloadString },
    })

    return NextResponse.json({ success: true, layout: result.data, storeId: effectiveStoreId }, { headers })
  } catch (error) {
    console.error('[API] /api/admin/home-layout POST error:', error)
    return NextResponse.json({ error: 'Failed to save home layout configuration' }, { status: 500, headers })
  }
}
