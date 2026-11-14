import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { DEFAULT_HOME_LAYOUT, homeLayoutConfigSchema } from '@/lib/home-layout-config'

export const dynamic = 'force-dynamic'
const headers = { 'Cache-Control': 'no-store, max-age=0' }

export async function GET(request: NextRequest) {
  try {
    const session = await auth().catch(() => null)
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401, headers })
    }

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
  try {
    const session = await auth().catch(() => null)
    const role = (session?.user as any)?.role?.toUpperCase()
    if (!session?.user || (role !== 'ADMIN' && role !== 'SUPER_ADMIN')) {
      return NextResponse.json({ error: 'Unauthorized: Admin role required' }, { status: 401, headers })
    }

    const body = await request.json()
    const result = homeLayoutConfigSchema.safeParse(body)
    if (!result.success) {
      return NextResponse.json(
        { error: 'Invalid configuration payload', issues: result.error.issues },
        { status: 422, headers }
      )
    }

    const payloadString = JSON.stringify(result.data)

    await prisma.storeSetting.upsert({
      where: { key: 'home_sections_layout' },
      update: { value: payloadString },
      create: { key: 'home_sections_layout', value: payloadString },
    })

    return NextResponse.json({ success: true, layout: result.data }, { headers })
  } catch (error) {
    console.error('[API] /api/admin/home-layout POST error:', error)
    return NextResponse.json({ error: 'Failed to save home layout configuration' }, { status: 500, headers })
  }
}
