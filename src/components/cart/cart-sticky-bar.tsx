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
        "gpu-accelerated fixed bottom-[68px] left-3.5 right-3.5 z-40 bg-white/20 dark:bg-zinc-950/20 backdrop-blur-xl text-white rounded-[36px] shadow-[0_10px_35px_rgba(0,176,80,0.15)] border border-white/40 md:hidden animate-slide-up p-3 flex flex-col gap-2.5 cursor-pointer select-none",
        isBouncing && "animate-bounce-subtle"
      )}
    >
      {/* Integrated delivery progress bar at top edge */}
      <div className="w-full px-1">
        <div className="relative pt-1">
          <div className="w-full h-1 bg-slate-200/40 dark:bg-zinc-800/45 rounded-full overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-emerald-600 to-emerald-500 transition-all duration-500"
              style={{ width: `${deliveryProgress}%` }}
            />
          </div>
        </div>


      </div>

      {/* Main content nested capsule */}
      <div className="bg-gradient-to-r from-emerald-700/85 to-emerald-600/85 rounded-[20px] px-4 py-3 flex items-center justify-between border border-white/25">
        <div className="flex items-center gap-3">
          <span className="text-[13px] font-extrabold text-white leading-tight">
            {totalItems} {totalItems === 1 ? 'Item' : 'Items'} • {formatPrice(total)}
          </span>
          <span className="text-[19px] text-amber-400 font-bold leading-none select-none">⚡</span>
        </div>

        {/* Premium View Cart Button */}
        <motion.button
          onClick={(e) => {
            e.stopPropagation()
            triggerHaptic('light')
            toggleCart()
          }}
          whileHover={{ scale: 1.05 }}
          whileTap={{ scale: 0.95 }}
          className="bg-white text-emerald-800 font-black text-[11px] px-5 py-2.5 rounded-full flex items-center gap-1.5 shadow-[0_8px_20px_rgba(0,0,0,0.1)] active:scale-95 transition-all cursor-pointer tracking-wider uppercase"
        >
          <span>View Cart</span>
          <ArrowRight className="h-3.5 w-3.5 stroke-[3]" />
        </motion.button>
      </div>
    </motion.div>
  )
}
