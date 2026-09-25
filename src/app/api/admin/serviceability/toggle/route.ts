import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth-guard'
import { clearSettingsCache } from '@/lib/settings-cache'
import { revalidateStorefront } from '@/lib/revalidate'

export type ServiceabilityAction = 'RESUME' | 'PAUSE' | 'CLOSE_TODAY'
export type ServiceabilityTarget = 'HUB' | 'RESTAURANT' | 'GLOBAL'

export async function POST(request: NextRequest) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const body = await request.json()
    const {
      targetType = 'HUB',
      targetId,
      action,
      pauseMinutes,
      reason = 'OPERATIONAL_ADJUSTMENT',
      customReasonText,
    }: {
      targetType: ServiceabilityTarget
      targetId?: string
      action: ServiceabilityAction
      pauseMinutes?: number
      reason?: string
      customReasonText?: string
    } = body

    const finalReason = customReasonText?.trim() || reason
    const now = new Date()

    let pauseUntil: Date | null = null
    let isOpen = true

    if (action === 'PAUSE') {
      const minutes = Number(pauseMinutes) || 30
      pauseUntil = new Date(now.getTime() + minutes * 60 * 1000)
      isOpen = false
    } else if (action === 'CLOSE_TODAY') {
      pauseUntil = null
      isOpen = false
    } else if (action === 'RESUME') {
      pauseUntil = null
      isOpen = true
    }

    // 1. HUB / DARKSTORE SERVICEABILITY TOGGLE
    if (targetType === 'HUB') {
      const storeId = targetId || 'hub-209206'
      
      const updatedStore = await prisma.darkStore.update({
        where: { id: storeId },
        data: {
          groceryOpen: isOpen,
          pauseUntil: pauseUntil,
          closeReason: isOpen ? null : finalReason,
          closedByUserId: session.user?.id || null,
        },
      })

      // Sync StoreSetting for backward compatibility
      const storePrefix = `store:${storeId}:`
      await prisma.storeSetting.upsert({
        where: { key: `${storePrefix}grocery_mart_open` },
        update: { value: String(isOpen) },
        create: { key: `${storePrefix}grocery_mart_open`, value: String(isOpen) },
      })

      if (storeId === 'hub-209206') {
        await prisma.storeSetting.upsert({
          where: { key: 'grocery_mart_open' },
          update: { value: String(isOpen) },
          create: { key: 'grocery_mart_open', value: String(isOpen) },
        })
      }

      await clearSettingsCache()
      await revalidateStorefront()

      try {
        const fastApiUrl = process.env.NEXT_PUBLIC_FASTAPI_URL || 'https://fastkirana-production-0cdd.up.railway.app'
        await fetch(`${fastApiUrl}/api/stores/clear-cache`, { method: 'POST', signal: AbortSignal.timeout(3000) }).catch(() => {})
      } catch (_) {}

      return NextResponse.json({
        success: true,
        targetType: 'HUB',
        targetId: storeId,
        storeName: updatedStore.name,
        status: isOpen ? 'ONLINE' : (pauseUntil ? 'PAUSED' : 'CLOSED'),
        pauseUntil: updatedStore.pauseUntil,
        closeReason: updatedStore.closeReason,
        message: isOpen
          ? `${updatedStore.name} is now ONLINE and accepting orders.`
          : (pauseUntil
              ? `${updatedStore.name} paused until ${pauseUntil.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}.`
              : `${updatedStore.name} is CLOSED for the day.`),
      })
    }

    // 2. RESTAURANT / KITCHEN SERVICEABILITY TOGGLE
    if (targetType === 'RESTAURANT') {
      if (!targetId) {
        return NextResponse.json({ error: 'targetId (restaurantId) is required for RESTAURANT toggle' }, { status: 400 })
      }

      const updatedRestaurant = await prisma.restaurant.update({
        where: { id: targetId },
        data: {
          isOpen: isOpen,
          pauseUntil: pauseUntil,
          closeReason: isOpen ? null : finalReason,
        },
      })

      await clearSettingsCache()
      await revalidateStorefront()

      return NextResponse.json({
        success: true,
        targetType: 'RESTAURANT',
        targetId,
        restaurantName: updatedRestaurant.name,
        status: isOpen ? 'ONLINE' : (pauseUntil ? 'PAUSED' : 'CLOSED'),
        pauseUntil: updatedRestaurant.pauseUntil,
        closeReason: updatedRestaurant.closeReason,
        message: isOpen
          ? `${updatedRestaurant.name} kitchen is now OPEN.`
          : (pauseUntil
              ? `${updatedRestaurant.name} paused until ${pauseUntil.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}.`
              : `${updatedRestaurant.name} kitchen is CLOSED.`),
      })
    }

    // 3. GLOBAL PLATFORM TOGGLE
    if (targetType === 'GLOBAL') {
      await prisma.storeSetting.upsert({
        where: { key: 'global_store_open' },
        update: { value: String(isOpen) },
        create: { key: 'global_store_open', value: String(isOpen) },
      })
      await prisma.storeSetting.upsert({
        where: { key: 'grocery_mart_open' },
        update: { value: String(isOpen) },
        create: { key: 'grocery_mart_open', value: String(isOpen) },
      })

      await clearSettingsCache()
      await revalidateStorefront()

      return NextResponse.json({
        success: true,
        targetType: 'GLOBAL',
        status: isOpen ? 'ONLINE' : 'CLOSED',
        message: isOpen ? 'Global platform is ONLINE.' : 'Global platform is set to EMERGENCY OFFLINE.',
      })
    }

    return NextResponse.json({ error: 'Invalid targetType' }, { status: 400 })
  } catch (error: any) {
    console.error('Serviceability toggle error:', error)
    return NextResponse.json({ error: error.message || 'Failed to update store serviceability' }, { status: 500 })
  }
}
