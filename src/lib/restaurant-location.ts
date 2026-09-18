/**
 * Restaurant location and delivery radius resolver.
 * Maps products and restaurants to their verified GPS coordinates and delivery radius.
 */

export interface RestaurantLocationInfo {
  id: string
  name: string
  slug: string
  lat: number
  lng: number
  deliveryRadiusKm: number
}

// Verified GPS coordinates and delivery zones of known restaurant partners
export const KNOWN_RESTAURANT_LOCATIONS: Record<string, RestaurantLocationInfo> = {
  'REST-101': {
    id: 'REST-101',
    name: 'A.S. Restaurant',
    slug: 'as-restaurant',
    lat: 26.1494833,
    lng: 80.1672394,
    deliveryRadiusKm: 5.0,
  },
  'REST-102': {
    id: 'REST-102',
    name: 'Wedson Restaurant',
    slug: 'wedson-restaurant',
    lat: 26.147862,
    lng: 80.172482,
    deliveryRadiusKm: 5.0,
  },
  'REST-103': {
    id: 'REST-103',
    name: 'Bal Udyan Restaurant',
    slug: 'bal-udyan-restaurant',
    lat: 26.1468042,
    lng: 80.1773979,
    deliveryRadiusKm: 5.0,
  },
  'REST-104': {
    id: 'REST-104',
    name: 'Hot Pizza Lovers',
    slug: 'hot-pizza-lovers',
    lat: 26.1484783,
    lng: 80.1667542,
    deliveryRadiusKm: 5.0,
  },
  // Legacy CUID / alias mappings
  'cms2p1lap0000n0id8alldboy': {
    id: 'REST-101',
    name: 'A.S. Restaurant',
    slug: 'as-restaurant',
    lat: 26.1494833,
    lng: 80.1672394,
    deliveryRadiusKm: 5.0,
  },
  'cms2p1lyx0001n0idod904lfu': {
    id: 'REST-102',
    name: 'Wedson Restaurant',
    slug: 'wedson-restaurant',
    lat: 26.147862,
    lng: 80.172482,
    deliveryRadiusKm: 5.0,
  },
  'cmsbhxb6a000304if8kf1cwji': {
    id: 'REST-103',
    name: 'Bal Udyan Restaurant',
    slug: 'bal-udyan-restaurant',
    lat: 26.1468042,
    lng: 80.1773979,
    deliveryRadiusKm: 5.0,
  },
}

/**
 * Resolves restaurant location and delivery radius from a product or restaurant object.
 */
export function getRestaurantLocation(
  productOrRestaurant: any,
  fallbackLat: number,
  fallbackLng: number
): RestaurantLocationInfo | null {
  if (!productOrRestaurant) return null

  const rest = productOrRestaurant.restaurant || productOrRestaurant
  const rId = String(rest?.id || productOrRestaurant?.restaurantId || '').trim()
  const rSlug = String(rest?.slug || '').toLowerCase().trim()
  const rName = String(rest?.name || productOrRestaurant?.restaurantName || '').trim()

  // 1. Check if direct valid GPS coordinates exist on the object
  const rawLat = rest?.lat ?? (rest?.latitude ? parseFloat(String(rest.latitude)) : null)
  const rawLng = rest?.lng ?? (rest?.longitude ? parseFloat(String(rest.longitude)) : null)
  const rawRadius = rest?.deliveryRadiusKm ? parseFloat(String(rest.deliveryRadiusKm)) : null

  if (rawLat && rawLng && !isNaN(rawLat) && !isNaN(rawLng)) {
    return {
      id: rId || 'RESTAURANT',
      name: rName || 'Restaurant',
      slug: rSlug || 'restaurant',
      lat: rawLat,
      lng: rawLng,
      deliveryRadiusKm: rawRadius && !isNaN(rawRadius) ? rawRadius : 5.0,
    }
  }

  // 2. Check by ID in known restaurant locations
  if (rId && KNOWN_RESTAURANT_LOCATIONS[rId]) {
    return KNOWN_RESTAURANT_LOCATIONS[rId]
  }

  // 3. Check by slug / name in known restaurants
  const lowerSlug = rSlug.toLowerCase()
  const lowerName = rName.toLowerCase()

  if (
    lowerSlug.includes('as-') ||
    lowerSlug === 'as' ||
    lowerName.includes('a.s') ||
    lowerName.includes('as restaurant')
  ) {
    return KNOWN_RESTAURANT_LOCATIONS['REST-101']
  }
  if (
    lowerSlug.includes('wedson') ||
    lowerSlug === 'restaurant-kitchen' ||
    lowerName.includes('wedson')
  ) {
    return KNOWN_RESTAURANT_LOCATIONS['REST-102']
  }
  if (
    lowerSlug.includes('bal') ||
    lowerSlug.includes('udyan') ||
    lowerName.includes('bal udyan')
  ) {
    return KNOWN_RESTAURANT_LOCATIONS['REST-103']
  }
  if (
    lowerSlug.includes('pizza') ||
    lowerSlug.includes('pari') ||
    lowerName.includes('pizza') ||
    lowerName.includes('pari')
  ) {
    return KNOWN_RESTAURANT_LOCATIONS['REST-104']
  }

  // 4. If it's a restaurant product but coordinates are unknown, return fallback with default radius
  if (rId || rest) {
    return {
      id: rId || 'RESTAURANT',
      name: rName || 'Restaurant',
      slug: rSlug || 'restaurant',
      lat: fallbackLat,
      lng: fallbackLng,
      deliveryRadiusKm: 5.0,
    }
  }

  return null
}
