/**
 * Central distance utility for delivery zone calculations.
 * Uses the Haversine formula to calculate straight-line distance.
 */

/**
 * Calculate the distance in km between two GPS coordinates using the Haversine formula.
 */
export function getDistanceKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const R = 6371 // Earth's radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180
  const dLng = ((lng2 - lng1) * Math.PI) / 180
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

/**
 * Distance-based delivery rules interface.
 */
export interface DeliveryRules {
  distanceKm: number
  minOrder: number
  deliveryFee: number
  baseFee: number
  freeDeliveryThreshold: number
  isServiceable: boolean
  zoneName: string
  surgeFee: number
  surgeReason?: string
  maxRadiusKm: number
  smallOrderFee?: number
  smallOrderThreshold?: number
  nightFee?: number
}

export interface DeliveryRuleOptions {
  maxRadiusKm?: number
  surgeFee?: number
  surgeReason?: string
  isRainMode?: boolean
  settings?: Record<string, string | undefined>
  storeName?: string
  cityName?: string
  tier1Fee?: number
  tier2Fee?: number
  tier3Fee?: number
  tier1Threshold?: number
  tier2Threshold?: number
  tier3Threshold?: number
  perKmFeeBeyond5km?: number
}

/**
 * Advanced distance-based delivery rules with dynamic radius, settings-configured tier pricing & surge fee calculation.
 */
export function getDeliveryRules(
  distanceKm: number,
  options: DeliveryRuleOptions = {}
): DeliveryRules {
  const maxRadiusKm = options.maxRadiusKm ?? (options.settings?.delivery_radius ? parseFloat(options.settings.delivery_radius) : 5.0)
  const surgeFee = options.surgeFee ?? 0
  const surgeReason = options.surgeReason

  // Configurable tier delivery fees from store settings
  const tier1Fee = options.tier1Fee ?? (options.settings?.delivery_fee_tier1 ? parseFloat(options.settings.delivery_fee_tier1) : (options.settings?.delivery_fee ? parseFloat(options.settings.delivery_fee) : 25))
  const tier2Fee = options.tier2Fee ?? (options.settings?.delivery_fee_tier2 ? parseFloat(options.settings.delivery_fee_tier2) : 35)
  const tier3Fee = options.tier3Fee ?? (options.settings?.delivery_fee_tier3 ? parseFloat(options.settings.delivery_fee_tier3) : 50)
  const perKmFeeBeyond5km = options.perKmFeeBeyond5km ?? (options.settings?.delivery_fee_per_km_beyond_5km ? parseFloat(options.settings.delivery_fee_per_km_beyond_5km) : 10)

  // Configurable free delivery thresholds from store settings
  const tier1Threshold = options.tier1Threshold ?? (options.settings?.delivery_threshold_tier1 ? parseFloat(options.settings.delivery_threshold_tier1) : (options.settings?.grocery_free_delivery_threshold ? parseFloat(options.settings.grocery_free_delivery_threshold) : 199))
  const tier2Threshold = options.tier2Threshold ?? (options.settings?.delivery_threshold_tier2 ? parseFloat(options.settings.delivery_threshold_tier2) : 299)
  const tier3Threshold = options.tier3Threshold ?? (options.settings?.delivery_threshold_tier3 ? parseFloat(options.settings.delivery_threshold_tier3) : 399)

  // Store / City Name for localized zone labeling
  const rawCity = options.cityName || options.storeName || (options.settings?.store_name ? options.settings.store_name.replace(/\s+(Hub|Market|Central|Dark\s*Store).*$/i, '').trim() : '') || 'Local'
  const zoneCityLabel = rawCity ? `${rawCity} ` : ''

  // 1. Check if distance strictly exceeds max allowed delivery radius
  if (distanceKm > maxRadiusKm) {
    return {
      distanceKm,
      minOrder: 20,
      deliveryFee: 0,
      baseFee: 0,
      freeDeliveryThreshold: tier3Threshold + 100,
      isServiceable: false,
      zoneName: `Outside Delivery Zone (> ${maxRadiusKm.toFixed(1)} km)`,
      surgeFee,
      surgeReason,
      maxRadiusKm,
    }
  }

  // Zone 1: 0 - 2.0 km (Local Zone)
  if (distanceKm <= 2.0) {
    return {
      distanceKm,
      minOrder: 0,
      deliveryFee: tier1Fee + surgeFee,
      baseFee: tier1Fee,
      freeDeliveryThreshold: tier1Threshold,
      isServiceable: true,
      zoneName: `0 - 2 km (${zoneCityLabel}Local Zone)`,
      surgeFee,
      surgeReason,
      maxRadiusKm,
    }
  }

  // Zone 2: 2.0 - 3.0 km (Suburban Zone)
  if (distanceKm <= 3.0) {
    return {
      distanceKm,
      minOrder: 0,
      deliveryFee: tier2Fee + surgeFee,
      baseFee: tier2Fee,
      freeDeliveryThreshold: tier2Threshold,
      isServiceable: true,
      zoneName: '2 - 3 km (Suburban Zone)',
      surgeFee,
      surgeReason,
      maxRadiusKm,
    }
  }

  // Zone 3: 3.0 - 5.0 km (Extended Zone)
  if (distanceKm <= 5.0) {
    return {
      distanceKm,
      minOrder: 0,
      deliveryFee: tier3Fee + surgeFee,
      baseFee: tier3Fee,
      freeDeliveryThreshold: tier3Threshold,
      isServiceable: true,
      zoneName: '3 - 5 km (Extended Zone)',
      surgeFee,
      surgeReason,
      maxRadiusKm,
    }
  }

  // Zone 4: 5.0 km up to maxRadiusKm (Long Distance Serviceable Zone)
  const extraKm = Math.ceil(distanceKm - 5.0)
  const longDistanceFee = tier3Fee + (extraKm * perKmFeeBeyond5km)
  const longDistanceThreshold = tier3Threshold + (extraKm * 50)

  return {
    distanceKm,
    minOrder: 0,
    deliveryFee: longDistanceFee + surgeFee,
    baseFee: longDistanceFee,
    freeDeliveryThreshold: longDistanceThreshold,
    isServiceable: true,
    zoneName: `5 - ${maxRadiusKm.toFixed(0)} km (Long Distance Zone)`,
    surgeFee,
    surgeReason,
    maxRadiusKm,
  }
}

/** Default store coordinates (Ghatampur Hub) */
export const DEFAULT_STORE_LAT = 26.1534185
export const DEFAULT_STORE_LNG = 80.1714024

