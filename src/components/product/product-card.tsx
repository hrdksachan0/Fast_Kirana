'use client'

import { useState, useCallback, useMemo, useRef, useEffect } from 'react'
import Link from 'next/link'
import { Plus, Minus, Check, Zap, Heart } from 'lucide-react'
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
  isCompact?: boolean
}

import { isCafeProduct, cn, getProductLimit } from '@/lib/utils'
import { useLiveStock } from '@/components/providers/live-stock-provider'

export function ProductCard({ product, isCompact = false }: ProductCardProps) {
  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const restaurantOpen = useUIStore((s) => s.restaurantOpen)
  const categoryStatus = useUIStore((s) => s.categoryStatus) || {}
  const setActiveVariantProduct = useUIStore((s) => s.setActiveVariantProduct)
  
  const [mounted, setMounted] = useState(false)
  useEffect(() => {
    setMounted(true)
  }, [])
  
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
  const resolvedQuantity = mounted ? quantity : 0
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

  const isCafe = product.category?.slug === 'cafe' || product.tags?.includes('cafe')
  const isRestaurant = product.category?.slug === 'restaurant' || product.tags?.includes('restaurant')
  const categorySlug = product.category?.slug || ''
  const isCategoryOpen = categoryStatus[categorySlug] !== false
  const isStoreClosed = isCafe 
    ? (!cafeOpen || !isCategoryOpen) 
    : isRestaurant
      ? (!restaurantOpen || !isCategoryOpen)
      : (!groceryMartOpen || !isCategoryOpen)

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
    <div
      className={cn(
        "group relative flex flex-col overflow-hidden rounded-3xl border transition-all duration-300 ease-out cursor-pointer",
        isRestaurant 
          ? "border-red-500/25 dark:border-red-500/35 bg-gradient-to-b from-white via-white to-red-50/20 dark:from-zinc-950 dark:to-red-950/20 shadow-2xs hover:shadow-md hover:border-red-500/50"
          : "border-zinc-100 dark:border-zinc-900/60 bg-white/95 dark:bg-zinc-950/70 backdrop-blur-xs shadow-xs hover:shadow-md hover:border-zinc-200 dark:hover:border-zinc-800",
        isCompact 
          ? "p-1.5 min-[375px]:p-2 h-[185px] min-[375px]:h-[205px] sm:h-[230px]" 
          : "p-2 min-[375px]:p-2.5 h-[225px] min-[375px]:h-[245px] sm:h-[265px] md:h-[300px]"
      )}
    >
      {/* Cart Add Success Animation Overlay (with smooth enter and exit transitions) */}
      <AnimatePresence>
        {showAdded && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.18 }}
            className="absolute inset-0 z-30 flex items-center justify-center bg-[#2e7d32]/10 rounded-3xl pointer-events-none"
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
          <div className={cn(
            "absolute left-2 top-2 z-10 rounded-full bg-gradient-to-r from-rose-500 to-orange-500 px-2 py-0.5 font-black text-white shadow-[0_2px_8px_rgba(244,63,94,0.3)] tracking-wider whitespace-nowrap pointer-events-none select-none",
            isCompact ? "text-[7.5px] px-1.5" : "text-[8.5px] min-[375px]:text-[9.5px]"
          )}>
            {resolvedDiscount}% OFF
          </div>
        )}

        {/* Image Container */}
        <div 
          ref={imageRef} 
          className={cn(
            "relative w-full overflow-hidden rounded-2xl bg-muted/15 dark:bg-white/[0.03] flex items-center justify-center shrink-0 border border-border/30",
            isCompact 
              ? "h-[75px] min-[375px]:h-[85px] sm:h-[105px]" 
              : "h-[95px] min-[375px]:h-[110px] sm:h-[125px] md:h-[145px]"
          )}
        >
          <ProductImage
            src={product.imageUrl}
            alt={product.name}
            categorySlug={categorySlug}
            isBestseller={product.tags?.includes('popular')}
            width={200}
            className="h-full w-full object-contain p-1.5 transition-transform duration-300 md:group-hover:scale-105 group-active:scale-[0.97] md:group-active:scale-105"
          />

          {/* Green Veg Icon Badge for Restaurant Dishes */}
          {isRestaurant && (
            <div className="absolute top-1.5 right-1.5 z-10 flex items-center justify-center h-3.5 w-3.5 rounded-xs border border-emerald-600 bg-white dark:bg-zinc-900 shadow-2xs pointer-events-none select-none" title="Pure Veg Dish">
              <div className="h-1.5 w-1.5 rounded-full bg-emerald-600" />
            </div>
          )}

          {/* Bestseller Tag */}
          {(product.tags?.includes('popular') || product.isBestSeller) && (
            <div className={cn(
              "absolute bottom-1.5 left-1.5 z-10 flex items-center gap-0.5 rounded-full backdrop-blur-md px-2 py-0.5 text-[8px] font-extrabold text-white pointer-events-none select-none",
              isRestaurant 
                ? "bg-gradient-to-r from-red-600 to-amber-600 shadow-[0_2px_8px_rgba(226,10,34,0.3)]" 
                : "bg-amber-500/95 shadow-[0_2px_8px_rgba(245,158,11,0.25)]"
            )}>
              {isRestaurant ? '👨‍🍳 Wedson Special' : '⭐ Bestseller'}
            </div>
          )}

          {/* Cafe Fresh Tag */}
          {isCafe && (
            <div className="absolute bottom-1.5 right-1.5 z-10 flex items-center gap-0.5 rounded-full bg-orange-500/90 backdrop-blur-md px-2 py-0.5 text-[8px] font-extrabold text-white shadow-[0_2px_8px_rgba(249,115,22,0.2)] pointer-events-none select-none">
              ☕ Cafe Fresh
            </div>
          )}

          {/* Low Stock Badge */}
          {isLowStock && (
            <motion.div
              key={resolvedStock}
              initial={{ scale: 0.85, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={{ type: 'spring', stiffness: 300, damping: 15 }}
              className={cn(
                "absolute z-10 flex items-center gap-0.5 rounded-md bg-red-500/95 px-1.5 py-0.5 text-[8px] font-bold text-white shadow-[0_2px_8px_rgba(239,68,68,0.3)] pointer-events-none select-none",
                (product.tags?.includes('popular') || product.isBestSeller)
                  ? "bottom-7 left-1.5"
                  : "bottom-1.5 right-1.5"
              )}
            >
              Only {resolvedStock} left
            </motion.div>
          )}
        </div>

        {/* ROW 1: Pack Size (Left) & ADD Button (Right) — Immediately below image container */}
        <div className="flex items-center justify-between gap-1 mt-1.5 mb-1 shrink-0 w-full min-w-0">
          <div className="min-w-0 flex-1 overflow-hidden">
            {hasVariants ? (
              <span className="inline-flex items-center gap-0.5 text-[7.5px] min-[375px]:text-[8.5px] font-extrabold text-[#2e7d32] dark:text-emerald-400 bg-emerald-500/10 px-1 py-0.5 rounded-full border border-emerald-500/30 whitespace-nowrap truncate max-w-full leading-tight">
                {variantsList.length} Options ▾
              </span>
            ) : (
              <span className="text-[8.5px] min-[375px]:text-[9.5px] sm:text-xs font-bold text-zinc-600 dark:text-zinc-400 leading-none truncate block whitespace-nowrap">
                {product.unit}
              </span>
            )}
          </div>

          {/* Right Side: ADD Button / Qty Selector */}
          <div className={cn(
            "relative shrink-0 flex-shrink-0 ml-auto",
            isCompact 
              ? "h-6 min-[375px]:h-6.5 w-[44px] min-[375px]:w-[50px] sm:w-14" 
              : "h-6.5 sm:h-7.5 w-[50px] min-[375px]:w-[56px] sm:w-16"
          )}>
            <AnimatePresence mode="wait">
              {resolvedQuantity === 0 ? (
                <button
                  type="button"
                  onClick={(e) => {
                    if (resolvedStock <= 0 || !resolvedIsAvailable) {
                      handleNotifyMe(e)
                    } else {
                      handleAdd(e)
                    }
                  }}
                  disabled={isStoreClosed && resolvedStock > 0}
                  className={cn(
                    "w-full h-full border-2 font-black rounded-lg md:hover:scale-[1.03] active:scale-95 transition-all duration-200 flex items-center justify-center gap-0.5 cursor-pointer shadow-2xs px-1 outline-none",
                    isCompact ? "text-[7.5px] min-[375px]:text-[8.5px]" : "text-[8.5px] sm:text-[10px]",
                    isStoreClosed && resolvedStock > 0
                      ? "border-zinc-300 bg-zinc-50 text-zinc-400 cursor-not-allowed"
                      : resolvedStock <= 0 || !resolvedIsAvailable
                      ? "border-amber-500 bg-amber-500/5 text-amber-600"
                      : isRestaurant
                      ? "border-[#e20a22] bg-white dark:bg-zinc-900 text-[#e20a22] dark:text-red-400 md:hover:bg-[#e20a22] md:hover:text-white"
                      : "border-[#22c55e] bg-white dark:bg-zinc-900 text-[#16a34a] dark:text-emerald-400 md:hover:bg-[#22c55e] md:hover:text-white"
                  )}
                >
                  {resolvedStock <= 0 || !resolvedIsAvailable ? (
                    'Notify'
                  ) : isStoreClosed ? (
                    'Closed'
                  ) : (
                    <>
                      ADD
                      <Plus className="h-2.5 w-2.5 stroke-[3]" />
                    </>
                  )}
                </button>
              ) : (
                <div className={cn(
                  "flex h-full w-full items-center justify-between rounded-lg text-white font-bold shadow-xs overflow-hidden",
                  isRestaurant ? "bg-[#e20a22]" : "bg-[#22c55e]"
                )}>
                  <button
                    onClick={handleDecrement}
                    className="flex-1 flex h-full items-center justify-center hover:bg-black/10 transition-all cursor-pointer"
                  >
                    <Minus className="h-2.5 w-2.5 stroke-[3]" />
                  </button>
                  <span className="shrink-0 flex items-center justify-center font-black select-none text-[9px] min-[375px]:text-[10px]">
                    {quantity}
                  </span>
                  <button
                    onClick={handleIncrement}
                    disabled={quantity >= resolvedStock || quantity >= getProductLimit(product) || isStoreClosed}
                    className="flex-1 flex h-full items-center justify-center hover:bg-black/10 transition-all disabled:opacity-50 cursor-pointer"
                  >
                    <Plus className="h-2.5 w-2.5 stroke-[3]" />
                  </button>
                </div>
              )}
            </AnimatePresence>
          </div>
        </div>

        {/* ROW 2: Price & MRP */}
        <div className="flex items-baseline gap-1.5 flex-wrap leading-none mb-1">
          <motion.span
            key={resolvedPrice}
            className={cn(
              "font-black text-text-primary block tracking-tight",
              isCompact 
                ? "text-[11px] min-[375px]:text-xs sm:text-sm" 
                : "text-[12px] min-[375px]:text-sm sm:text-base"
            )}
          >
            ₹{resolvedPrice}
          </motion.span>
          {resolvedMrp > resolvedPrice && (
            <span className="text-[9px] min-[375px]:text-[10px] text-zinc-400 dark:text-zinc-500 line-through font-semibold">
              ₹{resolvedMrp}
            </span>
          )}
        </div>

        {/* ROW 3: Product Name / Title */}
        <h3 className={cn(
          "font-extrabold text-text-primary line-clamp-2 leading-tight transition-colors mb-1",
          isCompact 
            ? "text-[9.5px] min-[375px]:text-[10px] min-h-[22px]" 
            : "text-[10.5px] min-[375px]:text-[11.5px] sm:text-xs min-h-[26px]"
        )}>
          {product.name}
        </h3>
      </Link>
    </div>
  )
}
