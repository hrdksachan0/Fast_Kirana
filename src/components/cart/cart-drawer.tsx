'use client'

import { X, ShoppingBag, Minus, Plus, ArrowRight, ChevronDown, ChevronUp } from 'lucide-react'
import { useCart } from '@/hooks/use-cart'
import { useUIStore } from '@/stores/ui-store'
import { formatPrice } from '@/lib/utils'
import { GROCERY_FREE_DELIVERY_THRESHOLD, CAFE_FREE_DELIVERY_THRESHOLD, COMBINED_FREE_DELIVERY_THRESHOLD, FREE_DELIVERY_THRESHOLD, DELIVERY_FEE } from '@/lib/constants'
import Link from 'next/link'
import { useState, useEffect } from 'react'
import { ProductImage } from '@/components/product/product-image'
import { isCafeProduct, cn } from '@/lib/utils'
import { motion, AnimatePresence } from 'framer-motion'

import { useRouter } from 'next/navigation'
import { useCartStore } from '@/stores/cart-store'
import { toast } from 'sonner'

export function CartDrawer() {
  const router = useRouter()
  const isOpen = useUIStore((s) => s.isCartOpen)
  const setCartOpen = useUIStore((s) => s.setCartOpen)
  const setActiveVariantProduct = useUIStore((s) => s.setActiveVariantProduct)

  // Prefetch checkout page on drawer open for instant transitions
  useEffect(() => {
    if (isOpen) {
      router.prefetch('/checkout')
    }
  }, [isOpen, router])

  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const restaurantOpen = useUIStore((s) => s.restaurantOpen)
  const categoryStatus = useUIStore((s) => s.categoryStatus) || {}
  
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

  const handleApplyCoupon = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!couponInput.trim()) return

    setIsCouponLoading(true)
    try {
      const res = await fetch('/api/coupons/validate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          code: couponInput.trim().toUpperCase(),
          subtotal,
          items: items.map(i => ({
            id: i.product.id,
            price: i.product.price,
            categoryId: i.product.category?.id,
            quantity: i.quantity
          }))
        }),
      })

      const data = await res.json()

      if (!res.ok) {
        toast.error(data.error || 'Failed to apply coupon')
      } else {
        setAppliedCoupon({
          code: data.coupon.code,
          discountAmount: data.coupon.discountAmount,
        })
        setAppliedCouponCode(data.coupon.code)
        toast.success(`Coupon "${data.coupon.code}" applied! You saved ₹${data.coupon.discountAmount.toFixed(0)}`)
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
    if (!isOpen) return
    
    // Fetch products from database to suggest cheap quick-add items
    fetch('/api/products?limit=20')
      .then((res) => res.json())
      .then((data) => {
        if (data.products) {
          const inCartIds = new Set(items.map((i) => i.product.id))
          const upsellCandidates = data.products.filter(
            (p: any) => !inCartIds.has(p.id) && p.price < 100 && p.isAvailable
          )
          setRecommendations(upsellCandidates.slice(0, 4))
        }
      })
      .catch((err) => console.error('Failed to fetch upsell products:', err))
  }, [isOpen, items])

  const groceryItems = items.filter((item) => !isCafeProduct(item.product))
  const cafeItems = items.filter((item) => isCafeProduct(item.product))

  const subtotal = getSubtotal()

  // Auto-validate coupon on cart drawer load
  useEffect(() => {
    if (appliedCouponCode && items.length > 0 && !appliedCoupon) {
      fetch('/api/coupons/validate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          code: appliedCouponCode,
          subtotal,
          items: items.map(i => ({
            id: i.product.id,
            price: i.product.price,
            categoryId: i.product.category?.id,
            quantity: i.quantity
          }))
        })
      })
      .then(res => {
        if (res.ok) return res.json()
        throw new Error('Invalid')
      })
      .then(data => {
        setAppliedCoupon({
          code: data.coupon.code,
          discountAmount: data.coupon.discountAmount,
        })
      })
      .catch(() => {
        setAppliedCouponCode(null)
        setAppliedCoupon(null)
      })
    } else if (!appliedCouponCode) {
      setAppliedCoupon(null)
    }
  }, [appliedCouponCode, items.length, subtotal])
  const savings = getSavings()

  const grocerySubtotal = groceryItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0)
  const cafeSubtotal = cafeItems.reduce((sum, item) => sum + item.product.price * item.quantity, 0)

  const groceryAdjustedSubtotal = grocerySubtotal
  const cafeAdjustedSubtotal = cafeSubtotal
  const combinedAdjustedSubtotal = groceryAdjustedSubtotal + cafeAdjustedSubtotal

  const settings = useUIStore((s) => s.settings) || {}

  // In the cart drawer, delivery is FREE when minimum order for zone is met.
  const deliveryFee = 0

  const couponDiscount = appliedCoupon ? appliedCoupon.discountAmount : 0
  const total = Math.max(0, combinedAdjustedSubtotal - couponDiscount) + deliveryFee

  const hasInventoryIssues = items.some((item) => {
    const limit = isCafeProduct(item.product) ? 10 : 5
    return item.quantity > item.product.stock || item.product.stock <= 0 || item.product.isAvailable === false || item.quantity > limit
  })
  const isItemClosed = (product: any) => {
    const isCafe = product.category?.slug === 'cafe' || product.tags?.includes('cafe')
    const isRestaurant = product.category?.slug === 'restaurant' || product.tags?.includes('restaurant')
    const categorySlug = product.category?.slug || ''
    const isCatOpen = categoryStatus[categorySlug] !== false
    if (isCafe) return !cafeOpen || !isCatOpen
    if (isRestaurant) return !restaurantOpen || !isCatOpen
    return !groceryMartOpen || !isCatOpen
  }

  const hasClosedGroceryItems = groceryItems.some(item => isItemClosed(item.product))
  const hasClosedCafeItems = cafeItems.some(item => isItemClosed(item.product))
  const isBelowMinOrder = subtotal < 20
  const isCheckoutBlocked = hasClosedGroceryItems || hasClosedCafeItems || hasInventoryIssues || isBelowMinOrder

  const handleAutoAdjust = () => {
    let adjustedCount = 0
    items.forEach((item) => {
      const limit = isCafeProduct(item.product) ? 10 : 5
      if (item.product.isAvailable === false || item.product.stock <= 0) {
        removeItem(item.product.id, item.product.name)
        adjustedCount++
      } else if (item.quantity > limit) {
        updateQuantity(item.product.id, item.product.name, Math.min(item.product.stock, limit))
        adjustedCount++
      } else if (item.quantity > item.product.stock) {
        updateQuantity(item.product.id, item.product.name, Math.min(item.product.stock, limit))
        adjustedCount++
      }
    })
  }

  const renderItemRow = (item: typeof items[0]) => {
    const perItemSaving = item.product.mrp > item.product.price
      ? (item.product.mrp - item.product.price) * item.quantity
      : 0

    const isCafe = isCafeProduct(item.product)
    const isStoreClosed = isItemClosed(item.product)

    return (
      <motion.div
        key={item.product.id}
        layout
        initial={{ height: 0, opacity: 0, marginBottom: 0 }}
        animate={{ height: 'auto', opacity: 1, marginBottom: 12 }}
        exit={{ height: 0, opacity: 0, marginBottom: 0 }}
        transition={{ duration: 0.15, ease: 'easeOut' }}
        className="overflow-hidden"
      >
        <div className="flex flex-col gap-2 rounded-2xl border border-zinc-100 dark:border-zinc-800/80 bg-zinc-50/50 dark:bg-zinc-900/40 p-3.5 transition-all duration-300">
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
              <h4 className="text-xs sm:text-sm font-bold text-zinc-850 dark:text-zinc-100 truncate leading-snug">{item.product.name}</h4>
              <p className="text-[10px] text-zinc-500 font-bold mt-0.5">{item.product.unit}</p>
              <div className="flex items-center gap-2 mt-1.5">
                <span className="text-sm font-black text-zinc-850 dark:text-zinc-100">{formatPrice(item.product.price)}</span>
                {item.product.mrp > item.product.price && (
                  <span className="text-xs text-zinc-400 dark:text-zinc-500 line-through font-semibold">{formatPrice(item.product.mrp)}</span>
                )}
              </div>
              {/* Per-item savings */}
              {perItemSaving > 0 && (
                <p className="text-[10px] font-extrabold text-accent mt-1 bg-accent/5 px-2 py-0.5 rounded-md w-fit">
                  Save {formatPrice(perItemSaving)}
                </p>
              )}
              {item.product.stock <= 0 || item.product.isAvailable === false ? (
                <p className="text-[9px] font-black text-red-550 mt-1.5 flex items-center gap-1">
                  <span>❌</span> Out of Stock
                </p>
              ) : item.quantity > (isCafe ? 10 : 5) ? (
                <p className="text-[9px] font-black text-red-550 mt-1.5 flex items-center gap-1">
                  <span>⚠️</span> Max limit is {isCafe ? 10 : 5} units
                </p>
              ) : item.quantity > item.product.stock ? (
                <p className="text-[9px] font-black text-amber-600 dark:text-amber-400 mt-1.5 flex items-center gap-1">
                  <span>⚠️</span> Only {item.product.stock} available
                </p>
              ) : null}
            </div>

            {/* Quantity controller */}
            <div className="flex items-center bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-full p-1 shadow-sm shrink-0">
              <button
                onClick={() => updateQuantity(item.product.id, item.product.name, item.quantity - 1)}
                className="flex h-8 w-8 items-center justify-center text-zinc-600 dark:text-zinc-400 hover:bg-zinc-100 dark:hover:bg-zinc-800 rounded-full transition-colors cursor-pointer"
                aria-label="Decrease quantity"
              >
                <Minus size={14} className="stroke-[2.5]" />
              </button>
              <span className="w-6 text-center text-xs font-black text-zinc-850 dark:text-zinc-100">
                {item.quantity}
              </span>
              <button
                onClick={() => updateQuantity(item.product.id, item.product.name, item.quantity + 1)}
                disabled={isStoreClosed || item.quantity >= item.product.stock || item.quantity >= (isCafe ? 10 : 5)}
                className="flex h-8 w-8 items-center justify-center text-primary hover:bg-zinc-100 dark:hover:bg-zinc-800 rounded-full transition-colors disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                aria-label="Increase quantity"
              >
                <Plus size={14} className="stroke-[2.5]" />
              </button>
            </div>
          </div>

          {/* Cooking Instructions Notes for Cafe Items */}
          {isCafe && (
            <div className="mt-1 border-t border-zinc-100/50 dark:border-zinc-850/10 pt-2 shrink-0">
              <input
                type="text"
                value={item.notes || ''}
                onChange={(e) => updateItemNotes(item.product.id, e.target.value)}
                placeholder="Cooking instruction (e.g. less sugar, extra spicy)..."
                className="w-full px-3 py-1.5 border border-zinc-200/60 dark:border-zinc-800 rounded-xl text-[10px] bg-white/50 dark:bg-zinc-900/50 focus:outline-none focus:border-primary/45 font-bold"
              />
            </div>
          )}
        </div>
      </motion.div>
    )
  }

  // Prevent body scroll when drawer is open
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => { document.body.style.overflow = '' }
  }, [isOpen])

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
            className="gpu-accelerated fixed bottom-0 left-0 right-0 sm:left-auto sm:right-0 sm:top-0 z-50 h-[85vh] sm:h-full w-full sm:w-[420px] bg-white dark:bg-zinc-950 rounded-t-3xl sm:rounded-none shadow-2xl flex flex-col focus:outline-none border-t sm:border-t-0 sm:border-l border-zinc-100 dark:border-zinc-900/50"
          >
            {/* Drag handle for mobile */}
            <div className="flex justify-center py-2.5 sm:hidden cursor-grab active:cursor-grabbing shrink-0">
              <div className="w-12 h-1.5 rounded-full bg-zinc-200 dark:bg-zinc-800" />
            </div>
        {/* Header */}
        <div className="flex items-center justify-between border-b border-zinc-100 dark:border-zinc-900 px-5 py-4 shrink-0">
          <div className="flex items-center gap-2">
            <ShoppingBag size={20} className="text-primary" />
            <h2 className="text-base font-black text-zinc-850 dark:text-zinc-100">Your Cart</h2>
            <span className="rounded-full bg-primary/10 px-2 py-0.5 text-xs font-black text-primary">
              {items.reduce((sum, item) => sum + item.quantity, 0)} items
            </span>
          </div>
          <button
            onClick={() => setCartOpen(false)}
            className="rounded-lg p-2 hover:bg-zinc-100 dark:hover:bg-zinc-900 transition-colors cursor-pointer"
            aria-label="Close cart"
          >
            <X size={20} className="text-zinc-500" />
          </button>
        </div>

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
            <div className="flex-1 overflow-y-auto p-4 space-y-4">
              {hasInventoryIssues && (
                <button
                  onClick={handleAutoAdjust}
                  className="w-full text-center text-[10px] font-black text-accent bg-accent/5 hover:bg-accent/10 border border-accent/20 py-2.5 rounded-xl transition-all flex items-center justify-center gap-1 cursor-pointer mb-2 animate-slide-down"
                >
                  🪄 Auto-Adjust Out of Stock Items
                </button>
              )}
              {/* Premium Distance & Delivery Banner */}
              <div className="rounded-2xl bg-gradient-to-br from-emerald-50 to-teal-50/60 dark:from-emerald-950/20 dark:to-teal-950/10 border border-emerald-200/60 dark:border-emerald-900/40 p-3.5 mb-3 shadow-sm">
                <div className="flex items-center gap-2 border-b border-emerald-200/50 dark:border-emerald-900/30 pb-2 mb-2">
                  <span className="text-sm">🚚</span>
                  <p className="text-xs font-black text-emerald-800 dark:text-emerald-300">
                    Distance Delivery Zones (FREE Delivery 🎉)
                  </p>
                </div>
                  <div className="grid grid-cols-1 gap-1.5 text-[11px] font-bold text-emerald-900 dark:text-emerald-200">
                  <div className="flex items-center justify-between bg-white/70 dark:bg-zinc-900/60 px-2.5 py-1.5 rounded-lg border border-emerald-100 dark:border-emerald-900/30">
                    <span>📍 0–2 km</span>
                    <span className="font-extrabold text-emerald-600 dark:text-emerald-400">FREE on ₹199+ (else ₹25)</span>
                  </div>
                  <div className="flex items-center justify-between bg-white/70 dark:bg-zinc-900/60 px-2.5 py-1.5 rounded-lg border border-emerald-100 dark:border-emerald-900/30">
                    <span>📍 2–3 km</span>
                    <span className="font-extrabold text-emerald-600 dark:text-emerald-400">FREE on ₹249+ (else ₹35)</span>
                  </div>
                  <div className="flex items-center justify-between bg-white/70 dark:bg-zinc-900/60 px-2.5 py-1.5 rounded-lg border border-emerald-100 dark:border-emerald-900/30 opacity-70">
                    <span>📍 3+ km</span>
                    <span className="font-extrabold text-rose-500 dark:text-rose-450">Not Serviceable</span>
                  </div>
                </div>
              </div>

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

              {/* Cafe Items Section */}
              {cafeItems.length > 0 && (
                <div className="flex flex-col pt-4 border-t border-zinc-100 dark:border-zinc-900">
                  <div className="flex flex-col px-1 mb-3">
                    <span className="text-xs font-black text-rose-600 flex items-center gap-1.5">
                      ☕ FastKirana Cafe
                    </span>
                    <span className="text-[10px] text-rose-500/80 font-bold ml-0.5 mt-0.5">
                      Freshly prepared in Cafe Kitchen
                    </span>
                  </div>
                  <AnimatePresence initial={false}>
                    {cafeItems.map(renderItemRow)}
                  </AnimatePresence>
                </div>
              )}

              {/* Smart Add-on Suggestions */}
              {deliveryFee > 0 && recommendations.length > 0 && (
                <div className="mt-6 border-t border-zinc-100 dark:border-zinc-900 pt-4 space-y-3 pb-4">
                  <h4 className="text-xs font-black text-zinc-800 dark:text-zinc-200 flex items-center gap-1.5 px-1">
                    <span>💡</span> Add items to unlock FREE Delivery
                  </h4>
                  <div className="grid grid-cols-2 gap-2">
                    {recommendations.map((prod) => {
                      const isRecCafe = isCafeProduct(prod)
                      const isRecClosed = isRecCafe ? !cafeOpen : !groceryMartOpen
                      return (
                        <div
                          key={prod.id}
                          className="flex items-center gap-2 rounded-xl border border-zinc-100 dark:border-zinc-900 bg-zinc-50/20 dark:bg-zinc-900/10 p-2 hover:border-primary/10 transition-all shadow-[0_2px_8px_rgba(0,0,0,0.01)]"
                        >
                          <div className="h-10 w-10 shrink-0 bg-white dark:bg-zinc-900 border border-zinc-100 dark:border-zinc-800 rounded-lg overflow-hidden flex items-center justify-center">
                            <ProductImage
                              src={prod.imageUrl}
                              alt={prod.name}
                              categorySlug={prod.category?.slug}
                              className="h-full w-full object-contain p-1"
                            />
                          </div>
                          <div className="flex-1 min-w-0 text-left">
                            <p className="text-[10px] font-black text-zinc-800 dark:text-zinc-250 truncate leading-tight">
                              {prod.name}
                            </p>
                            <p className="text-[9px] text-zinc-500 font-bold mt-0.5">{prod.unit}</p>
                            <p className="text-[10px] font-black text-primary mt-0.5">
                              {formatPrice(prod.price)}
                            </p>
                          </div>
                          <button
                            type="button"
                            disabled={isRecClosed}
                            onClick={() => {
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
                                })
                              }
                            }}
                            className="shrink-0 rounded-lg bg-primary/10 hover:bg-primary text-primary hover:text-white px-2 py-1 text-[9px] font-black transition-colors cursor-pointer disabled:bg-zinc-100 dark:disabled:bg-zinc-800 disabled:text-zinc-400 disabled:cursor-not-allowed"
                          >
                            {isRecClosed ? 'Closed' : (prod.variants && Array.isArray(prod.variants) && prod.variants.length > 0) ? 'Options' : '+ Add'}
                          </button>
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
                      <span className="text-[10px] font-black text-accent bg-accent/10 px-2 py-0.5 rounded border border-accent/20">
                        {appliedCoupon.code}
                      </span>
                      <p className="text-[9px] text-accent font-semibold mt-1">Saved ₹{couponDiscount.toFixed(0)}</p>
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
            <div className="border-t border-zinc-100 dark:border-zinc-900 bg-white dark:bg-zinc-950 p-4 pb-6 shrink-0">
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
                        FREE when minimum order is met
                      </span>
                    </div>
                    <span className="text-accent font-black text-xs">
                      FREE 🎉
                    </span>
                  </div>
                </div>
              )}

              {/* Savings reminder badge */}
              {savings > 0 && (
                <div className="flex items-center justify-between rounded-xl bg-emerald-50/60 dark:bg-emerald-950/20 border border-emerald-100/50 dark:border-emerald-900/30 px-3.5 py-2 mb-3.5 animate-pulse-gentle">
                  <span className="text-xs font-extrabold text-[#00b140] flex items-center gap-1.5 leading-none">
                    🎉 You are saving {formatPrice(savings)} on this order!
                  </span>
                </div>
              )}

              {isBelowMinOrder && (
                <div className="flex items-center justify-between rounded-xl bg-rose-50/60 dark:bg-rose-950/20 border border-rose-100/50 dark:border-rose-900/30 px-3.5 py-2 mb-3.5">
                  <span className="text-[10px] font-black text-rose-600 flex items-center gap-1.5 leading-none">
                    🛍️ Add ₹{20 - subtotal} more to place order (Min. ₹20)
                  </span>
                </div>
              )}

              {/* Main row: price summary + CTA button */}
              <div className="flex items-center justify-between gap-4">
                {/* Collapsible Price Summary */}
                <div className="flex flex-col text-left">
                  <span className="text-[10px] text-zinc-400 dark:text-zinc-500 font-extrabold uppercase tracking-wider">Total Bill</span>
                  <span className="text-lg font-black text-zinc-800 dark:text-zinc-100 leading-tight">
                    {formatPrice(total)}
                  </span>
                  <button
                    onClick={() => setShowBillDetails(!showBillDetails)}
                    className="text-[10px] font-extrabold text-[#00b140] flex items-center gap-0.5 hover:underline cursor-pointer select-none leading-none mt-1"
                  >
                    <span>{showBillDetails ? 'Hide Details' : 'View Bill'}</span>
                    {showBillDetails ? <ChevronDown size={10} /> : <ChevronUp size={10} />}
                  </button>
                </div>

                {/* Checkout Button */}
                <div className="flex-1 max-w-[240px]">
                  {isCheckoutBlocked ? (
                    <button
                      disabled
                      className="w-full h-12 rounded-full bg-zinc-100 dark:bg-zinc-800 text-[11px] sm:text-xs font-black text-zinc-400 dark:text-zinc-500 cursor-not-allowed border border-zinc-200 dark:border-zinc-700/50 flex items-center justify-center gap-1"
                    >
                      {hasClosedGroceryItems || hasClosedCafeItems ? (
                        <>Closed Items <ArrowRight size={14} /></>
                      ) : hasInventoryIssues ? (
                        <>Fix Stock <ArrowRight size={14} /></>
                      ) : (
                        <>Min. Order ₹20 <ArrowRight size={14} /></>
                      )}
                    </button>
                  ) : (
                    <Link
                      href="/checkout"
                      onClick={() => setCartOpen(false)}
                      className="group relative overflow-hidden w-full h-12 rounded-full bg-gradient-to-r from-accent to-accent-dark text-sm sm:text-base font-black text-white hover:text-white transition-all duration-300 active:scale-[0.97] shadow-lg shadow-accent/15 hover:shadow-xl hover:shadow-accent/30 flex items-center justify-center gap-1.5 cursor-pointer hover:scale-[1.03]"
                    >
                      <span className="relative z-10">Checkout</span>
                      <ArrowRight size={16} className="relative z-10 transition-transform duration-300 ease-out group-hover:translate-x-1.5" />
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
