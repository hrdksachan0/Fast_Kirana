import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export const dynamic = 'force-dynamic'

export async function GET() {
  try {
    const stores = await prisma.darkStore.findMany({
      where: { isActive: true },
      select: {
        id: true,
        name: true,
        latitude: true,
        longitude: true,
        deliveryRadiusKm: true,
        isActive: true,
        groceryOpen: true,
      },
      orderBy: { name: 'asc' },
    })

    const formatted = stores.map((s) => ({
      id: s.id,
      name: s.name,
      latitude: s.latitude,
      longitude: s.longitude,
      deliveryRadiusKm: s.deliveryRadiusKm || 5.0,
      isActive: s.isActive,
      groceryOpen: s.groceryOpen,
      city: s.name.replace(/\s+(Hub|Market|Central|Dark\s*Store).*$/i, '').trim(),
    }))

    return NextResponse.json({
      success: true,
      hubs: formatted,
    })
  } catch (error: any) {
    console.error('Failed to fetch store hubs:', error)
    // Fallback default Ghatampur hub
    return NextResponse.json({
      success: true,
      hubs: [
        {
          id: 'hub-209206',
          name: 'Ghatampur Central Hub',
          latitude: 26.1534185,
          longitude: 80.1714024,
          deliveryRadiusKm: 5.0,
          isActive: true,
          groceryOpen: true,
          city: 'Ghatampur',
        },
      ],
    })
  }
}
