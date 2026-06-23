'use client'

import { useCartStore } from '@/stores/cart-store'
import { useUIStore } from '@/stores/ui-store'
import { cn, formatPrice } from '@/lib/utils'
import { FREE_DELIVERY_THRESHOLD, DELIVERY_FEE } from '@/lib/constants'
import { ShoppingBag, ArrowRight, Zap, Check } from 'lucide-react'
import { useState, useEffect } from 'react'
import { usePathname, useRouter } from 'next/navigation'
import { motion } from 'framer-motion'
import { triggerHaptic } from '@/lib/haptic'

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

  const router = useRouter()
  const pathname = usePathname()

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

        {/* Premium Checkout Button */}
        <motion.button
          onClick={() => {
            triggerHaptic('light')
            router.push('/checkout')
          }}
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          className="bg-white text-emerald-600 font-extrabold text-[11px] px-4.5 py-2.5 rounded-xl flex items-center gap-1 shadow-[0_8px_20px_rgba(0,0,0,0.1)] active:scale-95 transition-all cursor-pointer tracking-wider uppercase border border-white/10 hover:shadow-lg"
        >
          <span>Checkout</span>
          <ArrowRight className="h-3.5 w-3.5 stroke-[3] animate-pulse" />
        </motion.button>
      </div>
    </div>
  )
}
