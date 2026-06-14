import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'
import { clearSettingsCache } from '@/lib/settings-cache'

async function checkAdmin() {
  const session = await auth()
  return session?.user && (session.user as any).role === 'ADMIN'
}

export async function PATCH(request: NextRequest) {
  try {
    if (!(await checkAdmin())) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()

    // Expecting payload: { deliveries_count: '...', rating_value: '...', happy_families: '...', trusted_text: '...' }
    const updates = Object.entries(body).map(([key, value]) => {
      return prisma.storeSetting.upsert({
        where: { key },
        update: { value: String(value) },
        create: { key, value: String(value) },
      })
    })

    await Promise.all(updates)

    // Clear shared in-memory settings cache for instant client sync
    clearSettingsCache()

    // Invalidate storefront settings cache
    revalidateStorefront()

    return NextResponse.json({ success: true })
  } catch (error: any) {
    console.error('Error saving admin settings:', error)
    return NextResponse.json({ error: error.message || 'Failed to save settings' }, { status: 500 })
  }
}
