import { revalidatePath, revalidateTag } from 'next/cache'

/**
 * On-demand cache revalidation helper for storefront pages.
 * Purges Next.js static / ISR cache so updates (stock changes, new products, edits)
 * reflect immediately without requiring a manual browser refresh (F5).
 */
export function revalidateStorefront(categorySlug?: string | null, restaurantSlug?: string | null) {
  try {
    // 1. Purge all product-level ISR caches (covers stock/price/availability
    //    changes surfaced in home, category, trending, search, etc.)
    revalidateTag('products', 'max')
    
    // Purge cached restaurant list (home page, etc.)
    revalidateTag('restaurants', 'max')

    // Purge cached store settings
    revalidateTag('settings', 'max')

    // 2. Revalidate landing page (home)
    revalidatePath('/')

    // 3. Revalidate Cafe page
    revalidatePath('/cafe')
    revalidatePath('/food')

    // 4. Revalidate dynamic category page if slug provided
    if (categorySlug) {
      revalidatePath(`/category/${categorySlug}`)
    }

    // 5. Revalidate restaurant detail page if slug provided
    if (restaurantSlug) {
      revalidatePath(`/restaurant/${restaurantSlug}`)
      revalidatePath(`/food/${restaurantSlug}`)
    }
  } catch (err) {
    console.error('Failed to trigger on-demand revalidation:', err)
  }
}
