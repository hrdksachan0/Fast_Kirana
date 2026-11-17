/**
 * Route Detector Utility for Ghatampur Delivery Operations
 * 
 * Classifies orders into 4 primary arterial delivery routes:
 * 1. Hamirpur Road (South Route)
 * 2. Moosanagar Road (West Route / Mughal Road)
 * 3. Kanpur Road (North Route / NH-34)
 * 4. Jahanabad Road (East / North-East Route)
 * Default fallback: Town Center (Internal Ghatampur town area)
 */

export type DeliveryRouteKey = 'ALL' | 'HAMIRPUR' | 'MOOSANAGAR' | 'KANPUR' | 'JAHANABAD' | 'TOWN_CENTER'

export interface RouteInfo {
  key: DeliveryRouteKey
  label: string
  shortLabel: string
  emoji: string
  colorBadgeClass: string
  activeButtonClass: string
  description: string
}

export const DELIVERY_ROUTES: Record<Exclude<DeliveryRouteKey, 'ALL'>, RouteInfo> = {
  HAMIRPUR: {
    key: 'HAMIRPUR',
    label: 'Hamirpur Road',
    shortLabel: 'Hamirpur Rd',
    emoji: '🔴',
    colorBadgeClass: 'bg-rose-500/10 text-rose-700 dark:text-rose-300 border-rose-500/30',
    activeButtonClass: 'bg-rose-600 text-white border-rose-600 shadow-rose-500/30',
    description: 'Hamirpur Chauraha, Bus Stand, Mandi Samiti, Yamuna Bridge, Patel Nagar, Bypass',
  },
  MOOSANAGAR: {
    key: 'MOOSANAGAR',
    label: 'Moosanagar Road',
    shortLabel: 'Moosanagar Rd',
    emoji: '🟣',
    colorBadgeClass: 'bg-purple-500/10 text-purple-700 dark:text-purple-300 border-purple-500/30',
    activeButtonClass: 'bg-purple-600 text-white border-purple-600 shadow-purple-500/30',
    description: 'Moosanagar Road, Mughal Road, CHC Hospital, Degree College, Block Office, Sarvoday Nagar',
  },
  KANPUR: {
    key: 'KANPUR',
    label: 'Kanpur Road',
    shortLabel: 'Kanpur Rd',
    emoji: '🔵',
    colorBadgeClass: 'bg-blue-500/10 text-blue-700 dark:text-blue-300 border-blue-500/30',
    activeButtonClass: 'bg-blue-600 text-white border-blue-600 shadow-blue-500/30',
    description: 'Kanpur Road, Railway Station, Crossing, Shahi Gate, Subhash Nagar, NH-34 North',
  },
  JAHANABAD: {
    key: 'JAHANABAD',
    label: 'Jahanabad Road',
    shortLabel: 'Jahanabad Rd',
    emoji: '🟢',
    colorBadgeClass: 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300 border-emerald-500/30',
    activeButtonClass: 'bg-emerald-600 text-white border-emerald-600 shadow-emerald-500/30',
    description: 'Jahanabad Tiraha, Kotwali, Thana Road, Sabzi Mandi, Purana Bazar East',
  },
  TOWN_CENTER: {
    key: 'TOWN_CENTER',
    label: 'Town Center',
    shortLabel: 'Town Center',
    emoji: '🟡',
    colorBadgeClass: 'bg-amber-500/10 text-amber-700 dark:text-amber-300 border-amber-500/30',
    activeButtonClass: 'bg-amber-600 text-white border-amber-600 shadow-amber-500/30',
    description: 'Chauraha Chowk, Sadar Bazar, Main Town, Central Hub',
  },
}

const HAMIRPUR_KEYWORDS = [
  'hamirpur', 'hamir pur', 'bus stand', 'mandi', 'mandi samiti', 'yamuna', 'pul',
  'bypass', 'by pass', 'patel nagar', 'kushwaha', 'south', 'nh34 south', 'nh-34 south',
  'saukhara', 'bairi'
]

const MOOSANAGAR_KEYWORDS = [
  'moosanagar', 'musa nagar', 'musanagar', 'mughal', 'mughal road', 'chc', 'hospital',
  'degree college', 'college', 'block', 'sarvoday', 'sarvodaya', 'west', 'bindki road'
]

const KANPUR_KEYWORDS = [
  'kanpur', 'kanpur road', 'railway', 'station', 'crossing', 'fatak', 'shahi gate',
  'subhash nagar', 'subhash', 'north', 'nh34 north', 'nh-34 north', 'kora jahanabad mode'
]

