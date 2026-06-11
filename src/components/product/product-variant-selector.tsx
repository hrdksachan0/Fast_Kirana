'use client'

import { useState, useMemo } from 'react'
import { Product } from '@/types'
import { ProductStockBanner } from './product-stock-banner'
import { ProductDetailActions } from './product-detail-actions'
import { Truck, ShieldCheck } from 'lucide-react'

interface ProductVariantSelectorProps {
  product: Product
}

export function ProductVariantSelector({ product }: ProductVariantSelectorProps) {
  const hasVariants = product.variants && Array.isArray(product.variants) && product.variants.length > 0
  const variantsList = hasVariants ? (product.variants as any[]) : []

  // Track selected variant name
  const [selectedVariantName, setSelectedVariantName] = useState<string>(
    hasVariants ? variantsList[0].name : ''
  )

  const activeVariant = useMemo(() => {
    if (!hasVariants) return null
    return variantsList.find((v) => v.name === selectedVariantName) || variantsList[0]
  }, [hasVariants, variantsList, selectedVariantName])

  // Resolve ID, Price, MRP, and Stock
  const resolvedVariantName = activeVariant ? activeVariant.name : null
  const resolvedId = resolvedVariantName ? `${product.id}_${resolvedVariantName}` : product.id
  const initialStock = activeVariant ? activeVariant.stock : product.stock
  const resolvedPrice = activeVariant ? activeVariant.price : product.price
  const resolvedMrp = activeVariant ? activeVariant.mrp : product.mrp
  const resolvedDiscount = resolvedMrp > resolvedPrice
    ? Math.max(0, Math.round(((resolvedMrp - resolvedPrice) / resolvedMrp) * 100))
    : 0

  // Construct the updated product object to pass to action buttons
  const resolvedProductForActions = useMemo(() => {
    return {
      ...product,
      id: resolvedId,
      name: resolvedVariantName ? `${product.name} (${resolvedVariantName})` : product.name,
      price: resolvedPrice,
      mrp: resolvedMrp,
      discount: resolvedDiscount,
      stock: initialStock,
    }
  }, [product, resolvedId, resolvedVariantName, resolvedPrice, resolvedMrp, resolvedDiscount, initialStock])

  return (
    <div className="space-y-4">
      {/* Variant Selector Pills */}
      {hasVariants && (
        <div className="space-y-2">
          <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
            Select Size / Option
          </label>
          <div className="flex flex-wrap gap-2">
            {variantsList.map((v) => {
              const isSelected = v.name === selectedVariantName
              return (
                <button
                  key={v.name}
                  onClick={() => setSelectedVariantName(v.name)}
                  className={`px-4 py-2 text-xs font-bold rounded-xl border transition-all duration-200 cursor-pointer ${
                    isSelected
                      ? 'bg-primary border-primary text-white shadow-sm'
                      : 'bg-muted/30 border-border/60 text-text-primary hover:border-primary/50'
                  }`}
                >
                  {v.name}
                </button>
              )
            })}
          </div>
        </div>
      )}

      {/* Dynamic Price Display */}
      <div className="flex items-baseline gap-3 pt-1">
        <span className="text-3xl font-black text-text-primary">
          ₹{resolvedPrice}
        </span>
        {resolvedMrp > resolvedPrice && (
          <span className="text-lg text-text-muted line-through font-bold">
            ₹{resolvedMrp}
          </span>
        )}
        {resolvedDiscount > 0 && (
          <span className="text-xs font-extrabold text-accent bg-accent/10 px-2 py-0.5 rounded-lg">
            {resolvedDiscount}% OFF
          </span>
        )}
      </div>

      {/* Delivery banner CTA inside product details */}
      <div className="flex items-center gap-3 border border-border/60 bg-muted/30 p-3 rounded-xl">
        <Truck className="h-5 w-5 text-accent animate-pulse-gentle" />
        <span className="text-xs font-bold text-text-primary">
          Delivered to your door with <span className="text-accent">Fast Delivery</span>
        </span>
      </div>

      {/* Dark Store verification banner */}
      <div className="flex items-start gap-3 border border-accent/20 bg-accent/5 p-2.5 min-[375px]:p-3.5 rounded-xl shadow-[0_0_12px_rgba(0,177,64,0.03)] border-l-4 border-l-accent">
        <ShieldCheck className="h-5 w-5 text-accent shrink-0 mt-0.5" />
        <div className="text-xs font-bold text-text-primary">
          <span className="text-accent">FastKirana DarkStore Fresh Verified</span>
          <p className="text-[10px] text-text-secondary mt-1 font-semibold leading-relaxed">
            Sourced directly, stored in a hygiene-controlled environment, and packed under strict guidelines. Freshness guaranteed with zero retail shelf dust.
          </p>
        </div>
      </div>

      {/* Dynamic Stock Alert Warning Banner */}
      <ProductStockBanner
        productId={resolvedId}
        initialStock={initialStock}
        categorySlug={product.category?.slug}
        tags={product.tags}
      />

      {/* Dynamic Add to Cart and Buy Buttons */}
      <div className="pt-1">
        <ProductDetailActions product={resolvedProductForActions} />
      </div>
    </div>
  )
}
