import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { revalidateStorefront } from '@/lib/revalidate'
import { clearSettingsCache } from '@/lib/settings-cache'
import { requireAdmin } from '@/lib/auth-guard'
import { checkIsStoreOpen } from '@/app/api/settings/route'

async function batchUpsertStoreSettings(entries: { key: string; value: string }[]) {
  if (entries.length === 0) return
  // Build safe parameterized bulk upsert using Prisma.sql and Prisma.join
  const valueTuples = entries.map(
    (e) => Prisma.sql`(${`ss_${Math.random().toString(36).substring(2, 14)}`}, ${e.key}, ${String(e.value)}, NOW(), NOW())`
  )
  await prisma.$executeRaw`
    INSERT INTO store_settings (id, key, value, "createdAt", "updatedAt")
    VALUES ${Prisma.join(valueTuples)}
    ON CONFLICT (key) DO UPDATE
    SET value = EXCLUDED.value, "updatedAt" = NOW()
  `
}

export async function PATCH(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error

  try {
    const body = await request.json()
    const { storeId, ...settingsPayload } = body
    const isStoreScoped = Boolean(storeId && storeId !== 'all')

    // 1. Fetch current settings in 1 fast query to perform in-memory delta checks
    const currentSettings = await prisma.storeSetting.findMany()
    const currentMap = new Map(currentSettings.map((s) => [s.key, s.value]))

    if (isStoreScoped) {
      // Store-scoped updates: prefix keys with store:${storeId}:
      const storePrefix = `store:${storeId}:`
      const mapToUpsert = new Map<string, string>()

      for (const [key, value] of Object.entries(settingsPayload)) {
        const scopedKey = `${storePrefix}${key}`
        const strVal = String(value)
        if (!currentMap.has(scopedKey) || currentMap.get(scopedKey) !== strVal) {
          mapToUpsert.set(scopedKey, strVal)
        }

        // If updating Ghatampur base hub, keep legacy un-prefixed keys in sync for backward compatibility
        if (storeId === 'hub-209206') {
          if (!currentMap.has(key) || currentMap.get(key) !== strVal) {
            mapToUpsert.set(key, strVal)
          }
        }
      }

      if (mapToUpsert.size > 0) {
        const uniqueEntries = Array.from(mapToUpsert.entries()).map(([k, v]) => ({ key: k, value: v }))
        await batchUpsertStoreSettings(uniqueEntries)

        // Sync DarkStore table fields for this specific hub
        const darkStoreUpdateData: Record<string, any> = {}

        if (settingsPayload.store_lat && !isNaN(parseFloat(settingsPayload.store_lat))) {
          darkStoreUpdateData.latitude = parseFloat(settingsPayload.store_lat)
        }
        if (settingsPayload.store_lng && !isNaN(parseFloat(settingsPayload.store_lng))) {
          darkStoreUpdateData.longitude = parseFloat(settingsPayload.store_lng)
        }
        if (settingsPayload.delivery_radius && !isNaN(parseFloat(settingsPayload.delivery_radius))) {
          darkStoreUpdateData.deliveryRadiusKm = parseFloat(settingsPayload.delivery_radius)
        }

        if (
          settingsPayload.grocery_auto_timing !== undefined ||
          settingsPayload.grocery_mart_open !== undefined ||
          settingsPayload.grocery_open_time !== undefined ||
          settingsPayload.grocery_close_time !== undefined
        ) {
          const mergedSettings: Record<string, string> = {
            ...Object.fromEntries(
              Array.from(currentMap.entries())
                .filter(([k]) => k.startsWith(storePrefix))
                .map(([k, v]) => [k.slice(storePrefix.length), v])
            ),
            ...settingsPayload,
          }
          darkStoreUpdateData.groceryOpen = checkIsStoreOpen(mergedSettings, 'grocery')
        }

        if (settingsPayload.surge_manual_amount !== undefined && !isNaN(parseFloat(settingsPayload.surge_manual_amount))) {
          if (settingsPayload.surge_mode === 'MANUAL_ON') {
            darkStoreUpdateData.surgeCharge = parseFloat(settingsPayload.surge_manual_amount)
          } else if (settingsPayload.surge_mode === 'MANUAL_OFF') {
            darkStoreUpdateData.surgeCharge = 0.0
          }
        }

        if (Object.keys(darkStoreUpdateData).length > 0) {
          try {
            await prisma.darkStore.update({
              where: { id: storeId },
              data: darkStoreUpdateData,
            })
          } catch (syncErr) {
            console.warn(`Failed to sync dark store ${storeId} data:`, syncErr)
          }
        }
      }
    } else {
      // Global/Platform-wide updates (legacy or superadmin all-hubs mode)
      const mapToUpsert = new Map<string, string>()
      for (const [key, value] of Object.entries(settingsPayload)) {
        const strVal = String(value)
        if (!currentMap.has(key) || currentMap.get(key) !== strVal) {
          mapToUpsert.set(key, strVal)
        }
      }

      if (mapToUpsert.size > 0) {
        const uniqueEntries = Array.from(mapToUpsert.entries()).map(([k, v]) => ({ key: k, value: v }))
        await batchUpsertStoreSettings(uniqueEntries)

        // Sync dark stores table if radius or coords changed
        const darkStoreGlobalUpdate: Record<string, any> = {}
        if (settingsPayload.delivery_radius && !isNaN(parseFloat(settingsPayload.delivery_radius))) {
          darkStoreGlobalUpdate.deliveryRadiusKm = parseFloat(settingsPayload.delivery_radius)
        }
        if (settingsPayload.store_lat && !isNaN(parseFloat(settingsPayload.store_lat))) {
          darkStoreGlobalUpdate.latitude = parseFloat(settingsPayload.store_lat)
        }
        if (settingsPayload.store_lng && !isNaN(parseFloat(settingsPayload.store_lng))) {
          darkStoreGlobalUpdate.longitude = parseFloat(settingsPayload.store_lng)
        }

        if (
          settingsPayload.grocery_auto_timing !== undefined ||
          settingsPayload.grocery_mart_open !== undefined ||
          settingsPayload.grocery_open_time !== undefined ||
          settingsPayload.grocery_close_time !== undefined
        ) {
          const mergedSettings: Record<string, string> = { ...Object.fromEntries(currentMap.entries()), ...settingsPayload }
          darkStoreGlobalUpdate.groceryOpen = checkIsStoreOpen(mergedSettings, 'grocery')
        }

        if (Object.keys(darkStoreGlobalUpdate).length > 0) {
          try {
            const centralHub = await prisma.darkStore.findFirst({ where: { id: 'hub-209206' } })
            if (centralHub) {
              await prisma.darkStore.update({
                where: { id: centralHub.id },
                data: darkStoreGlobalUpdate,
              })
            }
          } catch (syncErr) {
            console.warn('Failed to sync dark stores status/radius:', syncErr)
          }
        }

        // Sync active restaurants ONLY if restaurant timings actually changed
        const resOpenChanged =
          settingsPayload.restaurant_open_time &&
          currentMap.get('restaurant_open_time') !== settingsPayload.restaurant_open_time
        const resCloseChanged =
          settingsPayload.restaurant_close_time &&
          currentMap.get('restaurant_close_time') !== settingsPayload.restaurant_close_time

        if (resOpenChanged || resCloseChanged) {
          try {
            const updateData: { openTime?: string; closeTime?: string } = {}
            if (settingsPayload.restaurant_open_time) updateData.openTime = settingsPayload.restaurant_open_time
            if (settingsPayload.restaurant_close_time) updateData.closeTime = settingsPayload.restaurant_close_time
            await prisma.restaurant.updateMany({
              where: { isActive: true },
              data: updateData,
            })
          } catch (rErr) {
            console.warn('Failed to sync restaurant timings:', rErr)
          }
        }
      }
    }

    // 3. Trigger storefront revalidation and cache clear asynchronously without blocking the response
    Promise.resolve().then(async () => {
      try {
        await clearSettingsCache().catch(() => {})
        revalidateStorefront()
        const fastApiUrl = process.env.NEXT_PUBLIC_FASTAPI_URL || 'https://api.fastkirana.in'
        fetch(`${fastApiUrl}/api/stores/clear-cache`, { method: 'POST' }).catch(() => {})
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
