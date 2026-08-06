'use client'

import { usePathname } from 'next/navigation'
import { useCartStore } from '@/stores/cart-store'
import { cn } from '@/lib/utils'

export function MainWrapper({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const hasCartItems = useCartStore((s) => s.items.length > 0)
  const isCategoryPage = pathname?.startsWith('/category/')
  const isStorefrontPage = pathname?.startsWith('/food/') || pathname?.startsWith('/restaurant') || pathname?.startsWith('/cafe') || pathname?.startsWith('/cart') || isCategoryPage

  return (
    <main className={cn(
      "flex-grow min-h-[calc(100vh-80px)] transition-all duration-300 md:pb-0",
      hasCartItems ? "pb-44" : "pb-24",
      isStorefrontPage ? "pt-[48px] md:pt-[65px]" : "pt-[96px] md:pt-[80px]"
    )}>
      {children}
    </main>
  )
}
