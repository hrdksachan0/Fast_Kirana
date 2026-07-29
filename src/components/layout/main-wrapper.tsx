'use client'

import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'

export function MainWrapper({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()
  const isCategoryPage = pathname?.startsWith('/category/')
  const isStorefrontPage = pathname?.startsWith('/food/') || pathname?.startsWith('/restaurant') || pathname?.startsWith('/cafe') || pathname?.startsWith('/cart') || isCategoryPage

  return (
    <main className={cn(
      "flex-grow min-h-[calc(100vh-80px)] transition-all duration-300",
      isStorefrontPage ? "pt-[48px] md:pt-[65px]" : "pt-[96px] md:pt-[80px]"
    )}>
      {children}
    </main>
  )
}
