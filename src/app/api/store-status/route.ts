import { NextRequest, NextResponse } from 'next/server'
import { cache } from '@/lib/redis-client'
import { checkIsStoreOpen } from '@/app/api/settings/route'
import { prisma } from '@/lib/prisma'
import { checkStoreOperatingStatus } from '@/lib/restaurant-schedule'
import { evaluateSurgeStatus } from '@/lib/surge-manager'

export const dynamic = 'force-dynamic'

const CACHE_TTL_SECONDS = 60

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const hubId = searchParams.get('hubId') || searchParams.get('storeId')
    const cacheKey = hubId && hubId !== 'all' ? `store:status:${hubId}` : 'store:status:global'

    // 1. Check Redis / Memory cache
    const cached = await cache.get<Record<string, any>>(cacheKey)
    if (cached) {
      return NextResponse.json(cached, {
        headers: {
          'Cache-Control': 'public, s-maxage=10, stale-while-revalidate=30',
          'X-Cache-Status': 'HIT',
        },
      })
    }

    // 2. Fetch minimal state from DB
    const [settingsList, activeRestaurants] = await Promise.all([
      prisma.storeSetting.findMany({
        where: {
          key: {
            in: [
              'grocery_mart_open',
              'cafe_open',
              'restaurant_open',
              'grocery_auto_timing',
              'grocery_open_time',
              'grocery_close_time',
              'cafe_auto_timing',
              'cafe_open_time',
              'cafe_close_time',
              'restaurant_auto_timing',
              'restaurant_open_time',
              'restaurant_close_time',
              'delivery_radius',
              'store_lat',
              'store_lng',
              'surge_mode',
              'surge_manual_amount',
              'surge_max_cap',
            ],
          },
        },
        select: { key: true, value: true },
      }),
      prisma.restaurant.findMany({
        where: { isActive: true },
        select: { id: true, slug: true, name: true, isOpen: true, openTime: true, closeTime: true, updatedAt: true },
      }),
    ])

    const settingsMap: Record<string, string> = {}
    for (const s of settingsList) {
      settingsMap[s.key] = s.value
    }

    // Compute live operational statuses
    const isGroceryOpen = checkIsStoreOpen(settingsMap, 'grocery')
    const isCafeOpen = checkIsStoreOpen(settingsMap, 'cafe')
    const isRestaurantOpen = checkIsStoreOpen(settingsMap, 'restaurant')

    const outletStatuses: Record<string, boolean> = {}
    for (const r of activeRestaurants) {
      const opStatus = checkStoreOperatingStatus(r)
      outletStatuses[r.id] = opStatus.isOpen
      if (r.slug) outletStatuses[r.slug] = opStatus.isOpen
    }

    // Quick surge evaluation
    let surgeActive = false
    let surgeFee = 0
    try {
      const surge = await evaluateSurgeStatus(settingsMap, hubId)
      surgeActive = surge.isSurgeActive
      surgeFee = surge.surgeFee
    } catch (_e) {
      // Non-fatal
    }

    const payload = {
      grocery_mart_open: isGroceryOpen ? 'true' : 'false',
      cafe_open: isCafeOpen ? 'true' : 'false',
      restaurant_open: isRestaurantOpen ? 'true' : 'false',
      delivery_radius: settingsMap['delivery_radius'] || '2.0',
      store_lat: settingsMap['store_lat'] || '26.1534185',
      store_lng: settingsMap['store_lng'] || '80.1714024',
      surge_active: surgeActive ? 'true' : 'false',
      surge_fee: String(surgeFee),
      outlets: outletStatuses,
      timestamp: Date.now(),
    }

    // Cache in Redis with 60s TTL
    await cache.set(cacheKey, payload, { ex: CACHE_TTL_SECONDS })

    return NextResponse.json(payload, {
      headers: {
        'Cache-Control': 'public, s-maxage=10, stale-while-revalidate=30',
        'X-Cache-Status': 'MISS',
      },
    })
  } catch (error) {
    console.error('Store status API error:', error)
    return NextResponse.json({
      grocery_mart_open: 'true',
      cafe_open: 'true',
      restaurant_open: 'true',
      delivery_radius: '2.0',
      store_lat: '26.1534185',
      store_lng: '80.1714024',
      surge_active: 'false',
      surge_fee: '0',
      outlets: {},
      timestamp: Date.now(),
    })
  }
}
