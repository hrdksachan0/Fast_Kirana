import { revalidatePath, revalidateTag } from 'next/cache'

/**
 * On-demand cache revalidation helper for storefront pages.
 * Purges Next.js static / ISR cache specifically for the affected content
 * to minimize costly ISR writes on Vercel while keeping data fresh.
 */
export function revalidateStorefront(
  categorySlug?: string | null,
  restaurantSlug?: string | null,
  options?: { isGlobal?: boolean }
) {
  try {
    if (options?.isGlobal) {
      revalidateAll()
      return
    }

    if (categorySlug === 'restaurants' || restaurantSlug) {
      revalidateRestaurant(restaurantSlug || null)
      return
    }

    if (categorySlug) {
      revalidateCategory(categorySlug)
      return
    }

    // Default: only invalidate the homepage (not every category page + every product cache)
    // Category-specific pages are invalidated only when categorySlug is provided above
    revalidateTag('products', 'max')
    revalidateTag('banners', 'max')
    revalidatePath('/', 'page')
  } catch (err) {
    console.error('Failed to trigger targeted revalidation:', err)
  }
}

export function revalidateBanners() {
  try {
    revalidateTag('banners', 'max')
    revalidatePath('/', 'page')
    revalidatePath('/food', 'page')
    revalidatePath('/cafe', 'page')
  } catch (err) {
    console.error('Failed to revalidate banners tag:', err)
  }
}

export function revalidateCategory(categorySlug: string) {
  try {
    revalidateTag('categories', 'max')
    revalidatePath(`/category/${categorySlug}`, 'page')
  } catch (err) {
    console.error(`Failed to revalidate category ${categorySlug}:`, err)
  }
}

export function revalidateRestaurant(restaurantSlug?: string | null) {
  try {
    revalidateTag('restaurants', 'max')
    revalidatePath('/')
    revalidatePath('/food')
    revalidatePath('/cafe')
    if (restaurantSlug) {
      revalidatePath(`/food/${restaurantSlug}`)
      revalidatePath(`/restaurant/${restaurantSlug}`)
    }
  } catch (err) {
    console.error(`Failed to revalidate restaurant ${restaurantSlug}:`, err)
  }
}

export function revalidateSettings() {
  try {
    revalidateTag('settings', 'max')
  } catch (err) {
    console.error('Failed to revalidate settings tag:', err)
  }
}

let lastRevalidateAllTime = 0

export function revalidateAll() {
  // Debounce global revalidation to at most once per 5 minutes to prevent ISR write storms
  const now = Date.now()
  if (now - lastRevalidateAllTime < 300000) {
    return
  }
  lastRevalidateAllTime = now

  try {
    revalidateTag('products', 'max')
    revalidateTag('categories', 'max')
    revalidateTag('banners', 'max')
    revalidateTag('settings', 'max')

    // CRITICAL: Revalidate page ONLY, NEVER 'layout' (layout forces full-site rebuild causing 1M+ ISR writes)
    revalidatePath('/', 'page')
    revalidatePath('/cafe', 'page')
    revalidatePath('/food', 'page')
  } catch (err) {
    console.error('Failed to trigger full revalidation:', err)
  }
}

