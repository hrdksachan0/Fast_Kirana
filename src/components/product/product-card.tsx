'use client'

import { useState, useCallback, useMemo, useRef, useEffect } from 'react'
import Link from 'next/link'
import { Plus, Minus, Check, Zap } from 'lucide-react'
import { useCart } from '@/hooks/use-cart'
import { Button } from '@/components/ui/button'
import { Product } from '@/types'
import { useUIStore } from '@/stores/ui-store'
import { ProductImage } from '@/components/product/product-image'
import { motion, AnimatePresence } from 'framer-motion'
import { usePushNotification } from '@/hooks/use-push-notification'
import { toast } from 'sonner'
import { triggerHaptic } from '@/lib/haptic'

interface ProductCardProps {
  product: Product
}

import { isCafeProduct, cn } from '@/lib/utils'
import { useLiveStock } from '@/components/providers/live-stock-provider'

export function ProductCard({ product }: ProductCardProps) {
  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const setActiveVariantProduct = useUIStore((s) => s.setActiveVariantProduct)
  
  const hasVariants = product.variants && Array.isArray(product.variants) && product.variants.length > 0
  const variantsList = hasVariants ? (product.variants as any[]) : []
  
  // Calculate starting price for variant display
  const startingPrice = useMemo(() => {
    if (!hasVariants) return product.price
    return Math.min(...variantsList.map((v) => v.price))
  }, [hasVariants, variantsList, product.price])

  const startingMrp = useMemo(() => {
    if (!hasVariants) return product.mrp
    const startVar = variantsList.find(v => v.price === startingPrice)
    return startVar ? startVar.mrp : product.mrp
  }, [hasVariants, variantsList, startingPrice, product.mrp])

  const liveState = useLiveStock(product.id)

  const resolvedPrice = useMemo(() => {
    if (liveState !== null) return liveState.price
    return startingPrice
  }, [liveState, startingPrice])

  const resolvedMrp = useMemo(() => {
    if (liveState !== null) return liveState.mrp
    return startingMrp
  }, [liveState, startingMrp])

  // Cart operations
  const { items, getItemQuantity, addItem, updateQuantity } = useCart()

  // Calculate total quantity of all variants of this product in the cart
  const totalQuantity = useMemo(() => {
    if (!hasVariants) return getItemQuantity(product.id)
    return items
      .filter((item) => item.product.id === product.id || item.product.id.startsWith(`${product.id}_`))
      .reduce((sum, item) => sum + item.quantity, 0)
  }, [items, hasVariants, product.id, getItemQuantity])

  const quantity = totalQuantity
  const [showAdded, setShowAdded] = useState(false)
  const imageRef = useRef<HTMLDivElement>(null)

  const { subscribe } = usePushNotification()
  const [isNotifySubscribed, setIsNotifySubscribed] = useState(false)

  useEffect(() => {
    if (typeof window !== 'undefined') {
      setIsNotifySubscribed(localStorage.getItem(`notify-stock-${product.id}`) === 'true')
    }
  }, [product.id])

  const handleNotifyMe = useCallback((e?: React.MouseEvent) => {
    if (e) {
      e.preventDefault()
      e.stopPropagation()
    }
    
    if (isNotifySubscribed) {
      toast.success(`You are already subscribed to stock alerts for ${product.name}.`)
      return
    }

    subscribe(() => {
      localStorage.setItem(`notify-stock-${product.id}`, 'true')
      setIsNotifySubscribed(true)
      toast.success(`🔔 Alert saved! We'll notify you when ${product.name} is back in stock.`, {
        id: `notify-stock-alert-${product.id}`,
      })
    })
  }, [isNotifySubscribed, product.id, product.name, subscribe])

  const isCafe = isCafeProduct(product)
  const isStoreClosed = isCafe ? !cafeOpen : !groceryMartOpen

  // Map of category slug to emoji representation
  const emojiMap: Record<string, string> = {
    'fruits-vegetables': '🥬',
    'dairy-breakfast': '🥛',
    'snacks-munchies': '🍿',
    'beverages': '🥤',
    'personal-care': '🧴',
    'household': '🏠',
    'bakery-biscuits': '🍞',
    'atta-rice-dal': '🌾',
  }

  const categorySlug = product.category?.slug || ''
  const categoryEmoji = emojiMap[categorySlug] || '🛒'

  // Total stock across all variants
  const totalStock = useMemo(() => {
    if (!hasVariants) return product.stock
    return variantsList.reduce((sum, v) => sum + (v.stock || 0), 0)
  }, [hasVariants, variantsList, product.stock])

  const resolvedStock = useMemo(() => {
    if (liveState !== null) return liveState.stock
    return totalStock
  }, [liveState, totalStock])

  const resolvedIsAvailable = useMemo(() => {
    if (liveState !== null) return liveState.isAvailable
    return product.isAvailable
  }, [liveState, product.isAvailable])

  // Calculate discount dynamically if price/mrp changed
  const resolvedDiscount = useMemo(() => {
    if (resolvedMrp <= resolvedPrice) return 0
    return Math.max(0, Math.round(((resolvedMrp - resolvedPrice) / resolvedMrp) * 100))
  }, [resolvedMrp, resolvedPrice])

  const handleAdd = useCallback((e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    triggerHaptic('light')
    
    if (hasVariants) {
      setActiveVariantProduct(product)
    } else {
      addItem({
        id: product.id,
        name: product.name,
        slug: product.slug,
        imageUrl: product.imageUrl,
        mrp: resolvedMrp,
        price: resolvedPrice,
        discount: resolvedDiscount,
        unit: product.unit,
        stock: resolvedStock,
        isAvailable: resolvedIsAvailable,
        category: product.category,
      })
      setShowAdded(true)
      setTimeout(() => setShowAdded(false), 600)
    }
  }, [hasVariants, product, resolvedMrp, resolvedPrice, resolvedDiscount, resolvedStock, resolvedIsAvailable, addItem, setActiveVariantProduct])

  const handleIncrement = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    triggerHaptic('light')
    if (hasVariants) {
      setActiveVariantProduct(product)
    } else {
      updateQuantity(product.id, product.name, quantity + 1)
    }
  }

  const handleDecrement = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    triggerHaptic('medium')
    if (hasVariants) {
      setActiveVariantProduct(product)
    } else {
      updateQuantity(product.id, product.name, quantity - 1)
    }
  }

  const savings = resolvedMrp - resolvedPrice

  const isLowStock = product.category?.slug !== 'cafe' && !product.tags?.includes('cafe') && resolvedStock > 0 && resolvedStock <= (product.minStock ?? 10)

  return (
    <motion.div
      whileHover={{ y: -6, scale: 1.015, transition: { type: 'spring', stiffness: 350, damping: 18 } }}
      whileTap={{ scale: 0.97 }}
      className="group relative flex flex-col overflow-hidden rounded-xl border border-border/60 dark:border-zinc-800/60 bg-card p-1.5 min-[375px]:p-2 sm:p-3 shadow-card transition-all duration-300 md:hover:shadow-[0_8px_30px_rgba(226,10,34,0.12),0_2px_8px_rgba(0,0,0,0.06)] md:dark:hover:shadow-[0_8px_30px_rgba(226,10,34,0.2),0_2px_8px_rgba(0,0,0,0.3)] md:hover:border-primary/25 cursor-pointer h-[210px] min-[375px]:h-[230px] sm:h-[250px] md:h-[290px]"
    >
      {/* Cart Add Success Animation Overlay (with smooth enter and exit transitions) */}
      <AnimatePresence>
        {showAdded && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.18 }}
            className="absolute inset-0 z-30 flex items-center justify-center bg-[#2e7d32]/10 rounded-xl pointer-events-none"
          >
            <motion.div
              initial={{ scale: 0.6, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.6, opacity: 0 }}
              transition={{ duration: 0.12, ease: 'easeOut' }}
              className="flex h-8 w-8 items-center justify-center rounded-full bg-[#2e7d32] text-white shadow-lg"
            >
              <Check className="h-4 w-4" strokeWidth={3} />
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      <Link href={`/product/${product.slug}`} className="flex flex-col flex-1 min-h-0">

        {/* Discount Badge — top left */}
        {resolvedDiscount > 0 && (
          <div className="absolute left-0 top-0 z-10 rounded-tl-xl rounded-br-lg bg-[#FF2E55] px-2 py-0.5 text-[9px] min-[375px]:text-[10px] font-extrabold text-white shadow-sm whitespace-nowrap pointer-events-none select-none">
            {resolvedDiscount}% OFF
          </div>
        )}

        {/* Image Container */}
        <div ref={imageRef} className="relative aspect-square w-full overflow-hidden rounded-lg bg-muted/10 dark:bg-white/[0.02] flex items-center justify-center shrink-0">
          <ProductImage
            src={product.imageUrl}
            alt={product.name}
            categorySlug={categorySlug}
            isBestseller={product.tags?.includes('popular')}
            className="h-full w-full object-contain p-1 transition-transform duration-300 md:group-hover:scale-105 group-active:scale-[0.97] md:group-active:scale-105"
          />

          {/* Bestseller Tag */}
          {product.tags?.includes('popular') && (
            <div className="absolute bottom-0.5 left-0.5 z-10 flex items-center gap-0.5 rounded bg-amber-500/90 px-1 py-0.5 text-[7px] min-[375px]:text-[8px] font-bold text-white shadow-sm">
              ⭐ Bestseller
            </div>
          )}

          {/* Low Stock Badge — overlay on image */}
          {isLowStock && (
            <motion.div
              key={resolvedStock}
              initial={{ scale: 0.85, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={{ type: 'spring', stiffness: 300, damping: 15 }}
              className="absolute top-0.5 right-0.5 z-10 flex items-center gap-0.5 rounded bg-red-500/90 px-1 min-[375px]:px-1.5 py-0.5 text-[7px] min-[375px]:text-[8px] font-bold text-white shadow-sm pointer-events-none select-none"
            >
              Only {resolvedStock} left
            </motion.div>
          )}
        </div>

        {/* Product Info — flex-1 takes remaining space between image and bottom row */}
        <div className="flex flex-col flex-1 min-h-0 justify-center mt-1">
          {/* Name — fixed min-height for 2 lines */}
          <h3 className="text-[10px] min-[375px]:text-[11px] sm:text-xs md:text-sm font-extrabold text-text-primary line-clamp-2 leading-tight md:group-hover:text-primary transition-colors min-h-[22px] min-[375px]:min-h-[26px] sm:min-h-[32px]">
            {product.name}
          </h3>
          {/* Unit / Customisable — fixed height container */}
          <div className="h-4 min-[375px]:h-[18px] sm:h-5 flex items-center">
            {hasVariants ? (
              <span className="inline-flex items-center gap-0.5 text-[8px] min-[375px]:text-[9px] sm:text-[10px] font-black text-primary bg-primary/5 px-1.5 py-0.5 rounded-md w-fit border border-primary/10 leading-none">
                Customisable ▾
              </span>
            ) : (
              <span className="text-[8px] min-[375px]:text-[9px] sm:text-xs font-bold text-text-muted leading-none">
                {product.unit}
              </span>
            )}
          </div>
        </div>
      </Link>

      {/* Consolidated Bottom Row: Price, MRP, Savings and ADD Button — always pinned to bottom */}
      <div className="flex items-end justify-between gap-1 mt-auto pt-1 w-full min-w-0 shrink-0">
        {/* Left Side: Pricing & Savings */}
        <div className="flex flex-col min-w-0 flex-1">
          <div className="flex items-baseline gap-1 flex-wrap leading-none">
            <motion.span
              key={resolvedPrice}
              initial={{ scale: 0.85, y: -2 }}
              animate={{ scale: 1, y: 0 }}
              transition={{ type: 'spring', stiffness: 400, damping: 12 }}
              className="text-[10px] min-[375px]:text-xs sm:text-base font-black text-text-primary block"
            >
              ₹{resolvedPrice}
            </motion.span>
            {resolvedMrp > resolvedPrice && (
              <span className="text-[8px] min-[375px]:text-[9px] text-text-muted line-through font-bold">
                ₹{resolvedMrp}
              </span>
            )}
          </div>
          {/* Savings — always reserves height for stable layout */}
          <span 
            className={cn(
              "text-[7.5px] min-[375px]:text-[8px] font-black mt-0.5 block truncate tracking-tight leading-none h-[10px] min-[375px]:h-[11px]",
              savings > 0 ? "text-[#2e7d32] dark:text-emerald-400" : "text-transparent select-none pointer-events-none"
            )}
            title={savings > 0 ? `Save ₹${savings}` : undefined}
            aria-hidden={savings <= 0}
          >
            {savings > 0 ? `Save ₹${savings}` : '\u00A0'}
          </span>
        </div>

        {/* Right Side: Add to Cart Actions */}
        <div className="relative h-8 sm:h-9 w-[64px] min-[375px]:w-[72px] sm:w-20 shrink-0 flex-shrink-0">
          <AnimatePresence mode="wait">
            {quantity === 0 ? (
              <motion.div
                key="add-to-cart-button"
                initial={{ opacity: 0, scale: 0.92 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.92 }}
                transition={{ duration: 0.15 }}
                className="w-full h-full"
              >
                <Button
                  onClick={(e) => {
                    if (resolvedStock <= 0 || !resolvedIsAvailable) {
                      handleNotifyMe(e)
                    } else {
                      handleAdd(e)
                    }
                  }}
                  disabled={isStoreClosed && resolvedStock > 0}
                  className={cn(
                    "w-full h-full border text-[10px] sm:text-xs font-black rounded-md md:hover:scale-[1.03] active:scale-95 transition-all duration-200 flex items-center justify-center gap-0.5 cursor-pointer shadow-sm",
                    resolvedStock <= 0 || !resolvedIsAvailable
                      ? "border-amber-500/30 bg-amber-500/5 hover:bg-amber-500/10 text-amber-600 dark:text-amber-400"
                      : "border-[#2e7d32] bg-gradient-to-b from-white to-green-50/50 dark:from-zinc-900 dark:to-zinc-800 text-[#2e7d32] dark:text-emerald-400 md:hover:bg-[#2e7d32] md:hover:text-white"
                  )}
                >
                  {resolvedStock <= 0 || !resolvedIsAvailable ? (
                    isNotifySubscribed ? (
                      <span className="flex items-center gap-0.5 text-[9px] sm:text-[10px] text-emerald-600 dark:text-emerald-400 font-bold">
                        <Check className="h-2.5 w-2.5 stroke-[3.5]" />
                        Alerted
                      </span>
                    ) : (
                      <span className="flex items-center gap-0.5 text-[9px] sm:text-[10px] text-amber-600 dark:text-amber-500 font-extrabold">
                        🔔 Notify
                      </span>
                    )
                  ) : isStoreClosed ? (
                    'Closed'
                  ) : (
                    <>
                      ADD
                      <Plus className="h-2.5 w-2.5 sm:h-3 sm:w-3 stroke-[3]" />
                    </>
                  )}
                </Button>
              </motion.div>
            ) : (
              <motion.div
                key="qty-counter-selector"
                initial={{ opacity: 0, scale: 0.92 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.92 }}
                transition={{ duration: 0.15 }}
                className="flex h-full w-full items-center justify-between rounded-md bg-gradient-to-r from-[#2e7d32] to-[#1b5e20] text-white font-bold shadow-sm overflow-hidden transition-all duration-300"
              >
                <motion.button
                  whileTap={{ scale: 0.82 }}
                  onClick={handleDecrement}
                  className="flex-1 flex h-full items-center justify-center hover:bg-black/10 transition-all cursor-pointer"
                  aria-label="Decrease quantity"
                >
                  <Minus className="h-2 w-2 sm:h-3 sm:w-3 stroke-[3]" />
                </motion.button>
                <span className="w-4 min-[375px]:w-5 sm:w-7 shrink-0 flex items-center justify-center text-[9px] sm:text-xs font-black select-none h-full bg-[#2e7d32] border-x border-white/20">
                  {quantity}
                </span>
                <motion.button
                  whileTap={{ scale: 0.82 }}
                  onClick={handleIncrement}
                  disabled={quantity >= resolvedStock || quantity >= (isCafe ? 10 : 5) || isStoreClosed}
                  className="flex-1 flex h-full items-center justify-center hover:bg-black/10 transition-all disabled:opacity-50 cursor-pointer"
                  aria-label="Increase quantity"
                >
                  <Plus className="h-2.5 w-2.5 sm:h-3 sm:w-3 stroke-[3]" />
                </motion.button>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </motion.div>
  )
}
