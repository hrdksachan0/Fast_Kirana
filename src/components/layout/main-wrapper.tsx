'use client'

import { usePathname } from 'next/navigation'
import { useCartStore } from '@/stores/cart-store'
import { cn } from '@/lib/utils'
import { motion, AnimatePresence } from 'framer-motion'

export function MainWrapper({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const hasCartItems = useCartStore((s) => s.items.length > 0)
  const isCategoryPage = pathname?.startsWith('/category/')
  const isStorefrontPage = pathname?.startsWith('/food/') || pathname?.startsWith('/restaurant') || pathname?.startsWith('/cafe') || pathname?.startsWith('/cart') || pathname?.startsWith('/checkout') || isCategoryPage

  const isFoodRestaurant = pathname?.startsWith('/food/')

  return (
    <main className={cn(
      "flex-grow min-h-[calc(100vh-80px)] transition-all duration-300 md:pb-0",
      hasCartItems ? "pb-44" : "pb-24",
      isFoodRestaurant ? "pt-0" : isStorefrontPage ? "pt-[48px] md:pt-[65px]" : "pt-[96px] md:pt-[80px]"
    )}>
      <motion.div
        key={pathname}
        initial={{ opacity: 0.85 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.15, ease: 'easeOut' }}
        className="w-full"
      >
        {children}
      </motion.div>
    </main>
  )
}

