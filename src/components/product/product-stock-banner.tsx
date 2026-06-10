'use client'

import { useLiveStock } from '@/components/providers/live-stock-provider'

interface ProductStockBannerProps {
  productId: string
  initialStock: number
  categorySlug?: string
  tags?: string[]
}

export function ProductStockBanner({
  productId,
  initialStock,
  categorySlug,
  tags,
}: ProductStockBannerProps) {
  const liveState = useLiveStock(productId)
  const resolvedStock = liveState !== null ? liveState.stock : initialStock

  const isCafe = categorySlug === 'cafe' || tags?.includes('cafe')

  if (isCafe) return null
  if (resolvedStock <= 0 || resolvedStock >= 15) return null

  return (
    <div className="flex items-center gap-2 border border-rose-500/20 bg-rose-500/5 p-3 rounded-xl text-xs font-black text-rose-500 animate-pulse-gentle">
      ⚠️ Only {resolvedStock} units left in stock! Order soon.
    </div>
  )
}
