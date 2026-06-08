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
    <div className="fixed bottom-[56px] left-0 right-0 z-30 bg-[#f4fbf7] dark:bg-zinc-950 border-t border-[#e2f0e7] dark:border-zinc-800/30 shadow-[0_-4px_12px_rgba(0,0,0,0.03)] md:hidden animate-slide-up">
      {/* Integrated delivery progress bar at top edge */}
      {!isB2BMode && !hasFreeDelivery && (
        <div className="w-full h-0.5 bg-[#e2f0e7] dark:bg-zinc-800/30">
          <div
            className="h-full bg-[#00b140] transition-all duration-500"
            style={{ width: `${deliveryProgress}%` }}
          />
        </div>
      )}

      {/* Main content row */}
      <div className="flex items-center justify-between px-3.5 py-2">
        <div className="flex items-center gap-3">
          {/* Cart Icon Container with Red Badge */}
          <div onClick={toggleCart} className="relative h-9 w-9 bg-[#00b140]/10 dark:bg-emerald-950/20 text-[#00b140] rounded-full flex items-center justify-center cursor-pointer shrink-0">
            <ShoppingBag className="h-4.5 w-4.5 stroke-[2.2]" />
            <span className="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-primary text-[8px] font-black text-white shadow-sm border border-white dark:border-zinc-950">
              {totalItems}
            </span>
          </div>

          {/* Pricing and Savings details */}
          <div className="text-left flex flex-col justify-center">
            <span className="text-[11px] font-black text-zinc-800 dark:text-zinc-100 leading-tight">
              {totalItems} {totalItems === 1 ? 'Item' : 'Items'} • {formatPrice(total)}
            </span>
            {savings > 0 && !isB2BMode ? (
              <span className="text-[9px] font-black text-[#00b140] leading-none mt-0.5 animate-pulse-gentle">
                You save {formatPrice(savings)} on this order
              </span>
            ) : !isB2BMode && !hasFreeDelivery ? (
              <span className="text-[9px] font-bold text-zinc-500 leading-none mt-0.5">
                Add {formatPrice(needsForFreeDelivery)} for free delivery
              </span>
            ) : (
              <span className="text-[9px] font-bold text-zinc-500 leading-none mt-0.5">
                Free delivery on this order
              </span>
            )}
          </div>
        </div>

        {/* View Cart Button */}
        <button
          onClick={toggleCart}
          className="bg-[#00b140] hover:bg-[#009b35] text-white text-[11px] font-black px-4 py-2 rounded-xl flex items-center gap-1.5 shadow-md shadow-emerald-500/10 active:scale-95 transition-all cursor-pointer"
        >
          View Cart
          <ArrowRight className="h-3 w-3 stroke-[2.5]" />
        </button>
      </div>
    </div>
  )
}
