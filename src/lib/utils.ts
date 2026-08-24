import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

/** Retry a promise-returning function with exponential-like delay */
export async function withRetry<T>(
  fn: () => Promise<T>,
  retries = 3,
  delayMs = 1500
): Promise<T> {
  let lastError: unknown
  for (let i = 0; i < retries; i++) {
    try {
      return await fn()
    } catch (err) {
      lastError = err
      if (i < retries - 1) {
        await new Promise((resolve) => setTimeout(resolve, delayMs))
      }
    }
  }
  throw lastError
}

export function formatPrice(price: number): string {
  return `₹${price.toLocaleString('en-IN')}`
}

import { formatTime12h } from "./date-helpers"

// Re-export formatTime12h from date-helpers so callers can use one import
export { formatTime12h }

export function isCafeProduct(p: any): boolean {
  if (!p) return false
  // 1. Explicit restaurant assignment
  if (p.restaurantId || p.restaurant || p.restaurantName) return true
  
  // 2. Explicit restaurant category
  const categorySlug = (p.category?.slug || p.categorySlug || '').toLowerCase()
  if (categorySlug === 'restaurant' || categorySlug === 'restaurant-food' || categorySlug === 'fast-food-kitchen' || categorySlug === 'cafe') return true
  
  // 3. Explicit restaurant tags ONLY (do not include grocery terms like beverage or dessert)
  if (Array.isArray(p.tags) && p.tags.some((t: string) => ['restaurant', 'wedson', 'as-restaurant', 'as-cafe', 'bal-udyan'].includes(t.toLowerCase()))) return true
  
  return false
}

export function getOptimizedImageUrl(url: string | null | undefined, width = 300): string | null {
  if (!url) return null
  if (url.includes('cloudinary.com') && url.includes('/image/upload/')) {
    return url.replace('/image/upload/', `/image/upload/f_auto,q_auto,w_${width},c_limit/`)
  }
  return url
}

export function isDummyEmail(email: string | null | undefined): boolean {
  if (!email) return true
  const lower = email.toLowerCase().trim()
  return (
    lower.startsWith('wa-') ||
    lower.startsWith('user-') ||
    lower.endsWith('@fastkirana.com') ||
    lower.endsWith('@fastkirana.in')
  )
}

export function formatDisplayEmail(email: string | null | undefined): string {
  if (!email || isDummyEmail(email)) return ''
  return email.trim()
}

export function formatPhone(phone: string | null | undefined): string {
  if (!phone) return ''
  const trimmed = phone.trim()
  if (trimmed.startsWith('wa-') && trimmed.includes('@')) {
    const phoneDigits = trimmed.split('@')[0].replace('wa-', '')
    const cleanPhone = phoneDigits.length === 12 && phoneDigits.startsWith('91')
      ? phoneDigits.slice(2)
      : phoneDigits
    return `+91 ${cleanPhone}`
  }
  return trimmed
}

export function formatAddress(
  addr: any,
  includeCityAndPincode = true
): string {
  if (!addr) return ''
  if (typeof addr === 'string') return addr
  const parts: string[] = []
  
  if (addr.houseNo && addr.houseNo !== '.' && String(addr.houseNo).toLowerCase() !== 'n/a' && String(addr.houseNo).toLowerCase() !== 'ghatampur') {
    parts.push(`House No ${addr.houseNo}`)
  }
  
  if (addr.street && addr.street !== '.' && String(addr.street).toLowerCase() !== 'n/a') {
    parts.push(String(addr.street))
  }
  
  if (addr.area && addr.area !== '.' && String(addr.area).toLowerCase() !== 'n/a' && String(addr.area).toLowerCase() !== 'ghatampur') {
    parts.push(String(addr.area))
  }
  
  if (includeCityAndPincode) {
    if (addr.city && addr.city !== '.' && String(addr.city).toLowerCase() !== 'n/a') {
      const streetLower = addr.street ? String(addr.street).toLowerCase() : ''
      const cityLower = String(addr.city).toLowerCase()
      if (!streetLower.includes(cityLower)) {
        parts.push(String(addr.city))
      }
    }
    
    if (addr.pincode && addr.pincode !== '.' && String(addr.pincode).toLowerCase() !== 'n/a') {
      parts.push(String(addr.pincode))
    }
  }
  
  return parts.join(', ')
}

export function sortProductsByStock<T extends { stock?: number | null; variants?: any }>(products: T[]): T[] {
  return [...products].sort((a, b) => {
    const aInStock = isProductInStock(a)
    const bInStock = isProductInStock(b)
    if (aInStock && !bInStock) return -1
    if (!aInStock && bInStock) return 1
    return 0
  })
}

