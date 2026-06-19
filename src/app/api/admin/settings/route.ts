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

    // 1. Fetch current settings to perform delta updates
    const currentSettings = await prisma.storeSetting.findMany()
    const currentMap = new Map(currentSettings.map(s => [s.key, s.value]))

    // 2. Filter payload to only run database writes for keys that actually changed
    const changedEntries = Object.entries(body).filter(([key, value]) => {
      return !currentMap.has(key) || currentMap.get(key) !== String(value)
    })

    if (changedEntries.length > 0) {
      const updates = changedEntries.map(([key, value]) => {
        return prisma.storeSetting.upsert({
          where: { key },
          update: { value: String(value) },
          create: { key, value: String(value) },
        })
      })

      await Promise.all(updates)

      // Clear shared in-memory settings cache for instant client sync
      clearSettingsCache()
    }

    // 3. Trigger storefront revalidation asynchronously without blocking the response
    Promise.resolve().then(() => {
      try {
        revalidateStorefront()
      } catch (err) {
        console.error('Background revalidation failed:', err)
      }
    })

    return NextResponse.json({ success: true })
  } catch (error: any) {
    console.error('Error saving admin settings:', error)
    return NextResponse.json({ error: error.message || 'Failed to save settings' }, { status: 500 })
  }
}
