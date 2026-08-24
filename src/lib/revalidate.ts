import { revalidatePath, revalidateTag } from 'next/cache'

/**
 * On-demand cache revalidation helper for storefront pages.
 * Purges Next.js static / ISR cache so updates (stock changes, new products, edits)
 * reflect immediately without requiring a manual browser refresh (F5).
 */
export function revalidateStorefront(categorySlug?: string | null, restaurantSlug?: string | null) {
  try {
    // 1. Purge Next.js data tags
    revalidateTag('products')
    revalidateTag('categories')
    revalidateTag('restaurants')
    revalidateTag('trending')
    revalidateTag('flash-deals')
    revalidateTag('best-sellers')
    revalidateTag('settings')

    // 2. Purge paths and layouts
    revalidatePath('/', 'layout')
    revalidatePath('/cafe')
    revalidatePath('/food')
    revalidatePath('/food/[slug]', 'page')
    revalidatePath('/restaurant/[slug]', 'page')
    revalidatePath('/category/[slug]', 'page')

    if (categorySlug) {
      revalidatePath(`/category/${categorySlug}`)
    }
    if (restaurantSlug) {
      revalidatePath(`/food/${restaurantSlug}`)
      revalidatePath(`/restaurant/${restaurantSlug}`)
    }
  } catch (err) {
    console.error('Failed to trigger on-demand revalidation:', err)
  }
}
