'use client'

import { useCartStore } from '@/stores/cart-store'
import { useUIStore } from '@/stores/ui-store'
import { cn, formatPrice } from '@/lib/utils'
import { FREE_DELIVERY_THRESHOLD, DELIVERY_FEE } from '@/lib/constants'
import { ShoppingBag, ArrowRight, Zap } from 'lucide-react'
import { useState, useEffect } from 'react'

import { usePathname } from 'next/navigation'
import { isCafeProduct } from '@/lib/utils'

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

  const pathname = usePathname()

  // Suppress sticky cart bar on checkout, tracking, login, and worker consoles to prevent overlay clutter
  const isIgnoredPage = !pathname ||
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
    <div className="fixed bottom-[68px] left-3.5 right-3.5 z-40 bg-gradient-to-r from-emerald-600 via-emerald-500 to-[#00b140] text-white rounded-2xl shadow-[0_10px_30px_rgba(0,177,64,0.22)] border border-emerald-400/20 md:hidden animate-slide-up overflow-hidden">
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
      <div className="flex items-center justify-between px-4 py-3">
        <div className="flex items-center gap-3">
          {/* Cart Icon Container with White/Emerald Theme */}
          <div onClick={toggleCart} className="relative h-9 w-9 bg-white/20 text-white rounded-xl flex items-center justify-center cursor-pointer shrink-0">
            <ShoppingBag className="h-5 w-5 stroke-[2.2]" />
            <span className="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-rose-500 text-[9px] font-black text-white shadow-sm border border-emerald-500">
              {totalItems}
            </span>
          </div>

          {/* Pricing and Savings details */}
          <div className="text-left flex flex-col justify-center">
            <span className="text-xs font-black text-white leading-tight">
              {totalItems} {totalItems === 1 ? 'Item' : 'Items'} • {formatPrice(total)}
            </span>
            {savings > 0 ? (
              <span className="text-[10px] font-bold text-emerald-100 leading-none mt-0.5 flex items-center gap-1">
                <Zap className="h-3 w-3 fill-amber-300 stroke-none animate-pulse-gentle" />
                Saved {formatPrice(savings)}
              </span>
            ) : !hasFreeDelivery ? (
              <span className="text-[10px] font-medium text-emerald-100 leading-none mt-0.5">
                Add {formatPrice(needsForFreeDelivery)} for Free Delivery
              </span>
            ) : (
              <span className="text-[10px] font-bold text-emerald-100 leading-none mt-0.5">
                🎉 Free Delivery Applied
              </span>
            )}
          </div>
        </div>

        {/* High Contrast Proceed / Checkout Pill */}
        <button
          onClick={toggleCart}
          className="bg-white text-[#00b140] hover:bg-zinc-50 text-[11px] font-black px-4.5 py-2.5 rounded-xl flex items-center gap-1.5 shadow-sm active:scale-95 transition-all cursor-pointer tracking-tight"
        >
          Proceed to Cart
          <ArrowRight className="h-3.5 w-3.5 stroke-[3]" />
        </button>
      </div>
    </div>
  )
}
