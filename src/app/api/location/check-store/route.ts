import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

function isPointInPolygon(point: { lat: number; lng: number }, polygon: { lat: number; lng: number }[]): boolean {
  const x = point.lat
  const y = point.lng
  let inside = false
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const xi = polygon[i].lat
    const yi = polygon[i].lng
    const xj = polygon[j].lat
    const yj = polygon[j].lng

    const intersect = ((yi > y) !== (yj > y))
        && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
    if (intersect) inside = !inside
  }
  return inside
}

function calculateDistanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371
  const dLat = (lat2 - lat1) * (Math.PI / 180)
  const dLon = (lon2 - lon1) * (Math.PI / 180)
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const latStr = searchParams.get('lat')
    const lngStr = searchParams.get('lng')

    if (!latStr || !lngStr) {
      return NextResponse.json({ error: 'Missing coordinates' }, { status: 400 })
    }

    const lat = parseFloat(latStr)
    const lng = parseFloat(lngStr)

    if (isNaN(lat) || isNaN(lng)) {
      return NextResponse.json({ error: 'Invalid coordinates' }, { status: 400 })
    }

    // ─── FastAPI Railway Proxy First ──────────────────────────────────────────
    const fastApiUrl = process.env.NEXT_PUBLIC_FASTAPI_URL || 'https://fastkiran-backend-production.up.railway.app'
    try {
      const fastApiResponse = await fetch(`${fastApiUrl}/api/location/check-store?lat=${lat}&lng=${lng}`, {
        headers: { 'Accept': 'application/json' },
        signal: AbortSignal.timeout(4000),
      })
      if (fastApiResponse.ok) {
        const data = await fastApiResponse.json()
        if (data && data.id) {
          return NextResponse.json(data)
        }
      }
    } catch (_) {}

    // Fetch all active dark stores
    const stores = await prisma.darkStore.findMany({
      where: { isActive: true }
    })

    // 1. Check delivery polygon containment first
    let matchedStore: any = null
    let matchedDistanceKm = 0

    for (const store of stores) {
      if (store.deliveryPolygon) {
        try {
          const polygon = typeof store.deliveryPolygon === 'string' 
            ? JSON.parse(store.deliveryPolygon) 
            : store.deliveryPolygon

          if (Array.isArray(polygon) && isPointInPolygon({ lat, lng }, polygon)) {
            matchedStore = store
            matchedDistanceKm = calculateDistanceKm(lat, lng, store.latitude, store.longitude)
            break
          }
        } catch (e) {
          console.error(`Failed to parse polygon for store: ${store.name}`, e)
        }
      }
    }

    // 2. Check circular delivery radius (Haversine distance)
    if (!matchedStore) {
      let closestStore: any = null
      let minDistance = Infinity

      for (const store of stores) {
        const dist = calculateDistanceKm(lat, lng, store.latitude, store.longitude)
        const allowedRadius = store.deliveryRadiusKm || 5.0
        if (dist <= allowedRadius && dist < minDistance) {
          minDistance = dist
          closestStore = store
        }
      }

      if (closestStore) {
        matchedStore = closestStore
        matchedDistanceKm = minDistance
      }
    }

    const isInsideZone = !!matchedStore

    // 3. If no store within zone, find the overall closest store for distance reporting
    let closestHub: any = null
    let closestHubDistance = Infinity
    for (const store of stores) {
      const dist = calculateDistanceKm(lat, lng, store.latitude, store.longitude)
      if (dist < closestHubDistance) {
        closestHubDistance = dist
        closestHub = store
      }
    }

    const targetStore = matchedStore || closestHub || stores[0] || {
      id: 'default-hub',
      name: 'Central Hub',
      latitude: 26.1534,
      longitude: 80.1714,
      isActive: true,
      surgeCharge: 0.0,
      groceryOpen: true,
      deliveryPolygon: null,
      deliveryRadiusKm: 5.0,
      createdAt: new Date(),
      updatedAt: new Date()
    }

    // Check inventory & restaurant availability for this hub
    let inventoryCount = 0
    let restaurantCount = 0
    if (targetStore.id) {
      try {
        const [invCount, restCount] = await Promise.all([
          prisma.storeInventory.count({
            where: { storeId: targetStore.id, stock: { gt: 0 } }
          }),
          prisma.restaurant.count({
            where: {
              isActive: true,
              storeId: targetStore.id
            }
          })
        ])
        inventoryCount = invCount
        restaurantCount = restCount
      } catch (countErr) {
        console.warn('Failed to check hub inventory count:', countErr)
      }
    }

    const isComingSoon = isInsideZone && inventoryCount === 0 && restaurantCount === 0

    return NextResponse.json({
      ...targetStore,
      isServiceable: isInsideZone,
      distanceKm: isInsideZone ? matchedDistanceKm : closestHubDistance,
      hasInventory: inventoryCount > 0,
      inventoryCount,
      hasRestaurants: restaurantCount > 0,
      restaurantCount,
      isComingSoon,
    })
  } catch (error: any) {
    console.error('Error in check-store API:', error)
    return NextResponse.json({ error: error.message || 'Internal server error' }, { status: 500 })
  }
}
