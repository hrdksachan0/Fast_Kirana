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

    if (restaurantSlug) {
      revalidateRestaurant(restaurantSlug)
      return
    }

    if (categorySlug) {
      revalidateCategory(categorySlug)
      return
    }

    // Default targeted product update
    revalidateTag('products', 'max')
    revalidatePath('/category/[slug]', 'page')
  } catch (err) {
    console.error('Failed to trigger targeted revalidation:', err)
  }
}

export function revalidateCategory(categorySlug: string) {
  try {
    revalidateTag('categories', 'max')
    revalidateTag('products', 'max')
    revalidatePath(`/category/${categorySlug}`)
    revalidatePath('/category/[slug]', 'page')
  } catch (err) {
    console.error(`Failed to revalidate category ${categorySlug}:`, err)
  }
}

export function revalidateRestaurant(restaurantSlug: string) {
  try {
    revalidateTag('restaurants', 'max')
    revalidatePath(`/food/${restaurantSlug}`)
    revalidatePath(`/restaurant/${restaurantSlug}`)
    revalidatePath('/food')
    revalidatePath('/cafe')
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

export function revalidateAll() {
  try {
    revalidateTag('products', 'max')
    revalidateTag('categories', 'max')
    revalidateTag('restaurants', 'max')
    revalidateTag('trending', 'max')
    revalidateTag('flash-deals', 'max')
    revalidateTag('best-sellers', 'max')
    revalidateTag('settings', 'max')

    revalidatePath('/', 'layout')
    revalidatePath('/cafe')
    revalidatePath('/food')
    revalidatePath('/category/[slug]', 'page')
  } catch (err) {
    console.error('Failed to trigger full revalidation:', err)
  }
}

