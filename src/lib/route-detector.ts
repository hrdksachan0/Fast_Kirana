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
  'hamirpur road', 'hamirpur rd', 'hamirpur', 'hamir pur', 'bus stand', 'bus adda',
  'mandi samiti', 'mandi', 'yamuna pul', 'yamuna bridge', 'yamuna',
  'bypass south', 'south bypass', 'by pass south', 'patel nagar', 'kushwaha nagar',
  'kushwaha', 'south', 'nh34 south', 'nh-34 south', 'saukhara', 'bairi'
]

const MOOSANAGAR_KEYWORDS = [
  'moosanagar road', 'moosanagar rd', 'moosanagar', 'moosangar', 'musa nagar', 'musanagar',
  'mughal road', 'mughal rd', 'mughal', 'chc hospital', 'chc', 'samudayik', 'hospital',
  'degree college', 'college', 'block office', 'block', 'sarvoday nagar', 'sarvoday',
  'sarvodaya', 'west', 'bindki road', 'bindki rd', 'bindki', 'ansar market'
]

const KANPUR_KEYWORDS = [
  'kanpur road', 'kanpur rd', 'kanpur highway', 'railway station', 'railway', 'crossing',
  'railway crossing', 'fatak', 'railway fatak', 'station road', 'station rd', 'shahi gate',
  'subhash nagar', 'subhash', 'north', 'nh34 north', 'nh-34 north', 'kora jahanabad',
  'kora mode', 'kora mor'
]

const JAHANABAD_KEYWORDS = [
  'jahanabad road', 'jahanabad rd', 'jahanabad', 'jahana bad', 'jahanabad tiraha', 'tiraha',
  'kotwali', 'thana road', 'thana rd', 'thana', 'police station', 'sabzi mandi',
  'purana bazar', 'purana bazaar', 'east', 'kasba'
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

  const addressTokens: string[] = []
  let lat: number | null = null
  let lng: number | null = null

  const extractFromMap = (addr: any) => {
    if (!addr || typeof addr !== 'object') return
    for (const key of ['area', 'street', 'houseNo', 'landmark', 'label', 'locality', 'address', 'formattedAddress', 'addressLine1', 'addressLine2', 'city']) {
      const val = addr[key]
      if (val && typeof val === 'string' && val.trim()) {
        const str = val.trim()
        if (key === 'city' && (str.toLowerCase() === 'kanpur' || str.toLowerCase() === 'kanpur nagar')) {
          continue
        }
        addressTokens.push(str)
      }
    }
    if (lat === null && addr.lat !== undefined && addr.lat !== null) {
      const parsed = Number(addr.lat)
      if (!isNaN(parsed)) lat = parsed
    }
    if (lng === null && addr.lng !== undefined && addr.lng !== null) {
      const parsed = Number(addr.lng)
      if (!isNaN(parsed)) lng = parsed
    }
  }

  const rawAddr = order.address || order.addresses || order.customerAddress || order.addressRaw
  if (Array.isArray(rawAddr)) {
    rawAddr.forEach(extractFromMap)
  } else if (rawAddr && typeof rawAddr === 'object') {
    extractFromMap(rawAddr)
  } else if (typeof rawAddr === 'string') {
    addressTokens.push(rawAddr)
  }

  if (Array.isArray(order.subOrders)) {
    for (const sub of order.subOrders) {
      const sAddr = sub.address || sub.addresses || sub.customerAddress
      if (sAddr) extractFromMap(sAddr)
      if (sub.notes) addressTokens.push(String(sub.notes))
    }
  }

  if (order.deliveryLat !== undefined && order.deliveryLat !== null) {
    const parsed = Number(order.deliveryLat)
    if (!isNaN(parsed)) lat = parsed
  }
  if (order.deliveryLng !== undefined && order.deliveryLng !== null) {
    const parsed = Number(order.deliveryLng)
    if (!isNaN(parsed)) lng = parsed
  }

  const rawText = (addressTokens.join(' ') + ' ' + (order.notes || '') + ' ' + (order.deliveryInstructions || '')).toLowerCase()

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
  if (lat && lng && lat > 20 && lng > 70) {
    const centerLat = 26.155
    const centerLng = 80.165
    const dLat = lat - centerLat
    const dLng = lng - centerLng

    if (Math.abs(dLat) > 0.004 || Math.abs(dLng) > 0.004) {
      if (dLat < -0.004 && Math.abs(dLat) >= Math.abs(dLng)) return DELIVERY_ROUTES.HAMIRPUR // South
      if (dLat > 0.004 && Math.abs(dLat) >= Math.abs(dLng)) return DELIVERY_ROUTES.KANPUR // North
      if (dLng < -0.004 && Math.abs(dLng) > Math.abs(dLat)) return DELIVERY_ROUTES.MOOSANAGAR // West
      if (dLng > 0.004 && Math.abs(dLng) > Math.abs(dLat)) return DELIVERY_ROUTES.JAHANABAD // East
    }
  }

  return DELIVERY_ROUTES.TOWN_CENTER
}
