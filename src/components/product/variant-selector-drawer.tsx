'use client'

import { useUIStore } from '@/stores/ui-store'
import { useCart } from '@/hooks/use-cart'
import { X, Plus, Minus, ShieldCheck, ArrowRight } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { useMemo, useEffect } from 'react'
import { cn, formatPrice } from '@/lib/utils'
import { ProductImage } from '@/components/product/product-image'
import { useLiveStock } from '@/components/providers/live-stock-provider'
import { Product } from '@/types'

interface VariantRowProps {
  variant: any
  product: Product
  cafeOpen: boolean
  groceryMartOpen: boolean
}

function VariantRow({ variant, product, cafeOpen, groceryMartOpen }: VariantRowProps) {
  const { getItemQuantity, addItem, updateQuantity } = useCart()
  const resolvedId = `${product.id}_${variant.name}`
  const quantity = getItemQuantity(resolvedId)

  // Use live stock provider for real-time prices & stock
  const liveState = useLiveStock(resolvedId)
  const resolvedStock = liveState !== null ? liveState.stock : variant.stock
  const resolvedPrice = liveState !== null ? liveState.price : variant.price
  const resolvedMrp = liveState !== null ? liveState.mrp : variant.mrp
  const resolvedIsAvailable = liveState !== null ? liveState.isAvailable : (product.isAvailable ?? true)

  const discount = resolvedMrp > resolvedPrice
    ? Math.max(0, Math.round(((resolvedMrp - resolvedPrice) / resolvedMrp) * 100))
    : 0

  const categoryStatus = useUIStore((s) => s.categoryStatus) || {}
  const isCafe = product.category?.slug === 'cafe' || product.tags?.includes('cafe')
  const categorySlug = product.category?.slug || ''
  const isCategoryOpen = categoryStatus[categorySlug] !== false
  const isStoreClosed = isCafe 
    ? (!cafeOpen || !isCategoryOpen) 
    : (!groceryMartOpen || !isCategoryOpen)

  const cartProduct = useMemo(() => ({
    id: resolvedId,
    name: `${product.name} (${variant.name})`,
    slug: product.slug,
    imageUrl: product.imageUrl,
    mrp: resolvedMrp,
    price: resolvedPrice,
    discount: discount,
    unit: product.unit,
    stock: resolvedStock,
    isAvailable: resolvedIsAvailable,
    category: product.category,
  }), [product, variant, resolvedId, resolvedMrp, resolvedPrice, discount, resolvedStock, resolvedIsAvailable])

  const handleAdd = () => {
    addItem(cartProduct)
  }

  const handleIncrement = () => {
    updateQuantity(resolvedId, cartProduct.name, quantity + 1)
  }

  const handleDecrement = () => {
    updateQuantity(resolvedId, cartProduct.name, quantity - 1)
  }

  const isSelected = quantity > 0

  return (
    <div className={cn(
      "flex items-center justify-between p-3 sm:p-4 rounded-xl transition-all duration-300 border-2",
      isSelected 
        ? "border-emerald-500 bg-emerald-50/30 dark:bg-emerald-950/10 shadow-xs" 
        : "border-border/60 bg-card/60 dark:bg-zinc-900/40 hover:border-primary/20"
    )}>
      <div className="flex-1 min-w-0 pr-3 text-left">
        <span className="text-xs sm:text-sm font-black text-text-primary truncate block">
          {variant.name}
        </span>
        <div className="flex items-baseline gap-1.5 mt-0.5 flex-wrap">
          <span className="text-xs sm:text-sm font-black text-text-primary">
            ₹{resolvedPrice}
          </span>
          {resolvedMrp > resolvedPrice && (
            <>
              <span className="text-[10px] text-text-muted line-through font-bold">
                ₹{resolvedMrp}
              </span>
              <span className="bg-[#fff1ed] dark:bg-red-500/10 text-orange-600 dark:text-orange-400 text-[8px] font-black px-1 py-0.5 rounded">
                {discount}% OFF
              </span>
            </>
          )}
        </div>
        {resolvedStock > 0 && resolvedStock <= (product.minStock ?? 10) && (
          <span className="text-[9px] font-bold text-red-500 dark:text-red-400 mt-1 block">
            Only {resolvedStock} left in stock!
          </span>
        )}
      </div>

      {/* Cart Actions */}
      <div className="relative h-8 w-16 sm:w-20 shrink-0">
        {quantity === 0 ? (
          <button
            onClick={handleAdd}
            disabled={resolvedStock <= 0 || isStoreClosed}
            className="w-full h-full border border-green-600 bg-white dark:bg-zinc-900 text-[#2e7d32] dark:text-emerald-400 text-[10px] sm:text-xs font-black rounded-lg hover:bg-[#2e7d32] hover:text-white transition-all duration-200 flex items-center justify-center gap-0.5 cursor-pointer shadow-xs disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {resolvedStock <= 0 ? 'Out' : isStoreClosed ? 'Closed' : '+ ADD'}
          </button>
        ) : (
          <div className="flex h-full w-full items-center justify-between rounded-lg bg-gradient-to-r from-[#2e7d32] to-[#1b5e20] text-white font-bold overflow-hidden shadow-xs">
            <button
              onClick={handleDecrement}
              className="flex-1 flex h-full items-center justify-center hover:bg-black/10 active:scale-90 transition-all cursor-pointer"
              aria-label="Decrease quantity"
            >
              <Minus className="h-3 w-3 stroke-[3]" />
            </button>
            <span className="w-5 shrink-0 flex items-center justify-center text-[10px] sm:text-xs font-black select-none">
              {quantity}
            </span>
            <button
              onClick={handleIncrement}
              disabled={quantity >= resolvedStock || quantity >= (isCafe ? 10 : 5) || isStoreClosed}
              className="flex-1 flex h-full items-center justify-center hover:bg-black/10 active:scale-90 transition-all disabled:opacity-50 cursor-pointer"
              aria-label="Increase quantity"
            >
              <Plus className="h-3 w-3 stroke-[3]" />
            </button>
          </div>
        )}
      </div>
    </div>
  )
}

