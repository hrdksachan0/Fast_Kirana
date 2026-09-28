import { NextRequest, NextResponse } from 'next/server'

interface CacheEntry {
  points: [number, number][]
  polyline?: string
  distanceMeters?: number
  durationSeconds?: number
  provider: 'google' | 'osrm' | 'direct'
  timestamp: number
}

// In-memory route cache: stores fetched routes for 2 hours (Zero excess API costs)
const routeCache = new Map<string, CacheEntry>()
const CACHE_TTL_MS = 2 * 60 * 60 * 1000 // 2 hours

function decodeGooglePolyline(encoded: string): [number, number][] {
  const poly: [number, number][] = []
  let index = 0
  const len = encoded.length
  let lat = 0
  let lng = 0

  while (index < len) {
    let b: number
    let shift = 0
    let result = 0
    do {
      b = encoded.charCodeAt(index++) - 63
      result |= (b & 0x1f) << shift
      shift += 5
    } while (b >= 0x20)
    const dlat = (result & 1) !== 0 ? ~(result >> 1) : result >> 1
    lat += dlat

    shift = 0
    result = 0
    do {
      b = encoded.charCodeAt(index++) - 63
      result |= (b & 0x1f) << shift
      shift += 5
    } while (b >= 0x20)
    const dlng = (result & 1) !== 0 ? ~(result >> 1) : result >> 1
    lng += dlng

    poly.push([lat / 1e5, lng / 1e5])
  }
  return poly
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const origin = searchParams.get('origin')
  const destination = searchParams.get('destination')

  if (!origin || !destination) {
    return NextResponse.json({ error: 'Origin and destination are required (lat,lng format)' }, { status: 400 })
  }

  // Parse origin and destination coords
  const [oLat, oLng] = origin.split(',').map((s) => parseFloat(s.trim()))
  const [dLat, dLng] = destination.split(',').map((s) => parseFloat(s.trim()))

  if (isNaN(oLat) || isNaN(oLng) || isNaN(dLat) || isNaN(dLng)) {
    return NextResponse.json({ error: 'Invalid origin or destination coordinates' }, { status: 400 })
  }

  // 1. Strict In-Memory Cache Check: 0 API calls, 0 cost
  const cacheKey = `${oLat.toFixed(4)},${oLng.toFixed(4)}->${dLat.toFixed(4)},${dLng.toFixed(4)}`
  const cached = routeCache.get(cacheKey)
  if (cached && Date.now() - cached.timestamp < CACHE_TTL_MS) {
    return NextResponse.json({
      success: true,
      provider: cached.provider,
      cached: true,
      points: cached.points,
      polyline: cached.polyline,
      distanceMeters: cached.distanceMeters,
      durationSeconds: cached.durationSeconds,
    })
  }

  // 2. TIER 1: Open-source OSRM routing (100% Free, ₹0 cloud cost)
  try {
    const osrmUrl = `https://router.project-osrm.org/route/v1/driving/${oLng},${oLat};${dLng},${dLat}?overview=full&geometries=geojson`
    const osrmRes = await fetch(osrmUrl, {
      signal: AbortSignal.timeout(4000),
      headers: { 'User-Agent': 'FastKirana/1.0 (support@fastkirana.in)' },
    })

    if (osrmRes.ok) {
      const data = await osrmRes.json()
      if (data.routes && data.routes.length > 0) {
        const route = data.routes[0]
        const rawCoords = route.geometry?.coordinates as [number, number][]
        if (rawCoords && rawCoords.length > 0) {
          // GeoJSON coordinates are [lng, lat] -> convert to [lat, lng]
          const points: [number, number][] = rawCoords.map(([lng, lat]) => [lat, lng])
          const entry: CacheEntry = {
            points,
            distanceMeters: route.distance,
            durationSeconds: route.duration,
            provider: 'osrm',
            timestamp: Date.now(),
          }
          routeCache.set(cacheKey, entry)
          return NextResponse.json({
            success: true,
            provider: 'osrm',
            cached: false,
            points: entry.points,
            distanceMeters: entry.distanceMeters,
            durationSeconds: entry.durationSeconds,
          })
        }
      }
    }
  } catch {
    // OSRM failed or timed out, gracefully proceed to Google fallback
  }

  // 3. TIER 2: Google Maps Directions API (Fallback if OSRM is down, single-request cached)
  const apiKey = process.env.GOOGLE_MAPS_API_KEY || process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY
  if (apiKey) {
    try {
      const gmapsUrl = `https://maps.googleapis.com/maps/api/directions/json?origin=${oLat},${oLng}&destination=${dLat},${dLng}&mode=driving&key=${apiKey}`
      const gmapsRes = await fetch(gmapsUrl, { signal: AbortSignal.timeout(5000) })

      if (gmapsRes.ok) {
        const data = await gmapsRes.json()
        if (data.routes && data.routes.length > 0) {
          const route = data.routes[0]
          const overviewPolyline = route.overview_polyline?.points
          const leg = route.legs?.[0]
          if (overviewPolyline) {
            const points = decodeGooglePolyline(overviewPolyline)
            const entry: CacheEntry = {
              points,
              polyline: overviewPolyline,
              distanceMeters: leg?.distance?.value,
              durationSeconds: leg?.duration?.value,
              provider: 'google',
              timestamp: Date.now(),
            }
            routeCache.set(cacheKey, entry)
            return NextResponse.json({
              success: true,
              provider: 'google',
              cached: false,
              points: entry.points,
              polyline: entry.polyline,
              distanceMeters: entry.distanceMeters,
              durationSeconds: entry.durationSeconds,
            })
          }
        }
      }
    } catch {
      // Google API error, proceed to direct fallback
    }
  }

  // 4. TIER 3: Direct geodesic fallback line
  const directPoints: [number, number][] = [
    [oLat, oLng],
    [dLat, dLng],
  ]
  return NextResponse.json({
    success: true,
    provider: 'direct',
    cached: false,
    points: directPoints,
  })
}
