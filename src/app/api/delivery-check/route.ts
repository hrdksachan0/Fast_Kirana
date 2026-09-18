import { NextResponse } from 'next/server'
import { getDistanceKm, getDeliveryRules, DEFAULT_STORE_LAT, DEFAULT_STORE_LNG } from '@/lib/distance'
import { prisma } from '@/lib/prisma'

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url)
    const lat = searchParams.get('lat')
    const lng = searchParams.get('lng')

    if (!lat || !lng) {
      return NextResponse.json({ error: 'lat and lng are required' }, { status: 400 })
    }

    const customerLat = parseFloat(lat)
    const customerLng = parseFloat(lng)

    if (isNaN(customerLat) || isNaN(customerLng)) {
      return NextResponse.json({ error: 'Invalid lat/lng values' }, { status: 400 })
    }

    const storeId = searchParams.get('storeId')

    // Fetch store coordinates & radius settings
    let storeLat = DEFAULT_STORE_LAT
    let storeLng = DEFAULT_STORE_LNG
    let maxRadiusKm = 5.0
    let surgeFee = 0
    let settingsMap: Record<string, string> = {}

    try {
      const { buildSettingsMap } = await import('@/app/api/settings/route')
      settingsMap = await buildSettingsMap(storeId)
      if (settingsMap['store_lat']) storeLat = parseFloat(settingsMap['store_lat'])
      if (settingsMap['store_lng']) storeLng = parseFloat(settingsMap['store_lng'])
      if (settingsMap['delivery_radius']) maxRadiusKm = parseFloat(settingsMap['delivery_radius'])
      if (settingsMap['surge_fee']) surgeFee = parseFloat(settingsMap['surge_fee'])
    } catch {
      // Use defaults if DB fails
    }

    const distanceKm = getDistanceKm(storeLat, storeLng, customerLat, customerLng)
    const rules = getDeliveryRules(distanceKm, {
      maxRadiusKm,
      surgeFee,
      settings: settingsMap,
      storeName: settingsMap['store_name']
    })

    return NextResponse.json(rules)
  } catch (error) {
    console.error('Delivery check error:', error)
    return NextResponse.json({ error: 'Failed to check delivery' }, { status: 500 })
  }
}
