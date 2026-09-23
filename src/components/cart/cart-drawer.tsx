'use client'

import { X, ShoppingBag, Minus, Plus, ArrowRight, ChevronDown, ChevronUp, ChevronLeft, ChevronRight } from 'lucide-react'
import { useCart } from '@/hooks/use-cart'
import { useUIStore } from '@/stores/ui-store'
import { formatPrice, formatTime12h } from '@/lib/utils'
import { GROCERY_FREE_DELIVERY_THRESHOLD, CAFE_FREE_DELIVERY_THRESHOLD, COMBINED_FREE_DELIVERY_THRESHOLD, FREE_DELIVERY_THRESHOLD, DELIVERY_FEE, getOutletName } from '@/lib/constants'
import Link from 'next/link'
import { useState, useEffect, useRef, useMemo } from 'react'
import { ProductImage } from '@/components/product/product-image'
import { isCafeProduct, cn, getProductLimit, isProductStoreClosed } from '@/lib/utils'
import { getDeliveryRules } from '@/lib/distance'
import { motion, AnimatePresence } from 'framer-motion'

import { useCartStore } from '@/stores/cart-store'
import { toast } from 'sonner'
import { triggerHaptic } from '@/lib/haptic'
import { BogoCartGiftCard } from '@/components/cart/bogo-cart-gift-card'
import { isProductEligibleForCoupon } from '@/lib/coupon-rules'

