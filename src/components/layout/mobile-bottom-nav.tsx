'use client'

import { useState, useEffect, useRef } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Home, Search, CircleUser, LayoutGrid } from 'lucide-react'
import { motion } from 'framer-motion'
import { useUIStore } from '@/stores/ui-store'
import { cn } from '@/lib/utils'

export function MobileBottomNav() {
  const pathname = usePathname()
  const isVisible = useUIStore((s) => s.isTabBarVisible)
  const setTabBarVisible = useUIStore((s) => s.setTabBarVisible)
  const lastScrollY = useRef(0)
  const idleTimerRef = useRef<NodeJS.Timeout | null>(null)

  useEffect(() => {
    const handleScroll = () => {
      const currentScrollY = window.scrollY || document.documentElement.scrollTop
      const diff = currentScrollY - lastScrollY.current

      // Clear any existing idle timeout
      if (idleTimerRef.current) {
        clearTimeout(idleTimerRef.current)
      }

      // Always show near the top of the page
      if (currentScrollY <= 60) {
        setTabBarVisible(true)
      } else {
        // Scroll DOWN -> hide bottom nav
        if (diff > 8) {
          setTabBarVisible(false)
        } 
        // Scroll UP -> show bottom nav
        else if (diff < -8) {
          setTabBarVisible(true)
        }
      }

      lastScrollY.current = currentScrollY

      // Show bottom nav after 300ms of no scrolling (idle)
      idleTimerRef.current = setTimeout(() => {
        setTabBarVisible(true)
      }, 300)
    }

    // Tap anywhere on the screen -> show bottom nav immediately
    const handleTouchOrTap = () => {
      setTabBarVisible(true)
      if (idleTimerRef.current) {
        clearTimeout(idleTimerRef.current)
      }
    }

    window.addEventListener('scroll', handleScroll, { passive: true })
    window.addEventListener('touchstart', handleTouchOrTap, { passive: true })
    window.addEventListener('pointerdown', handleTouchOrTap, { passive: true })

    return () => {
      window.removeEventListener('scroll', handleScroll)
      window.removeEventListener('touchstart', handleTouchOrTap)
      window.removeEventListener('pointerdown', handleTouchOrTap)
      if (idleTimerRef.current) {
        clearTimeout(idleTimerRef.current)
      }
    }
  }, [setTabBarVisible])

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
    <motion.div
      initial={false}
      animate={{
        y: isVisible ? 0 : 96,
        opacity: isVisible ? 1 : 0,
        scale: isVisible ? 1 : 0.96,
      }}
      transition={{
        duration: 0.28,
        ease: [0.16, 1, 0.3, 1], // Smooth 60 FPS cubic-bezier
      }}
      style={{
        pointerEvents: isVisible ? 'auto' : 'none',
      }}
      className="fixed bottom-4 left-1/2 -translate-x-1/2 w-[94%] max-w-[480px] sm:w-[86%] sm:max-w-[580px] z-40 bg-white/95 dark:bg-zinc-950/95 backdrop-blur-md border border-zinc-200/40 dark:border-zinc-800/40 h-[66px] rounded-full flex items-center justify-around px-4 shadow-[0_10px_35px_rgba(0,0,0,0.08)] dark:shadow-[0_10px_35px_rgba(0,0,0,0.3)] md:hidden"
    >
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
    </motion.div>
  )
}
