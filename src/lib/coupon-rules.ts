/**
 * Coupon & Promotional Rules Engine
 * Evaluates whether products/dishes qualify for promotional offers (BOGO, Category discounts, etc.)
 */

export interface CouponRuleTarget {
  id?: string
  code?: string
  discountType?: string
  bogoType?: string | null
  badgeText?: string | null
  menuSection?: string | null
  categoryId?: string | null
  restaurantId?: string | null
  bogoDishId?: string | null
  isActive?: boolean
  expiresAt?: Date | string | null
}

/**
 * Checks whether a single product or dish matches a coupon's restriction rules.
 */
export function isProductEligibleForCoupon(product: any, coupon: CouponRuleTarget): boolean {
  if (!product || !coupon) return false
  if (coupon.isActive === false) return false

  // Check expiration if present
  if (coupon.expiresAt) {
    const exp = new Date(coupon.expiresAt)
    if (!isNaN(exp.getTime()) && exp < new Date()) {
      return false
    }
  }

  // Check restaurant match
  if (coupon.restaurantId) {
    const pRestId = product.restaurantId || product.restaurant?.id || (product as any).restaurant_id
    if (pRestId && pRestId !== coupon.restaurantId) {
      return false
    }
  }

  // 1. Specific Dish ID restriction
  if (coupon.bogoDishId) {
    const pId = String(product.id || product.productId || '').split('_')[0]
    return pId === coupon.bogoDishId
  }

  // 2. Specific Category ID restriction
  if (coupon.categoryId) {
    const pCatId = product.categoryId || product.category?.id
    if (pCatId !== coupon.categoryId) {
      return false
    }
  }

  // 3. Specific Menu Section(s) restriction (e.g. "pizza", "pasta", "burger,sandwich")
  if (coupon.menuSection && coupon.menuSection.trim()) {
    const secFilters = coupon.menuSection
      .split(',')
      .map((s) => s.trim().toLowerCase().replace(/[^a-z0-9]/g, ''))
      .filter(Boolean)

    if (secFilters.length > 0) {
      const pTags = (product.tags || []).map((t: string) => String(t).toLowerCase().replace(/[^a-z0-9]/g, ''))
      const pSec = String(product.menuSection || product.sectionId || product.sectionTitle || '').toLowerCase().replace(/[^a-z0-9]/g, '')
      const pCatSlug = String(product.category?.slug || '').toLowerCase().replace(/[^a-z0-9]/g, '')
      const pCatName = String(product.category?.name || '').toLowerCase().replace(/[^a-z0-9]/g, '')
      const pName = String(product.name || '').toLowerCase().replace(/[^a-z0-9]/g, '')
      const pSlug = String(product.slug || '').toLowerCase().replace(/[^a-z0-9]/g, '')

      const matches = secFilters.some((filter) => {
        // Direct tag or explicit menu section match
        const directMatch =
          pTags.some((t: string) => t.includes(filter) || filter.includes(t)) ||
          pSec.includes(filter) ||
          pCatSlug.includes(filter) ||
          pCatName.includes(filter)

        if (directMatch) return true

        // Fallback to name/slug match ONLY IF there is no conflicting section tag
        const knownSections = ['burger', 'sandwich', 'pasta', 'maggie', 'maggi', 'calzone', 'garlic', 'beverage', 'drink', 'dessert', 'icecream', 'biryani', 'pizza', 'shake']
        const otherSections = knownSections.filter((s) => !filter.includes(s) && !s.includes(filter))
        const hasConflictingTag = pTags.some((t: string) => otherSections.some((s) => t.includes(s))) ||
          otherSections.some((s) => pSec.includes(s))

        if (hasConflictingTag) return false

        return pName.includes(filter) || pSlug.includes(filter)
      })

      if (!matches) {
        return false
      }
    }
  }

  // If no restrictions or all restrictions matched
  return true
}

/**
 * Resolves the appropriate BOGO badge text for a product given a list of active coupons.
 * Returns null if the product does NOT qualify for any active promotional campaign.
 */
export function resolveProductBogoBadge(product: any, coupons: CouponRuleTarget[]): string | null {
  if (!product) return null
  if (product.bogoBadge) return product.bogoBadge

  // Explicit product-level tag override (e.g. product marked with 'bogo')
  const pTags = (product.tags || []).map((t: string) => String(t).toLowerCase())
  const hasDirectBogoTag = pTags.includes('bogo') || pTags.some((t: string) => t.includes('bogo'))
  if (hasDirectBogoTag) {
    return 'BOGO'
  }

  if (!coupons || !Array.isArray(coupons) || coupons.length === 0) {
    return null
  }

  for (const coupon of coupons) {
    if (coupon.discountType !== 'BOGO' && !coupon.badgeText) continue

    if (isProductEligibleForCoupon(product, coupon)) {
      if (coupon.badgeText && coupon.badgeText.trim()) {
        const upBadge = coupon.badgeText.trim().toUpperCase()
        if (upBadge.includes('CHEAPEST') || upBadge.includes('BUY 2')) {
          return 'BUY 2 GET 1'
        }
        if (upBadge.includes('BUY 1') || upBadge.includes('GET 1') || upBadge.includes('BUY LARGE')) {
          return 'BUY 1 GET 1'
        }
        return coupon.badgeText.trim()
      }

      if (coupon.bogoType === 'CHEAPEST_FREE') {
        return 'BUY 2 GET 1'
      }
      if (coupon.bogoType === 'BUY_LARGE_GET_SMALL' || coupon.bogoType === 'SAME_ITEM') {
        return 'BUY 1 GET 1'
      }
      return 'BOGO DEAL'
    }
  }

  return null
}
