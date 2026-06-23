'use client'

import { useCartStore } from '@/stores/cart-store'
import { useUIStore } from '@/stores/ui-store'
import { cn, formatPrice } from '@/lib/utils'
import { FREE_DELIVERY_THRESHOLD, DELIVERY_FEE } from '@/lib/constants'
import { ShoppingBag, ArrowRight, Zap, Check } from 'lucide-react'
import { useState, useEffect } from 'react'
import { usePathname, useRouter } from 'next/navigation'
import { motion, useMotionValue, useTransform } from 'framer-motion'

function getDeliveryETA(): string {
  const now = new Date()
  now.setMinutes(now.getMinutes() + 10)
  return now.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true })
}

export function CartStickyBar() {
  const items = useCartStore((s) => s.items)
  const getSubtotal = useCartStore((s) => s.getSubtotal)
  const getSavings = useCartStore((s) => s.getSavings)
  const totalItems = useCartStore((s) => s.getTotalItems())

  const toggleCart = useUIStore((s) => s.toggleCart)
  const isCartOpen = useUIStore((s) => s.isCartOpen)
  const [eta, setEta] = useState(getDeliveryETA)
  const [isBouncing, setIsBouncing] = useState(false)
  const [slideSuccess, setSlideSuccess] = useState(false)

  const router = useRouter()
  const pathname = usePathname()
  
  // Motion values for swipe to checkout interaction
  const x = useMotionValue(0)
  const textOpacity = useTransform(x, [0, 80], [1, 0])

  // Listen for cart-bounce event to trigger visual bounce animation
  useEffect(() => {
    const handleBounce = () => {
      setIsBouncing(true)
      setTimeout(() => setIsBouncing(false), 300)
    }
    window.addEventListener('cart-bounce', handleBounce)
    return () => window.removeEventListener('cart-bounce', handleBounce)
  }, [])

  // Update ETA every minute
  useEffect(() => {
    const interval = setInterval(() => {
      setEta(getDeliveryETA())
    }, 60000)
    return () => clearInterval(interval)
  }, [])

  // Reset slide success state when pathname changes or cart items change
  useEffect(() => {
    setSlideSuccess(false)
    x.set(0)
  }, [pathname, items.length, x])

  // Suppress sticky cart bar on checkout, cart, tracking, login, and worker consoles to prevent overlay clutter
  const isIgnoredPage = !pathname ||
    pathname === '/cart' ||
    pathname.startsWith('/cart/') ||
    pathname.startsWith('/checkout') ||
    pathname.startsWith('/order/') ||
    pathname.startsWith('/login') ||
    pathname.startsWith('/signup') ||
    pathname.startsWith('/admin') ||
    pathname.startsWith('/picker') ||
    pathname.startsWith('/cafe-kitchen') ||
    pathname.startsWith('/delivery')

  if (items.length === 0 || isCartOpen || isIgnoredPage) return null

  const subtotal = getSubtotal()
  const savings = getSavings()
  
  const total = subtotal
  const needsForFreeDelivery = FREE_DELIVERY_THRESHOLD - subtotal
  const deliveryProgress = Math.min((subtotal / FREE_DELIVERY_THRESHOLD) * 100, 100)
  const hasFreeDelivery = needsForFreeDelivery <= 0

  const handleDragEnd = () => {
    // If dragged past threshold, trigger immediate checkout redirect
    if (x.get() > 95) {
      setSlideSuccess(true)
      setTimeout(() => {
        router.push('/checkout')
      }, 200)
    } else {
      // Reset position
      x.set(0)
    }
  }

  return (
    <div className={cn(
      "fixed bottom-[68px] left-3.5 right-3.5 z-40 bg-gradient-to-r from-emerald-600 via-emerald-500 to-[#00b140] text-white rounded-2xl shadow-[0_10px_30px_rgba(0,177,64,0.22)] border border-emerald-400/20 md:hidden animate-slide-up overflow-hidden",
      isBouncing && "animate-bounce-subtle"
    )}>
      {/* Integrated delivery progress bar at top edge */}
      {!hasFreeDelivery && (
        <div className="w-full h-[3px] bg-emerald-700/30">
          <div
            className="h-full bg-white transition-all duration-500"
            style={{ width: `${deliveryProgress}%` }}
          />
        </div>
      )}

      {/* Main content row */}
      <div className="flex items-center justify-between px-3.5 py-2">
        <div className="flex items-center gap-2.5">
          {/* Cart Icon Container */}
          <div onClick={toggleCart} className="relative h-8 w-8 bg-white/20 text-white rounded-lg flex items-center justify-center cursor-pointer shrink-0">
            <ShoppingBag className="h-4.5 w-4.5 stroke-[2]" />
            <span className="absolute -top-0.5 -right-0.5 flex h-3.5 w-3.5 items-center justify-center rounded-full bg-rose-500 text-[8px] font-black text-white shadow-sm border border-emerald-500">
              {totalItems}
            </span>
          </div>

          {/* Pricing and Savings details */}
          <div className="text-left flex flex-col justify-center">
            <span className="text-[11px] font-black text-white leading-tight">
              {totalItems} {totalItems === 1 ? 'Item' : 'Items'} • {formatPrice(total)}
            </span>
            {savings > 0 ? (
              <span className="text-[9px] font-bold text-emerald-100 leading-none mt-0.5 flex items-center gap-1">
                <Zap className="h-2.5 w-2.5 fill-amber-300 stroke-none animate-pulse-gentle" />
                Saved {formatPrice(savings)}
              </span>
            ) : !hasFreeDelivery ? (
              <span className="text-[9px] font-medium text-emerald-100 leading-none mt-0.5">
                Add {formatPrice(needsForFreeDelivery)} for Free
              </span>
            ) : (
              <span className="text-[9px] font-bold text-emerald-100 leading-none mt-0.5">
                🎉 Free Delivery
              </span>
            )}
          </div>
        </div>

        {/* Premium Swipe to Checkout slider */}
        <div className="relative w-[135px] h-8.5 bg-emerald-700/40 rounded-xl border border-white/10 overflow-hidden flex items-center justify-center shrink-0">
          {slideSuccess ? (
            <motion.div
              initial={{ scale: 0.8, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              className="flex items-center gap-1 text-[10px] font-black text-white"
            >
              <Check className="h-3 w-3 stroke-[3]" />
              Processing...
            </motion.div>
          ) : (
            <>
              <motion.span
                style={{ opacity: textOpacity }}
                className="text-[9px] font-black text-white/70 select-none pointer-events-none whitespace-nowrap"
              >
                Swipe to Checkout ➔
              </motion.span>
              <motion.div
                drag="x"
                dragConstraints={{ left: 0, right: 101 }}
                dragElastic={0.05}
                dragMomentum={false}
                style={{ x }}
                onDragEnd={handleDragEnd}
                className="absolute left-0.5 top-0.5 bottom-0.5 w-7.5 bg-white rounded-lg flex items-center justify-center cursor-pointer shadow-md z-10 text-emerald-600 active:scale-95 transition-transform"
              >
                <ArrowRight className="h-3.5 w-3.5 stroke-[3]" />
              </motion.div>
            </>
          )}
        </div>
      </div>
    </div>
  )
}
