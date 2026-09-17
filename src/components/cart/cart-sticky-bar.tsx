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
        "gpu-accelerated fixed left-3 right-3 z-40 bg-gradient-to-r from-[#e11d48] via-[#e20a22] to-[#b91c1c] backdrop-blur-xl text-white rounded-2xl shadow-[0_8px_30px_rgba(226,10,34,0.4)] border border-white/20 md:hidden animate-slide-up overflow-hidden cursor-pointer select-none flex flex-col",
        isBouncing && "animate-bounce-subtle"
      )}
    >
      {/* Top Edge Progress Bar for Free Delivery */}
      <div className="w-full h-[3px] bg-black/20 overflow-hidden">
        <div
          className="h-full bg-gradient-to-r from-amber-300 via-yellow-200 to-emerald-400 transition-all duration-500"
          style={{ width: `${deliveryProgress}%` }}
        />
      </div>

      {/* Compact Cart Content Row */}
      <div className="px-3 py-2 flex items-center justify-between gap-2">
        <div className="flex items-center gap-2 min-w-0 flex-1">
          {/* Compact Overlapping Item Previews */}
          <div className="flex items-center shrink-0">
            {items.length > 0 ? (
              <div className="flex items-center -space-x-2">
                {items.slice(0, 2).map((it, idx) => (
                  <div
                    key={`${it.product.id}-${idx}`}
                    className="relative w-6 h-6 rounded-full border-[1.5px] border-white/90 overflow-hidden bg-white shadow-xs shrink-0"
                    style={{ zIndex: 10 - idx }}
                  >
                    {it.product.imageUrl ? (
                      <img
                        src={it.product.imageUrl}
                        alt={it.product.name}
                        className="w-full h-full object-contain"
                      />
                    ) : (
                      <div className="w-full h-full bg-orange-100 text-[8px] font-black flex items-center justify-center text-orange-600">
                        {it.product.name.charAt(0)}
                      </div>
                    )}
                  </div>
                ))}
                {items.length > 2 && (
                  <div
                    className="relative w-6 h-6 rounded-full border-[1.5px] border-white/90 bg-black/60 text-white text-[8px] font-black flex items-center justify-center shadow-xs shrink-0"
                    style={{ zIndex: 5 }}
                  >
                    +{items.length - 2}
                  </div>
                )}
              </div>
            ) : (
              <div className="relative w-6 h-6 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center border border-white/30 shrink-0">
                <ShoppingBag className="h-3.5 w-3.5 text-white stroke-[2.4]" />
              </div>
            )}
          </div>
          
          {/* Title & Subtitle Stack */}
          <div className="flex flex-col text-left min-w-0 flex-1">
            <div className="flex items-baseline gap-1 leading-tight">
              <span className="text-[13px] font-black text-white tabular-nums drop-shadow-xs whitespace-nowrap">
                {formatPrice(subtotal)}
              </span>
              <span className="text-[10px] font-bold text-white/70 whitespace-nowrap">
                • {totalItems} {totalItems === 1 ? 'item' : 'items'}
              </span>
            </div>
            <span className="text-[9.5px] font-bold text-amber-200/90 leading-snug whitespace-nowrap overflow-hidden text-ellipsis mt-px">
              {!isLocationServiceable
                ? "📍 Outside Service Zone"
                : hasFreeDelivery 
                ? "✨ Free delivery unlocked!" 
                : `Add ${formatPrice(needsForFreeDelivery)} for free delivery`}
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
            "font-black text-[10px] tracking-wide px-3 py-1.5 rounded-full flex items-center gap-1 shadow-md transition-all cursor-pointer shrink-0 uppercase",
            !isLocationServiceable
              ? "bg-amber-400 text-black hover:bg-amber-300"
              : "bg-white text-[#e20a22] hover:bg-red-50"
          )}
        >
          <span>{!isLocationServiceable ? "CHECK" : "VIEW CART"}</span>
          <ChevronRight className="h-3 w-3 stroke-[3]" />
        </motion.button>
      </div>
    </motion.div>
  )
}
