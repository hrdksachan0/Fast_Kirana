'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { useSession } from 'next-auth/react'
import { useCart } from '@/hooks/use-cart'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Trash2, Plus, Minus, ArrowRight, Ticket, Loader2, ShoppingBag } from 'lucide-react'
import { ProductImage } from '@/components/product/product-image'
import { FREE_DELIVERY_THRESHOLD, DELIVERY_FEE, TAX_RATE } from '@/lib/constants'
import { toast } from 'sonner'
import { cn, isCafeProduct } from '@/lib/utils'
import { useUIStore } from '@/stores/ui-store'
import { motion, AnimatePresence } from 'framer-motion'

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

  const [couponCode, setCouponCode] = useState('')
  const [appliedCoupon, setAppliedCoupon] = useState<{
    code: string
    discountAmount: number
  } | null>(null)
  const [isCouponLoading, setIsCouponLoading] = useState(false)

  const subtotal = getSubtotal()
  const mrpTotal = getMrpTotal()
  const itemDiscount = getSavings()

  const handleApplyCoupon = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!couponCode.trim()) return

    setIsCouponLoading(true)
    try {
      const res = await fetch('/api/coupons/validate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code: couponCode, subtotal }),
      })

      const data = await res.json()

      if (!res.ok) {
        toast.error(data.error || 'Failed to apply coupon')
      } else {
        setAppliedCoupon({
          code: data.coupon.code,
          discountAmount: data.coupon.discountAmount,
        })
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

  const groceryDeliveryFee = groceryItems.length > 0 && groceryAdjustedSubtotal < FREE_DELIVERY_THRESHOLD ? DELIVERY_FEE : 0
  const cafeDeliveryFee = cafeItems.length > 0 && cafeAdjustedSubtotal < 200 ? 25 : 0

  const deliveryFee = groceryDeliveryFee + cafeDeliveryFee
  const taxes = (groceryAdjustedSubtotal - groceryDiscount) * TAX_RATE + (cafeAdjustedSubtotal - cafeDiscount) * TAX_RATE
  const grandTotal = (groceryAdjustedSubtotal - groceryDiscount) + (cafeAdjustedSubtotal - cafeDiscount) + deliveryFee + taxes

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



  const hasClosedGroceryItems = groceryItems.length > 0 && !groceryMartOpen
  const hasClosedCafeItems = cafeItems.length > 0 && !cafeOpen
  const isCheckoutBlocked = hasClosedGroceryItems || hasClosedCafeItems

  const renderItemRow = (item: typeof items[0]) => {
    const isCafe = isCafeProduct(item.product)
    const isStoreClosed = isCafe ? !cafeOpen : !groceryMartOpen

    return (
      <motion.div
        key={item.product.id}
        layout
        initial={{ height: 0, opacity: 0, scale: 0.95 }}
        animate={{ height: 'auto', opacity: 1, scale: 1 }}
        exit={{ height: 0, opacity: 0, scale: 0.95 }}
        transition={{ duration: 0.15, ease: 'easeOut' }}
        className="overflow-hidden border-b border-border/40 last:border-0"
      >
        <div className="flex items-center gap-2.5 min-[375px]:gap-4 py-3 min-[375px]:py-3.5">
          <div className="relative w-14 h-14 min-[375px]:w-16 min-[375px]:h-16 rounded-xl border border-border bg-muted/20 flex items-center justify-center overflow-hidden shrink-0">
            <ProductImage
              src={item.product.imageUrl}
              alt={item.product.name}
              categorySlug={item.product.category?.slug}
              className="h-full w-full object-contain p-1"
            />
          </div>

          <div className="flex-grow">
            <h3 className="text-xs min-[375px]:text-sm font-bold text-text-primary line-clamp-1">{item.product.name}</h3>
            <p className="text-xs text-text-secondary mt-0.5">{item.product.unit}</p>
            <div className="flex items-center gap-2 mt-1">
              <span className="text-xs min-[375px]:text-sm font-bold text-text-primary">₹{item.product.price}</span>
              {item.product.mrp > item.product.price && (
                <span className="text-xs text-text-muted line-through">₹{item.product.mrp}</span>
              )}
            </div>
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
      </motion.div>
    )
  }

  return (
    <div className="container mx-auto px-2 min-[375px]:px-4 py-4 min-[375px]:py-6 max-w-7xl">
      <h1 className="text-lg min-[375px]:text-xl md:text-2xl font-black text-text-primary mb-4 md:mb-6">Review Cart Items</h1>
      
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 md:gap-8">
        {/* Left: Items list */}
        <div className="lg:col-span-2 space-y-5 md:space-y-6">
          {/* Grocery Section */}
          {groceryItems.length > 0 && (
            <div className="bg-card border border-border p-3.5 min-[375px]:p-5 rounded-2xl shadow-sm space-y-3.5 sm:space-y-4">
              <div className="flex flex-col border-b border-border/40 pb-3">
                <h2 className="text-base font-black text-primary flex items-center gap-1.5">
                  📦 Grocery & Daily Essentials
                </h2>
                <p className="text-xs text-text-muted mt-1 font-bold">
                  Delivered in 10 minutes from FastKirana Darkstore
                </p>
              </div>

              {/* Free delivery indicator progress bar */}
              {groceryItems.length > 0 && (
                <>
                  {groceryAdjustedSubtotal < FREE_DELIVERY_THRESHOLD ? (
                    <div className="rounded-xl bg-accent/5 border border-accent/20 p-3.5 mb-2">
                      <p className="text-xs font-bold text-accent">
                        Shop for ₹{(FREE_DELIVERY_THRESHOLD - groceryAdjustedSubtotal).toFixed(0)} more of groceries to get FREE delivery!
                      </p>
                      <div className="mt-2 h-1.5 rounded-full bg-accent/15 overflow-hidden">
                        <div
                          className="h-full rounded-full bg-accent transition-all duration-500"
                          style={{ width: `${(groceryAdjustedSubtotal / FREE_DELIVERY_THRESHOLD) * 100}%` }}
                        />
                      </div>
                    </div>
                  ) : (
                    <div className="rounded-xl bg-accent/10 border border-accent/30 p-3 text-center mb-2">
                      <p className="text-xs text-accent font-black">
                        🎉 FREE Grocery delivery unlocked!
                      </p>
                    </div>
                  )}
                </>
              )}

              <div className="flex flex-col">
                <AnimatePresence initial={false}>
                  {groceryItems.map(renderItemRow)}
                </AnimatePresence>
              </div>
            </div>
          )}

          {/* Cafe Section */}
          {cafeItems.length > 0 && (
            <div className="bg-card border border-border p-3.5 min-[375px]:p-5 rounded-2xl shadow-sm space-y-3.5 sm:space-y-4">
              <div className="flex flex-col border-b border-border/40 pb-3">
                <h2 className="text-base font-black text-rose-600 flex items-center gap-1.5">
                  ☕ FastKirana Cafe
                </h2>
                <p className="text-xs text-rose-500/80 mt-1 font-bold">
                  Fresh & piping hot snacks and brews prepared in Cafe Kitchen
                </p>
              </div>

              {/* Free delivery indicator progress bar for cafe */}
              {cafeItems.length > 0 && (
                <>
                  {cafeAdjustedSubtotal < 200 ? (
                    <div className="rounded-xl bg-rose-50 dark:bg-rose-950/20 border border-rose-100 dark:border-rose-900/30 p-3.5 mb-2">
                      <p className="text-xs font-bold text-rose-700 dark:text-rose-300">
                        Shop for ₹{(200 - cafeAdjustedSubtotal).toFixed(0)} more from Cafe to get FREE delivery! (Else ₹25 delivery fee applies)
                      </p>
                      <div className="mt-2 h-1.5 rounded-full bg-rose-100 dark:bg-rose-900/40 overflow-hidden">
                        <div
                          className="h-full rounded-full bg-rose-500 transition-all duration-500"
                          style={{ width: `${(cafeAdjustedSubtotal / 200) * 100}%` }}
                        />
                      </div>
                    </div>
                  ) : (
                    <div className="rounded-xl bg-rose-100/60 dark:bg-rose-950/30 border border-rose-200 dark:border-rose-900/30 p-3 text-center mb-2">
                      <p className="text-xs text-rose-700 dark:text-rose-300 font-black">
                        🎉 FREE Cafe delivery unlocked!
                      </p>
                    </div>
                  )}
                </>
              )}

              <div className="flex flex-col">
                <AnimatePresence initial={false}>
                  {cafeItems.map(renderItemRow)}
                </AnimatePresence>
              </div>
            </div>
          )}
        </div>

        {/* Right: Summary and Checkout */}
        <div className="space-y-4">
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
                  className="uppercase h-10 text-xs font-bold"
                />
                <Button
                  type="submit"
                  disabled={isCouponLoading || !couponCode.trim()}
                  className="bg-primary text-white hover:bg-primary/95 text-xs font-bold h-10 px-4"
                >
                  {isCouponLoading ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
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

              <div className="flex justify-between">
                <span className="text-text-secondary">Handling & Delivery</span>
                <span className={cn(deliveryFee === 0 ? "text-accent font-bold" : "")}>
                  {deliveryFee === 0 ? 'FREE' : `₹${deliveryFee}`}
                </span>
              </div>

              <div className="flex justify-between">
                <span className="text-text-secondary">GST / Taxes (5%)</span>
                <span>₹{taxes.toFixed(0)}</span>
              </div>

              <div className="flex justify-between text-base font-black text-text-primary border-t border-border/40 pt-3 mt-3">
                <span>Grand Total</span>
                <span className="text-primary">₹{grandTotal.toFixed(0)}</span>
              </div>
            </div>

            {isCheckoutBlocked && (
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
            <Button
              onClick={handleCheckoutRedirect}
              disabled={isCheckoutBlocked}
              className="w-full bg-accent text-white hover:bg-accent-dark h-12 font-bold rounded-xl text-sm flex items-center justify-center gap-2 pt-1 transition-all disabled:bg-muted disabled:text-text-muted disabled:cursor-not-allowed disabled:opacity-75"
            >
              {isCheckoutBlocked ? 'Checkout Blocked (Store Closed)' : 'Confirm and Checkout'}
              <ArrowRight className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </div>
    </div>
  )
}
