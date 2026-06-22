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

  // If no Google Maps API Key is provided, return an error (OpenStreetMap disabled)
  if (!apiKey) {
    console.error('GOOGLE_MAPS_API_KEY is not configured in .env')
    return NextResponse.json({ error: 'Google Maps API is not configured on this server.' }, { status: 500 })
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
