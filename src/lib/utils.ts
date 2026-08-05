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
  if (p.restaurantId || p.restaurant || p.restaurantName) return true
  const categorySlug = (p.category?.slug || p.categorySlug || '').toLowerCase()
  const categoryName = (p.category?.name || '').toLowerCase()
  if (categorySlug === 'cafe' || categorySlug === 'restaurant' || categorySlug.includes('cafe') || categorySlug.includes('restaurant')) return true
  if (Array.isArray(p.tags) && p.tags.some((t: string) => ['cafe', 'restaurant', 'wedson', 'as-restaurant', 'food', 'shakes', 'beverage', 'beverages', 'pizza', 'burger', 'dessert', 'starters', 'main-course'].includes(t.toLowerCase()))) return true
  return false
}

export function getOptimizedImageUrl(url: string | null | undefined, width = 300): string | null {
  if (!url) return null
  if (url.includes('cloudinary.com') && url.includes('/image/upload/')) {
    return url.replace('/image/upload/', `/image/upload/f_auto,q_auto,w_${width},c_limit/`)
  }
  return url
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
  addr: { houseNo?: string; street?: string; area?: string; city?: string; pincode?: string } | null | undefined,
  includeCityAndPincode = true
): string {
  if (!addr) return ''
  const parts: string[] = []
  
  if (addr.houseNo && addr.houseNo !== '.' && addr.houseNo.toLowerCase() !== 'n/a' && addr.houseNo.toLowerCase() !== 'ghatampur') {
    parts.push(`House No ${addr.houseNo}`)
  }
  
  if (addr.street && addr.street !== '.' && addr.street.toLowerCase() !== 'n/a') {
    parts.push(addr.street)
  }
  
  if (addr.area && addr.area !== '.' && addr.area.toLowerCase() !== 'n/a' && addr.area.toLowerCase() !== 'ghatampur') {
    parts.push(addr.area)
  }
  
  if (includeCityAndPincode) {
    if (addr.city && addr.city !== '.' && addr.city.toLowerCase() !== 'n/a') {
      // Only include city if it is not already present in the street string (case-insensitive)
      const streetLower = addr.street ? addr.street.toLowerCase() : ''
      const cityLower = addr.city.toLowerCase()
      if (!streetLower.includes(cityLower)) {
        parts.push(addr.city)
      }
    }
    
    if (addr.pincode && addr.pincode !== '.' && addr.pincode.toLowerCase() !== 'n/a') {
      parts.push(addr.pincode)
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
    /cola|pepsi|sprite|fanta|coke|campa|shake|juice|soda|nimbu|lassi|cold.?drink|soft.?drink|hell|thumsup|dew|maaza/i.test(name)
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

export function isProductStoreClosed(
  p: any,
  status: { groceryMartOpen: boolean; cafeOpen: boolean; restaurantOpen: boolean },
  categoryStatus?: Record<string, boolean>
): boolean {
  if (!p) return !status.groceryMartOpen
  const categorySlug = p.category?.slug || p.categorySlug || (typeof p.category === 'string' ? p.category : '')
  const isCatOpen = categoryStatus && categorySlug ? categoryStatus[categorySlug] !== false : true
  if (!isCatOpen) return true

  const type = getProductType(p)
  if (type === 'BYPASS') return !status.groceryMartOpen && !status.cafeOpen && !status.restaurantOpen

  // Check specific restaurant isOpen status if product is linked to an individual restaurant
  const restObj = p.restaurant
  if (restObj && typeof restObj === 'object' && restObj.isOpen !== undefined && restObj.isOpen !== null) {
    if (restObj.isOpen === false || restObj.isOpen === 'false') return true
  }

  if (type === 'RESTAURANT') return !status.restaurantOpen
  if (type === 'CAFE') return !status.cafeOpen
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