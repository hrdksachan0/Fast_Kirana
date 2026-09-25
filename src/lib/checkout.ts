/**
 * Shared checkout validation and utility functions.
 * Used by both COD and Paytm checkout flows to avoid duplication.
 */

import { getDistanceKm, getDeliveryRules } from './distance'
import { getLast10Digits, isValidIndianPhone } from './phone'
import { getRestaurantLocation } from './restaurant-location'

// ── Default store configuration (overridable via StoreSetting) ──────────────

export const DEFAULT_STORE_LAT = 26.1534185
export const DEFAULT_STORE_LNG = 80.1714024
export const DEFAULT_STORE_PINCODE = '209206'
export const DEFAULT_SHOP_NAME = 'FastKirana Dark Store'
export const DEFAULT_CONTACT_PHONE = process.env.NEXT_PUBLIC_SUPPORT_PHONE || '+91 8112849854'
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

// ── Types ────────────────────────────────────────────────────────────────────

export interface CartItemInput {
  product: {
    id: string
    name: string
    category?: { slug?: string } | null
    restaurantId?: string | null
    tags?: string[]
    restaurant?: {
      id?: string
      name?: string
      isOpen?: boolean | null
      openTime?: string | null
      closeTime?: string | null
      updatedAt?: Date | string | null
    } | null
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

// ── Helpers ───────────────────────────────────────────────────────────────────

export function classifyItems(items: CartItemInput[]) {
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

export function validateAddress(
  address: Address,
  storeLat: number,
  storeLng: number,
  maxRadiusKm: number
): { valid: boolean; error?: string } {
  const p = (address.pincode || '').trim().replace(/\s+/g, '')
  const c = (address.city || '').trim().toLowerCase()

  const isAkbarpur = p === '224122' || c.includes('akbarpur') || c.includes('ambedkar')
  const allowedPincodes = isAkbarpur
    ? ['224122']
    : [DEFAULT_STORE_PINCODE, '209206', '209201', '209214', '209208', '208001', '208002', '208011', '208012', '208020']

  if (p && !allowedPincodes.includes(p) && !/^\d{6}$/.test(p)) {
    return { valid: false, error: `Selected address pincode (${p}) is outside our delivery zone.` }
  }

  const allowedCities = isAkbarpur
    ? ['akbarpur', 'ambedkar', 'ambedkarnagar', 'up', 'uttar pradesh']
    : ['ghatampur', 'kanpur', 'nagar', 'dehat', 'up', 'uttar pradesh']

  if (c && !allowedCities.some(cityKeyword => c.includes(cityKeyword))) {
    return { valid: false, error: 'Selected address city is outside our delivery zone.' }
  }

  const phoneVal = (address.phone || '').trim()
  const cleanPhone = getLast10Digits(phoneVal)
  if (!isValidIndianPhone(cleanPhone)) {
    return { valid: false, error: 'The selected address is missing a valid 10-digit mobile number. Please add a new address with a valid phone number.' }
  }

  if (address.lat && address.lng) {
    // If Akbarpur, measure against Akbarpur Hub coordinates
    const targetStoreLat = isAkbarpur ? 26.4380 : storeLat
    const targetStoreLng = isAkbarpur ? 82.5400 : storeLng
    const dist = getDistanceKm(targetStoreLat, targetStoreLng, address.lat, address.lng)

    // Auto-Healing:
    // If the customer has explicitly entered a valid recognized pincode (e.g. 209206 for Ghatampur, 224122 for Akbarpur)
    // or valid city text, but their phone/browser GPS coordinates point to a distant cell tower (> 10 km away, e.g. Kanpur tower 45 km away),
    // DO NOT hard block them! Auto-heal or treat as valid delivery address.
    const isExplicitLocalPincode = p === '209206' || p === '224122' || c.includes('ghatampur') || c.includes('akbarpur')
    if (dist >= 25.0 && isExplicitLocalPincode) {
      console.warn(`[Auto-Heal] Address ${address.id || ''} has cell-tower drift (${dist.toFixed(1)} km) for pincode ${p}. Allowing order.`);
      return { valid: true }
    }

    const rules = getDeliveryRules(dist, { maxRadiusKm })
    if (!rules.isServiceable) {
      return { valid: false, error: `Your address is outside our delivery zone (${dist.toFixed(1)} km away). We deliver only up to ${maxRadiusKm} km.` }
    }
  }

  return { valid: true }
}

// ── Main validation function ────────────────────────────────────────────────────

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

import { checkStoreOperatingStatus } from './restaurant-schedule'

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

  // ── Specific Restaurant / Cafe Outlet Schedule Checks ──────────────────
  for (const item of items) {
    const rest = item.product.restaurant
    if (rest) {
      const opStatus = checkStoreOperatingStatus(rest)
      if (!opStatus.isOpen) {
        return {
          valid: false,
          error: `${rest.name || 'Restaurant'} is currently closed (${opStatus.formattedScheduleStr || 'Outside operating hours'}). Please remove restaurant items to checkout.`
        }
      }
    }
  }

  // ── Address validation for delivery ────────────────────────────────────
  if (deliveryMethod === 'DELIVERY') {
    const targetId = selectedAddressId || (addresses.length > 0 ? addresses[0].id : '')
    const selectedAddr = addresses.find(a => a.id === targetId)

    if (selectedAddr) {
      const storeLat = parseFloat(settings.store_lat || '') || DEFAULT_STORE_LAT
      const storeLng = parseFloat(settings.store_lng || '') || DEFAULT_STORE_LNG
      const maxRadiusKm = parseFloat(settings.delivery_radius || String(DEFAULT_DELIVERY_RADIUS_KM))

      // If cart has grocery items, validate dark store radius
      if (hasGrocery) {
        const addrValidation = validateAddress(selectedAddr, storeLat, storeLng, maxRadiusKm)
        if (!addrValidation.valid) {
          return { valid: false, error: addrValidation.error }
        }
      }

      // If cart has restaurant/cafe items, validate against the restaurant's location
      if (hasCafe || hasRestaurant) {
        const firstRestItem = items.find(i => i.product.restaurant || i.product.restaurantId) || items[0]
        const restLoc = getRestaurantLocation(firstRestItem.product, storeLat, storeLng)

        if (restLoc && selectedAddr.lat && selectedAddr.lng) {
          const rDist = getDistanceKm(restLoc.lat, restLoc.lng, selectedAddr.lat, selectedAddr.lng)
          const p = (selectedAddr.pincode || '').trim().replace(/\s+/g, '')
          const c = (selectedAddr.city || '').trim().toLowerCase()
          const isExplicitLocalPincode = p === '209206' || p === '224122' || c.includes('ghatampur') || c.includes('akbarpur')
          if (rDist > restLoc.deliveryRadiusKm && !(rDist >= 25.0 && isExplicitLocalPincode)) {
            return {
              valid: false,
              error: `Your address is outside ${restLoc.name}'s delivery zone (${rDist.toFixed(1)} km away). Delivery from this restaurant is strictly limited to ${restLoc.deliveryRadiusKm.toFixed(0)} km.`
            }
          }
        } else if (!hasGrocery) {
          // If pure restaurant and no GPS coords on address, run city/pincode basic check
          const addrValidation = validateAddress(selectedAddr, storeLat, storeLng, restLoc?.deliveryRadiusKm || 5.0)
          if (!addrValidation.valid) {
            return { valid: false, error: addrValidation.error }
          }
        }
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
    items: CartItemInput[]
    deliveryMethod: 'DELIVERY' | 'PICKUP'
    scheduledSlot: string
    appliedCouponCode: string | null
    customerPhone?: string
    contactPhone?: string
    packagingOption?: 'NORMAL' | 'PREMIUM'
    packagingFee?: number
    userId?: string
    userPhone?: string
    isOrderForSomeone?: boolean
    receiverName?: string
    receiverPhone?: string
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
    shopPhone: ctx.contactPhone || DEFAULT_CONTACT_PHONE,
    userId: ctx.userId,
    userPhone: ctx.userPhone,
    phone: ctx.userPhone || ctx.customerPhone || undefined,
    customerPhone: ctx.customerPhone || undefined,
    receiverName: ctx.receiverName,
    receiverPhone: ctx.receiverPhone,
    isOrderForSomeone: ctx.isOrderForSomeone,
    couponCode: ctx.appliedCouponCode,
    packagingOption: ctx.packagingOption || 'NORMAL',
    packagingFee: ctx.packagingFee || 0,
  }
}
