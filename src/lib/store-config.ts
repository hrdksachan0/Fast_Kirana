/**
 * Centralized store configuration for FastKirana.
 * Safe to import from both client components and server API routes.
 * Values here are fallback defaults; the authoritative source is the
 * StoreSetting table in the database (fetched via /api/settings).
 */

// ── Coordinates ──────────────────────────────────────────────────────────────

export const STORE_LAT = 26.1534185
export const STORE_LNG = 80.1714024

// ── Address & Contact ────────────────────────────────────────────────────────

export const STORE_PINCODE = '209206'
export const STORE_ADDRESS = 'NH34, Ghatampur, Kanpur Nagar'
export const STORE_PHONE = '+91 70544 70303'
export const SHOP_NAME = 'FastKirana Dark Store'
export const SERVICE_AREA_NAME = 'Ghatampur'

// ── Delivery Settings ────────────────────────────────────────────────────────

export const DELIVERY_RADIUS_KM = 2.0
export const MIN_ORDER_VALUE = 20

// ── Pickup Addresses ─────────────────────────────────────────────────────────

export const GROCERY_PICKUP_ADDRESS = 'Vikas Medical Store, NH34, Ghatampur, Kanpur Nagar, Kanpur, 209206'
export const CAFE_PICKUP_ADDRESS = 'Vikas Medical Store, NH34, Ghatampur, Kanpur Nagar, Kanpur, 209206'
export const RESTAURANT_PICKUP_ADDRESS = 'A.S Restaurant, Ghatampur, Kanpur Nagar, Kanpur, 209206'

// ── Free Delivery Thresholds ─────────────────────────────────────────────────

export const GROCERY_FREE_DELIVERY_THRESHOLD = 200
export const CAFE_FREE_DELIVERY_THRESHOLD = 200
export const COMBINED_FREE_DELIVERY_THRESHOLD = 200
export const DELIVERY_FEE = 25

// ── Helper: resolve from settings map ────────────────────────────────────────

export function resolvePincode(settings?: Record<string, string | undefined>): string {
  return settings?.store_pincode || STORE_PINCODE
}

export function resolvePhone(settings?: Record<string, string | undefined>): string {
  return settings?.store_phone || settings?.contact_phone || STORE_PHONE
}

export function resolveAddress(settings?: Record<string, string | undefined>): string {
  return settings?.store_address || settings?.contact_address || STORE_ADDRESS
}

export function resolveLat(settings?: Record<string, string | undefined>): number {
  return parseFloat(settings?.store_lat || '') || STORE_LAT
}

export function resolveLng(settings?: Record<string, string | undefined>): number {
  return parseFloat(settings?.store_lng || '') || STORE_LNG
}

export function resolveMinOrder(settings?: Record<string, string | undefined>): number {
  return parseInt(settings?.min_order_value || String(MIN_ORDER_VALUE), 10)
}

export function resolveDeliveryRadius(settings?: Record<string, string | undefined>): number {
  return parseFloat(settings?.delivery_radius || String(DELIVERY_RADIUS_KM))
}
