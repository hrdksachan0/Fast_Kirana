'use client'

import { useState, useEffect, useMemo } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { useSession } from 'next-auth/react'
import { useCart } from '@/hooks/use-cart'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Trash2, Plus, Minus, ArrowRight, Ticket, Loader2, ShoppingBag, ChevronsRight } from 'lucide-react'
import { ProductImage } from '@/components/product/product-image'
import { GROCERY_FREE_DELIVERY_THRESHOLD, CAFE_FREE_DELIVERY_THRESHOLD, COMBINED_FREE_DELIVERY_THRESHOLD, DELIVERY_FEE, TAX_RATE, MIN_CART_VALUE, getOutletName } from '@/lib/constants'
import { toast } from 'sonner'
import { cn, isCafeProduct, isProductStoreClosed } from '@/lib/utils'
import { useUIStore } from '@/stores/ui-store'
import { useCartStore } from '@/stores/cart-store'
import { motion, AnimatePresence } from 'framer-motion'
import { CartConflictDialog } from '@/components/cart/cart-conflict-dialog'
import { BogoCartGiftCard } from '@/components/cart/bogo-cart-gift-card'

export default function CartPage() {
  const { data: session } = useSession()
  const router = useRouter()
  const {
    items,
    updateQuantity,
    removeItem,
    getSubtotal,
    getMrpTotal,
    getSavings,
  } = useCart()

  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const restaurantOpen = useUIStore((s) => s.restaurantOpen)
  const categoryStatus = useUIStore((s) => s.categoryStatus) || {}

  const [taxRate, setTaxRate] = useState(TAX_RATE)
  const [miscFee, setMiscFee] = useState(0)
  const [miscFeeLabel, setMiscFeeLabel] = useState('Miscellaneous Additions')

  useEffect(() => {
    fetch('/api/settings', { cache: 'no-store' })
      .then(res => res.json())
      .then(data => {
        if (data.tax_rate !== undefined) {
          setTaxRate(data.tax_rate)
        }
        if (data.misc_fee !== undefined) {
          setMiscFee(parseFloat(data.misc_fee))
        }
        if (data.misc_fee_label !== undefined) {
          setMiscFeeLabel(data.misc_fee_label)
        }
      })
      .catch(err => console.error('Error fetching settings in cart page:', err))
  }, [])

  const appliedCouponCode = useCartStore((s) => s.appliedCouponCode)
  const setAppliedCouponCode = useCartStore((s) => s.setAppliedCouponCode)

  const [couponCode, setCouponCode] = useState('')
  const [appliedCoupon, setAppliedCoupon] = useState<{
    code: string
    discountAmount: number
    discountType?: string
    bogoType?: string
    badgeText?: string
    freeGiftDetails?: {
      id: string
      name: string
      price: number
      imageUrl?: string | null
      rewardVariant?: string
    }
    nudgeMessage?: string
    freeItems?: Array<{
      id: string
      productId?: string
      name: string
      freeQty: number
      price: number
    }>
    rewardVariant?: string
    triggerVariant?: string
    bogoDishId?: string
  } | null>(null)
  const [isCouponLoading, setIsCouponLoading] = useState(false)

  const subtotal = getSubtotal()
  const mrpTotal = getMrpTotal()
  const itemDiscount = getSavings()

  const formatItemsForCoupon = (cartItems: any[]) => {
    return cartItems.map((i) => {
      const p = i.product || {}
      return {
        id: p.id || i.productId || i.id,
        productId: p.id || i.productId || i.id,
        name: p.name || i.name,
        price: Number(p.price) || Number(i.price) || 0,
        categoryId: p.category?.id || p.categoryId || (i as any).categoryId,
        restaurantId: p.restaurantId || (p.restaurant as any)?.id || (i as any).restaurantId || null,
        menuSection: p.menuSection || (i as any).menuSection || null,
        tags: p.tags || (i as any).tags || [],
        quantity: i.quantity || 1,
        selectedVariant: (p as any).selectedVariant || (i as any).selectedVariant || (p as any).unit || (i as any).unit || null,
        variant: (p as any).variant || (i as any).variant || (p as any).unit || (i as any).unit || null,
        unit: (p as any).unit || (i as any).unit || null,
      }
    })
  }

  // Auto-validate or auto-apply coupon when cart items or subtotal change
  useEffect(() => {
    if (items.length === 0) {
      setAppliedCoupon(null)
      setAppliedCouponCode(null)
      return
    }

    const payloadItems = formatItemsForCoupon(items)

    // 1. If coupon code is already applied, re-validate against current items
    if (appliedCouponCode) {
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
          if (data?.coupon) {
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

    // 2. If NO coupon code is applied, check for active auto-apply coupons!
    const restId = payloadItems.find((it) => it.restaurantId)?.restaurantId || null
    const url = restId ? `/api/coupons?restaurantId=${restId}` : '/api/coupons'

    fetch(url)
      .then((res) => (res.ok ? res.json() : []))
      .then(async (coupons: any[]) => {
        const autoCoupons = (coupons || []).filter((c: any) => c.autoApply && c.isActive)
        for (const c of autoCoupons) {
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
                if (data.coupon.discountAmount > 0) {
                  toast.success(`⚡ Offer "${data.coupon.code}" auto-applied! You saved ₹${data.coupon.discountAmount.toFixed(0)}`, {
                    icon: '🎉',
                  })
                }
                break
              }
            }
          } catch {}
        }
      })
      .catch(() => {})
  }, [appliedCouponCode, items.length, subtotal])

  const handleApplyCoupon = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!couponCode.trim()) return

    setIsCouponLoading(true)
    try {
      const payloadItems = formatItemsForCoupon(items)
      const res = await fetch('/api/coupons/validate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          code: couponCode,
          subtotal,
          items: payloadItems,
        }),
      })

      const data = await res.json()

      if (!res.ok) {
        toast.error(data.error || 'Failed to apply coupon')
      } else {
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
    setCouponCode('')
    toast.success('Coupon removed')
  }

  const promoDiscount = appliedCoupon ? appliedCoupon.discountAmount : 0

  const groceryItems = items.filter(item => !isCafeProduct(item.product))
  const cafeItems = items.filter(item => isCafeProduct(item.product))

  const grocerySubtotal = groceryItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0)
  const cafeSubtotal = cafeItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0)

  const groceryB2BDiscount = 0
  const cafeB2BDiscount = 0

  const groceryAdjustedSubtotal = grocerySubtotal - groceryB2BDiscount
  const cafeAdjustedSubtotal = cafeSubtotal - cafeB2BDiscount
  const b2bDiscount = groceryB2BDiscount + cafeB2BDiscount

  const groceryDiscount = subtotal > 0 ? (grocerySubtotal / subtotal) * promoDiscount : 0
  const cafeDiscount = subtotal > 0 ? (cafeSubtotal / subtotal) * promoDiscount : 0

  const settings = useUIStore((s) => s.settings) || {}
  const groceryThreshold = settings.grocery_free_delivery_threshold ? parseFloat(settings.grocery_free_delivery_threshold) : GROCERY_FREE_DELIVERY_THRESHOLD
  const cafeThreshold = settings.cafe_free_delivery_threshold ? parseFloat(settings.cafe_free_delivery_threshold) : CAFE_FREE_DELIVERY_THRESHOLD
  const combinedThreshold = settings.combined_free_delivery_threshold ? parseFloat(settings.combined_free_delivery_threshold) : COMBINED_FREE_DELIVERY_THRESHOLD
  const deliveryFeeVal = settings.delivery_fee ? parseFloat(settings.delivery_fee) : DELIVERY_FEE

  const activeThreshold = (groceryItems.length > 0 && cafeItems.length > 0)
    ? combinedThreshold
    : (cafeItems.length > 0 ? cafeThreshold : groceryThreshold)

  const activeSubtotal = (groceryAdjustedSubtotal - groceryDiscount) + (cafeAdjustedSubtotal - cafeDiscount)
  const deliveryFee = activeSubtotal < activeThreshold ? deliveryFeeVal : 0
  const taxes = (groceryAdjustedSubtotal - groceryDiscount) * taxRate + (cafeAdjustedSubtotal - cafeDiscount) * taxRate
  const grandTotal = activeSubtotal + deliveryFee + taxes + miscFee

  const handleCheckoutRedirect = () => {
    if (session) {
      router.push('/checkout')
    } else {
      router.push('/login?callbackUrl=/checkout')
    }
  }

  if (items.length === 0) {
    return (
      <div className="container mx-auto px-4 py-16 text-center max-w-md space-y-6">
        <div className="flex h-24 w-24 items-center justify-center rounded-full bg-primary/5 text-primary shadow-inner mx-auto">
          <ShoppingBag size={48} className="stroke-[1.5]" />
        </div>
        <div>
          <h1 className="text-xl font-extrabold text-text-primary">Your cart is empty</h1>
          <p className="text-xs text-text-secondary mt-1">
            Fill it with fresh fruits, dairy, snacks, and daily essentials from our local stores.
          </p>
        </div>
        <Link href="/" className="inline-block bg-primary text-white px-6 py-3 rounded-xl font-bold hover:bg-primary-dark transition-all">
          Explore Products
        </Link>
      </div>
    )
  }

  const hasInventoryIssues = items.some(
    (item) => item.quantity > item.product.stock || item.product.stock <= 0 || item.product.isAvailable === false
  )
  const isItemClosed = (product: any) => {
    return isProductStoreClosed(
      product,
      { groceryMartOpen, cafeOpen, restaurantOpen, ...settings },
      categoryStatus
    )
  }

  const hasClosedGroceryItems = groceryItems.some(item => isItemClosed(item.product))
  const hasClosedCafeItems = cafeItems.some(item => isItemClosed(item.product))
  const isBelowMinOrder = false
  const isCheckoutBlocked = hasClosedGroceryItems || hasClosedCafeItems || hasInventoryIssues

  const handleAutoAdjust = () => {
    let adjustedCount = 0
    items.forEach((item) => {
      if (item.product.isAvailable === false || item.product.stock <= 0) {
        removeItem(item.product.id, item.product.name)
        adjustedCount++
      } else if (item.quantity > item.product.stock) {
        updateQuantity(item.product.id, item.product.name, item.product.stock)
        adjustedCount++
      }
    })
    if (adjustedCount > 0) {
      toast.success(`Automatically adjusted ${adjustedCount} item(s) to match available stock!`, {
        id: 'cart-auto-adjust-success',
      })
    }
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
      if (appliedCoupon.bogoType === 'BUY_LARGE_GET_SMALL') {
        const rewardVar = (appliedCoupon.rewardVariant || 'small').toLowerCase()
        const smallItems = cafeItems.filter((it) => {
          const text = `${it.product.unit || ''} ${it.product.name || ''} ${(it.product as any).selectedVariant || ''}`.toLowerCase()
          return text.includes(rewardVar)
        })
        if (smallItems.length > 0) {
          const sorted = [...smallItems].sort((a, b) => a.product.price - b.product.price)
          map.set(sorted[0].product.id, {
            freeQty: 1,
            badgeText: '100% FREE (BOGO)',
          })
        }
      } else if (appliedCoupon.bogoType === 'CHEAPEST_FREE' && cafeItems.length >= 2) {
        const sorted = [...cafeItems].sort((a, b) => a.product.price - b.product.price)
        map.set(sorted[0].product.id, {
          freeQty: 1,
          badgeText: 'CHEAPEST FREE',
        })
      } else if (appliedCoupon.bogoType === 'SAME_ITEM' || !appliedCoupon.bogoType) {
        for (const it of cafeItems) {
          if (appliedCoupon.bogoDishId && (it.product.id === appliedCoupon.bogoDishId || it.product.id.startsWith(`${appliedCoupon.bogoDishId}_`))) {
            map.set(it.product.id, { freeQty: 1, badgeText: '100% FREE (BOGO)' })
            break
          }
          if (it.quantity >= 2) {
            map.set(it.product.id, { freeQty: Math.floor(it.quantity / 2), badgeText: '100% FREE (BOGO)' })
            break
          }
        }
      }
    }

    return map
  }, [appliedCoupon, items, cafeItems])

  const renderItemRow = (item: typeof items[0]) => {
    const isStoreClosed = isItemClosed(item.product)

    const isOOS = item.product.stock <= 0 || item.product.isAvailable === false
    const isExceeded = item.quantity > item.product.stock && !isOOS

    const freeInfo = freeItemsMap.get(item.product.id)
    const isFreeItem = Boolean(freeInfo && freeInfo.freeQty > 0)
    const freeQty = freeInfo ? freeInfo.freeQty : 0
    const isFullyFree = isFreeItem && freeQty >= item.quantity
    const isPartiallyFree = isFreeItem && freeQty > 0 && freeQty < item.quantity
    const perItemSaving = isFullyFree ? (item.product.price * item.quantity) : isPartiallyFree ? (item.product.price * freeQty) : 0

    return (
      <motion.div
        key={item.product.id}
        layout
        initial={{ height: 0, opacity: 0, scale: 0.95 }}
        animate={{ height: 'auto', opacity: 1, scale: 1 }}
        exit={{ height: 0, opacity: 0, scale: 0.95 }}
        transition={{ duration: 0.15, ease: 'easeOut' }}
        className={cn(
          "overflow-hidden border-b border-border/40 last:border-0 rounded-2xl transition-all duration-300",
          isFullyFree && "bg-gradient-to-r from-emerald-500/10 via-emerald-500/5 to-transparent border border-emerald-500/30 p-2 sm:p-2.5 my-1.5 shadow-xs"
        )}
      >
        <div className="flex flex-col w-full">
          {/* Top badge if free */}
          {isFreeItem && (
            <div className="flex items-center gap-1.5 mb-1.5">
              <span className="inline-flex items-center gap-1 text-[10px] font-black uppercase tracking-wider text-emerald-700 dark:text-emerald-300 bg-emerald-500/15 border border-emerald-500/25 px-2 py-0.5 rounded-md shadow-2xs animate-pulse-gentle">
                🎁 {freeInfo?.badgeText || '100% FREE WITH BOGO'}
              </span>
              <span className="text-[10px] font-bold text-emerald-600 dark:text-emerald-400">
                (Price cut to ₹0)
              </span>
            </div>
          )}

          <div className="flex items-center gap-2.5 min-[375px]:gap-4 py-2 min-[375px]:py-2.5">
            <div className="relative w-14 h-14 min-[375px]:w-16 min-[375px]:h-16 rounded-xl border border-border bg-muted/20 flex items-center justify-center overflow-hidden shrink-0">
              <ProductImage
                src={item.product.imageUrl}
                alt={item.product.name}
                categorySlug={item.product.category?.slug}
                className="h-full w-full object-contain p-1"
              />
              {isFullyFree && (
                <div className="absolute top-1 left-1 bg-emerald-600 text-white text-[8px] font-black uppercase px-1 py-0.5 rounded shadow-xs leading-none">
                  FREE
                </div>
              )}
            </div>

            <div className="flex-grow min-w-0">
              <h3 className="text-xs min-[375px]:text-sm font-bold text-text-primary line-clamp-1">{item.product.name}</h3>
              <p className="text-xs text-text-secondary mt-0.5">{item.product.unit}</p>
              
              <div className="flex items-center gap-2 mt-1 flex-wrap">
                {isFullyFree ? (
                  <>
                    <span className="text-xs text-text-muted line-through font-bold">
                      ₹{(item.product.price * item.quantity).toFixed(0)}
                    </span>
                    <span className="text-xs min-[375px]:text-sm font-black text-emerald-600 dark:text-emerald-400 flex items-center gap-1 drop-shadow-xs">
                      ₹0
                      <span className="text-[9px] font-black uppercase px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30">
                        FREE
                      </span>
                    </span>
                  </>
                ) : isPartiallyFree ? (
                  <>
                    <span className="text-xs text-text-muted line-through font-bold">
                      ₹{(item.product.price * item.quantity).toFixed(0)}
                    </span>
                    <span className="text-xs min-[375px]:text-sm font-black text-emerald-600 dark:text-emerald-400">
                      ₹{(item.product.price * (item.quantity - freeQty)).toFixed(0)}
                    </span>
                    <span className="text-[9px] font-black text-emerald-700 dark:text-emerald-300 bg-emerald-500/15 px-1.5 py-0.5 rounded border border-emerald-500/25">
                      ({freeQty} FREE)
                    </span>
                  </>
                ) : (
                  <>
                    <span className="text-xs min-[375px]:text-sm font-bold text-text-primary">₹{item.product.price}</span>
                    {item.product.mrp > item.product.price && (
                      <span className="text-xs text-text-muted line-through">₹{item.product.mrp}</span>
                    )}
                  </>
                )}
              </div>

              {perItemSaving > 0 && (
                <p className="text-[10px] font-black text-emerald-600 dark:text-emerald-400 mt-1">
                  🎉 Free Item (₹{perItemSaving.toFixed(0)} saved)
                </p>
              )}
            </div>

            <div className="flex flex-col items-end gap-3 shrink-0">
              <button
                onClick={() => removeItem(item.product.id, item.product.name)}
                className="text-text-muted hover:text-danger p-1 rounded hover:bg-danger/10 transition-colors"
                aria-label="Delete item"
              >
                <Trash2 className="h-4 w-4" />
              </button>

              <div className="flex h-8 w-24 items-center justify-between rounded-lg bg-accent text-white font-bold shadow-sm">
                <button
                  onClick={() => updateQuantity(item.product.id, item.product.name, item.quantity - 1)}
                  className="flex h-full w-8 items-center justify-center hover:bg-accent-dark rounded-l-lg transition-colors"
                >
                  <Minus className="h-3.5 w-3.5" />
                </button>
                <span className="text-xs select-none">{item.quantity}</span>
                <button
                  onClick={() => updateQuantity(item.product.id, item.product.name, item.quantity + 1)}
                  disabled={isStoreClosed || item.quantity >= item.product.stock}
                  className="flex h-full w-8 items-center justify-center hover:bg-accent-dark rounded-r-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <Plus className="h-3.5 w-3.5" />
                </button>
              </div>
            </div>
          </div>

          {/* Dynamic stock validation warnings inside the row */}
          <AnimatePresence>
            {isOOS && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                className="mb-3 bg-red-500/10 border border-red-500/20 text-red-500 dark:text-red-400 text-[10px] font-bold px-3 py-1.5 rounded-xl flex items-center gap-1.5"
              >
                <span>❌</span> Out of stock — please remove this item to checkout.
              </motion.div>
            )}
            {isExceeded && (
              <motion.div
                initial={{ height: 0, opacity: 0 }}
                animate={{ height: 'auto', opacity: 1 }}
                exit={{ height: 0, opacity: 0 }}
                className="mb-3 bg-amber-500/10 border border-amber-500/20 text-amber-600 dark:text-amber-400 text-[10px] font-bold px-3 py-1.5 rounded-xl flex items-center gap-1.5"
              >
                <span>⚠️</span> Only {item.product.stock} units available in stock.
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </motion.div>
    )
  }

  return (
    <div className="container mx-auto px-2 min-[375px]:px-4 py-4 min-[375px]:py-6 max-w-7xl">
      <CartConflictDialog />
      <div className="flex flex-wrap items-center justify-between gap-3 mb-4 md:mb-6">
        <h1 className="text-lg min-[375px]:text-xl md:text-2xl font-black text-text-primary">Review Cart Items</h1>
        {hasInventoryIssues && (
          <button
            onClick={handleAutoAdjust}
            className="text-xs font-bold text-accent bg-accent/10 hover:bg-accent hover:text-white px-3 py-1.5 rounded-xl border border-accent/20 transition-all flex items-center gap-1 cursor-pointer"
          >
            🪄 Auto-Adjust Cart Quantities
          </button>
        )}
      </div>
      
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 md:gap-8">
        {/* Left: Items list */}
        <div className="lg:col-span-2 space-y-5 md:space-y-6">
          {/* Celebratory Top Banner for Free Item / BOGO / Applied Coupon */}
          {appliedCoupon && (
            <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-emerald-600 via-teal-600 to-emerald-500 p-4 text-white shadow-lg shadow-emerald-500/20 animate-in fade-in slide-in-from-top-2 duration-300">
              <div className="absolute -right-6 -bottom-6 w-32 h-32 bg-white/10 rounded-full blur-2xl pointer-events-none" />
              <div className="relative flex items-center justify-between gap-4">
                <div className="flex items-center gap-3.5 min-w-0">
                  <div className="w-12 h-12 rounded-2xl bg-white/20 backdrop-blur-md flex items-center justify-center text-2xl shrink-0 shadow-inner border border-white/25">
                    🎁
                  </div>
                  <div className="min-w-0">
                    <div className="flex items-center gap-1.5 flex-wrap">
                      <span className="text-[10px] uppercase tracking-wider font-black bg-white/25 text-white px-2.5 py-0.5 rounded-full backdrop-blur-xs">
                        {appliedCoupon.bogoType ? 'BOGO FREE DEAL ACTIVE' : 'PROMO APPLIED'}
                      </span>
                      <span className="text-xs font-bold text-emerald-100">
                        ({appliedCoupon.code})
                      </span>
                    </div>
                    <h3 className="text-sm sm:text-base font-black text-white mt-1 leading-tight">
                      {appliedCoupon.bogoType && promoDiscount > 0
                        ? '🎉 1 Free Item Added at ₹0!'
                        : appliedCoupon.bogoType
                        ? '🎁 Buy 1 Get 1 Free Deal Applied!'
                        : `🎉 Saved ₹${promoDiscount.toFixed(0)} on this order!`}
                    </h3>
                    <p className="text-xs text-emerald-100/90 font-medium mt-0.5">
                      {appliedCoupon.bogoType && promoDiscount > 0
                        ? 'The eligible free deal item below is discounted to ₹0!'
                        : appliedCoupon.nudgeMessage
                        ? appliedCoupon.nudgeMessage
                        : `Enjoy extra savings with code ${appliedCoupon.code}!`}
                    </p>
                  </div>
                </div>
                {promoDiscount > 0 && (
                  <div className="text-right shrink-0 bg-white/15 backdrop-blur-md px-3 py-2 rounded-xl border border-white/20">
                    <span className="text-[10px] uppercase font-black text-emerald-100 block">YOU SAVE</span>
                    <span className="text-base sm:text-lg font-black text-white leading-none">₹{promoDiscount.toFixed(0)}</span>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Grocery Section */}
          {groceryItems.length > 0 && (
            <div className="bg-card border border-border p-3.5 min-[375px]:p-5 rounded-2xl shadow-sm space-y-3.5 sm:space-y-4">
              <div className="flex flex-col border-b border-border/40 pb-3">
                <h2 className="text-base font-black text-primary flex items-center gap-1.5">
                  📦 Grocery & Daily Essentials
                </h2>
                <p className="text-xs text-text-muted mt-1 font-bold">
                  Delivered from FastKirana Darkstore
                </p>
              </div>

              <div className="flex flex-col">
                <AnimatePresence initial={false}>
                  {groceryItems.map(renderItemRow)}
                </AnimatePresence>
              </div>
            </div>
          )}

          {/* Outlet / Cafe / Restaurant Section */}
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
                  <div key={outletName} className="bg-card border border-border p-3.5 min-[375px]:p-5 rounded-2xl shadow-sm space-y-3.5 sm:space-y-4">
                    <div className="flex flex-col border-b border-border/40 pb-3">
                      <h2 className="text-base font-black text-rose-600 flex items-center gap-1.5">
                        {isWedson ? '🥘' : '☕'} {outletName}
                      </h2>
                      <p className="text-xs text-rose-500/80 mt-1 font-bold">
                        Fresh & piping hot items prepared at outlet kitchen
                      </p>
                    </div>

                    <div className="flex flex-col">
                      <AnimatePresence initial={false}>
                        {items.map(renderItemRow)}
                      </AnimatePresence>
                    </div>
                  </div>
                )
              })
            })()
          )}
        </div>

        {/* Right: Summary and Checkout */}
        <div className="space-y-4">
          {/* BOGO Free Gift Card */}
          {appliedCoupon?.freeGiftDetails && (
            <BogoCartGiftCard
              giftItem={appliedCoupon.freeGiftDetails}
              offerName={appliedCoupon.badgeText || appliedCoupon.code}
            />
          )}

          {/* BOGO Nudge Alert */}
          {appliedCoupon?.nudgeMessage && !appliedCoupon?.freeGiftDetails && (
            <div className="bg-gradient-to-r from-amber-500/15 via-orange-500/10 to-amber-500/15 border border-amber-500/30 rounded-2xl p-3 flex items-center gap-2.5 shadow-xs animate-slide-down">
              <span className="text-xl animate-bounce">🎁</span>
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

          {/* Coupon entry */}
          <div className="bg-card border border-border p-3.5 min-[375px]:p-4 rounded-2xl shadow-sm space-y-3">
            <h2 className="text-sm font-bold text-text-primary flex items-center gap-2">
              <Ticket className="h-4 w-4 text-primary" />
              Apply Coupon Code
            </h2>
            
            {appliedCoupon ? (
              <div className="flex items-center justify-between border border-accent/30 bg-accent/5 p-3 rounded-xl">
                <div>
                  <span className="text-xs font-black text-accent bg-accent/10 px-2.5 py-0.5 rounded border border-accent/20">
                    {appliedCoupon.code}
                  </span>
                  <p className="text-[10px] text-accent font-semibold mt-1">Saved ₹{appliedCoupon.discountAmount.toFixed(0)}</p>
                </div>
                <Button
                  onClick={handleRemoveCoupon}
                  variant="ghost"
                  className="text-xs text-danger hover:text-danger hover:bg-danger/10 px-2 h-7"
                >
                  Remove
                </Button>
              </div>
            ) : (
              <form onSubmit={handleApplyCoupon} className="flex gap-2">
                <Input
                  placeholder="e.g. WELCOME50"
                  value={couponCode}
                  onChange={(e) => setCouponCode(e.target.value)}
                  disabled={isCouponLoading}
                  className="uppercase h-10 text-xs font-bold"
                />
                <Button
                  type="submit"
                  disabled={isCouponLoading || !couponCode.trim()}
                  className="bg-primary text-white hover:bg-primary/95 text-xs font-bold h-10 px-4 min-w-[80px]"
                >
                  {isCouponLoading ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin mr-1" />
                      Checking
                    </>
                  ) : (
                    'Apply'
                  )}
                </Button>
              </form>
            )}
          </div>

          {/* Bill summary list */}
          <div className="bg-card border border-border p-3.5 min-[375px]:p-5 rounded-2xl shadow-sm space-y-3.5 sm:space-y-4">
            <h2 className="text-base font-bold text-text-primary border-b border-border/40 pb-2.5">
              Bill Summary
            </h2>
            
            <div className="space-y-2 text-xs font-semibold">
              <div className="flex justify-between">
                <span className="text-text-secondary">Item Total (MRP)</span>
                <span>₹{mrpTotal.toFixed(0)}</span>
              </div>
              
              {itemDiscount > 0 && (
                <div className="flex justify-between text-accent font-bold">
                  <span>Product Discount</span>
                  <span>-₹{itemDiscount.toFixed(0)}</span>
                </div>
              )}



              {appliedCoupon && (
                <div className="flex justify-between text-accent font-bold">
                  <span>Coupon Discount ({appliedCoupon.code})</span>
                  <span>-₹{promoDiscount.toFixed(0)}</span>
                </div>
              )}

              <div className="flex justify-between items-center">
                <div className="flex flex-col text-left">
                  <span className="text-text-secondary">Delivery Charges</span>
                  <span className="text-[10px] text-text-muted">
                    {deliveryFee === 0 ? `FREE on orders above ₹${activeThreshold}` : `₹${deliveryFee} fee on orders under ₹${activeThreshold}`}
                  </span>
                </div>
                <span className={cn(deliveryFee === 0 ? "text-accent font-black text-xs" : "font-bold text-text-primary text-xs")}>
                  {deliveryFee === 0 ? 'FREE 🎉' : `₹${deliveryFee}`}
                </span>
              </div>

              {taxRate > 0 && (
                <div className="flex justify-between">
                  <span className="text-text-secondary">GST / Taxes ({Math.round(taxRate * 100)}%)</span>
                  <span>₹{taxes.toFixed(0)}</span>
                </div>
              )}

              {miscFee > 0 && (
                <div className="flex justify-between">
                  <span className="text-text-secondary">{miscFeeLabel}</span>
                  <span>₹{miscFee.toFixed(0)}</span>
                </div>
              )}

              {(itemDiscount + promoDiscount) > 0 && (
                <div className="flex items-center justify-between rounded-xl bg-emerald-50/60 dark:bg-emerald-950/20 border border-emerald-100/50 dark:border-emerald-900/30 px-3 py-2 animate-pulse-gentle">
                  <span className="text-xs font-extrabold text-[#00b140] flex items-center gap-1.5 leading-none">
                    🎉 You are saving ₹{(itemDiscount + promoDiscount).toFixed(0)} on this order!
                  </span>
                  {promoDiscount > 0 && (
                    <span className="text-[10px] font-black text-emerald-700 dark:text-emerald-300 bg-emerald-500/15 px-2 py-0.5 rounded-full">
                      Incl. ₹{promoDiscount.toFixed(0)} deal
                    </span>
                  )}
                </div>
              )}

              <div className="flex justify-between text-base font-black text-text-primary border-t border-border/40 pt-3 mt-3">
                <span>Grand Total</span>
                <span className="text-primary">₹{grandTotal.toFixed(0)}</span>
              </div>
            </div>

            {hasInventoryIssues && (
              <div className="rounded-2xl border border-red-200/40 bg-red-50/30 dark:bg-red-950/20 dark:border-red-800/20 p-4 text-left mb-2 shadow-sm backdrop-blur-md flex gap-3 items-start relative overflow-hidden">
                <span className="text-2xl mt-0.5 select-none shrink-0" role="img" aria-label="Warning">
                  ⚠️
                </span>
                <div className="space-y-1 min-w-0">
                  <h5 className="text-xs font-black text-red-800 dark:text-red-300">
                    Stock Limit Exceeded
                  </h5>
                  <p className="text-[10px] font-bold text-red-700/90 dark:text-red-450/90 leading-normal">
                    Some items in your cart exceed available stock. Please adjust quantities or use the auto-adjust helper to proceed.
                  </p>
                </div>
              </div>
            )}

            {isCheckoutBlocked && (hasClosedGroceryItems || hasClosedCafeItems) && (
              <div className="rounded-2xl border border-amber-200/40 bg-amber-50/30 dark:bg-amber-950/20 dark:border-amber-800/20 p-4 text-left mb-2 shadow-sm backdrop-blur-md flex gap-3 items-start relative overflow-hidden">
                <div className="absolute top-0 right-0 p-1 pointer-events-none opacity-20 text-4xl animate-float">
                  {hasClosedCafeItems ? '☕' : '💤'}
                </div>
                <span className="text-2xl mt-0.5 select-none shrink-0" role="img" aria-label="Store Closed">
                  {hasClosedCafeItems ? '☕' : '💤'}
                </span>
                <div className="space-y-1 min-w-0">
                  <h5 className="text-xs font-black text-amber-800 dark:text-amber-300">
                    Store Temporarily Closed
                  </h5>
                  <p className="text-[10px] font-bold text-amber-700/90 dark:text-amber-400/90 leading-normal">
                    {hasClosedGroceryItems && hasClosedCafeItems ? (
                      'Both our Grocery Mart and Cafe are closed right now. Catalog browsing remains open, but checkout is blocked.'
                    ) : hasClosedGroceryItems ? (
                      'Our Grocery Mart is currently closed for the night. Please remove grocery items to order from the Cafe.'
                    ) : (
                      'Our Cafe kitchen is closed for preparation. Please remove cafe items to order groceries.'
                    )}
                  </p>
                  <p className="text-[9px] font-bold text-amber-600/80 dark:text-amber-500/80">
                    Store Hours: 6:00 AM - 11:59 PM Daily
                  </p>
                </div>
              </div>
            )}

            {/* Confirmation triggers checkout */}
            <button
              type="button"
              onClick={handleCheckoutRedirect}
              disabled={isCheckoutBlocked}
              className={cn(
                "group relative overflow-hidden w-full h-14 bg-gradient-to-r from-accent to-accent-dark text-white rounded-full font-black text-sm sm:text-base tracking-wide uppercase transition-all duration-300 hover:scale-[1.02] active:scale-[0.98] flex items-center justify-center gap-2 shadow-lg shadow-accent/25 hover:shadow-xl hover:shadow-accent/45",
                isCheckoutBlocked && "opacity-60 cursor-not-allowed shadow-none"
              )}
            >
              {hasClosedGroceryItems || hasClosedCafeItems ? (
                'Checkout Blocked (Store Closed)'
              ) : hasInventoryIssues ? (
                'Fix Stock Issues to Checkout'
              ) : isBelowMinOrder ? (
                'Min. Order ₹20 Required'
              ) : (
                <>
                  <span className="relative z-10">Confirm and Checkout</span>
                  <ChevronsRight className="h-4 w-4 text-white relative z-10 transition-transform duration-300 ease-out group-hover:translate-x-1.5" />
                  <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000 ease-out pointer-events-none" />
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
