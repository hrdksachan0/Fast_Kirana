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
    <div className="fixed bottom-5 left-4 right-4 z-40 rounded-3xl bg-white/80 dark:bg-zinc-950/75 backdrop-blur-2xl h-[80px] flex items-center justify-around px-4 shadow-[0_16px_48px_rgba(0,0,0,0.18)] border border-zinc-200/30 dark:border-zinc-800/20 md:hidden animate-slide-up">
      {navItems.map((item, idx) => {
        const Icon = item.icon
        const isActive = item.active

        return (
          <Link key={idx} href={item.href} className="flex-1 flex flex-col justify-center h-full items-center">
            <div className="flex flex-col items-center justify-center w-full">
              {/* Icon Container with premium active capsule effect */}
              <div
                className={cn(
                  "flex items-center justify-center rounded-full h-11 w-11 transition-all duration-300 active:scale-95",
                  isActive
                    ? "bg-[#fff1ed] dark:bg-rose-950/20 text-primary shadow-sm scale-110"
                    : "text-zinc-500 hover:text-zinc-800 dark:hover:text-zinc-100 bg-transparent"
                )}
              >
                <Icon
                  className={cn(
                    "h-6 w-6 transition-all duration-300",
                    isActive ? "stroke-[2.5]" : "stroke-[1.8]"
                  )}
                  fill="none"
                />
              </div>
              
              {/* Text Label */}
              <span
                className={cn(
                  "text-[10px] mt-1.5 tracking-wider font-extrabold leading-none uppercase transition-all duration-300",
                  isActive
                    ? "text-primary font-black scale-105"
                    : "text-zinc-500"
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
