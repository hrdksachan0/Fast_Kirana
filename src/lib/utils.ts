import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatPrice(price: number): string {
  return `₹${price.toLocaleString('en-IN')}`
}

export function format12h(timeStr: string | null | undefined): string {
  if (!timeStr) return ''
  const parts = timeStr.split(':')
  if (parts.length < 2) return timeStr
  const hour = parseInt(parts[0])
  const minute = parts[1]
  const ampm = hour >= 12 ? 'PM' : 'AM'
  const displayHour = hour % 12 === 0 ? 12 : hour % 12
  return `${displayHour}:${minute} ${ampm}`
}

export function isCafeProduct(p: any): boolean {
  if (!p) return false
  const categorySlug = p.category?.slug || p.categorySlug
  if (categorySlug === 'cafe' || categorySlug === 'restaurant' || categorySlug === 'ice-cream' || categorySlug === 'beverages') return true
  if (p.tags?.includes('cafe') || p.tags?.includes('restaurant') || p.tags?.includes('ice-cream') || p.tags?.includes('beverages')) return true
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
  const slug = p.category?.slug || p.categorySlug || ''
  const tags = p.tags || []
  if (slug === 'restaurant' || tags.includes('restaurant')) return 'RESTAURANT'
  if (slug === 'ice-cream' || slug === 'beverages' || tags.includes('ice-cream') || tags.includes('beverages')) return 'BYPASS'
  if (slug === 'cafe' || tags.includes('cafe')) return 'CAFE'
  return 'GROCERY'
}

export function getProductLimit(p: any): number {
  const type = getProductType(p)
  if (type === 'RESTAURANT') return 20
  if (type === 'CAFE') return 10
  return 5 // GROCERY / BYPASS
}

export function isProductStoreClosed(
  p: any,
  status: { groceryMartOpen: boolean; cafeOpen: boolean; restaurantOpen: boolean }
): boolean {
  const type = getProductType(p)
  if (type === 'RESTAURANT') return !status.restaurantOpen
  if (type === 'CAFE') return !status.cafeOpen
  if (type === 'BYPASS') return !status.groceryMartOpen && !status.cafeOpen // Open if either is open
  return !status.groceryMartOpen
}



