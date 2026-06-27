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
    <motion.div
      onClick={() => {
        triggerHaptic('light')
        toggleCart()
      }}
      whileTap={{ scale: 0.98 }}
      className={cn(
        "gpu-accelerated fixed bottom-[68px] left-4 right-4 z-40 bg-gradient-to-r from-emerald-800/95 to-green-700/95 backdrop-blur-lg text-white rounded-2xl shadow-[0_8px_30px_rgba(16,185,129,0.3)] border border-white/15 md:hidden animate-slide-up overflow-hidden cursor-pointer select-none flex flex-col",
        isBouncing && "animate-bounce-subtle"
      )}
    >
      {/* Top Edge Progress Bar */}
      <div className="w-full h-1 bg-white/10 overflow-hidden">
        <div
          className="h-full bg-gradient-to-r from-amber-400 to-emerald-400 transition-all duration-500"
          style={{ width: `${deliveryProgress}%` }}
        />
      </div>

      {/* Slim Content Row */}
      <div className="px-4 py-2.5 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="text-[12px] font-black text-white tracking-wide uppercase">
            {totalItems} {totalItems === 1 ? 'Item' : 'Items'} • {formatPrice(total)}
          </span>
          <span className="text-base text-amber-455 animate-pulse-gentle">⚡</span>
        </div>

        {/* Premium View Cart Button */}
        <motion.button
          onClick={(e) => {
            e.stopPropagation()
            triggerHaptic('light')
            toggleCart()
          }}
          whileHover={{ scale: 1.03 }}
          whileTap={{ scale: 0.97 }}
          className="bg-white text-emerald-800 font-extrabold text-[10px] px-4.5 py-2 rounded-full flex items-center gap-1 shadow-sm active:scale-95 transition-all cursor-pointer tracking-wider uppercase"
        >
          <span>View Cart</span>
          <ArrowRight className="h-3 w-3 stroke-[3]" />
        </motion.button>
      </div>
    </motion.div>
  )
}
