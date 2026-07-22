import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export async function GET(request: NextRequest) {
  try {
    let apiKey = process.env.GOOGLE_MAPS_API_KEY || process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY || ''

    if (!apiKey) {
      const setting = await prisma.storeSetting.findUnique({
        where: { key: 'google_maps_api_key' },
      })
      if (setting?.value) {
        apiKey = setting.value
      }
    }

    if (!apiKey) {
      return NextResponse.json({ error: 'Google Maps API Key not configured in env or settings' }, { status: 404 })
    }

    return NextResponse.json({ apiKey })
  } catch (error) {
    console.error('Failed to fetch Google Maps API key:', error)
    return NextResponse.json({ error: 'Failed to fetch Google Maps API key' }, { status: 500 })
  }
}
