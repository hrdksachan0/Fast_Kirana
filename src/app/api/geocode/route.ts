import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'

export async function GET(request: NextRequest) {
  const session = await auth()
  if (!session?.user?.id) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const { searchParams } = new URL(request.url)
  const lat = searchParams.get('lat')
  const lng = searchParams.get('lng')
  const addressQuery = searchParams.get('address')

  const apiKey = process.env.GOOGLE_MAPS_API_KEY

  // If no Google Maps API Key is provided, fallback to OpenStreetMap Nominatim
  if (!apiKey) {
    console.warn('GOOGLE_MAPS_API_KEY is not configured in .env. Falling back to OpenStreetMap.')
    try {
      if (lat && lng) {
        const osmRes = await fetch(
          `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&zoom=16&addressdetails=1`,
          { headers: { 'User-Agent': 'FastKiranaApp/1.0' } }
        )
        if (osmRes.ok) {
          const data = await osmRes.json()
          return NextResponse.json({ source: 'osm', data })
        }
      } else if (addressQuery) {
        const osmRes = await fetch(
          `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(addressQuery)}&limit=1`,
          { headers: { 'User-Agent': 'FastKiranaApp/1.0' } }
        )
        if (osmRes.ok) {
          const data = await osmRes.json()
          return NextResponse.json({ source: 'osm', data })
        }
      }
      return NextResponse.json({ error: 'Failed to fetch from OpenStreetMap' }, { status: 500 })
    } catch (err: any) {
      return NextResponse.json({ error: err.message || 'OSM Error' }, { status: 500 })
    }
  }

  try {
    if (lat && lng) {
      const googleRes = await fetch(
        `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${apiKey}`
      )
      if (googleRes.ok) {
        const data = await googleRes.json()
        return NextResponse.json({ source: 'google', data })
      }
    } else if (addressQuery) {
      const googleRes = await fetch(
        `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(addressQuery)}&key=${apiKey}`
      )
      if (googleRes.ok) {
        const data = await googleRes.json()
        return NextResponse.json({ source: 'google', data })
      }
    }
    return NextResponse.json({ error: 'Invalid parameters' }, { status: 400 })
  } catch (err: any) {
    return NextResponse.json({ error: err.message || 'Google Maps API Error' }, { status: 500 })
  }
}
