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
 * Distance-based delivery rules.
 * Returns minimum order, delivery fee, and serviceability for a given distance.
 */
export interface DeliveryRules {
  distanceKm: number
  minOrder: number
  deliveryFee: number
  isServiceable: boolean
  zoneName: string
}

export function getDeliveryRules(distanceKm: number): DeliveryRules {
  if (distanceKm <= 2) {
    return {
      distanceKm,
      minOrder: 200,
      deliveryFee: 0,
      isServiceable: true,
      zoneName: '0-2 km',
    }
  }
  if (distanceKm <= 3) {
    return {
      distanceKm,
      minOrder: 300,
      deliveryFee: 0,
      isServiceable: true,
      zoneName: '2-3 km',
    }
  }
  if (distanceKm <= 4) {
    return {
      distanceKm,
      minOrder: 400,
      deliveryFee: 0,
      isServiceable: true,
      zoneName: '3-4 km',
    }
  }
  return {
    distanceKm,
    minOrder: 0,
    deliveryFee: 0,
    isServiceable: false,
    zoneName: '4+ km (out of range)',
  }
}

/** Default store coordinates (Ghatampur Hub) */
export const DEFAULT_STORE_LAT = 26.1534185
export const DEFAULT_STORE_LNG = 80.1714024
