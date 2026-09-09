import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { evaluateSurgeStatus } from '@/lib/surge-manager'

export const dynamic = 'force-dynamic'

export async function GET() {
  try {
    const [stores, storeSettings] = await Promise.all([
      prisma.darkStore.findMany({
        where: { isActive: true },
        select: {
          id: true,
          name: true,
          latitude: true,
          longitude: true,
          deliveryRadiusKm: true,
          isActive: true,
          groceryOpen: true,
          surgeCharge: true,
        },
        orderBy: { name: 'asc' },
      }),
      prisma.storeSetting.findMany({
        select: { key: true, value: true }
      })
    ])

    const settingsMap = storeSettings.reduce((acc, s) => {
      acc[s.key] = s.value
      return acc
    }, {} as Record<string, string>)

    const formatted = await Promise.all(
      stores.map(async (s) => {
        let liveSurgeFee = s.surgeCharge || 0
        let isSurgeActive = liveSurgeFee > 0
        let surgeReason = ''

        try {
          const surge = await evaluateSurgeStatus(settingsMap, s.id, {
            lat: s.latitude,
            lng: s.longitude
          })
          liveSurgeFee = surge.surgeFee
          isSurgeActive = surge.isSurgeActive
          surgeReason = surge.surgeReason
        } catch (err) {
          console.warn(`Surge eval failed for hub ${s.id}:`, err)
        }

        return {
          id: s.id,
          name: s.name,
          latitude: s.latitude,
          longitude: s.longitude,
          deliveryRadiusKm: s.deliveryRadiusKm || 5.0,
          isActive: s.isActive,
          groceryOpen: s.groceryOpen,
          surgeCharge: liveSurgeFee,
          surgeActive: isSurgeActive,
          surgeReason,
          city: s.name.replace(/\s+(Hub|Market|Central|Dark\s*Store).*$/i, '').trim(),
        }
      })
    )

    return NextResponse.json({
      success: true,
      hubs: formatted,
    })
  } catch (error: any) {
    console.error('Failed to fetch store hubs:', error)
    return NextResponse.json({
      success: false,
      error: 'Failed to fetch hubs',
      hubs: [],
    }, { status: 500 })
  }
}
