/**
 * Shared checkout validation and utility functions.
 * Used by both COD and Paytm checkout flows to avoid duplication.
 */

import { toast } from 'sonner'
import { triggerHaptic } from './haptic'
import { getDistanceKm, getDeliveryRules } from './distance'
import { getLast10Digits, isValidIndianPhone } from './phone'
import type { CartItem } from '@/stores/cart-store'

// ── Default store configuration (overridable via StoreSetting) ──────────────

export const DEFAULT_STORE_LAT = 26.1534185
export const DEFAULT_STORE_LNG = 80.1714024
export const DEFAULT_STORE_PINCODE = '209206'
export const DEFAULT_SHOP_NAME = 'FastKirana Dark Store'
export const DEFAULT_CONTACT_PHONE = '+91 70544 70303'
export const DEFAULT_CONTACT_ADDRESS = 'NH34, Ghatampur, Kanpur Nagar'
export const DEFAULT_DELIVERY_RADIUS_KM = 2.0
export const DEFAULT_MIN_ORDER = 20

export function resolveStoreLat(settings: SettingsMap): number {
  return parseFloat(settings.store_lat || '') || DEFAULT_STORE_LAT
}

export function resolveStoreLng(settings: SettingsMap): number {
  return parseFloat(settings.store_lng || '') || DEFAULT_STORE_LNG
}

export function resolveStorePincode(settings: SettingsMap): string {
  return settings.store_pincode || DEFAULT_STORE_PINCODE
}

export function resolveStorePhone(settings: SettingsMap): string {
  return settings.store_phone || DEFAULT_CONTACT_PHONE
}

export function resolveStoreAddress(settings: SettingsMap): string {
  return settings.store_address || DEFAULT_CONTACT_ADDRESS
}

export function resolveShopName(settings: SettingsMap): string {
  return settings.shop_name || DEFAULT_SHOP_NAME
}

export function resolveMinOrder(settings: SettingsMap): number {
  return parseInt(settings.min_order_value || String(DEFAULT_MIN_ORDER), 10)
}

// ── Types ───────────────────────────────────────────────────────────────────

export interface CartItemInput {
  product: {
    id: string
    name: string
    category?: { slug?: string } | null
    restaurantId?: string | null
    tags?: string[]
  }
}

export interface Address {
  id: string
  pincode: string
  city: string
  phone: string
  lat?: number | null
  lng?: number | null
  street?: string
}

export interface SettingsMap {
  grocery_mart_open?: string
  cafe_open?: string
  restaurant_open?: string
  delivery_radius?: string
  store_lat?: string
  store_lng?: string
  store_pincode?: string
  store_phone?: string
  store_address?: string
  shop_name?: string
  min_order_value?: string
  grocery_close_time?: string
  cafe_close_time?: string
  [key: string]: string | undefined
}

export interface DeliveryMethod {
  DELIVERY: 'DELIVERY'
  PICKUP: 'PICKUP'
}

// ── Helpers ─────────────────────────────────────────────────────────────────

function classifyItems(items: any[]) {
  let hasCafe = false
  let hasRestaurant = false
  let hasGrocery = false

  for (const item of items) {
    const catSlug = (item.product.category?.slug || '').toLowerCase()
    const tags = (item.product.tags || []).map((t: string) => t.toLowerCase())
    const isCafe = item.product.restaurantId !== undefined && item.product.restaurantId !== null
      || catSlug === 'cafe' || catSlug === 'restaurant'
      || tags.some((t: string) => ['cafe', 'restaurant', 'wedson', 'as-restaurant', 'food', 'shakes', 'beverage', 'beverages', 'pizza', 'burger', 'dessert', 'starters', 'main-course'].includes(t))
    const isRestaurant = catSlug === 'restaurant' || tags.some((t: string) => ['restaurant', 'wedson', 'as-restaurant'].includes(t))

    if (isRestaurant) {
      hasRestaurant = true
    } else if (isCafe) {
      hasCafe = true
    } else {
      hasGrocery = true
    }
  }

  return { hasCafe, hasRestaurant, hasGrocery }
}

