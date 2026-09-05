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

import { formatOrderTime, addMinutesTo } from '@/lib/date-helpers'

function getDeliveryETA(): string {
  const etaDate = addMinutesTo(new Date(), 10)
  return formatOrderTime(etaDate)
}

export function CartStickyBar() {
  const items = useCartStore((s) => s.items)
  const getSubtotal = useCartStore((s) => s.getSubtotal)
  const totalItems = useCartStore((s) => s.getTotalItems())

  const toggleCart = useUIStore((s) => s.toggleCart)
  const isCartOpen = useUIStore((s) => s.isCartOpen)
  const isTabBarVisible = useUIStore((s) => s.isTabBarVisible)
  const isLocationServiceable = useUIStore((s) => s.isLocationServiceable)
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

  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
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

  if (!mounted || items.length === 0 || isCartOpen || isIgnoredPage) return null

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
      initial={false}
      animate={{
        bottom: isTabBarVisible
          ? 'calc(72px + env(safe-area-inset-bottom, 0px))'
          : 'calc(12px + env(safe-area-inset-bottom, 0px))',
      }}
      transition={{
        duration: 0.28,
        ease: [0.16, 1, 0.3, 1],
      }}
      className={cn(
        "gpu-accelerated fixed left-3.5 right-3.5 z-40 bg-gradient-to-r from-[#e8153a] via-[#ff2d55] to-[#ff4742] backdrop-blur-xl text-white rounded-[20px] shadow-[0_8px_24px_rgba(232,21,58,0.35)] border border-red-300/30 md:hidden animate-slide-up overflow-hidden cursor-pointer select-none flex flex-col",
        isBouncing && "animate-bounce-subtle"
      )}
    >
      {/* Top Edge Progress Bar for Free Delivery */}
      <div className="w-full h-[3px] bg-black/15 overflow-hidden">
        <div
          className="h-full bg-gradient-to-r from-amber-300 via-yellow-300 to-emerald-300 transition-all duration-500 shadow-xs"
          style={{ width: `${deliveryProgress}%` }}
        />
      </div>

      {/* Balanced Cart Content Row */}
      <div className="px-3.5 py-2 flex items-center justify-between">
        <div className="flex items-center gap-2.5 min-w-0">
          {/* Shopping Bag Circle Container */}
          <div className="relative w-8 h-8 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center border border-white/30 shrink-0 shadow-inner">
            <ShoppingBag className="h-4 w-4 text-white stroke-[2.4]" />
            {/* Notification Badge */}
            <motion.span 
              key={totalItems}
              initial={{ scale: 0.7 }}
              animate={{ scale: 1 }}
              transition={{ type: "spring", stiffness: 500, damping: 15 }}
              className="absolute -top-1 -right-1 bg-white text-[#e8153a] text-[8.5px] font-black w-4 h-4 rounded-full flex items-center justify-center shadow-md tabular-nums border border-red-100"
            >
              {totalItems}
            </motion.span>
          </div>
          
          {/* Title & Subtitle Stack */}
          <div className="flex flex-col text-left min-w-0">
            <span className="text-xs sm:text-[13px] font-black text-white leading-tight tabular-nums drop-shadow-xs truncate">
              {totalItems} {totalItems === 1 ? 'Item' : 'Items'} • {formatPrice(subtotal)}
            </span>
            <span className="text-[9px] font-extrabold text-red-100/95 leading-tight truncate mt-0.5">
              {!isLocationServiceable
                ? "📍 Outside Ghatampur Zone"
                : hasFreeDelivery 
                ? "✨ Free delivery unlocked!" 
                : `Add ${formatPrice(needsForFreeDelivery)} for FREE delivery`}
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
          whileHover={{ scale: 1.03 }}
          whileTap={{ scale: 0.95 }}
          className={cn(
            "font-black text-[10px] tracking-wide px-3.5 py-1.5 rounded-full flex items-center gap-1 shadow-sm transition-all cursor-pointer shrink-0",
            !isLocationServiceable
              ? "bg-amber-400 text-black hover:bg-amber-300"
              : "bg-white text-[#e8153a] hover:bg-red-50"
          )}
        >
          <span>{!isLocationServiceable ? "CHECK ZONE" : "VIEW CART"}</span>
          <ChevronRight className="h-3.5 w-3.5 stroke-[3]" />
        </motion.button>
      </div>
    </motion.div>
  )
}
