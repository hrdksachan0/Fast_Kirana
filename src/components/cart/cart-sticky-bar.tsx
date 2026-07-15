'use client'

import { useCartStore } from '@/stores/cart-store'
import { useUIStore } from '@/stores/ui-store'
import { cn, formatPrice } from '@/lib/utils'
import { FREE_DELIVERY_THRESHOLD } from '@/lib/constants'
import { ShoppingBag, ChevronRight } from 'lucide-react'
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
  const totalItems = useCartStore((s) => s.getTotalItems())

  const toggleCart = useUIStore((s) => s.toggleCart)
  const isCartOpen = useUIStore((s) => s.isCartOpen)
  const [isBouncing, setIsBouncing] = useState(false)

  const router = useRouter()
  const pathname = usePathname()

  // Prefetch checkout page on mount for instant page loading
  useEffect(() => {
    router.prefetch('/checkout')
  }, [router])

  // Listen for cart-bounce event to trigger visual bounce animation
  useEffect(() => {
    const handleBounce = () => {
      setIsBouncing(true)
      setTimeout(() => setIsBouncing(false), 300)
    }
    window.addEventListener('cart-bounce', handleBounce)
    return () => window.removeEventListener('cart-bounce', handleBounce)
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
  const needsForFreeDelivery = FREE_DELIVERY_THRESHOLD - subtotal
  const deliveryProgress = Math.min((subtotal / FREE_DELIVERY_THRESHOLD) * 100, 100)
  const hasFreeDelivery = needsForFreeDelivery <= 0

  return (
    <motion.div
      onClick={() => {
        triggerHaptic('light')
        toggleCart()
      }}
      whileTap={{ scale: 0.98 }}
      className={cn(
        "gpu-accelerated fixed bottom-[90px] left-3.5 right-3.5 z-40 bg-[#097925] text-white rounded-[20px] shadow-[0_8px_25px_rgba(9,121,37,0.2)] border border-white/10 md:hidden animate-slide-up overflow-hidden cursor-pointer select-none flex flex-col",
        isBouncing && "animate-bounce-subtle"
      )}
    >
      {/* Top Edge Progress Bar matching the mockup indicator */}
      <div className="w-full h-1 bg-white/10 overflow-hidden">
        <div
          className="h-full bg-[#facc15] transition-all duration-500"
          style={{ width: `${deliveryProgress}%` }}
        />
      </div>

      {/* Slimmer Spacing Row */}
      <div className="px-3 py-2 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          {/* Shopping Bag Circle Container */}
          <div className="relative w-8 h-8 rounded-full bg-green-950/40 flex items-center justify-center border border-white/10 shrink-0">
            <ShoppingBag className="h-4 w-4 text-white stroke-[2.2]" />
            {/* Red Notification Badge */}
            <span className="absolute -top-0.5 -right-0.5 bg-red-500 text-white text-[8px] font-black w-4 h-4 rounded-full flex items-center justify-center shadow-xs">
              {totalItems}
            </span>
          </div>
          
          {/* Title & Subtitle Stack */}
          <div className="flex flex-col text-left">
            <span className="text-xs font-black text-white leading-tight">
              {totalItems} {totalItems === 1 ? 'Item' : 'Items'} • {formatPrice(subtotal)}
            </span>
            <span className="text-[9px] font-bold text-white/80 leading-tight mt-0.5">
              {hasFreeDelivery 
                ? "Free delivery active!" 
                : `Add ${formatPrice(needsForFreeDelivery)} more for free delivery`}
            </span>
          </div>
        </div>

        {/* View Cart Button Pill */}
        <motion.button
          onClick={(e) => {
            e.stopPropagation()
            triggerHaptic('light')
            toggleCart()
          }}
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          className="bg-white text-[#097925] font-black text-[10px] tracking-wide px-4 py-1.5 rounded-full flex items-center gap-0.5 shadow-xs transition-all cursor-pointer active:scale-95"
        >
          <span>VIEW CART</span>
          <ChevronRight className="h-3 w-3 stroke-[3]" />
        </motion.button>
      </div>
    </motion.div>
  )
}
