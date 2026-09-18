import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'
import { clearSettingsCache } from '@/lib/settings-cache'
import { requireAdmin } from '@/lib/auth-guard'

import { checkIsStoreOpen } from '@/app/api/settings/route'

export async function PATCH(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const body = await request.json()
    const { storeId, ...settingsPayload } = body
    const isStoreScoped = Boolean(storeId && storeId !== 'all')

    // 1. Fetch current settings to perform delta updates
    const currentSettings = await prisma.storeSetting.findMany()
    const currentMap = new Map(currentSettings.map(s => [s.key, s.value]))

    if (isStoreScoped) {
      // Store-scoped updates: prefix keys with store:${storeId}:
      const storePrefix = `store:${storeId}:`
      const changedEntries = Object.entries(settingsPayload).filter(([key, value]) => {
        const scopedKey = `${storePrefix}${key}`
        return !currentMap.has(scopedKey) || currentMap.get(scopedKey) !== String(value)
      })

      if (changedEntries.length > 0) {
        const updates: Promise<any>[] = []

        changedEntries.forEach(([key, value]) => {
          const scopedKey = `${storePrefix}${key}`
          updates.push(
            prisma.storeSetting.upsert({
              where: { key: scopedKey },
              update: { value: String(value) },
              create: { key: scopedKey, value: String(value) },
            })
          )

          // If updating Ghatampur base hub, keep legacy un-prefixed keys in sync for backward compatibility
          if (storeId === 'hub-209206') {
            updates.push(
              prisma.storeSetting.upsert({
                where: { key },
                update: { value: String(value) },
                create: { key, value: String(value) },
              })
            )
          }
        })

        await Promise.all(updates)

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

        clearSettingsCache()
      }
    } else {
      // Global/Platform-wide updates (legacy or superadmin all-hubs mode)
      const changedEntries = Object.entries(settingsPayload).filter(([key, value]) => {
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

        // Sync all dark_stores table if grocery operating state or auto timing changed
        if (
          settingsPayload.grocery_auto_timing !== undefined ||
          settingsPayload.grocery_mart_open !== undefined ||
          settingsPayload.grocery_open_time !== undefined ||
          settingsPayload.grocery_close_time !== undefined
        ) {
          const mergedSettings: Record<string, string> = { ...Object.fromEntries(currentMap.entries()), ...settingsPayload }
          const isEffectiveOpen = checkIsStoreOpen(mergedSettings, 'grocery')
          try {
            await prisma.darkStore.updateMany({
              data: { groceryOpen: isEffectiveOpen },
            })
          } catch (syncErr) {
            console.warn('Failed to sync dark stores status:', syncErr)
          }
        }

        // Sync active restaurants if restaurant timings updated
        if (settingsPayload.restaurant_open_time !== undefined || settingsPayload.restaurant_close_time !== undefined) {
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

        clearSettingsCache()
      }
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
