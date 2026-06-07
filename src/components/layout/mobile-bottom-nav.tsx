'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Home, Search, Building2, CircleUser, LayoutGrid } from 'lucide-react'
import { useUIStore } from '@/stores/ui-store'
import { cn } from '@/lib/utils'

export function MobileBottomNav() {
  const pathname = usePathname()
  const isB2BMode = useUIStore((s) => s.isB2BMode)

  // Navigation Items with modern symbols
  const navItems = [
    {
      label: 'Home',
      icon: Home,
      href: '/',
      active: pathname === '/',
    },
    {
      label: 'Search',
      icon: Search,
      href: '/search',
      active: pathname === '/search',
    },
    isB2BMode
      ? {
          label: 'Wholesale',
          icon: Building2,
          href: '/wholesale',
          active: pathname === '/wholesale',
        }
      : {
          label: 'Categories',
          icon: LayoutGrid, // Modern category layout symbol
          href: '/category/fruits-vegetables',
          active: pathname.startsWith('/category'),
        },
    {
      label: 'Account',
      icon: CircleUser, // Modern circular user symbol
      href: '/account',
      active: pathname.startsWith('/account'),
    },
  ]

  return (
    <div className="fixed bottom-0 left-0 right-0 z-40 bg-white dark:bg-zinc-950/95 border-t border-zinc-200/50 dark:border-zinc-800/30 h-[56px] pb-0.5 flex items-center justify-around px-2 shadow-[0_-4px_16px_rgba(0,0,0,0.04)] md:hidden animate-slide-up">
      {navItems.map((item, idx) => {
        const Icon = item.icon
        const isActive = item.active

        return (
          <Link key={idx} href={item.href} className="flex-1 flex flex-col justify-center h-full items-center">
            <div className="flex flex-col items-center justify-center w-full">
              {/* Icon Container */}
              <div
                className={cn(
                  "flex items-center justify-center h-7 w-7 transition-all duration-300 active:scale-95",
                  isActive ? "text-primary" : "text-zinc-400 dark:text-zinc-500"
                )}
              >
                <Icon
                  className={cn(
                    "h-5 w-5 transition-all duration-300",
                    isActive ? "stroke-[2.2]" : "stroke-[1.8]"
                  )}
                  fill="none"
                />
              </div>
              
              {/* Text Label */}
              <span
                className={cn(
                  "text-[9px] mt-0.5 font-bold transition-all duration-300",
                  isActive ? "text-primary font-black" : "text-zinc-500"
                )}
              >
                {item.label}
              </span>
            </div>
          </Link>
        )
      })}
    </div>
  )
}
