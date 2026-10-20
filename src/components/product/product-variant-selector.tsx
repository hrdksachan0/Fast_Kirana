'use client'

import { useState, useMemo, useEffect } from 'react'
import { Product } from '@/types'
import { ProductStockBanner } from './product-stock-banner'
import { ProductDetailActions } from './product-detail-actions'
import { Truck, ShieldCheck } from 'lucide-react'

interface ProductVariantSelectorProps {
  product: Product
}

export function ProductVariantSelector({ product }: ProductVariantSelectorProps) {
  const normalizedVariants = useMemo(() => {
    if (!product.variants) return []
    let list: any[] = []
    if (Array.isArray(product.variants)) {
      list = [...product.variants]
    } else if (typeof product.variants === 'string') {
      try {
        const parsed = JSON.parse(product.variants)
        if (Array.isArray(parsed)) list = parsed
      } catch {}
    }
    return list
      .filter((v) => v && typeof v === 'object')
      .map((v, i) => ({
        ...v,
        name: String(v.name || v.title || v.unit || `Option ${i + 1}`),
        price: Number(v.price) || Number(product.price) || 0,
        mrp: Number(v.mrp) || Number(v.price) || Number(product.mrp) || 0,
        stock: v.stock !== undefined ? Number(v.stock) : Number(product.stock ?? 0),
      }))
      .sort((a, b) => (Number(a.price) || 0) - (Number(b.price) || 0))
  }, [product.variants, product.price, product.mrp, product.stock])

  const hasVariants = normalizedVariants.length > 0
  const variantsList = normalizedVariants

  // Zepto/Blinkit behavior: Auto-select the first in-stock variant
  const initialVariant = useMemo(() => {
    if (variantsList.length === 0) return ''
    const inStock = variantsList.find((v) => (v.stock ?? 0) > 0)
    return inStock ? inStock.name : variantsList[0].name
  }, [variantsList])

  const [selectedVariantName, setSelectedVariantName] = useState<string>(initialVariant)

  // Keep selected variant in sync when variant list changes
  useEffect(() => {
    if (initialVariant && !selectedVariantName) {
      setSelectedVariantName(initialVariant)
    }
  }, [initialVariant, selectedVariantName])

  const activeVariant = useMemo(() => {
    if (!hasVariants || variantsList.length === 0) return null
    return variantsList.find((v) => v.name === selectedVariantName) || variantsList[0]
  }, [hasVariants, variantsList, selectedVariantName])

  // Resolve ID, Price, MRP, and Stock
  const resolvedVariantName = activeVariant ? activeVariant.name : null
  const resolvedId = resolvedVariantName ? `${product.id}_${resolvedVariantName}` : product.id
  const initialStock = activeVariant ? (activeVariant.stock ?? 0) : (product.stock ?? 0)
  const isVariantInStock = initialStock > 0 && product.isAvailable !== false
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
      isAvailable: isVariantInStock,
    }
  }, [product, resolvedId, resolvedVariantName, resolvedPrice, resolvedMrp, resolvedDiscount, initialStock, isVariantInStock])

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
              const isSoldOut = (v.stock ?? 0) <= 0
              return (
                <button
                  key={v.name}
                  onClick={() => setSelectedVariantName(v.name)}
                  className={`px-3.5 py-1.5 text-xs font-bold rounded-xl border transition-all duration-200 cursor-pointer flex items-center gap-1.5 ${
                    isSelected
                      ? (isSoldOut ? 'bg-zinc-800 border-zinc-700 text-zinc-300' : 'bg-primary border-primary text-white shadow-sm')
                      : isSoldOut
                      ? 'bg-zinc-100 dark:bg-zinc-900 border-zinc-300 dark:border-zinc-800 text-zinc-400 opacity-60'
                      : 'bg-muted/30 border-border/60 text-text-primary hover:border-primary/50'
                  }`}
                >
                  <span className={isSoldOut && !isSelected ? 'line-through' : ''}>{v.name}</span>
                  {isSoldOut && (
                    <span className="text-[9px] uppercase tracking-wider font-black text-rose-500 bg-rose-50 dark:bg-rose-950/40 px-1 py-0.5 rounded">
                      Sold Out
                    </span>
                  )}
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

      {/* Dynamic Add to Cart and Buy Buttons */}
      <div className="pt-2">
        <ProductDetailActions product={resolvedProductForActions} />
      </div>

      {/* Dynamic Stock Alert Warning Banner */}
      <ProductStockBanner
        productId={resolvedId}
        initialStock={initialStock}
        categorySlug={product.category?.slug}
        tags={product.tags}
      />

      {/* Delivery banner CTA inside product details */}
      <div className="flex items-center gap-3 border border-border/60 bg-muted/30 p-3 rounded-xl mt-1">
        <Truck className="h-5 w-5 text-accent animate-pulse-gentle" />
        <span className="text-xs font-bold text-text-primary">
          Delivered to your door with <span className="text-accent">Fast Delivery</span>
        </span>
      </div>

      {/* Dark Store verification banner */}
      <div className="flex items-start gap-3 border border-accent/25 bg-accent/5 p-2.5 min-[375px]:p-3.5 rounded-xl shadow-xs">
        <ShieldCheck className="h-5 w-5 text-accent shrink-0 mt-0.5" />
        <div className="text-xs font-bold text-text-primary">
          <span className="text-accent">FastMinute DarkStore Fresh Verified</span>
          <p className="text-[10px] text-text-secondary mt-1 font-semibold leading-relaxed">
            Sourced directly, stored in a hygiene-controlled environment, and packed under strict guidelines. Freshness guaranteed with zero retail shelf dust.
          </p>
        </div>
      </div>
    </div>
  )
}
