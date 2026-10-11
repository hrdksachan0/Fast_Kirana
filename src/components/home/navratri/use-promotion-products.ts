'use client'

import { useEffect, useState } from 'react'
import type { Product } from '@/types'
import type { CampaignConfig } from '@/lib/campaign-config'
import { loadCampaignProductDetails, missingCampaignProductIds } from './promotion-products'

export function usePromotionProducts(
  data: CampaignConfig,
  catalogue: Product[],
  storeId?: string | null,
  loading = false,
  enabled = true
) {
  const scope = storeId && storeId !== 'all' ? storeId : 'hub-209206'
  const idsKey = missingCampaignProductIds(data, catalogue).join(',')
  const key = `${scope}:${idsKey}`
  const [resolved, setResolved] = useState<{ key: string; products: Product[] }>({
    key: '',
    products: [],
  })
  useEffect(() => {
    if (loading || !enabled || !idsKey) return
    const controller = new AbortController()
    void loadCampaignProductDetails(idsKey.split(','), scope, controller.signal).then(
      (products) => {
        if (!controller.signal.aborted) setResolved({ key, products })
      }
    )
    return () => controller.abort()
  }, [scope, idsKey, key, loading, enabled])
  if (loading || !enabled) return []
  return resolved.key === key ? [...catalogue, ...resolved.products] : catalogue
}
