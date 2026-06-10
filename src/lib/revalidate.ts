import { revalidatePath } from 'next/cache'

/**
 * On-demand cache revalidation helper for storefront pages.
 * Purges Next.js static / ISR cache so updates (stock changes, new products, edits)
 * reflect immediately without requiring a manual browser refresh (F5).
 */
export function revalidateStorefront(categorySlug?: string | null) {
  try {
    // 1. Revalidate landing page (home)
    revalidatePath('/')
    
    // 2. Revalidate Cafe page
    revalidatePath('/cafe')
    
    // 3. Revalidate dynamic category page if slug provided
    if (categorySlug) {
      revalidatePath(`/category/${categorySlug}`)
    }
  } catch (err) {
    console.error('Failed to trigger on-demand revalidation:', err)
  }
}
