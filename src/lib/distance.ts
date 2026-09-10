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
}

interface DeliveryRuleOptions {
  maxRadiusKm?: number
  surgeFee?: number
  surgeReason?: string
  isRainMode?: boolean
}

/**
 * Advanced distance-based delivery rules with dynamic radius & surge fee calculation.
 */
export function getDeliveryRules(
  distanceKm: number,
  options: DeliveryRuleOptions = {}
): DeliveryRules {
  const maxRadiusKm = options.maxRadiusKm ?? 5.0 // Default 5 km delivery radius
  const surgeFee = options.surgeFee ?? 0
  const surgeReason = options.surgeReason

  // Check if distance exceeds max allowed radius
  if (distanceKm > maxRadiusKm) {
    return {
      distanceKm,
      minOrder: 20,
      deliveryFee: 0,
      baseFee: 0,
      freeDeliveryThreshold: 499,
      isServiceable: false,
      zoneName: `Outside Delivery Zone (> ${maxRadiusKm.toFixed(1)} km)`,
      surgeFee,
      surgeReason,
      maxRadiusKm,
    }
  }

  // Zone 1: 0 - 2.0 km (Local Ghatampur)
  if (distanceKm <= 2.0) {
    return {
      distanceKm,
      minOrder: 0,
      deliveryFee: 25 + surgeFee,
      baseFee: 25,
      freeDeliveryThreshold: 199,
      isServiceable: true,
      zoneName: '0 - 2 km (Local Ghatampur Zone)',
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
      deliveryFee: 35 + surgeFee,
      baseFee: 35,
      freeDeliveryThreshold: 299,
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
      deliveryFee: 50 + surgeFee,
      baseFee: 50,
      freeDeliveryThreshold: 399,
      isServiceable: true,
      zoneName: '3 - 5 km (Extended Zone)',
      surgeFee,
      surgeReason,
      maxRadiusKm,
    }
  }

  // Zone 4: > 5.0 km (Outside Service Area)
  return {
    distanceKm,
    minOrder: 0,
    deliveryFee: 70 + surgeFee,
    baseFee: 70,
    freeDeliveryThreshold: 499,
    isServiceable: false,
    zoneName: `Outside Delivery Zone (> ${maxRadiusKm.toFixed(1)} km)`,
    surgeFee,
    surgeReason,
    maxRadiusKm,
  }
}

/** Default store coordinates (Ghatampur Hub) */
export const DEFAULT_STORE_LAT = 26.1534185
export const DEFAULT_STORE_LNG = 80.1714024
