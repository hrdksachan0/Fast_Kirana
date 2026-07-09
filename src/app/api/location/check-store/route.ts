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

    // Fetch all active dark stores
    const stores = await prisma.darkStore.findMany({
      where: { isActive: true }
    })

    // Find the first store whose delivery polygon contains the user's coordinates
    let matchedStore = null
    for (const store of stores) {
      if (store.deliveryPolygon) {
        try {
          const polygon = typeof store.deliveryPolygon === 'string' 
            ? JSON.parse(store.deliveryPolygon) 
            : store.deliveryPolygon

          if (Array.isArray(polygon) && isPointInPolygon({ lat, lng }, polygon)) {
            matchedStore = store
            break
          }
        } catch (e) {
          console.error(`Failed to parse polygon for store: ${store.name}`, e)
        }
      }
    }

    // Fallback logic for local testing/demo: if no geofenced store matches,
    // return the first active store in the database, or a default fallback object.
    if (!matchedStore) {
      if (stores.length > 0) {
        matchedStore = stores[0]
      } else {
        // Return a mock default store so the app functions out-of-the-box
        matchedStore = {
          id: 'default-swaroop-nagar',
          name: 'Swaroop Nagar Hub',
          latitude: 26.4950,
          longitude: 80.3050,
          isActive: true,
          surgeCharge: 0.0,
          groceryOpen: true,
          cafeOpen: true,
          deliveryPolygon: null,
          createdAt: new Date(),
          updatedAt: new Date()
        }
      }
    }

    return NextResponse.json(matchedStore)
  } catch (error: any) {
    console.error('Error in check-store API:', error)
    return NextResponse.json({ error: error.message || 'Internal server error' }, { status: 500 })
  }
}
