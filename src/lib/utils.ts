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
  if (p.category?.slug === 'cafe') return true
  if (p.tags?.includes('cafe')) return true
  return false
}

