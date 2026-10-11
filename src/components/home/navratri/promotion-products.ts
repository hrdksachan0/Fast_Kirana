import { apiUrl } from '@/lib/api-url'
import type { Product } from '@/types'
import type { CampaignConfig } from '@/lib/campaign-config'

export function missingCampaignProductIds(data: CampaignConfig, catalogue: Product[]): string[] {
  const present = new Set(catalogue.map((product) => product.id))
  const rotatingIds = data.products.flatMap((slot) =>
    slot.productId && !present.has(slot.productId) ? [slot.productId] : []
  )
  const tabProductIds = data.tabs.flatMap((tab: any) =>
    (tab.productIds || []).filter((id: string) => id && !present.has(id))
  )
  return [...new Set([...rotatingIds, ...tabProductIds])]
}

/** Resolve identities outside the bounded home feed using the same scoped detail API. */
export async function loadCampaignProductDetails(
  ids: string[],
  storeId: string,
  signal: AbortSignal,
  request: typeof fetch = fetch
): Promise<Product[]> {
  const results = await Promise.all(
    ids.map(async (id) => {
      try {
        const response = await request(
          `${apiUrl('/api/products')}/api/products/${encodeURIComponent(id)}?storeId=${encodeURIComponent(storeId)}`,
          { signal, cache: 'no-store' }
        )
        if (!response.ok) return null
        const product = (await response.json()) as Product
        if (
          product.id !== id ||
          typeof product.name !== 'string' ||
        product.isAvailable !== true ||
          product.restaurantId ||
        (product.imageUrl != null && typeof product.imageUrl !== 'string') ||
          !Number.isFinite(product.stock) ||
          product.stock <= 0 ||
          !Number.isFinite(product.price) ||
          product.price < 0 ||
          !Number.isFinite(product.mrp) ||
          product.mrp < 0
        )
          return null
        return product
      } catch {
        return null
      }
    })
  )
  return signal.aborted ? [] : results.filter((product): product is Product => product !== null)
}
