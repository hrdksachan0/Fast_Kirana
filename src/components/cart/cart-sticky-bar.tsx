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
  const isB2BMode = useUIStore((s) => s.isB2BMode)
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

  if (items.length === 0 || isCartOpen) return null

  const subtotal = getSubtotal()
  const savings = getSavings()
  
  const b2bDiscount = isB2BMode ? subtotal * 0.1 : 0
  const total = subtotal - b2bDiscount
  const needsForFreeDelivery = FREE_DELIVERY_THRESHOLD - subtotal
  const deliveryProgress = Math.min((subtotal / FREE_DELIVERY_THRESHOLD) * 100, 100)
  const hasFreeDelivery = needsForFreeDelivery <= 0

  return (
    <div className="fixed bottom-[100px] left-4 right-4 z-30 md:hidden animate-slide-up">
      <button
        id="cart-sticky-icon"
        onClick={toggleCart}
        className={cn(
          "w-full bg-gradient-to-r from-accent to-[#00c853] dark:from-emerald-700 dark:to-emerald-600 text-white rounded-2xl shadow-xl flex flex-col overflow-hidden transition-all active:scale-[0.98] cursor-pointer border border-accent-dark/10 dark:border-emerald-500/20",
          isBouncing && "scale-105 shadow-2xl"
        )}
      >
        {/* Integrated delivery progress bar at top edge */}
        {!isB2BMode && !hasFreeDelivery && (
          <div className="w-full h-1 bg-white/20">
            <div
              className="h-full bg-white/70 transition-all duration-500 rounded-r-full"
              style={{ width: `${deliveryProgress}%` }}
            />
          </div>
        )}

        {/* Main content row */}
        <div className="flex items-center justify-between p-3">
          <div className="flex items-center gap-2.5">
            <div className="h-9 w-9 rounded-xl bg-white/20 flex items-center justify-center">
              <ShoppingBag className="h-4.5 w-4.5 text-white" />
            </div>
            <div className="text-left">
              <div className="flex items-center gap-2">
                <span className="text-sm font-black text-white leading-none">
                  {formatPrice(total)}
                </span>
                {isB2BMode && <span className="text-[8px] font-semibold text-white/80 bg-white/15 px-1.5 py-0.5 rounded-full">10% Off</span>}
              </div>
              <span className="text-[10px] font-bold text-white/70 block leading-none mt-1">
                {totalItems} {totalItems === 1 ? 'item' : 'items'}
                {savings > 0 && !isB2BMode && (
                  <> · Saving {formatPrice(savings)}</>
                )}
                {!isB2BMode && !hasFreeDelivery && (
                  <> · Add {formatPrice(needsForFreeDelivery)} for free delivery</>
                )}
                {!isB2BMode && hasFreeDelivery && (
                  <> · Free delivery ✓</>
                )}
              </span>
            </div>
          </div>

          <div className="flex items-center gap-1.5 text-[11px] font-black uppercase tracking-wider bg-white/20 px-3.5 py-2 rounded-xl">
            View Cart
            <ArrowRight className="h-3.5 w-3.5" />
          </div>
        </div>
      </button>
    </div>
  )
}