/** Variant-aware stock check — matches the mobile app's isProductOutOfStock logic */
export function isProductInStock(p: { stock?: number | null; variants?: any }): boolean {
  const hasVariants = p.variants && Array.isArray(p.variants) && p.variants.length > 0
  if (!hasVariants) return (p.stock ?? 0) > 0
  const totalStock = (p.variants as any[]).reduce((sum: number, v: any) => sum + (v.stock || 0), 0)
  return totalStock > 0
}

/** Variant-aware price resolver — returns cheapest variant price or base price */
export function getProductPrice(p: { price: number; variants?: any }): number {
  const hasVariants = p.variants && Array.isArray(p.variants) && p.variants.length > 0
  if (!hasVariants) return p.price || 0
  const prices = (p.variants as any[]).map((v: any) => v.price).filter((pr: number) => pr > 0)
  return prices.length > 0 ? Math.min(...prices) : (p.price || 0)
}

export function getProductType(p: any): 'RESTAURANT' | 'CAFE' | 'BYPASS' | 'GROCERY' {
  if (!p) return 'GROCERY'

  const slug = (p.category?.slug || p.categorySlug || (typeof p.category === 'string' ? p.category : '') || '').toLowerCase()
  const tags = (p.tags || []).map((t: any) => (typeof t === 'string' ? t.toLowerCase().trim() : ''))
  const name = (p.name || '').toLowerCase()

  // 1. Check BYPASS (Beverages, Ice Cream, Desserts, Packaged drinks) BEFORE restaurantId
  if (
    slug === 'ice-cream' ||
    slug === 'beverages' ||
    tags.includes('ice-cream') ||
    tags.includes('beverages') ||
    tags.includes('desserts') ||
    tags.includes('drinks') ||
    tags.includes('chilled') ||
    tags.includes('soft-drink') ||
    /ice.?cream|kulfi|sundae/i.test(name) ||
    /cola|pepsi|sprite|fanta|coke|campa|shake|juice|soda|nimbu|lassi|cold.?drink|soft.?drink|hell|thumsup|\bdew\b|mountain.?dew|maaza/i.test(name)
  ) {
    return 'BYPASS'
  }

  // 2. Check restaurantId for actual restaurant food dishes
  if (p.restaurantId) {
    return 'RESTAURANT'
  }

  if (
    slug === 'restaurant' ||
    slug.includes('restaurant') ||
    tags.includes('restaurant') ||
    tags.some((t: string) => t.includes('restaurant'))
  ) {
    return 'RESTAURANT'
  }

  if (
    slug === 'cafe' ||
    slug.includes('cafe') ||
    tags.includes('cafe') ||
    tags.some((t: string) => t.includes('cafe'))
  ) {
    return 'CAFE'
  }

  return 'GROCERY'
}

export function getProductLimit(p: any): number {
  const type = getProductType(p)
  if (type === 'RESTAURANT') return 20
  if (type === 'CAFE') return 10
  return 10 // GROCERY / BYPASS
}

import { checkStoreOperatingStatus } from '@/lib/restaurant-schedule'

export function isProductStoreClosed(
  p: any,
  status: { groceryMartOpen: boolean; cafeOpen?: boolean; restaurantOpen?: boolean },
  categoryStatus?: Record<string, boolean>
): boolean {
  if (!p) return !status.groceryMartOpen

  // 1. Check category level status
  const categorySlug = p.category?.slug || p.categorySlug || (typeof p.category === 'string' ? p.category : '')
  const isCatOpen = categoryStatus && categorySlug ? categoryStatus[categorySlug] !== false : true
  if (!isCatOpen) return true

  // 2. Check explicit restaurantIsOpen property if attached
  if (p.restaurantIsOpen === false || p.restaurantIsOpen === 'false') return true

  // 3. Check specific restaurant / cafe operating status if product is linked to a restaurant object
  const restObj = p.restaurant
  if (restObj && typeof restObj === 'object') {
    const opStatus = checkStoreOperatingStatus(restObj)
    if (!opStatus.isOpen) return true
  }

  const type = getProductType(p)

  // 4. For Restaurant and Cafe items: controlled by Manage Restaurant isOpen status & Category status
  if (type === 'RESTAURANT' || type === 'CAFE') {
    if (status.restaurantOpen === false || status.cafeOpen === false) return true
    return false
  }

  if (type === 'BYPASS') {
    return !status.groceryMartOpen
  }

  // 5. Grocery Mart items: controlled by main Mart toggle
  return !status.groceryMartOpen
}
export function getDeliveryPin(orderId: string): string {
  let hash = 0
  for (let i = 0; i < orderId.length; i++) {
    hash = (hash * 31 + orderId.charCodeAt(i)) % 9999999
  }
  const pin = (hash % 9000) + 1000
  return pin.toString()
}

// Distance helper moved to @/lib/distance — use getDistanceKm instead