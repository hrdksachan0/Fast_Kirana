import { prisma } from '@/lib/prisma'

export interface DarkStoreInfo {
  id: string
  name: string
  city?: string
  latitude: number
  longitude: number
  deliveryRadiusKm: number
  isActive: boolean
  deliveryPolygon?: any
  surgeCharge?: number
}

// Calculate Haversine distance in KM
export function calculateDistanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371 // Earth radius in km
  const dLat = (lat2 - lat1) * (Math.PI / 180)
  const dLon = (lon2 - lon1) * (Math.PI / 180)
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

// Extract clean city keyword from store name (e.g. "Ghatampur Central Hub" -> "Ghatampur")
export function extractCityFromStoreName(name: string): string {
  if (!name) return ''
  return name
    .replace(/central|hub|dark\s*store|market|branch/gi, '')
    .trim()
}

// Extract 6-digit pincode if present in store ID (e.g. "hub-209206" -> "209206")
export function extractPincodeFromStoreId(storeId: string): string | null {
  const match = storeId.match(/\b\d{6}\b/)
  return match ? match[0] : null
}

/**
 * Dynamically resolve the most appropriate dark store for a customer address or location.
 * Fully database-driven: works for any newly created hub automatically.
 */
export async function resolveDarkStoreForCustomer(
  address?: { pincode?: string | null; city?: string | null; lat?: number | null; lng?: number | null } | null,
  preferredStoreId?: string | null
): Promise<{ storeId: string; store: DarkStoreInfo | null }> {
  try {
    const activeStores = await prisma.darkStore.findMany({
      where: { isActive: true },
      orderBy: { createdAt: 'asc' }
    })

    if (activeStores.length === 0) {
      return { storeId: preferredStoreId || 'hub-209206', store: null }
    }

    // 1. If explicit preferred store requested and active, use it
    if (preferredStoreId && preferredStoreId !== 'all') {
      const match = activeStores.find(s => s.id === preferredStoreId)
      if (match) return { storeId: match.id, store: match }
    }

    const addrLat = address?.lat ? parseFloat(String(address.lat)) : null
    const addrLng = address?.lng ? parseFloat(String(address.lng)) : null
    const addrPincode = (address?.pincode || '').replace(/\D/g, '').slice(0, 6)
    const addrCity = (address?.city || '').toLowerCase().trim()

    // 2. Match by GPS coordinates (nearest store within radius)
    if (addrLat && addrLng && !isNaN(addrLat) && !isNaN(addrLng)) {
      let closestStore: DarkStoreInfo | null = null
      let minDistance = Infinity

      for (const store of activeStores) {
        const dist = calculateDistanceKm(addrLat, addrLng, store.latitude, store.longitude)
        const allowedRadius = store.deliveryRadiusKm || 5.0
        if (dist <= allowedRadius && dist < minDistance) {
          minDistance = dist
          closestStore = store
        }
      }

      if (closestStore) {
        return { storeId: closestStore.id, store: closestStore }
      }
    }

    // 3. Match by 6-digit pincode
    if (addrPincode.length === 6) {
      const pinMatch = activeStores.find(s => {
        const storePin = extractPincodeFromStoreId(s.id)
        return storePin === addrPincode
      })
      if (pinMatch) return { storeId: pinMatch.id, store: pinMatch }
    }

    // 4. Match by city keyword
    if (addrCity) {
      const cityMatch = activeStores.find(s => {
        const cityKeyword = extractCityFromStoreName(s.name).toLowerCase()
        return cityKeyword && (addrCity.includes(cityKeyword) || cityKeyword.includes(addrCity))
      })
      if (cityMatch) return { storeId: cityMatch.id, store: cityMatch }
    }

    // 5. Default fallback to first active store in system
    return { storeId: activeStores[0].id, store: activeStores[0] }
  } catch (err) {
    console.error('Error in resolveDarkStoreForCustomer:', err)
    return { storeId: preferredStoreId || 'hub-209206', store: null }
  }
}

/**
 * Return Prisma order filter for a given storeId.
 * Symmetrical and identical for all hubs!
 */
export function getOrderStoreFilter(storeId?: string | null) {
  if (!storeId || storeId === 'all') return {}
  return { storeId }
}

/**
 * Return Prisma condition to scope customers / carts to a specific store.
 * Automatically handles any store dynamically!
 */
export async function getStoreUserFilter(storeId?: string | null) {
  if (!storeId || storeId === 'all') return {}

  const activeStores = await prisma.darkStore.findMany({
    select: { id: true, name: true }
  })
  const currentStore = activeStores.find(s => s.id === storeId)
  const storeCity = currentStore ? extractCityFromStoreName(currentStore.name) : ''
  const storePincode = extractPincodeFromStoreId(storeId)

  const otherStores = activeStores.filter(s => s.id !== storeId)
  const otherStoreIds = otherStores.map(s => s.id)

  const matchConditions: any[] = [
    { assignedStoreId: storeId },
    { orders: { some: { storeId } } }
  ]

  if (storePincode) {
    matchConditions.push({ addresses: { some: { pincode: storePincode } } })
  }
  if (storeCity) {
    matchConditions.push({ addresses: { some: { city: { contains: storeCity, mode: 'insensitive' } } } })
  }

  const otherPincodes = otherStores
    .map(s => extractPincodeFromStoreId(s.id))
    .filter(Boolean) as string[]

  // If this is the base central hub, it dynamically excludes users exclusively linked to other active hubs
  if (storeId === 'hub-209206') {
    return {
      AND: [
        ...(otherStoreIds.length > 0 ? [{ OR: [{ assignedStoreId: null }, { assignedStoreId: { notIn: otherStoreIds } }] }] : []),
        ...(otherPincodes.length > 0 ? [{ addresses: { none: { pincode: { in: otherPincodes } } } }] : []),
        ...(otherStoreIds.length > 0 ? [{ orders: { none: { storeId: { in: otherStoreIds } } } }] : [])
      ]
    }
  }

  return {
    OR: matchConditions,
    ...(otherStoreIds.length > 0 ? {
      NOT: {
        assignedStoreId: { in: otherStoreIds }
      }
    } : {})
  }
}

/**
 * Return restaurant filter for a store (city match)
 */
export async function getStoreRestaurantFilter(storeId?: string | null) {
  if (!storeId || storeId === 'all') return {}

  const store = await prisma.darkStore.findUnique({
    where: { id: storeId },
    select: { name: true }
  })
  if (!store) return {}

  const city = extractCityFromStoreName(store.name)
  if (!city) return {}

  return {
    city: { contains: city, mode: 'insensitive' as const }
  }
}

