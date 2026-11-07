import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { DEFAULT_BAKERY_CONFIG, bakeryStoreConfigSchema } from '@/lib/bakery-store-config'

export const dynamic = 'force-dynamic'
const headers = { 'Cache-Control': 'no-store, max-age=0' }

export async function GET(request: NextRequest) {
  try {
    const session = await auth().catch(() => null)
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401, headers })
    }

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
    console.error('[API] /api/admin/bakery-store GET error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500, headers })
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await auth().catch(() => null)
    const role = (session?.user as any)?.role?.toUpperCase()
    if (!session?.user || (role !== 'ADMIN' && role !== 'SUPER_ADMIN')) {
      return NextResponse.json({ error: 'Unauthorized: Admin role required' }, { status: 401, headers })
    }

    const body = await request.json()
    const result = bakeryStoreConfigSchema.safeParse(body)
    if (!result.success) {
      return NextResponse.json(
        { error: 'Invalid configuration payload', issues: result.error.issues },
        { status: 422, headers }
      )
    }

    const payloadString = JSON.stringify(result.data)

    await prisma.storeSetting.upsert({
      where: { key: 'bakery_store_config' },
      update: { value: payloadString },
      create: { key: 'bakery_store_config', value: payloadString },
    })

    return NextResponse.json({ success: true, config: result.data }, { headers })
  } catch (error) {
    console.error('[API] /api/admin/bakery-store POST error:', error)
    return NextResponse.json({ error: 'Failed to save bakery store configuration' }, { status: 500, headers })
  }
}
