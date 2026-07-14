import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatPrice(price: number): string {
  return `₹${price.toLocaleString('en-IN')}`
}

export function isCafeProduct(p: any): boolean {
  if (!p) return false
  const categorySlug = p.category?.slug || p.categorySlug
  if (categorySlug === 'cafe' || categorySlug === 'restaurant') return true
  if (p.tags?.includes('cafe') || p.tags?.includes('restaurant')) return true
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

export function sortProductsByStock<T extends { stock?: number | null }>(products: T[]): T[] {
  return [...products].sort((a, b) => {
    const aInStock = (a.stock ?? 0) > 0
    const bInStock = (b.stock ?? 0) > 0
    if (aInStock && !bInStock) return -1
    if (!aInStock && bInStock) return 1
    return 0
  })
}



