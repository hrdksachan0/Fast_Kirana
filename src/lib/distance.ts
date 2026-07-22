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
  freeDeliveryThreshold: number
  isServiceable: boolean
  zoneName: string
  surgeFee: number
  maxRadiusKm: number
}

interface DeliveryRuleOptions {
  maxRadiusKm?: number
  surgeFee?: number
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

  // Check if distance exceeds max allowed radius
  if (distanceKm > maxRadiusKm) {
    return {
      distanceKm,
      minOrder: 20,
      deliveryFee: 0,
      freeDeliveryThreshold: 499,
      isServiceable: false,
      zoneName: `Outside Delivery Zone (> ${maxRadiusKm.toFixed(1)} km)`,
      surgeFee,
      maxRadiusKm,
    }
  }

  // Zone 1: 0 - 2.0 km
  if (distanceKm <= 2.0) {
    return {
      distanceKm,
      minOrder: 20,
      deliveryFee: 25 + surgeFee,
      freeDeliveryThreshold: 199,
      isServiceable: true,
      zoneName: '0-2 km (Express Zone)',
      surgeFee,
      maxRadiusKm,
    }
  }

  // Zone 2: 2.0 - 4.0 km
  if (distanceKm <= 4.0) {
    return {
      distanceKm,
      minOrder: 20,
      deliveryFee: 35 + surgeFee,
      freeDeliveryThreshold: 249,
      isServiceable: true,
      zoneName: '2-4 km (Standard Zone)',
      surgeFee,
      maxRadiusKm,
    }
  }

  // Zone 3: 4.0 - 6.0 km
  if (distanceKm <= 6.0) {
    return {
      distanceKm,
      minOrder: 50,
      deliveryFee: 50 + surgeFee,
      freeDeliveryThreshold: 349,
      isServiceable: true,
      zoneName: '4-6 km (Extended Zone)',
      surgeFee,
      maxRadiusKm,
    }
  }

  // Zone 4: 6.0+ km (if maxRadiusKm allows)
  return {
    distanceKm,
    minOrder: 100,
    deliveryFee: 70 + surgeFee,
    freeDeliveryThreshold: 499,
    isServiceable: true,
    zoneName: '6+ km (Outer Zone)',
    surgeFee,
    maxRadiusKm,
  }
}

/** Default store coordinates (Ghatampur Hub) */
export const DEFAULT_STORE_LAT = 26.1534185
export const DEFAULT_STORE_LNG = 80.1714024
