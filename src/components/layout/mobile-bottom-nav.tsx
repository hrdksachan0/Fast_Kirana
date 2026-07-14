'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Home, Search, CircleUser, LayoutGrid } from 'lucide-react'
import { motion } from 'framer-motion'
import { cn } from '@/lib/utils'

export function MobileBottomNav() {
  const pathname = usePathname()

  // Suppress bottom navigation on checkout, cart, order tracking, admin, and worker screens
  if (
    !pathname ||
    pathname.startsWith('/checkout') ||
    pathname.startsWith('/order/') ||
    pathname.startsWith('/picker') ||
    pathname.startsWith('/admin') ||
    pathname === '/cart'
  ) {
    return null
  }

  // Navigation Items matching the mockup options
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
    {
      label: 'Categories',
      icon: LayoutGrid,
      href: '/category',
      active: pathname.startsWith('/category'),
    },
    {
      label: 'Account',
      icon: CircleUser,
      href: '/account',
      active: pathname.startsWith('/account'),
    },
  ]

  return (
    <div className="fixed bottom-4 left-1/2 -translate-x-1/2 w-[94%] max-w-[480px] sm:w-[86%] sm:max-w-[580px] z-40 bg-white/95 dark:bg-zinc-950/95 backdrop-blur-md border border-zinc-200/40 dark:border-zinc-800/40 h-[66px] rounded-full flex items-center justify-around px-4 shadow-[0_10px_35px_rgba(0,0,0,0.08)] dark:shadow-[0_10px_35px_rgba(0,0,0,0.3)] md:hidden">
      {navItems.map((item, idx) => {
        const Icon = item.icon
        const isActive = item.active

        return (
          <Link 
            key={idx} 
            href={item.href} 
            className="flex-1 flex flex-col justify-center h-full items-center select-none outline-none relative"
            suppressHydrationWarning
          >
            <div className="flex flex-col items-center justify-center w-full relative pb-1">
              {/* Icon Container with Red Gradient for Active item - vertically centered */}
              <div
                className={cn(
                  "flex items-center justify-center h-9 w-13 rounded-2xl transition-all duration-300 active:scale-95",
                  isActive 
                    ? "bg-[#e20a22] text-white shadow-md shadow-red-900/15" 
                    : "text-zinc-400 dark:text-zinc-500 hover:text-zinc-650"
                )}
              >
                <Icon
                  className={cn(
                    "h-5 w-5 transition-all duration-300",
                    isActive ? "stroke-[2.5]" : "stroke-[1.8]"
                  )}
                  fill="none"
                />
              </div>
              
              {/* Text Label */}
              <span
                className={cn(
                  "text-[10px] mt-1 font-bold transition-all duration-300",
                  isActive ? "text-[#e20a22] font-extrabold" : "text-zinc-500 dark:text-zinc-400"
                )}
              >
                {item.label}
              </span>

              {/* Red Line Indicator under the active tab label */}
              {isActive && (
                <motion.span
                  layoutId="activeBottomTabLine"
                  className="absolute bottom-[-1px] w-4.5 h-[2.5px] rounded-full bg-[#e20a22]"
                  transition={{
                    type: "spring",
                    stiffness: 380,
                    damping: 30,
                  }}
                />
              )}
            </div>
          </Link>
        )
      })}
    </div>
  )
}
