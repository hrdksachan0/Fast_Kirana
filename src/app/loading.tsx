'use client'

import { useEffect, useState } from 'react'
import { usePathname } from 'next/navigation'
import { ShoppingBag, ShieldCheck, User, CreditCard, Coffee, Truck, Package, Search, Loader2 } from 'lucide-react'
import { motion } from 'framer-motion'
import {
  HomepageSkeleton,
  CategorySkeleton,
  ProductDetailSkeleton,
  SearchSkeleton,
  CafeSkeleton,
  CartSkeleton,
  CheckoutSkeleton,
  AccountSkeleton,
  OrderDetailsSkeleton,
  AdminSkeleton,
  OperationalSkeleton,
} from '@/components/shared/skeletons'

export default function Loading() {
  const pathname = usePathname()
  const [visible, setVisible] = useState(false)

  // Delay showing the loader by 50ms to prevent flickering on ultra-fast transitions
  useEffect(() => {
    const timer = setTimeout(() => setVisible(true), 50)
    return () => clearTimeout(timer)
  }, [])

  if (!visible) return null

  // 1. Full-page customized skeleton rendering based on path
  if (pathname === '/' || pathname === '') {
    return <HomepageSkeleton />
  }
  if (pathname.startsWith('/category/')) {
    return <CategorySkeleton />
  }
  if (pathname.startsWith('/product/')) {
    return <ProductDetailSkeleton />
  }
  if (pathname.startsWith('/search')) {
    return <SearchSkeleton />
  }
  if (pathname.startsWith('/cafe-kitchen')) {
    return <OperationalSkeleton title="Cafe Kitchen" />
  }
  if (pathname.startsWith('/cafe')) {
    return <CafeSkeleton />
  }
  if (pathname.startsWith('/cart')) {
    return <CartSkeleton />
  }
  if (pathname.startsWith('/checkout')) {
    return <CheckoutSkeleton />
  }
  if (pathname.startsWith('/order/') && pathname.endsWith('/track')) {
    return <OrderDetailsSkeleton />
  }
  if (pathname.startsWith('/order/')) {
    return <OrderDetailsSkeleton />
  }
  if (pathname.startsWith('/account')) {
    return <AccountSkeleton />
  }
  if (pathname.startsWith('/admin')) {
    return <AdminSkeleton />
  }
  if (pathname.startsWith('/picker')) {
    return <OperationalSkeleton title="Picker Dashboard" />
  }
  if (pathname.startsWith('/delivery')) {
    return <OperationalSkeleton title="Delivery Rider" />
  }

  // 2. Fallback: Contextual path-aware toast spinner for minor/static pages (login, signup, setup-profile, etc.)
  let loadingText = 'Loading items...'
  let Icon = ShoppingBag
  let themeColor = 'text-primary border-primary/20 bg-primary/5'
  let glowColor = 'shadow-primary/5'

  if (pathname.startsWith('/admin')) {
    loadingText = 'Opening Admin Console...'
    Icon = ShieldCheck
    themeColor = 'text-rose-500 border-rose-500/20 bg-rose-500/5'
    glowColor = 'shadow-rose-500/5'
  } else if (pathname.startsWith('/account')) {
    loadingText = 'Loading Profile...'
    Icon = User
    themeColor = 'text-blue-500 border-blue-500/20 bg-blue-500/5'
    glowColor = 'shadow-blue-500/5'
  } else if (pathname.startsWith('/checkout')) {
    loadingText = 'Securing Checkout...'
    Icon = CreditCard
    themeColor = 'text-emerald-500 border-emerald-500/20 bg-emerald-500/5'
    glowColor = 'shadow-emerald-500/5'
  } else if (pathname.startsWith('/cafe')) {
    loadingText = 'Opening Cafe...'
    Icon = Coffee
    themeColor = 'text-amber-500 border-amber-500/20 bg-amber-500/5'
    glowColor = 'shadow-amber-500/5'
  } else if (pathname.startsWith('/delivery')) {
    loadingText = 'Loading Delivery...'
    Icon = Truck
    themeColor = 'text-cyan-500 border-cyan-500/20 bg-cyan-500/5'
    glowColor = 'shadow-cyan-500/5'
  } else if (pathname.startsWith('/picker')) {
    loadingText = 'Opening Picker...'
    Icon = Package
    themeColor = 'text-orange-500 border-orange-500/20 bg-orange-500/5'
    glowColor = 'shadow-orange-500/5'
  } else if (pathname.startsWith('/search')) {
    loadingText = 'Searching Catalog...'
    Icon = Search
    themeColor = 'text-zinc-500 border-zinc-500/20 bg-zinc-500/5'
    glowColor = 'shadow-zinc-500/5'
  } else if (pathname.startsWith('/order')) {
    loadingText = 'Loading Order Status...'
    Icon = Package
    themeColor = 'text-primary border-primary/20 bg-primary/5'
    glowColor = 'shadow-primary/5'
  }

  return (
    <div className="fixed top-[104px] right-4 md:top-24 md:right-6 z-[9999] pointer-events-none select-none">
      <motion.div
        initial={{ opacity: 0, x: 50, scale: 0.9 }}
        animate={{ opacity: 1, x: 0, scale: 1 }}
        transition={{ type: 'spring', stiffness: 300, damping: 25 }}
        className={`flex items-center gap-2.5 px-4 py-2 rounded-full border border-zinc-200/80 dark:border-zinc-800/80 bg-white/90 dark:bg-zinc-950/90 backdrop-blur-md shadow-lg ${glowColor} pointer-events-auto`}
      >
        {/* Glowing Spinning Loader Icon */}
        <div className="relative flex items-center justify-center w-5 h-5">
          <Loader2 className="absolute h-5 w-5 animate-spin text-primary stroke-[2.5]" />
          <Icon className={`h-2.5 w-2.5 ${themeColor} stroke-[2.5]`} />
        </div>

        {/* Path-Aware Subtext */}
        <span className="text-[11px] font-extrabold text-zinc-700 dark:text-zinc-300 tracking-tight">
          {loadingText}
        </span>
      </motion.div>
    </div>
  )
}