const JAHANABAD_KEYWORDS = [
  'jahanabad', 'jahana bad', 'tiraha', 'kotwali', 'thana', 'police station', 'sabzi mandi',
  'purana bazar', 'east', 'jahanabad road'
]

/**
 * Formats order notes with a standardized route override marker.
 */
export function setRouteInNotes(existingNotes: string | null | undefined, routeKey: DeliveryRouteKey): string {
  const cleaned = (existingNotes || '')
    .replace(/\s*\|\s*ROUTE:[A-Z_]+(?=\s*\||$)/gi, '')
    .replace(/ROUTE:[A-Z_]+/gi, '')
    .trim()
  if (routeKey === 'ALL') return cleaned
  const marker = `ROUTE:${routeKey}`
  return cleaned ? `${cleaned} | ${marker}` : marker
}

/**
 * Detects the route from order address strings and coordinates.
 * Priority: Manual Admin Override in notes > Address text keywords > Coordinates > Fallback
 */
export function detectOrderRoute(order: any): RouteInfo {
  if (!order) return DELIVERY_ROUTES.TOWN_CENTER

  // 1. Explicit Admin manual override in notes or deliveryRoute property
  let notesUpper = ((order.notes || '') + ' ' + (order.deliveryInstructions || '') + ' ' + (order.deliveryRoute || '')).toUpperCase()
  if (Array.isArray(order.subOrders)) {
    for (const sub of order.subOrders) {
      notesUpper += ' ' + ((sub.notes || '') + ' ' + (sub.deliveryInstructions || '') + ' ' + (sub.deliveryRoute || '')).toUpperCase()
    }
  }
  if (notesUpper.includes('ROUTE:HAMIRPUR')) return DELIVERY_ROUTES.HAMIRPUR
  if (notesUpper.includes('ROUTE:MOOSANAGAR')) return DELIVERY_ROUTES.MOOSANAGAR
  if (notesUpper.includes('ROUTE:KANPUR')) return DELIVERY_ROUTES.KANPUR
  if (notesUpper.includes('ROUTE:JAHANABAD')) return DELIVERY_ROUTES.JAHANABAD
  if (notesUpper.includes('ROUTE:TOWN_CENTER')) return DELIVERY_ROUTES.TOWN_CENTER

  if (order.deliveryRoute && DELIVERY_ROUTES[order.deliveryRoute as keyof typeof DELIVERY_ROUTES]) {
    return DELIVERY_ROUTES[order.deliveryRoute as keyof typeof DELIVERY_ROUTES]
  }

  const addr = order.address || {}
  const rawText = [
    addr.addressLine1 || '',
    addr.addressLine2 || '',
    addr.landmark || '',
    addr.city || '',
    addr.locality || '',
    order.notes || '',
    order.deliveryInstructions || '',
  ]
    .join(' ')
    .toLowerCase()

  // Match Hamirpur Road
  if (HAMIRPUR_KEYWORDS.some((kw) => rawText.includes(kw))) {
    return DELIVERY_ROUTES.HAMIRPUR
  }

  // Match Moosanagar Road
  if (MOOSANAGAR_KEYWORDS.some((kw) => rawText.includes(kw))) {
    return DELIVERY_ROUTES.MOOSANAGAR
  }

  // Match Kanpur Road
  if (KANPUR_KEYWORDS.some((kw) => rawText.includes(kw))) {
    return DELIVERY_ROUTES.KANPUR
  }

  // Match Jahanabad Road
  if (JAHANABAD_KEYWORDS.some((kw) => rawText.includes(kw))) {
    return DELIVERY_ROUTES.JAHANABAD
  }

  // Coordinate-based approximate direction if available (Ghatampur center is approx lat: 26.155, lng: 80.165)
  const lat = order.deliveryLat || addr.lat
  const lng = order.deliveryLng || addr.lng

  if (lat && lng) {
    const centerLat = 26.155
    const centerLng = 80.165
    const dLat = lat - centerLat
    const dLng = lng - centerLng

    if (Math.abs(dLat) > 0.005 || Math.abs(dLng) > 0.005) {
      if (dLat < -0.005) return DELIVERY_ROUTES.HAMIRPUR // South
      if (dLat > 0.005 && Math.abs(dLng) < 0.01) return DELIVERY_ROUTES.KANPUR // North
      if (dLng < -0.005) return DELIVERY_ROUTES.MOOSANAGAR // West
      if (dLng > 0.005) return DELIVERY_ROUTES.JAHANABAD // East
    }
  }

  return DELIVERY_ROUTES.TOWN_CENTER
}