export function VariantSelectorDrawer() {
  const activeProduct = useUIStore((s) => s.activeVariantProduct)
  const setActiveProduct = useUIStore((s) => s.setActiveVariantProduct)
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)

  const isOpen = activeProduct !== null

  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => {
      document.body.style.overflow = ''
    }
  }, [isOpen])

  const variantsList = useMemo(() => {
    if (!activeProduct || !activeProduct.variants || !Array.isArray(activeProduct.variants)) return []
    return activeProduct.variants
  }, [activeProduct])

  return (
    <AnimatePresence>
      {isOpen && activeProduct && (
        <div className="fixed inset-0 z-50 flex items-end justify-center select-none">
          {/* Dark Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="fixed inset-0 bg-black/60 backdrop-blur-xs cursor-pointer"
            onClick={() => setActiveProduct(null)}
          />

          {/* Drawer (Slides up from the bottom) */}
          <motion.div
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 25, stiffness: 220 }}
            className="gpu-accelerated relative w-full max-w-md bg-background border-t border-border rounded-t-3xl shadow-2xl flex flex-col max-h-[80vh] overflow-hidden"
          >
            {/* Header Handle */}
            <div className="w-12 h-1.5 bg-muted/70 rounded-full mx-auto my-3 shrink-0" />

            {/* Scrollable Content Container */}
            <div className="px-5 pb-4 flex-1 overflow-y-auto space-y-4">
              {/* Product Info Block */}
              <div className="flex gap-4 border-b border-border/40 pb-4">
                <div className="relative h-16 w-16 sm:h-20 sm:w-20 rounded-2xl border border-border/40 bg-muted/10 p-1 flex-shrink-0 flex items-center justify-center overflow-hidden">
                  <ProductImage
                    src={activeProduct.imageUrl}
                    alt={activeProduct.name}
                    categorySlug={activeProduct.category?.slug}
                    className="h-full w-full object-contain"
                  />
                </div>
                <div className="flex-1 min-w-0 text-left flex flex-col justify-center">
                  <h3 className="text-sm sm:text-base font-extrabold text-text-primary leading-tight">
                    {activeProduct.name}
                  </h3>
                  <span className="text-[10px] text-text-muted font-bold block mt-0.5">
                    {activeProduct.unit}
                  </span>
                  {activeProduct.description && (
                    <p className="text-[10px] text-text-secondary line-clamp-2 mt-1 leading-normal font-semibold">
                      {activeProduct.description}
                    </p>
                  )}
                </div>
                <button
                  onClick={() => setActiveProduct(null)}
                  className="p-1 rounded-full bg-muted/60 text-text-secondary hover:text-text-primary hover:bg-muted self-start"
                >
                  <X className="h-5 w-5" />
                </button>
              </div>

              {/* Title */}
              <div className="text-[10px] font-black uppercase tracking-wider text-text-muted text-left">
                Select Option / Quantity
              </div>

              {/* Variants List */}
              <div className="space-y-2.5 pb-2">
                {variantsList.map((v) => (
                  <VariantRow
                    key={v.name}
                    variant={v}
                    product={activeProduct}
                    cafeOpen={cafeOpen}
                    groceryMartOpen={groceryMartOpen}
                  />
                ))}
              </div>

              {/* Trust Badge */}
              <div className="flex items-start gap-3 border border-accent/15 bg-gradient-to-br from-accent/5 to-emerald-500/5 p-3.5 rounded-xl border-l-4 border-l-emerald-500 shadow-2xs">
                <ShieldCheck className="h-5 w-5 text-emerald-500 shrink-0 mt-0.5" />
                <div className="text-[11px] font-bold text-text-primary text-left">
                  <span className="text-emerald-600 dark:text-emerald-400 block font-black">FastKirana DarkStore Guaranteed</span>
                  <p className="text-[9.5px] text-text-secondary mt-1 font-semibold leading-relaxed">
                    Packed fresh, hygiene verified, and delivered directly to your doorstep.
                  </p>
                </div>
              </div>
            </div>

            {/* Sticky Action Footer */}
            <div className="p-5 bg-background border-t border-border/40 shrink-0">
              <button
                onClick={() => setActiveProduct(null)}
                className="w-full py-3.5 px-4 rounded-full bg-gradient-to-r from-emerald-600 to-green-500 hover:from-emerald-700 hover:to-green-600 text-white font-black text-xs sm:text-sm tracking-wider uppercase shadow-md hover:shadow-lg active:scale-[0.98] transition-all duration-200 flex items-center justify-center gap-2 cursor-pointer"
              >
                <span>Continue Shopping</span>
                <ArrowRight className="h-4 w-4 stroke-[3]" />
              </button>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  )
}
