import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin, getEffectiveStoreId } from '@/lib/auth-guard'
import { DEFAULT_BAKERY_CONFIG, bakeryStoreConfigSchema } from '@/lib/bakery-store-config'

export const dynamic = 'force-dynamic'
const headers = { 'Cache-Control': 'no-store, max-age=0' }

export async function GET(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const requested = request.nextUrl.searchParams.get('storeId')
    const effectiveStoreId = getEffectiveStoreId(session, requested)

    const key = effectiveStoreId ? `store:${effectiveStoreId}:bakery_store_config` : 'bakery_store_config'
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
    console.error('[API] /api/admin/bakery-store GET error:', error)
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

    const result = bakeryStoreConfigSchema.safeParse(body)
    if (!result.success) {
      return NextResponse.json(
        { error: 'Invalid configuration payload', issues: result.error.issues },
        { status: 422, headers }
      )
    }

    const payloadString = JSON.stringify(result.data)
    const key = effectiveStoreId ? `store:${effectiveStoreId}:bakery_store_config` : 'bakery_store_config'

    await prisma.storeSetting.upsert({
      where: { key },
      update: { value: payloadString },
      create: { key, value: payloadString },
    })

    return NextResponse.json({ success: true, config: result.data, storeId: effectiveStoreId }, { headers })
  } catch (error) {
    console.error('[API] /api/admin/bakery-store POST error:', error)
    return NextResponse.json({ error: 'Failed to save bakery store configuration' }, { status: 500, headers })
  }
}
