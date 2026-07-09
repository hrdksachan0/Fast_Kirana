import { NextRequest, NextResponse } from 'next/server'

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)
  const lat = searchParams.get('lat')
  const lng = searchParams.get('lng')
  const addressQuery = searchParams.get('address')

  const apiKey = process.env.GOOGLE_MAPS_API_KEY

  try {
    // If GOOGLE_MAPS_API_KEY is configured, use Google Maps API
    if (apiKey) {
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
    }

    // FALLBACK: If no GOOGLE_MAPS_API_KEY is configured, fallback to OpenStreetMap (Nominatim)
    console.log('No GOOGLE_MAPS_API_KEY configured. Falling back to OpenStreetMap Nominatim geocoding...')
    
    const headers = {
      'User-Agent': 'FastKiranaApp/1.0 (contact@fastkirana.in)'
    }

    if (lat && lng) {
      const osmRes = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}`,
        { headers }
      )
      if (osmRes.ok) {
        const osmData = await osmRes.json()
        const address = osmData.address || {}
        
        // Format to match Google Maps API response structure expected by the frontend
        const formattedResults = [
          {
            formatted_address: osmData.display_name,
            address_components: [
              {
                long_name: address.road || '',
                short_name: address.road || '',
                types: ['route']
              },
              {
                long_name: address.suburb || address.neighbourhood || address.residential || '',
                short_name: address.suburb || address.neighbourhood || address.residential || '',
                types: ['sublocality', 'sublocality_level_1']
              },
              {
                long_name: address.city || address.town || address.village || 'Ghatampur',
                short_name: address.city || address.town || address.village || 'Ghatampur',
                types: ['locality']
              },
              {
                long_name: address.postcode || '209206',
                short_name: address.postcode || '209206',
                types: ['postal_code']
              }
            ]
          }
        ]
        return NextResponse.json({ source: 'openstreetmap', data: { results: formattedResults } })
      }
    } else if (addressQuery) {
      const osmRes = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(addressQuery)}&limit=1`,
        { headers }
      )
      if (osmRes.ok) {
        const osmData = await osmRes.json()
        if (Array.isArray(osmData) && osmData.length > 0) {
          const firstResult = osmData[0]
          // Simple mock to keep Google Maps structure
          const formattedResults = [
            {
              formatted_address: firstResult.display_name,
              address_components: [
                {
                  long_name: firstResult.name || '',
                  short_name: firstResult.name || '',
                  types: ['route']
                },
                {
                  long_name: 'Ghatampur',
                  short_name: 'Ghatampur',
                  types: ['locality']
                },
                {
                  long_name: '209206',
                  short_name: '209206',
                  types: ['postal_code']
                }
              ]
            }
          ]
          return NextResponse.json({ source: 'openstreetmap', data: { results: formattedResults } })
        }
      }
    }
    
    return NextResponse.json({ error: 'Geocoding service unavailable' }, { status: 503 })
  } catch (err: any) {
    console.error('Error during fallback geocoding:', err)
    return NextResponse.json({ error: err.message || 'Geocoding failed' }, { status: 500 })
  }
}