export function CartDrawer() {
  const isOpen = useUIStore((s) => s.isCartOpen)
  const setCartOpen = useUIStore((s) => s.setCartOpen)
  const setActiveVariantProduct = useUIStore((s) => s.setActiveVariantProduct)

  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const restaurantOpen = useUIStore((s) => s.restaurantOpen)
  const categoryStatus = useUIStore((s) => s.categoryStatus) || {}
  const isLocationServiceable = useUIStore((s) => s.isLocationServiceable)
  const setLocationPickerOpen = useUIStore((s) => s.setLocationPickerOpen)
  
  const {
    items,
    addItem,
    updateQuantity,
    removeItem,
    getSubtotal,
    getSavings,
    updateItemNotes
  } = useCart()

  const [recommendations, setRecommendations] = useState<any[]>([])
  const [showBillDetails, setShowBillDetails] = useState(false)
  const [isMobile, setIsMobile] = useState(false)

  const appliedCouponCode = useCartStore((s) => s.appliedCouponCode)
  const setAppliedCouponCode = useCartStore((s) => s.setAppliedCouponCode)
  const [couponInput, setCouponInput] = useState('')
  const [appliedCoupon, setAppliedCoupon] = useState<any>(null)
  const [isCouponLoading, setIsCouponLoading] = useState(false)

  const recScrollRef = useRef<HTMLDivElement>(null)
  const couponInputRef = useRef<HTMLInputElement>(null)

  const scrollRecommendations = (direction: 'left' | 'right') => {
    if (recScrollRef.current) {
      const scrollOffset = direction === 'left' ? -180 : 180
      recScrollRef.current.scrollBy({ left: scrollOffset, behavior: 'smooth' })
    }
  }

  const handleApplyCoupon = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!couponInput.trim()) return

    setIsCouponLoading(true)
    try {
      const payloadItems = (items as any[]).map((i: any) => {
        const p = i.product || {}
        return {
          id: p.id || i.productId || i.id,
          productId: p.id || i.productId || i.id,
          name: p.name || i.name,
          price: Number(p.price) || Number(i.price) || 0,
          categoryId: p.category?.id || p.categoryId || i.categoryId,
          restaurantId: p.restaurantId || p.restaurant?.id || i.restaurantId || null,
          menuSection: p.menuSection || i.menuSection || null,
          tags: p.tags || i.tags || [],
          quantity: i.quantity || 1,
          selectedVariant: p.selectedVariant || i.selectedVariant || p.unit || i.unit || null,
          variant: p.variant || i.variant || p.unit || i.unit || null,
          unit: p.unit || i.unit || null,
        }
      })

      const res = await fetch('/api/coupons/validate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          code: couponInput.trim().toUpperCase(),
          subtotal,
          items: payloadItems,
        }),
      })

      const data = await res.json()

      if (!res.ok) {
        toast.error(data.error || 'Failed to apply coupon')
      } else {
        const couponObj = {
          code: data.coupon.code,
          discountAmount: data.coupon.discountAmount,
          discountType: data.coupon.discountType,
          bogoType: data.coupon.bogoType,
          badgeText: data.coupon.badgeText,
          freeGiftDetails: data.coupon.freeGiftDetails,
          nudgeMessage: data.coupon.nudgeMessage,
          freeItems: data.coupon.freeItems || [],
          rewardVariant: data.coupon.rewardVariant,
          triggerVariant: data.coupon.triggerVariant,
          bogoDishId: data.coupon.bogoDishId,
        }
        setAppliedCoupon(couponObj)
        setAppliedCouponCode(data.coupon.code)

        if (data.coupon.nudgeMessage) {
          toast.info(data.coupon.nudgeMessage, { icon: '🎁', duration: 4000 })
        } else {
          toast.success(`Coupon "${data.coupon.code}" applied! You saved ₹${data.coupon.discountAmount.toFixed(0)}`)
        }
      }
    } catch (err) {
      toast.error('Failed to validate coupon code')
    } finally {
      setIsCouponLoading(false)
    }
  }

  const handleRemoveCoupon = () => {
    setAppliedCoupon(null)
    setAppliedCouponCode(null)
    setCouponInput('')
    toast.success('Coupon removed')
  }

  useEffect(() => {
    const handleResize = () => {
      setIsMobile(window.innerWidth < 640)
    }
    handleResize()
    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  useEffect(() => {
    if (!isOpen || items.length === 0) {
      setRecommendations([])
      return
    }
    
    const productIds = items.map((i) => i.product.id).join(',')
    fetch(`/api/products/upsell?productIds=${productIds}`)
      .then((res) => res.json())
      .then((data) => {
        if (data.products) {
          setRecommendations(data.products)
        }
      })
      .catch((err) => console.error('Failed to fetch upsell products:', err))
  }, [isOpen, items])

  const groceryItems = items.filter((item) => !isCafeProduct(item.product))
  const cafeItems = items.filter((item) => isCafeProduct(item.product))

  const subtotal = getSubtotal()

  const cartHash = useMemo(
    () => items.map((i) => `${i.product.id}:${i.quantity}:${i.product.price}`).join('|'),
    [items]
  )

  // Auto-validate or auto-apply coupon on cart drawer load or item updates
  useEffect(() => {
    if (items.length === 0) {
      setAppliedCoupon(null)
      setAppliedCouponCode(null)
      return
    }

    const payloadItems = (items as any[]).map((i: any) => {
      const p = i.product || {}
      return {
        id: p.id || i.productId || i.id,
        productId: p.id || i.productId || i.id,
        name: p.name || i.name,
        price: Number(p.price) || Number(i.price) || 0,
        categoryId: p.category?.id || p.categoryId || i.categoryId,
        restaurantId: p.restaurantId || p.restaurant?.id || i.restaurantId || null,
        menuSection: p.menuSection || i.menuSection || null,
        tags: p.tags || i.tags || [],
        quantity: i.quantity || 1,
        selectedVariant: p.selectedVariant || i.selectedVariant || p.unit || i.unit || null,
        variant: p.variant || i.variant || p.unit || i.unit || null,
        unit: p.unit || i.unit || null,
      }
    })

    if (appliedCouponCode) {
      // Immediate client-side check: If BOGO offer is applied, ensure cart still has enough qualifying items
      if (appliedCoupon?.discountType === 'BOGO') {
        const qualifying = items.filter((it) => isProductEligibleForCoupon(it.product, appliedCoupon))
        const qQty = qualifying.reduce((sum, it) => sum + (it.quantity || 1), 0)
        if (appliedCoupon.bogoType === 'CHEAPEST_FREE' && qQty < 2) {
          setAppliedCoupon(null)
          setAppliedCouponCode(null)
          return
        }
        if (appliedCoupon.bogoType === 'SAME_ITEM' && !qualifying.some((it) => (it.quantity || 1) >= 2)) {
          setAppliedCoupon(null)
          setAppliedCouponCode(null)
          return
        }
      }

      fetch('/api/coupons/validate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          code: appliedCouponCode,
          subtotal,
          items: payloadItems,
        }),
      })
        .then((res) => (res.ok ? res.json() : null))
        .then((data) => {
          if (data?.coupon && (data.coupon.discountAmount > 0 || data.coupon.nudgeMessage)) {
            setAppliedCoupon({
              code: data.coupon.code,
              discountAmount: data.coupon.discountAmount,
              discountType: data.coupon.discountType,
              bogoType: data.coupon.bogoType,
              badgeText: data.coupon.badgeText,
              freeGiftDetails: data.coupon.freeGiftDetails,
              nudgeMessage: data.coupon.nudgeMessage,
              freeItems: data.coupon.freeItems || [],
              rewardVariant: data.coupon.rewardVariant,
              triggerVariant: data.coupon.triggerVariant,
              bogoDishId: data.coupon.bogoDishId,
            })
          } else {
            setAppliedCouponCode(null)
            setAppliedCoupon(null)
          }
        })
        .catch(() => {
          setAppliedCouponCode(null)
          setAppliedCoupon(null)
        })
      return
    }

    // Auto-apply if no coupon code manually set
    const restId = payloadItems.find((it) => it.restaurantId)?.restaurantId || null
    const url = restId ? `/api/coupons?restaurantId=${restId}` : '/api/coupons'

    fetch(url)
      .then((res) => (res.ok ? res.json() : []))
      .then(async (coupons: any[]) => {
        const autoCoupons = (coupons || []).filter((c: any) => c.autoApply && c.isActive)
        for (const c of autoCoupons) {
          // Pre-check: only test coupons whose basic item requirements are present
          const qualifying = items.filter((it) => isProductEligibleForCoupon(it.product, c))
          const qQty = qualifying.reduce((sum, it) => sum + (it.quantity || 1), 0)
          if (c.discountType === 'BOGO') {
            if (c.bogoType === 'CHEAPEST_FREE' && qQty < 2) continue
            if (c.bogoType === 'SAME_ITEM' && !qualifying.some((it) => (it.quantity || 1) >= 2)) continue
          }

          try {
            const valRes = await fetch('/api/coupons/validate', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                code: c.code,
                subtotal,
                items: payloadItems,
              }),
            })
            if (valRes.ok) {
              const data = await valRes.json()
              if (data.coupon && (data.coupon.discountAmount > 0 || data.coupon.nudgeMessage)) {
                setAppliedCouponCode(data.coupon.code)
                setAppliedCoupon({
                  code: data.coupon.code,
                  discountAmount: data.coupon.discountAmount,
                  discountType: data.coupon.discountType,
                  bogoType: data.coupon.bogoType,
                  badgeText: data.coupon.badgeText,
                  freeGiftDetails: data.coupon.freeGiftDetails,
                  nudgeMessage: data.coupon.nudgeMessage,
                  freeItems: data.coupon.freeItems || [],
                  rewardVariant: data.coupon.rewardVariant,
                  triggerVariant: data.coupon.triggerVariant,
                  bogoDishId: data.coupon.bogoDishId,
                })
                break
              }
            }
          } catch {}
        }
      })
      .catch(() => {})
  }, [appliedCouponCode, cartHash, subtotal])
  const savings = getSavings()

  const grocerySubtotal = groceryItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0)
  const cafeSubtotal = cafeItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0)

  const groceryAdjustedSubtotal = grocerySubtotal
  const cafeAdjustedSubtotal = cafeSubtotal
  const combinedAdjustedSubtotal = groceryAdjustedSubtotal + cafeAdjustedSubtotal
  const settings = useUIStore((s) => s.settings) || {}
  const userDistanceKm = useUIStore((s) => s.userDistanceKm)
  const deliveryRules = getDeliveryRules(userDistanceKm ?? 1.0, { settings })

  const activeThreshold = deliveryRules.isServiceable
    ? deliveryRules.freeDeliveryThreshold
    : (settings.combined_free_delivery_threshold
        ? parseFloat(settings.combined_free_delivery_threshold)
        : (settings.grocery_free_delivery_threshold
            ? parseFloat(settings.grocery_free_delivery_threshold)
            : (settings.delivery_threshold_tier1 ? parseFloat(settings.delivery_threshold_tier1) : GROCERY_FREE_DELIVERY_THRESHOLD)))

  const deliveryFeeVal = deliveryRules.isServiceable
    ? deliveryRules.deliveryFee
    : (settings.delivery_fee ? parseFloat(settings.delivery_fee) : (settings.delivery_fee_tier1 ? parseFloat(settings.delivery_fee_tier1) : DELIVERY_FEE))

  const miscFee = settings.misc_fee ? parseFloat(settings.misc_fee) : 0
  const miscFeeLabel = settings.misc_fee_label || 'Handling & Packaging Charge'

  const couponDiscount = appliedCoupon ? appliedCoupon.discountAmount : 0
  const activeSubtotal = Math.max(0, combinedAdjustedSubtotal - couponDiscount)
  const deliveryFee = activeSubtotal < activeThreshold ? deliveryFeeVal : 0
  const total = activeSubtotal + deliveryFee + miscFee

  const hasInventoryIssues = items.some((item) => {
    return (item.product.stock > 0 && item.quantity > item.product.stock) || item.product.stock <= 0 || item.product.isAvailable === false
  })
  
  const isItemClosed = (product: any) => {
    return isProductStoreClosed(
      product,
      { groceryMartOpen, cafeOpen, restaurantOpen, ...settings },
      categoryStatus
    )
  }

  const hasClosedGroceryItems = groceryItems.some(item => isItemClosed(item.product))
  const hasClosedCafeItems = cafeItems.some(item => isItemClosed(item.product))
  const minOrderValue = settings.min_order_value ? parseFloat(settings.min_order_value) : 20
  const isBelowMinOrder = minOrderValue > 0 && subtotal < minOrderValue
  const isCheckoutBlocked = hasClosedGroceryItems || hasClosedCafeItems || hasInventoryIssues || isBelowMinOrder

  const handleRemoveClosedItems = () => {
    let count = 0
    items.forEach((item) => {
      if (isItemClosed(item.product)) {
        removeItem(item.product.id, item.product.name)
        count++
      }
    })
    if (count > 0) {
      toast.success(`${count} closed item(s) removed`)
    }
  }

  const handleAutoAdjust = () => {
    let adjustedCount = 0
    items.forEach((item) => {
      if (item.product.isAvailable === false || item.product.stock <= 0) {
        removeItem(item.product.id, item.product.name)
        adjustedCount++
      } else if (item.product.stock > 0 && item.quantity > item.product.stock) {
        updateQuantity(item.product.id, item.product.name, item.product.stock)
        adjustedCount++
      }
    })
  }

  // Resolve free items from coupon
  const freeItemsMap = useMemo(() => {
    const map = new Map<string, { freeQty: number; badgeText?: string }>()
    if (!appliedCoupon || appliedCoupon.discountAmount <= 0) return map

    // 1. If server explicitly returned freeItems
    if (Array.isArray(appliedCoupon.freeItems) && appliedCoupon.freeItems.length > 0) {
      for (const f of appliedCoupon.freeItems) {
        const targetId = f.productId || f.id
        const matchedItem = items.find((it) => it.product.id === targetId || it.product.id.startsWith(`${targetId}_`) || it.product.name === f.name)
        const key = matchedItem ? matchedItem.product.id : targetId
        if (key) {
          map.set(key, {
            freeQty: f.freeQty || 1,
            badgeText: appliedCoupon.badgeText || (appliedCoupon.discountType === 'BOGO' ? '100% FREE (BOGO)' : 'FREE ITEM'),
          })
        }
      }
    }

    // 2. Fallback client-side matching if server freeItems wasn't received yet or BOGO is active
    if (map.size === 0 && appliedCoupon.discountType === 'BOGO') {
      const qualifyingCafeItems = cafeItems.filter((it) => isProductEligibleForCoupon(it.product, appliedCoupon))
      const totalQualifyingQty = qualifyingCafeItems.reduce((acc, it) => acc + (it.quantity || 1), 0)

      if (appliedCoupon.bogoType === 'BUY_LARGE_GET_SMALL') {
        const rewardVar = (appliedCoupon.rewardVariant || 'small').toLowerCase()
        const smallItems = qualifyingCafeItems.filter((it) => {
          const text = `${it.product.unit || ''} ${it.product.name || ''} ${(it.product as any).selectedVariant || ''}`.toLowerCase()
          return text.includes(rewardVar)
        })
        if (smallItems.length > 0) {
          const sorted = [...smallItems].sort((a, b) => a.product.price - b.product.price)
          map.set(sorted[0].product.id, {
            freeQty: 1,
            badgeText: appliedCoupon.badgeText || '100% FREE (BOGO)',
          })
        }
      } else if (appliedCoupon.bogoType === 'CHEAPEST_FREE' && totalQualifyingQty >= 2) {
        const sorted = [...qualifyingCafeItems].sort((a, b) => a.product.price - b.product.price)
        map.set(sorted[0].product.id, {
          freeQty: 1,
          badgeText: appliedCoupon.badgeText || 'CHEAPEST FREE',
        })
      } else if (appliedCoupon.bogoType === 'SAME_ITEM' || !appliedCoupon.bogoType) {
        for (const it of qualifyingCafeItems) {
          if (appliedCoupon.bogoDishId && (it.product.id === appliedCoupon.bogoDishId || it.product.id.startsWith(`${appliedCoupon.bogoDishId}_`))) {
            map.set(it.product.id, { freeQty: 1, badgeText: appliedCoupon.badgeText || '100% FREE (BOGO)' })
            break
          }
          if (it.quantity >= 2) {
            map.set(it.product.id, { freeQty: Math.floor(it.quantity / 2), badgeText: appliedCoupon.badgeText || '100% FREE (BOGO)' })
            break
          }
        }
      }
    }

    return map
  }, [appliedCoupon, items, cafeItems])

  const renderItemRow = (item: typeof items[0]) => {
    const freeInfo = freeItemsMap.get(item.product.id)
    const isFreeItem = Boolean(freeInfo && freeInfo.freeQty > 0)
    const freeQty = freeInfo ? freeInfo.freeQty : 0
    const isFullyFree = isFreeItem && freeQty >= item.quantity
    const isPartiallyFree = isFreeItem && freeQty > 0 && freeQty < item.quantity

    const perItemSaving = isFullyFree
      ? item.product.price * item.quantity
      : isPartiallyFree
      ? item.product.price * freeQty
      : item.product.mrp > item.product.price
      ? (item.product.mrp - item.product.price) * item.quantity
      : 0

    const isCafe = isCafeProduct(item.product)
    const isStoreClosed = isItemClosed(item.product)

    return (
      <div key={item.product.id} className="mb-3">
        <div className={cn(
          "flex flex-col gap-2 rounded-2xl border p-3.5 transition-all duration-300 relative overflow-hidden",
          isFullyFree
            ? "border-emerald-500/50 bg-gradient-to-r from-emerald-500/10 via-emerald-50/40 to-white dark:from-emerald-950/40 dark:via-emerald-950/20 dark:to-zinc-900 shadow-sm"
            : isPartiallyFree
            ? "border-emerald-500/30 bg-emerald-50/30 dark:bg-emerald-950/20"
            : "border-zinc-100 dark:border-zinc-800/80 bg-zinc-50/50 dark:bg-zinc-900/40"
        )}>
          {/* Free Badge ribbon on top of card */}
          {isFreeItem && (
            <div className="flex items-center justify-between gap-1.5 -mt-0.5 mb-1 pb-1.5 border-b border-emerald-500/20">
              <span className="inline-flex items-center gap-1 text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full bg-emerald-600 text-white shadow-xs">
                <span>🎁</span>
                <span>{freeInfo?.badgeText || '100% FREE (BOGO)'}</span>
              </span>
              <span className="text-[10px] font-black text-emerald-700 dark:text-emerald-300 flex items-center gap-0.5">
                <span>✨</span>
                <span>{isFullyFree ? '100% Free Item Unlocked' : `${freeQty} of ${item.quantity} Free`}</span>
              </span>
            </div>
          )}

          <div className="flex items-center gap-3.5">
            {/* Product image */}
            <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-xl bg-white dark:bg-zinc-900 border border-zinc-100 dark:border-zinc-800/80 overflow-hidden shadow-sm">
              <ProductImage
                src={item.product.imageUrl}
                alt={item.product.name}
                categorySlug={item.product.category?.slug}
                className="h-full w-full object-contain p-1"
              />
            </div>
            
            {/* Product details */}
            <div className="flex-1 min-w-0">
              <h4 className="text-xs sm:text-sm font-bold text-zinc-850 dark:text-zinc-100 line-clamp-2 leading-snug break-words">{item.product.name}</h4>
              <p className="text-[10px] text-zinc-500 font-bold mt-0.5">{item.product.unit}</p>
              {Array.isArray(item.product.selectedAddons) && item.product.selectedAddons.length > 0 && (
                <div className="flex flex-wrap gap-1 mt-1">
                  {item.product.selectedAddons.map((addon) => (
                    <span
                      key={addon.name}
                      className="inline-flex items-center text-[9px] font-bold text-emerald-700 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/40 px-1.5 py-0.5 rounded-md border border-emerald-200 dark:border-emerald-800/40"
                    >
                      +{addon.name} (₹{addon.price})
                    </span>
                  ))}
                </div>
              )}
              <div className="flex items-center gap-2 mt-1.5 flex-wrap">
                {isFullyFree ? (
                  <>
                    <span className="text-xs text-zinc-400 dark:text-zinc-500 line-through font-bold">
                      {formatPrice(item.product.price * item.quantity)}
                    </span>
                    <span className="text-sm sm:text-base font-black text-emerald-600 dark:text-emerald-400 flex items-center gap-1.5 drop-shadow-xs">
                      <span className="text-xs">₹</span>0
                      <span className="text-[10px] font-black uppercase px-2 py-0.5 rounded-md bg-emerald-500/20 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30 shadow-2xs">
                        FREE
                      </span>
                    </span>
                  </>
                ) : isPartiallyFree ? (
                  <>
                    <span className="text-xs text-zinc-400 dark:text-zinc-500 line-through font-bold">
                      {formatPrice(item.product.price * item.quantity)}
                    </span>
                    <span className="text-sm font-black text-emerald-600 dark:text-emerald-400">
                      {formatPrice(item.product.price * (item.quantity - freeQty))}
                    </span>
                    <span className="text-[10px] font-black text-emerald-700 dark:text-emerald-300 bg-emerald-500/15 px-1.5 py-0.5 rounded border border-emerald-500/25">
                      ({freeQty} FREE)
                    </span>
                  </>
                ) : (
                  <>
                    <span className="text-sm font-black text-zinc-850 dark:text-zinc-100">{formatPrice(item.product.price)}</span>
                    {item.product.mrp > item.product.price && (
                      <span className="text-xs text-zinc-400 dark:text-zinc-500 line-through font-semibold">{formatPrice(item.product.mrp)}</span>
                    )}
                  </>
                )}
              </div>
              {/* Per-item savings */}
              {perItemSaving > 0 && (
                <p className="text-[10px] font-extrabold text-emerald-600 dark:text-emerald-400 mt-1 bg-emerald-500/10 dark:bg-emerald-950/40 px-2 py-0.5 rounded-md w-fit border border-emerald-500/20">
                  {isFreeItem ? `🎉 Free Item (${formatPrice(perItemSaving)} saved)` : `Save ${formatPrice(perItemSaving)}`}
                </p>
              )}
              {isStoreClosed ? (
                <p className="text-[9px] font-black text-rose-500 mt-1.5 flex items-center gap-1 leading-none">
                  <span>🏪</span> Closed (Timings: {
                    (item.product.category?.slug === 'restaurant')
                      ? `${formatTime12h(settings.restaurant_open_time)} - ${formatTime12h(settings.restaurant_close_time)}`
                      : `${formatTime12h(settings.cafe_open_time)} - ${formatTime12h(settings.cafe_close_time)}`
                  })
                </p>
              ) : item.product.stock <= 0 || item.product.isAvailable === false ? (
                <p className="text-[9px] font-black text-red-550 mt-1.5 flex items-center gap-1">
                  <span>❌</span> Out of Stock
                </p>
              ) : item.product.stock > 0 && item.quantity > item.product.stock ? (
                <p className="text-[9px] font-black text-amber-600 dark:text-amber-400 mt-1.5 flex items-center gap-1">
                  <span>⚠️</span> Only {item.product.stock} available
                </p>
              ) : null}
            </div>

            {/* Quantity controller */}
            <div className="flex items-center gap-2 rounded-xl bg-white dark:bg-zinc-800 p-1 border border-zinc-200/80 dark:border-zinc-700/80 shadow-2xs">
              <button
                onClick={() => {
                  if (item.quantity === 1) {
                    removeItem(item.product.id, item.product.name)
                  } else {
                    updateQuantity(item.product.id, item.product.name, item.quantity - 1)
                  }
                }}
                className="flex h-7 w-7 items-center justify-center rounded-lg bg-zinc-50 dark:bg-zinc-900 text-zinc-600 dark:text-zinc-300 hover:bg-zinc-100 dark:hover:bg-zinc-800 transition-colors cursor-pointer active:scale-90"
                aria-label="Decrease quantity"
              >
                <Minus size={13} strokeWidth={2.5} />
              </button>
              <span className="w-5 text-center text-xs font-black text-zinc-800 dark:text-zinc-200">
                {item.quantity}
              </span>
              <button
                disabled={(item.product.stock > 0 && item.quantity >= item.product.stock) || isStoreClosed}
                onClick={() => {
                  if (item.product.stock > 0 && item.quantity >= item.product.stock) {
                    toast.error(`Only ${item.product.stock} units available in stock!`)
                    return
                  }
                  updateQuantity(item.product.id, item.product.name, item.quantity + 1)
                }}
                className={cn(
                  "flex h-7 w-7 items-center justify-center rounded-lg bg-primary text-white hover:bg-primary/95 transition-colors cursor-pointer active:scale-90 shadow-2xs",
                  ((item.product.stock > 0 && item.quantity >= item.product.stock) || isStoreClosed) && "opacity-50 cursor-not-allowed bg-zinc-200 dark:bg-zinc-700 text-zinc-400"
                )}
                aria-label="Increase quantity"
              >
                <Plus size={13} strokeWidth={2.5} />
              </button>
            </div>
          </div>

          {/* Cooking instruction field (Only for restaurant / cafe items) */}
          {isCafe && (
            <div className="mt-2 pt-2 border-t border-zinc-100 dark:border-zinc-800/80">
              <input
                type="text"
                defaultValue={item.notes || ''}
                onBlur={(e) => updateItemNotes(item.product.id, e.target.value)}
                placeholder="Cooking instruction (e.g. less sugar, extra spicy)..."
                className="w-full px-3 py-1.5 border border-zinc-200/60 dark:border-zinc-800 rounded-xl text-[10px] bg-white/50 dark:bg-zinc-900/50 focus:outline-none focus:border-primary/45 font-bold"
              />
            </div>
          )}
        </div>
      </div>
    )
  }

  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
  }, [])

  // Prevent body scroll when drawer is open
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => { document.body.style.overflow = '' }
  }, [isOpen])

  if (!mounted) return null

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="fixed inset-0 z-50 bg-black/40 backdrop-blur-sm"
            onClick={() => setCartOpen(false)}
          />

          {/* Drawer */}
          <motion.div
            initial={isMobile ? { y: '100%', x: 0 } : { x: '100%', y: 0 }}
            animate={{ y: 0, x: 0 }}
            exit={isMobile ? { y: '100%', x: 0 } : { x: '100%', y: 0 }}
            transition={{ type: 'spring', damping: 25, stiffness: 220 }}
            drag={isMobile ? "y" : false}
            dragConstraints={{ top: 0, bottom: 0 }}
            dragElastic={{ top: 0.1, bottom: 0.8 }}
            onDragEnd={(e, info) => {
              if (isMobile && info.offset.y > 150) {
                setCartOpen(false)
              }
            }}
            className="gpu-accelerated fixed bottom-0 left-0 right-0 sm:left-auto sm:right-0 sm:top-0 z-50 h-[88vh] max-h-[88dvh] sm:h-full w-full max-w-full sm:w-[420px] bg-white dark:bg-zinc-950 rounded-t-3xl sm:rounded-none shadow-2xl flex flex-col focus:outline-none border-t sm:border-t-0 sm:border-l border-zinc-100 dark:border-zinc-900/50 overflow-visible sm:overflow-x-hidden"
          >
            {/* Swiggy-style Floating Close Button (Mobile Top-Center above bottom sheet) */}
            <button
              type="button"
              onClick={() => {
                triggerHaptic('light')
                setCartOpen(false)
              }}
              className="sm:hidden absolute -top-12 left-1/2 -translate-x-1/2 w-9 h-9 rounded-full bg-zinc-900/90 dark:bg-zinc-800/95 hover:bg-black text-white flex items-center justify-center shadow-xl border border-white/20 active:scale-90 transition-transform cursor-pointer z-50 backdrop-blur-md"
              aria-label="Close cart"
            >
              <X size={18} className="stroke-[2.5]" />
            </button>

            {/* Drag handle for mobile */}
            <div className="flex justify-center py-2.5 sm:hidden cursor-grab active:cursor-grabbing shrink-0">
              <div className="w-12 h-1.5 rounded-full bg-zinc-200 dark:bg-zinc-800" />
            </div>

            {/* Header */}
            <div className="flex items-center justify-between border-b border-zinc-100 dark:border-zinc-900 px-4 sm:px-5 py-3.5 shrink-0 bg-white dark:bg-zinc-950">
              <div className="flex items-center gap-2.5 min-w-0">
                <div className="w-8 h-8 rounded-xl bg-primary/10 text-primary flex items-center justify-center shrink-0">
                  <ShoppingBag size={18} className="stroke-[2.2]" />
                </div>
                <div className="flex items-center gap-2">
                  <h2 className="text-sm sm:text-base font-black text-zinc-900 dark:text-zinc-100">Your Cart</h2>
                  <span className="rounded-full bg-primary/10 text-primary px-2 py-0.5 text-[10px] font-black">
                    {items.reduce((sum, item) => sum + item.quantity, 0)} {items.reduce((sum, item) => sum + item.quantity, 0) === 1 ? 'item' : 'items'}
                  </span>
                </div>
              </div>
              {/* Desktop Header Close Button (Hidden on Mobile, Swiggy-style top-center button used instead) */}
              <button
                type="button"
                onClick={() => setCartOpen(false)}
                className="hidden sm:flex w-8 h-8 rounded-full bg-zinc-100 dark:bg-zinc-850 hover:bg-zinc-200 dark:hover:bg-zinc-800 text-zinc-600 dark:text-zinc-300 items-center justify-center transition-colors cursor-pointer"
                aria-label="Close cart"
              >
                <X size={17} className="stroke-[2.5]" />
              </button>
            </div>

        {/* Free Delivery Tracker Bar */}
        {items.length > 0 && (
          <div className="px-4 py-2 bg-gradient-to-r from-amber-500/10 via-emerald-500/10 to-teal-500/10 border-b border-zinc-100 dark:border-zinc-900/60 shrink-0">
            <div className="flex items-center justify-between text-[10.5px] font-extrabold mb-1">
              <span className="text-zinc-700 dark:text-zinc-300 flex items-center gap-1">
                {activeSubtotal >= activeThreshold ? (
                  <>🎉 <strong className="text-emerald-600 dark:text-emerald-400">FREE Delivery</strong> Unlocked!</>
                ) : (
                  <>🚚 Add <strong className="text-primary">{formatPrice(activeThreshold - activeSubtotal)}</strong> for <strong className="text-emerald-600 dark:text-emerald-400">FREE Delivery</strong></>
                )}
              </span>
              <span className="text-[10px] font-black text-zinc-500 tabular-nums">
                {Math.min(100, Math.round((activeSubtotal / activeThreshold) * 100))}%
              </span>
            </div>
            <div className="w-full h-1.5 bg-zinc-200/80 dark:bg-zinc-800 rounded-full overflow-hidden">
              <div
                className="h-full bg-gradient-to-r from-amber-400 to-emerald-500 rounded-full transition-all duration-500"
                style={{ width: `${Math.min(100, (activeSubtotal / activeThreshold) * 100)}%` }}
              />
            </div>
          </div>
        )}

        {/* Content Area */}
        {items.length === 0 ? (
          <div className="flex flex-1 flex-col items-center justify-center gap-4 p-8">
            <div className="flex h-20 w-20 items-center justify-center rounded-full bg-primary/5 text-primary shadow-inner">
              <ShoppingBag size={40} className="stroke-[1.5]" />
            </div>
            <h3 className="text-base font-extrabold text-zinc-800 dark:text-zinc-200">Your cart is empty</h3>
            <p className="text-xs text-zinc-500 text-center max-w-[240px]">Add items to your cart to see them here</p>
            <button
              onClick={() => setCartOpen(false)}
              className="mt-2 rounded-xl bg-primary px-6 py-2.5 text-xs font-bold text-white hover:bg-primary/95 transition-colors cursor-pointer"
            >
              Start Shopping
            </button>
          </div>
        ) : (
          <>
            <div className="flex-1 overflow-y-auto overflow-x-hidden max-w-full p-4 space-y-4">
              {hasInventoryIssues && (
                <button
                  onClick={handleAutoAdjust}
                  className="w-full text-center text-[10px] font-black text-accent bg-accent/5 hover:bg-accent/10 border border-accent/20 py-2.5 rounded-xl transition-all flex items-center justify-center gap-1 cursor-pointer mb-2 animate-slide-down"
                >
                  🪄 Auto-Adjust Out of Stock Items
                </button>
              )}

              {/* Celebratory Top Banner for Free Item / BOGO / Applied Coupon */}
              {appliedCoupon && (
                <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-emerald-600 via-teal-600 to-emerald-500 p-3.5 text-white shadow-lg shadow-emerald-500/20 animate-in fade-in slide-in-from-top-2 duration-300">
                  <div className="absolute -right-6 -bottom-6 w-24 h-24 bg-white/10 rounded-full blur-xl pointer-events-none" />
                  <div className="relative flex items-center justify-between gap-3">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="w-10 h-10 rounded-xl bg-white/20 backdrop-blur-md flex items-center justify-center text-xl shrink-0 shadow-inner border border-white/25">
                        🎁
                      </div>
                      <div className="min-w-0">
                        <div className="flex items-center gap-1.5 flex-wrap">
                          <span className="text-[10px] uppercase tracking-wider font-black bg-white/25 text-white px-2 py-0.5 rounded-full backdrop-blur-xs">
                            {appliedCoupon.bogoType ? 'BOGO DEAL ACTIVE' : 'COUPON APPLIED'}
                          </span>
                          <span className="text-[10px] font-bold text-emerald-100">
                            ({appliedCoupon.code})
                          </span>
                        </div>
                        <h4 className="text-xs sm:text-sm font-black text-white mt-0.5 leading-tight">
                          {appliedCoupon.bogoType && couponDiscount > 0
                            ? '🎉 1 Free Item Added at ₹0!'
                            : appliedCoupon.bogoType
                            ? '🎁 Buy 1 Get 1 Free Applied!'
                            : `🎉 Saved ₹${couponDiscount.toFixed(0)} on this order!`}
                        </h4>
                        <p className="text-[10px] text-emerald-100/90 font-medium mt-0.5 line-clamp-1">
                          {appliedCoupon.bogoType && couponDiscount > 0
                            ? 'The eligible free deal item below is discounted to ₹0!'
                            : appliedCoupon.nudgeMessage
                            ? appliedCoupon.nudgeMessage
                            : `Enjoy extra savings with code ${appliedCoupon.code}!`}
                        </p>
                      </div>
                    </div>
                    {couponDiscount > 0 && (
                      <div className="text-right shrink-0 bg-white/15 backdrop-blur-md px-2.5 py-1.5 rounded-xl border border-white/20">
                        <span className="text-[9px] uppercase font-black text-emerald-100 block">YOU SAVE</span>
                        <span className="text-sm font-black text-white leading-none">₹{couponDiscount.toFixed(0)}</span>
                      </div>
                    )}
                  </div>
                </div>
              )}

              {/* BOGO Free Gift Card at Top */}
              {appliedCoupon?.freeGiftDetails && (
                <div className="mx-0.5">
                  <BogoCartGiftCard
                    giftItem={appliedCoupon.freeGiftDetails}
                    offerName={appliedCoupon.badgeText || appliedCoupon.code}
                  />
                </div>
              )}

              {/* BOGO Nudge Alert at Top */}
              {appliedCoupon?.nudgeMessage && !appliedCoupon?.freeGiftDetails && (
                <div className="bg-gradient-to-r from-amber-500/15 via-orange-500/10 to-amber-500/15 border border-amber-500/30 rounded-2xl p-3 flex items-center gap-2.5 shadow-xs animate-slide-down">
                  <span className="text-xl animate-pulse shrink-0">🎁</span>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-black text-amber-700 dark:text-amber-300 leading-snug">
                      {appliedCoupon.nudgeMessage}
                    </p>
                    <span className="text-[10px] font-bold text-amber-600/80 dark:text-amber-400/80">
                      Coupon {appliedCoupon.code} applied!
                    </span>
                  </div>
                </div>
              )}

              {/* Grocery Items Section */}
              {groceryItems.length > 0 && (
                <div className="flex flex-col">
                  <div className="flex flex-col px-1 mb-3">
                    <span className="text-xs font-black text-primary flex items-center gap-1.5">
                      📦 Grocery & Daily Essentials
                    </span>
                    <span className="text-[10px] text-zinc-500 font-bold ml-0.5 mt-0.5">
                      Delivered from FastKirana Darkstore
                    </span>
                  </div>
                  <AnimatePresence initial={false}>
                    {groceryItems.map(renderItemRow)}
                  </AnimatePresence>
                </div>
              )}

              {/* Outlet / Cafe / Restaurant Items Section */}
              {cafeItems.length > 0 && (
                (() => {
                  const groups: Record<string, typeof cafeItems> = {}
                  for (const item of cafeItems) {
                    const outlet = getOutletName(item.product)
                    if (!groups[outlet]) groups[outlet] = []
                    groups[outlet].push(item)
                  }

                  return Object.entries(groups).map(([outletName, items]) => {
                    const isWedson = outletName.toLowerCase().includes('wedson')
                    return (
                      <div key={outletName} className="flex flex-col pt-4 border-t border-zinc-100 dark:border-zinc-900">
                        <div className="flex flex-col px-1 mb-3">
                          <span className="text-xs font-black text-rose-600 flex items-center gap-1.5">
                            {isWedson ? '🥘' : '☕'} {outletName}
                          </span>
                          <span className="text-[10px] text-rose-500/80 font-bold ml-0.5 mt-0.5">
                            Freshly prepared at outlet kitchen
                          </span>
                        </div>
                        <AnimatePresence initial={false}>
                          {items.map(renderItemRow)}
                        </AnimatePresence>
                      </div>
                    )
                  })
                })()
              )}

              {/* Smart Add-on Suggestions Horizontal Slider */}
              {recommendations.length > 0 && (
                <div className="mt-4 border-t border-zinc-100 dark:border-zinc-900 pt-3 space-y-2 pb-2">
                  <div className="flex items-center justify-between px-1">
                    <h4 className="text-xs font-black text-zinc-800 dark:text-zinc-200 flex items-center gap-1.5">
                      <span>{cafeItems.length > 0 ? '🥤' : '🛒'}</span>
                      {cafeItems.length > 0 ? 'Complete your meal!' : 'Frequently bought together'}
                    </h4>
                    <div className="flex items-center gap-1">
                      <button
                        type="button"
                        onClick={() => scrollRecommendations('left')}
                        aria-label="Previous suggestions"
                        className="w-5 h-5 rounded-full border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-800 text-zinc-600 dark:text-zinc-300 flex items-center justify-center transition-all cursor-pointer active:scale-90 shadow-2xs"
                      >
                        <ChevronLeft size={12} />
                      </button>
                      <button
                        type="button"
                        onClick={() => scrollRecommendations('right')}
                        aria-label="Next suggestions"
                        className="w-5 h-5 rounded-full border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-800 text-zinc-600 dark:text-zinc-300 flex items-center justify-center transition-all cursor-pointer active:scale-90 shadow-2xs"
                      >
                        <ChevronRight size={12} />
                      </button>
                    </div>
                  </div>

                  <div 
                    ref={recScrollRef}
                    className="flex gap-2.5 overflow-x-auto scrollbar-none py-1 px-1 select-none scroll-smooth"
                    style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
                  >
                    {recommendations.map((prod) => {
                      const isRecCafe = isCafeProduct(prod)
                      const isRecClosed = isRecCafe ? !cafeOpen : !groceryMartOpen
                      return (
                        <div
                          key={prod.id}
                          className="w-[155px] min-[375px]:w-[165px] shrink-0 flex flex-col justify-between rounded-xl border border-zinc-150 dark:border-zinc-850 bg-white dark:bg-zinc-900 p-2.5 hover:border-primary/20 transition-all shadow-2xs"
                        >
                          <div className="flex items-center gap-2">
                            <div className="h-11 w-11 shrink-0 bg-zinc-50 dark:bg-zinc-950 border border-zinc-100 dark:border-zinc-800 rounded-lg overflow-hidden flex items-center justify-center p-1">
                              <ProductImage
                                src={prod.imageUrl}
                                alt={prod.name}
                                categorySlug={prod.category?.slug}
                                className="h-full w-full object-contain"
                              />
                            </div>
                            <div className="flex-1 min-w-0">
                              <p className="text-[10.5px] font-black text-zinc-800 dark:text-zinc-200 line-clamp-2 leading-tight">
                                {prod.name}
                              </p>
                              <p className="text-[9px] text-zinc-400 font-bold mt-0.5">{prod.unit}</p>
                            </div>
                          </div>

                          <div className="flex items-center justify-between mt-2 pt-2 border-t border-zinc-100 dark:border-zinc-800/60">
                            <span className="text-xs font-black text-primary">
                              {formatPrice(prod.price)}
                            </span>
                            {(() => {
                              const isRecSoldOut = (typeof prod.stock === 'number' ? prod.stock : 0) <= 0 || prod.isAvailable === false
                              return (
                                <button
                                  type="button"
                                  disabled={isRecSoldOut || isRecClosed}
                                  onClick={() => {
                                    if (isRecSoldOut) {
                                      toast.error(`Sorry, ${prod.name} is currently out of stock!`)
                                      return
                                    }
                                    if (prod.variants && Array.isArray(prod.variants) && prod.variants.length > 0) {
                                      setActiveVariantProduct(prod)
                                    } else {
                                      addItem({
                                        id: prod.id,
                                        name: prod.name,
                                        slug: prod.slug,
                                        imageUrl: prod.imageUrl,
                                        mrp: prod.mrp,
                                        price: prod.price,
                                        discount: prod.discount,
                                        unit: prod.unit,
                                        stock: prod.stock,
                                        isAvailable: prod.isAvailable ?? true,
                                        category: prod.category,
                                        tags: prod.tags,
                                        restaurantId: (prod as any).restaurantId || (prod as any).restaurant?.id,
                                        restaurantName: (prod as any).restaurantName || (prod as any).restaurant?.name,
                                        restaurant: (prod as any).restaurant,
                                      })
                                    }
                                  }}
                                  className="rounded-lg bg-primary/10 hover:bg-primary text-primary hover:text-white px-2.5 py-1 text-[10px] font-black transition-colors cursor-pointer disabled:bg-zinc-100 dark:disabled:bg-zinc-800 disabled:text-zinc-400 disabled:cursor-not-allowed"
                                >
                                  {isRecSoldOut ? 'Sold Out' : isRecClosed ? 'Closed' : (prod.variants && Array.isArray(prod.variants) && prod.variants.length > 0) ? 'Options' : '+ Add'}
                                </button>
                              )
                            })()}
                          </div>
                        </div>
                      )
                    })}
                  </div>
                </div>
              )}

              {/* Coupon Code Section */}
              <div className="bg-zinc-50 dark:bg-zinc-900 border border-zinc-150 dark:border-zinc-800 p-3.5 rounded-2xl space-y-2 mt-4 mx-1">
                <h4 className="text-xs font-black text-zinc-800 dark:text-zinc-250 flex items-center gap-1.5 leading-none">
                  <span>🎟️</span> Apply Promo / Coupon Code
                </h4>
                {appliedCoupon ? (
                  <div className="flex items-center justify-between border border-accent/20 bg-accent/5 p-2 rounded-xl">
                    <div className="text-left">
                      <div className="flex items-center gap-1.5">
                        <span className="text-[10px] font-black text-accent bg-accent/10 px-2 py-0.5 rounded border border-accent/20">
                          {appliedCoupon.code}
                        </span>
                        {appliedCoupon.bogoType && (
                          <span className="text-[9px] font-black text-emerald-700 dark:text-emerald-300 bg-emerald-500/15 px-1.5 py-0.5 rounded">
                            🎁 BOGO
                          </span>
                        )}
                      </div>
                      <p className="text-[9px] text-accent font-semibold mt-1">
                        {appliedCoupon.bogoType
                          ? `Saved ₹${couponDiscount.toFixed(0)} on free item!`
                          : `Saved ₹${couponDiscount.toFixed(0)}`}
                      </p>
                    </div>
                    <button
                      onClick={handleRemoveCoupon}
                      className="text-[10px] text-red-500 hover:bg-red-500/10 font-bold px-2 py-1 rounded cursor-pointer"
                    >
                      Remove
                    </button>
                  </div>
                ) : (
                  <form onSubmit={handleApplyCoupon} className="flex gap-2">
                    <input
                      ref={couponInputRef}
                      placeholder="Enter Coupon (e.g. CAFE50)"
                      value={couponInput}
                      onChange={(e) => setCouponInput(e.target.value)}
                      className="uppercase w-full px-3 py-1.5 border border-zinc-200 dark:border-zinc-800 rounded-xl text-xs bg-white dark:bg-zinc-900 focus:outline-none focus:border-primary/45 font-bold"
                    />
                    <button
                      type="submit"
                      disabled={isCouponLoading || !couponInput.trim()}
                      className="bg-primary text-white hover:bg-primary/95 text-xs font-black px-4 py-1.5 rounded-xl disabled:opacity-50 cursor-pointer"
                    >
                      {isCouponLoading ? 'Applying...' : 'Apply'}
                    </button>
                  </form>
                )}
              </div>
            </div>

            {/* Sticky Footer Area */}
            <div className="border-t border-zinc-100 dark:border-zinc-900 bg-white dark:bg-zinc-950 p-4 shrink-0" style={{ paddingBottom: 'calc(24px + env(safe-area-inset-bottom, 0px))' }}>
              {/* Expandable Bill details */}
              {showBillDetails && (
                <div className="mb-4 space-y-2 border-b border-zinc-100 dark:border-zinc-900 pb-3.5 animate-slide-down">

                  <div className="flex justify-between text-xs text-zinc-500 font-bold">
                    <span>Items Subtotal</span>
                    <span>{formatPrice(subtotal)}</span>
                  </div>
                  {couponDiscount > 0 && (
                    <div className="flex justify-between text-xs text-emerald-600 dark:text-emerald-450 font-bold">
                      <span>Coupon Applied ({appliedCoupon?.code})</span>
                      <span>-₹{couponDiscount.toFixed(0)}</span>
                    </div>
                  )}
                  <div className="flex justify-between text-xs text-zinc-500 font-bold items-center">
                    <div className="flex flex-col text-left">
                      <span>Delivery Charges</span>
                      <span className="text-[9px] text-zinc-400 font-normal">
                        {deliveryFee === 0 ? `FREE on orders above ₹${activeThreshold}` : `₹${deliveryFee} fee on orders under ₹${activeThreshold}`}
                      </span>
                    </div>
                    <span className={cn(deliveryFee === 0 ? "text-accent font-black text-xs" : "font-bold text-zinc-800 dark:text-zinc-200 text-xs")}>
                      {deliveryFee === 0 ? 'FREE 🎉' : `₹${deliveryFee}`}
                    </span>
                  </div>
                  {miscFee > 0 && (
                    <div className="flex justify-between text-xs text-zinc-500 font-bold items-center">
                      <span>{miscFeeLabel}</span>
                      <span className="font-bold text-zinc-800 dark:text-zinc-200 text-xs">₹{miscFee.toFixed(0)}</span>
                    </div>
                  )}
                </div>
              )}

              {/* Savings reminder badge */}
              {(savings + couponDiscount) > 0 && (
                <div className="flex items-center justify-between rounded-xl bg-emerald-50/60 dark:bg-emerald-950/20 border border-emerald-100/50 dark:border-emerald-900/30 px-3.5 py-2 mb-3.5 animate-pulse-gentle">
                  <span className="text-xs font-extrabold text-[#00b140] flex items-center gap-1.5 leading-none">
                    🎉 You are saving {formatPrice(savings + couponDiscount)} on this order!
                  </span>
                  {couponDiscount > 0 && (
                    <span className="text-[10px] font-black text-emerald-700 dark:text-emerald-300 bg-emerald-500/15 px-2 py-0.5 rounded-full">
                      Incl. ₹{couponDiscount.toFixed(0)} deal
                    </span>
                  )}
                </div>
              )}

              {(hasClosedGroceryItems || hasClosedCafeItems) && (
                <div className="flex flex-col rounded-xl bg-rose-50/60 dark:bg-rose-950/20 border border-rose-100/50 dark:border-rose-900/30 p-3 mb-3.5 text-left">
                  <span className="text-[10px] font-black text-rose-600 flex items-center gap-1 leading-none uppercase tracking-wide">
                    ⚠️ Closed Items in Cart
                  </span>
                  <span className="text-[9px] text-zinc-550 dark:text-zinc-400 font-bold mt-1.5 leading-normal">
                    Some items in your cart cannot be ordered now because the kitchen or store is closed.
                    {cafeItems.some(item => isItemClosed(item.product) && item.product.category?.slug === 'restaurant') && (
                      <strong className="block mt-1 font-extrabold text-red-500">
                        • Restaurant Timings: {formatTime12h(settings.restaurant_open_time)} - {formatTime12h(settings.restaurant_close_time)}
                      </strong>
                    )}
                    {cafeItems.some(item => isItemClosed(item.product) && item.product.category?.slug !== 'restaurant') && (
                      <strong className="block mt-0.5 font-extrabold text-orange-500">
                        • Cafe Timings: {formatTime12h(settings.cafe_open_time)} - {formatTime12h(settings.cafe_close_time)}
                      </strong>
                    )}
                  </span>
                </div>
              )}

              {/* Location unserviceable warning */}
              {!isLocationServiceable && (
                <div className="flex flex-col rounded-xl bg-rose-50/80 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-900/50 p-3 mb-3.5 text-left">
                  <span className="text-[10px] font-black text-rose-600 flex items-center gap-1 leading-none uppercase tracking-wide">
                    🚫 Outside Delivery Zone
                  </span>
                  <span className="text-[10px] text-zinc-600 dark:text-zinc-300 font-medium mt-1 leading-normal">
                    Delivery is currently not available at your detected location. Please change your delivery address to order.
                  </span>
                </div>
              )}

              {/* Main row: price summary + CTA button */}
              <div className="flex items-center justify-between gap-3 sm:gap-4">
                {/* Collapsible Price Summary */}
                <div className="flex flex-col text-left shrink-0">
                  <span className="text-[10px] text-zinc-400 dark:text-zinc-500 font-extrabold uppercase tracking-wider">To Pay</span>
                  <span className="text-xl font-black text-zinc-900 dark:text-zinc-100 leading-tight tabular-nums">
                    {formatPrice(total)}
                  </span>
                  <button
                    onClick={() => setShowBillDetails(!showBillDetails)}
                    className="text-[10.5px] font-black text-emerald-600 dark:text-emerald-400 flex items-center gap-0.5 hover:underline cursor-pointer select-none leading-none mt-1"
                  >
                    <span>{showBillDetails ? 'Hide Bill' : 'View Bill'}</span>
                    {showBillDetails ? <ChevronDown size={11} /> : <ChevronUp size={11} />}
                  </button>
                </div>

                {/* Checkout Button */}
                <div className="flex-1 min-w-0">
                  {hasClosedGroceryItems || hasClosedCafeItems ? (
                    <button
                      type="button"
                      onClick={handleRemoveClosedItems}
                      className="w-full h-12 rounded-2xl bg-amber-500 hover:bg-amber-600 text-white text-[11px] sm:text-xs font-black transition-all flex items-center justify-center gap-1.5 shadow-md active:scale-[0.98] cursor-pointer"
                    >
                      <span>Remove Closed Items &amp; Order</span>
                      <ArrowRight size={14} />
                    </button>
                  ) : hasInventoryIssues ? (
                    <button
                      type="button"
                      onClick={handleAutoAdjust}
                      className="w-full h-12 rounded-2xl bg-amber-500 hover:bg-amber-600 text-white text-[11px] sm:text-xs font-black transition-all flex items-center justify-center gap-1.5 shadow-md active:scale-[0.98] cursor-pointer"
                    >
                      <span>Adjust Stock to Available</span>
                      <ArrowRight size={14} />
                    </button>
                  ) : isBelowMinOrder ? (
                    <button
                      type="button"
                      disabled
                      className="w-full h-12 rounded-2xl bg-zinc-100 dark:bg-zinc-850 text-[11px] sm:text-xs font-black text-zinc-400 dark:text-zinc-500 cursor-not-allowed border border-zinc-200 dark:border-zinc-800 flex items-center justify-center gap-1"
                    >
                      <span>Min. Order ₹{minOrderValue} (Add {formatPrice(minOrderValue - subtotal)})</span>
                    </button>
                  ) : (
                    <Link
                      href="/checkout"
                      prefetch={false}
                      onClick={() => setCartOpen(false)}
                      className="group relative overflow-hidden w-full h-12 rounded-2xl bg-gradient-to-r from-emerald-600 via-emerald-500 to-teal-600 text-white hover:text-white transition-all duration-300 active:scale-[0.98] shadow-lg shadow-emerald-600/25 hover:shadow-xl hover:shadow-emerald-600/40 flex items-center justify-center gap-2 px-5 cursor-pointer hover:scale-[1.01] font-black text-xs sm:text-sm tracking-wide uppercase"
                    >
                      <span>Proceed to Checkout</span>
                      <ArrowRight size={16} className="transition-transform duration-300 ease-out group-hover:translate-x-1" />
                      <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-out pointer-events-none" />
                    </Link>
                  )}
                </div>
              </div>
            </div>
          </>
        )}
      </motion.div>
      </>
    )}
    </AnimatePresence>
  )
}
