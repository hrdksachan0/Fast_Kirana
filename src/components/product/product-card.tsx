'use client'

import { useState, useCallback, useMemo, useRef, useEffect } from 'react'
import Link from 'next/link'
import { Plus, Minus, Check, Zap, Heart, Store } from 'lucide-react'
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

import { useRouter } from 'next/navigation'
import { isCafeProduct, cn, getProductLimit, getProductType, isProductStoreClosed } from '@/lib/utils'
import { useLiveStock } from '@/components/providers/live-stock-provider'
import { checkDishTimeAvailability } from '@/lib/dish-timing'
import { getOutletName } from '@/lib/constants'

export function ProductCard({ product, isCompact = false }: ProductCardProps) {
  const router = useRouter()
  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const restaurantOpen = useUIStore((s) => s.restaurantOpen)
  const categoryStatus = useUIStore((s) => s.categoryStatus) || {}
  const setActiveVariantProduct = useUIStore((s) => s.setActiveVariantProduct)

  const [wishlistLoading, setWishlistLoading] = useState(false)
  const [isWishlisted, setIsWishlisted] = useState(false)

  const timingStatus = useMemo(() => {
    return checkDishTimeAvailability(
      (product as any).availableStartTime,
      (product as any).availableEndTime
    )
  }, [(product as any).availableStartTime, (product as any).availableEndTime])
  
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

  const toggleWishlist = useCallback(async () => {
    if (wishlistLoading) return

    setWishlistLoading(true)
    try {
      const res = await fetch('/api/wishlist', {
        method: isWishlisted ? 'DELETE' : 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ productId: product.id }),
      })

      if (!res.ok) {
        if (res.status === 401) {
          toast.error('Please log in to save items to your wishlist', {
            action: {
              label: 'Login',
              onClick: () => router.push('/login?callbackUrl=/account/wishlist'),
            },
          })
          return
        }
        throw new Error('Failed to update wishlist')
      }

      setIsWishlisted(!isWishlisted)
      toast.success(isWishlisted ? 'Removed from wishlist' : 'Added to wishlist')
    } catch {
      toast.error('Failed to update wishlist')
    } finally {
      setWishlistLoading(false)
    }
  }, [isWishlisted, product.id, wishlistLoading])

  const productType = getProductType(product)
  const isCafe = productType === 'CAFE'
  const isRestaurant = productType === 'RESTAURANT' || Boolean(product.restaurantId) || Boolean((product as any).restaurantId)
  const categorySlug = product.category?.slug || (product as any).categorySlug || ''
  const isCategoryOpen = categoryStatus[categorySlug] !== false
  const isStoreClosed = isProductStoreClosed(
    product,
    { groceryMartOpen, cafeOpen, restaurantOpen },
    categoryStatus
  )

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

  const resolvedIsAvailable = useMemo(() => {
    if (liveState !== null && typeof liveState.isAvailable === 'boolean') {
      return liveState.isAvailable
    }
    return product.isAvailable !== false
  }, [liveState, product.isAvailable])

  const resolvedStock = useMemo(() => {
    if (liveState !== null && typeof liveState.stock === 'number') {
      return liveState.stock
    }
    if (!resolvedIsAvailable || product.stock === 0 || (product as any).stock === 0) {
      return 0
    }
    if (typeof product.stock === 'number' && product.stock > 0) {
      return product.stock
    }
    if (isRestaurant || isCafe || Boolean(product.restaurantId) || Boolean((product as any).restaurantId)) {
      return 999
    }
    return totalStock
  }, [liveState, resolvedIsAvailable, product.stock, isRestaurant, isCafe, product.restaurantId, totalStock])

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
        restaurantId: (product as any).restaurantId || (product as any).restaurant?.id,
        restaurantName: (product as any).restaurantName || (product as any).restaurant?.name,
        restaurant: (product as any).restaurant,
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
        "group relative flex flex-col overflow-hidden rounded-[20px] transition-all duration-300 ease-out active:scale-[0.98] cursor-pointer",
        isRestaurant 
          ? "bg-white dark:bg-[#141210] border border-amber-500/25 hover:border-amber-500/50 shadow-[0_2px_10px_rgba(245,158,11,0.06)] hover:shadow-[0_12px_28px_-6px_rgba(245,158,11,0.15)]"
          : "bg-white dark:bg-[#121215] border border-zinc-200/80 dark:border-zinc-800/80 hover:border-zinc-300 dark:hover:border-zinc-700 shadow-[0_2px_8px_rgba(0,0,0,0.04),0_1px_2px_rgba(0,0,0,0.02)] hover:shadow-[0_12px_28px_-6px_rgba(0,0,0,0.08),0_4px_10px_rgba(0,0,0,0.03)] hover:-translate-y-0.5",
        isCompact 
          ? "h-[215px] min-[375px]:h-[235px] sm:h-[255px]" 
          : "h-[250px] min-[375px]:h-[272px] sm:h-[294px]"
      )}
    >
      <div className="flex flex-col h-full w-full p-2 sm:p-2.5 relative overflow-hidden">
      {/* Cart Add Success Animation Overlay (with smooth enter and exit transitions) */}
      <AnimatePresence>
        {showAdded && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.18 }}
            className="absolute inset-0 z-30 flex items-center justify-center bg-emerald-500/10 rounded-[20px] pointer-events-none backdrop-blur-[1px]"
          >
            <motion.div
              initial={{ scale: 0.6, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.6, opacity: 0 }}
              transition={{ duration: 0.12, ease: 'easeOut' }}
              className="flex h-8 w-8 items-center justify-center rounded-full bg-emerald-600 text-white shadow-lg"
            >
              <Check className="h-4 w-4" strokeWidth={3} />
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      <Link href={`/product/${product.slug}`} className="relative block shrink-0">

        {/* Discount Badge — top left */}
        {resolvedDiscount > 0 && (
          <div className={cn(
            "absolute left-1.5 top-1.5 z-10 rounded-md bg-gradient-to-r from-[#e8153a] to-[#ff3b30] px-1.5 py-0.5 font-black text-white shadow-[0_2px_6px_rgba(232,21,58,0.3)] tracking-wider whitespace-nowrap pointer-events-none select-none",
            isCompact ? "text-[7.5px]" : "text-[8px] min-[375px]:text-[8.5px]"
          )}>
            {resolvedDiscount}% OFF
          </div>
        )}

        {/* Image Container - Clean Soft Canvas */}
        <div
          ref={imageRef}
          className={cn(
            "relative w-full overflow-hidden rounded-[14px] bg-gradient-to-b from-zinc-50 via-zinc-100/35 to-zinc-50/60 dark:from-zinc-900/80 dark:via-zinc-900/40 dark:to-zinc-900/30 flex items-center justify-center shrink-0 border border-zinc-100/80 dark:border-zinc-800/40",
            isCompact
              ? "h-[92px] min-[375px]:h-[108px] sm:h-[122px]"
              : "h-[120px] min-[375px]:h-[135px] sm:h-[150px] md:h-[168px]"
          )}
        >
          <ProductImage
            src={product.imageUrl}
            alt={product.name}
            categorySlug={categorySlug}
            isBestseller={product.tags?.includes('popular')}
            width={240}
            className="h-full w-full object-contain p-1.5 transition-transform duration-300 ease-out md:group-hover:scale-108 group-active:scale-[0.97]"
          />

          {/* Heart / Wishlist Button */}
          <button
            type="button"
            onClick={(e) => {
              e.preventDefault()
              e.stopPropagation()
              toggleWishlist()
            }}
            disabled={wishlistLoading}
            aria-label={isWishlisted ? 'Remove from wishlist' : 'Add to wishlist'}
            className={cn(
              "absolute top-1.5 right-1.5 z-20 flex items-center justify-center rounded-full w-6.5 h-6.5 min-[375px]:w-7 min-[375px]:h-7 transition-all duration-200 cursor-pointer active:scale-90",
              isWishlisted
                ? "opacity-100 bg-rose-500 text-white shadow-md scale-105"
                : "opacity-80 sm:opacity-0 sm:group-hover:opacity-100 bg-white/90 dark:bg-zinc-800/90 text-zinc-500 dark:text-zinc-400 shadow-xs hover:text-rose-500 hover:scale-110 border border-zinc-200/50 dark:border-zinc-700/50",
              wishlistLoading && "opacity-70 cursor-wait"
            )}
          >
            {wishlistLoading ? (
              <svg className="h-3 w-3 animate-spin" viewBox="0 0 24 24" fill="none">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" />
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
              </svg>
            ) : (
              <Heart
                className={cn(
                  "h-3.5 w-3.5 transition-all",
                  isWishlisted && "fill-current"
                )}
                strokeWidth={isWishlisted ? 0 : 2.5}
              />
            )}
          </button>

          {/* Bestseller Tag */}
          {(product.tags?.includes('popular') || product.isBestSeller) && (
            <div className={cn(
              "absolute bottom-1.5 left-1.5 z-10 flex items-center gap-0.5 rounded-full px-2 py-0.5 text-[7.5px] min-[375px]:text-[8px] font-black pointer-events-none select-none tracking-tight",
              isRestaurant 
                ? "bg-red-600 text-white shadow-xs" 
                : "bg-amber-400 text-zinc-950 shadow-xs"
            )}>
              {isRestaurant ? ('👨‍🍳 ' + (((product as any).restaurant?.name || (product as any).restaurantName)?.split(' ')[0] || 'Chef') + ' Special') : '⭐ BESTSELLER'}
            </div>
          )}

          {/* Cafe Fresh Tag */}
          {isCafe && (
            <div className="absolute bottom-1.5 right-1.5 z-10 flex items-center gap-0.5 rounded-full bg-orange-500/90 backdrop-blur-md px-2 py-0.5 text-[8px] font-extrabold text-white shadow-xs pointer-events-none select-none">
              ☕ Cafe Fresh
            </div>
          )}

          {/* Time Slot Badge (if outside active timing) */}
          {!timingStatus.isAvailableNow && timingStatus.formattedTimeSlot && (
            <div className="absolute top-1.5 left-1.5 z-20 flex items-center gap-1 rounded-full bg-amber-500/95 backdrop-blur-md px-2 py-0.5 text-[8px] font-black text-white shadow-xs pointer-events-none select-none">
              ⏰ {timingStatus.formattedTimeSlot}
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
                "absolute z-10 flex items-center gap-0.5 rounded-md bg-red-500/95 px-1.5 py-0.5 text-[7.5px] font-bold text-white shadow-xs pointer-events-none select-none",
                (product.tags?.includes('popular') || product.isBestSeller)
                  ? "bottom-6 left-1.5"
                  : "bottom-1.5 right-1.5"
              )}
            >
              Only {resolvedStock} left
            </motion.div>
          )}

          {/* Out of Stock Overlay */}
          {(resolvedStock <= 0 || !resolvedIsAvailable) && (
            <div className="absolute inset-0 z-20 flex items-center justify-center bg-black/45 backdrop-blur-[1px] rounded-[14px] pointer-events-none select-none">
              <span className="rounded-full bg-zinc-950/90 px-2 py-0.5 text-[8.5px] min-[375px]:text-[9.5px] font-black text-rose-400 border border-rose-500/40 shadow-lg tracking-wider uppercase">
                Out of Stock
              </span>
            </div>
          )}
        </div>
      </Link>

        {/* ROW 1: Pack Size (Left) & ADD Button (Right) — Clean & Balanced */}
        <div className="flex items-center justify-between gap-1 mt-2 mb-1 shrink-0 w-full min-w-0">
          <div className="min-w-0 flex-1 overflow-hidden">
            {hasVariants ? (
              <span 
                onClick={(e) => {
                  e.preventDefault()
                  e.stopPropagation()
                  if (resolvedStock <= 0 || !resolvedIsAvailable) {
                    toast.error(`Sorry, ${product.name} is currently out of stock!`)
                    return
                  }
                  setActiveVariantProduct(product)
                }}
                className={cn(
                  "inline-flex items-center gap-0.5 text-[8px] min-[375px]:text-[8.5px] font-extrabold px-1.5 py-0.5 rounded-md border whitespace-nowrap truncate max-w-full leading-tight transition-all",
                  resolvedStock <= 0 || !resolvedIsAvailable
                    ? "text-zinc-400 dark:text-zinc-500 bg-zinc-100 dark:bg-zinc-800 border-zinc-200 dark:border-zinc-700 cursor-not-allowed opacity-75"
                    : "text-emerald-700 dark:text-emerald-400 bg-emerald-500/10 border-emerald-500/30 cursor-pointer active:scale-95"
                )}
              >
                {variantsList.length} Options ▾
              </span>
            ) : (
              <span className="text-[9px] min-[375px]:text-[10px] sm:text-[11px] font-extrabold text-zinc-400 dark:text-zinc-500 uppercase tracking-tight leading-none truncate block whitespace-nowrap">
                {product.unit}
              </span>
            )}
          </div>

          {/* Right Side: ADD Button / Qty Selector */}
          <div className={cn(
            "relative shrink-0 flex-shrink-0 ml-auto",
            isCompact 
              ? "h-6.5 min-[375px]:h-7 w-[46px] min-[375px]:w-[52px] sm:w-14" 
              : "h-7 sm:h-8 w-[52px] min-[375px]:w-[58px] sm:w-16"
          )}>
            <AnimatePresence mode="wait">
              {resolvedQuantity === 0 ? (
                <motion.button
                  whileTap={resolvedStock <= 0 || !resolvedIsAvailable ? undefined : { scale: 0.92 }}
                  transition={{ type: 'spring', stiffness: 400, damping: 15 }}
                  type="button"
                  onClick={(e) => {
                    if (resolvedStock <= 0 || !resolvedIsAvailable) {
                      e.preventDefault()
                      e.stopPropagation()
                      toast.error(`Sorry, ${product.name} is currently out of stock!`)
                    } else {
                      handleAdd(e)
                    }
                  }}
                  disabled={resolvedStock <= 0 || !resolvedIsAvailable || (isStoreClosed && resolvedStock > 0) || !timingStatus.isAvailableNow}
                  className={cn(
                    "w-full h-full border font-black rounded-lg transition-all duration-200 flex items-center justify-center gap-0.5 outline-none px-1 tracking-wide",
                    isCompact ? "text-[8px] min-[375px]:text-[9px]" : "text-[9px] sm:text-[10.5px]",
                    resolvedStock <= 0 || !resolvedIsAvailable
                      ? "border-zinc-200 dark:border-zinc-800 bg-zinc-100 dark:bg-zinc-800/80 text-zinc-400 dark:text-zinc-500 cursor-not-allowed shadow-none"
                      : !timingStatus.isAvailableNow
                      ? "border-amber-500/50 bg-amber-500/10 text-amber-600 dark:text-amber-400 cursor-not-allowed shadow-none"
                      : isStoreClosed && resolvedStock > 0
                      ? "border-zinc-200 dark:border-zinc-700 bg-zinc-100 dark:bg-zinc-800 text-zinc-500 dark:text-zinc-400 cursor-not-allowed shadow-none"
                      : isCafe
                      ? "border-orange-500 bg-orange-50/60 dark:bg-orange-950/20 text-orange-600 dark:text-orange-400 hover:bg-orange-500 hover:text-white cursor-pointer shadow-2xs hover:shadow-xs"
                      : isRestaurant
                      ? "border-[#e20a22] bg-rose-50/60 dark:bg-rose-950/20 text-[#e20a22] dark:text-rose-400 hover:bg-[#e20a22] hover:text-white cursor-pointer shadow-2xs hover:shadow-xs"
                      : "border-emerald-600 dark:border-emerald-500 bg-emerald-50/80 dark:bg-emerald-950/30 text-emerald-700 dark:text-emerald-300 hover:bg-emerald-600 hover:text-white cursor-pointer shadow-2xs hover:shadow-xs"
                  )}
                >
                  {resolvedStock <= 0 || !resolvedIsAvailable ? (
                    'Sold Out'
                  ) : !timingStatus.isAvailableNow ? (
                    `Next @ ${timingStatus.nextAvailableTimeStr || 'Slot'}`
                  ) : isStoreClosed ? (
                    'Closed'
                  ) : (
                    <>
                      ADD
                      <Plus className="h-2.5 w-2.5 stroke-[3]" />
                    </>
                  )}
                </motion.button>
              ) : (
                <div className={cn(
                  "flex h-full w-full items-center justify-between rounded-lg text-white font-black shadow-xs overflow-hidden",
                  isCafe ? "bg-orange-500" : isRestaurant ? "bg-[#e20a22]" : "bg-emerald-600"
                )}>
                  <motion.button
                    whileTap={{ scale: 0.85 }}
                    transition={{ type: 'spring', stiffness: 400, damping: 15 }}
                    onClick={handleDecrement}
                    className="flex-1 flex h-full items-center justify-center hover:bg-black/15 transition-all cursor-pointer"
                  >
                    <Minus className="h-2.5 w-2.5 stroke-[3]" />
                  </motion.button>
                  <span className="shrink-0 flex items-center justify-center font-black select-none text-[9.5px] min-[375px]:text-[10.5px]">
                    {quantity}
                  </span>
                  <motion.button
                    whileTap={{ scale: 0.85 }}
                    transition={{ type: 'spring', stiffness: 400, damping: 15 }}
                    onClick={handleIncrement}
                    disabled={quantity >= resolvedStock || quantity >= getProductLimit(product) || isStoreClosed}
                    className="flex-1 flex h-full items-center justify-center hover:bg-black/15 transition-all disabled:opacity-50 cursor-pointer"
                  >
                    <Plus className="h-2.5 w-2.5 stroke-[3]" />
                  </motion.button>
                </div>
              )}
            </AnimatePresence>
          </div>
        </div>

        {/* ROW 2, ROW 3, and Restaurant Outlet wrapped in Link for tap navigation */}
        <Link href={`/product/${product.slug}`} className="flex flex-col flex-1 min-h-0 min-w-0 justify-between">
          {/* ROW 2: Price & MRP */}
          <div className="flex items-baseline gap-1.5 flex-wrap leading-none mb-1">
            <motion.span
              key={resolvedPrice}
              initial={{ opacity: 0.5, y: -4 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ type: 'spring', stiffness: 300, damping: 20 }}
              className={cn(
                "font-black text-zinc-950 dark:text-white block tracking-tight tabular-nums",
                isCompact 
                  ? "text-[12px] min-[375px]:text-[13px] sm:text-[14px]" 
                  : "text-[13px] min-[375px]:text-[14px] sm:text-[16px]"
              )}
            >
              ₹{resolvedPrice}
            </motion.span>
            {resolvedMrp > resolvedPrice && (
              <span className="text-[9.5px] min-[375px]:text-[10px] text-zinc-400 dark:text-zinc-500 line-through font-medium tabular-nums">
                ₹{resolvedMrp}
              </span>
            )}
          </div>

          {/* ROW 3: Product Name / Title */}
          <div className="flex items-start gap-1 mb-0.5 min-w-0">
            {isRestaurant && (
              <div className="mt-0.5 shrink-0 flex items-center justify-center h-3 w-3 rounded-2xs border border-emerald-600 bg-white dark:bg-zinc-900 shadow-2xs" title="Pure Veg Dish">
                <div className="h-1 w-1 rounded-full bg-emerald-600" />
              </div>
            )}
            <h3 className={cn(
              "font-bold text-zinc-850 dark:text-zinc-100 line-clamp-2 leading-[1.3] transition-colors flex-1 min-w-0 group-hover:text-emerald-600 dark:group-hover:text-emerald-400",
              isCompact 
                ? "text-[10px] min-[375px]:text-[10.5px] min-h-[26px]" 
                : "text-[11px] min-[375px]:text-[12px] sm:text-[12.5px] min-h-[30px]"
            )}>
              {product.name}
            </h3>
          </div>

          {/* Restaurant Outlet Sub-label Identifier */}
          {(isRestaurant || Boolean(product.restaurantId) || Boolean((product as any).restaurantId)) && (
            <div className={cn(
              "inline-flex items-center gap-1 text-[8px] min-[375px]:text-[8.5px] font-extrabold px-1.5 py-0.5 rounded-md mt-auto min-w-0 leading-tight border w-fit max-w-full",
              getOutletName(product).includes('Wedson')
                ? "text-emerald-700 dark:text-emerald-300 bg-emerald-500/10 border-emerald-500/30"
                : getOutletName(product).includes('Bal Udyan')
                ? "text-purple-700 dark:text-purple-300 bg-purple-500/10 border-purple-500/30"
                : "text-amber-800 dark:text-amber-300 bg-amber-500/15 border-amber-500/30"
            )}>
              <Store className="h-2.5 w-2.5 shrink-0 opacity-80" />
              <span className="truncate tracking-tight">{getOutletName(product)}</span>
            </div>
          )}
        </Link>
      </div>
    </div>
  )
}
