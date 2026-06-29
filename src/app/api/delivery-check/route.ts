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

    // Fetch store coordinates from settings
    let storeLat = DEFAULT_STORE_LAT
    let storeLng = DEFAULT_STORE_LNG

    try {
      const settings = await prisma.storeSetting.findMany({
        where: { key: { in: ['store_lat', 'store_lng'] } },
      })
      for (const s of settings) {
        if (s.key === 'store_lat' && s.value) storeLat = parseFloat(s.value)
        if (s.key === 'store_lng' && s.value) storeLng = parseFloat(s.value)
      }
    } catch {
      // Use defaults if DB fails
    }

    const distanceKm = getDistanceKm(storeLat, storeLng, customerLat, customerLng)
    const rules = getDeliveryRules(distanceKm)

    return NextResponse.json(rules)
  } catch (error) {
    console.error('Delivery check error:', error)
    return NextResponse.json({ error: 'Failed to check delivery' }, { status: 500 })
  }
}