function validateAddress(
  address: Address,
  storeLat: number,
  storeLng: number,
  maxRadiusKm: number
): { valid: boolean; error?: string } {
  const p = address.pincode.trim()
  const c = address.city.trim().toLowerCase()

  if (p !== DEFAULT_STORE_PINCODE) {
    return { valid: false, error: `Selected address is outside our delivery zone. FastKirana only delivers to Ghatampur (Pincode: ${DEFAULT_STORE_PINCODE}).` }
  }

  if (!c.includes('ghatampur') && !c.includes('kanpur')) {
    return { valid: false, error: 'Selected address city is outside our delivery zone. FastKirana only delivers to Ghatampur / Kanpur.' }
  }

  const phoneVal = (address.phone || '').trim()
  const cleanPhone = getLast10Digits(phoneVal)
  if (!isValidIndianPhone(cleanPhone)) {
    return { valid: false, error: 'The selected address is missing a valid 10-digit mobile number. Please add a new address with a valid phone number.' }
  }

  if (address.lat && address.lng) {
    const dist = getDistanceKm(storeLat, storeLng, address.lat, address.lng)
    const rules = getDeliveryRules(dist, { maxRadiusKm })
    if (!rules.isServiceable) {
      return { valid: false, error: `Your address is outside our delivery zone (${dist.toFixed(1)} km away). We deliver only up to ${maxRadiusKm} km.` }
    }
  }

  return { valid: true }
}

// ── Main validation function ────────────────────────────────────────────────

export interface CheckoutValidationResult {
  valid: boolean
  error?: string
  finalAddressId?: string
}

export interface CheckoutValidationContext {
  items: CartItemInput[]
  addresses: Address[]
  selectedAddressId: string | undefined
  deliveryMethod: 'DELIVERY' | 'PICKUP'
  settings: SettingsMap
}

export async function validateCheckoutEligibility(
  ctx: CheckoutValidationContext
): Promise<CheckoutValidationResult> {
  const { items, addresses, selectedAddressId, deliveryMethod, settings } = ctx

  // ── Address required for delivery ──────────────────────────────────────
  if (deliveryMethod === 'DELIVERY' && !selectedAddressId && addresses.length === 0) {
    return { valid: false, error: 'Please select a delivery address' }
  }

  // ── Classify items ──────────────────────────────────────────────────────
  const { hasCafe, hasRestaurant, hasGrocery } = classifyItems(items)

  // ── Store open checks ───────────────────────────────────────────────────
  if (hasGrocery && settings.grocery_mart_open === 'false') {
    return { valid: false, error: 'Grocery Mart is temporarily closed. Please remove grocery items to checkout.' }
  }

  if (hasCafe && settings.cafe_open === 'false') {
    return { valid: false, error: 'FastKirana Cafe is temporarily closed. Please remove cafe items to checkout.' }
  }

  if (hasRestaurant && settings.restaurant_open === 'false') {
    return { valid: false, error: 'Wedson Restaurant is temporarily closed. Please remove restaurant items to checkout.' }
  }

  // ── Address validation for delivery ────────────────────────────────────
  if (deliveryMethod === 'DELIVERY') {
    const targetId = selectedAddressId || (addresses.length > 0 ? addresses[0].id : '')
    const selectedAddr = addresses.find(a => a.id === targetId)

    if (selectedAddr) {
      const storeLat = parseFloat(settings.store_lat || '') || DEFAULT_STORE_LAT
      const storeLng = parseFloat(settings.store_lng || '') || DEFAULT_STORE_LNG
      const maxRadiusKm = parseFloat(settings.delivery_radius || String(DEFAULT_DELIVERY_RADIUS_KM))

      const addrValidation = validateAddress(selectedAddr, storeLat, storeLng, maxRadiusKm)
      if (!addrValidation.valid) {
        return { valid: false, error: addrValidation.error }
      }
    }
  }

  const finalAddressId = deliveryMethod === 'PICKUP' ? 'STORE_PICKUP' : (selectedAddressId || (addresses.length > 0 ? addresses[0].id : ''))

  return { valid: true, finalAddressId }
}

// ── Place order payload builder ─────────────────────────────────────────────

export function buildOrderPayload(
  ctx: {
    finalAddressId: string
    paymentMethod: string
    items: any[]
    deliveryMethod: 'DELIVERY' | 'PICKUP'
    scheduledSlot: string
    appliedCouponCode: string | null
    contactPhone: string
  }
) {
  return {
    addressId: ctx.finalAddressId,
    paymentMethod: ctx.paymentMethod,
    items: ctx.items,
    deliveryMethod: ctx.deliveryMethod,
    isB2B: false,
    scheduledSlot: ctx.scheduledSlot,
    shopName: DEFAULT_SHOP_NAME,
    shopPhone: ctx.contactPhone,
    couponCode: ctx.appliedCouponCode,
  }
}
