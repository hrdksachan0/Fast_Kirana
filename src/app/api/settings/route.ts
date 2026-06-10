import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

const DEFAULT_SETTINGS = {
  deliveries_count: '10,000+',
  rating_value: '4.8',
  happy_families: '5,000+',
  trusted_text: '✨ Trusted by 5,000+ families in your town',
  grocery_mart_open: 'true',
  cafe_open: 'true',
  delivery_radius: '5',
  store_lat: '26.1534185',
  store_lng: '80.1714024',
  avg_delivery_time: '8 min',
  delivered_today: '1,231+',
  fresh_stock_loaded: '2 hrs ago',
}

export async function GET() {
  try {
    const settings = await prisma.storeSetting.findMany()
    const settingsMap: Record<string, string> = { ...DEFAULT_SETTINGS }

    settings.forEach((s) => {
      settingsMap[s.key] = s.value
    })

    return NextResponse.json(settingsMap)
  } catch (error) {
    console.error('Settings API error:', error)
    return NextResponse.json(DEFAULT_SETTINGS)
  }
}
