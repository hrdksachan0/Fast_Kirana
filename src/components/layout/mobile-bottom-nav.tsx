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
        bottom: 'calc(14px + env(safe-area-inset-bottom, 0px))',
      }}
      className="fixed left-1/2 -translate-x-1/2 w-[94%] max-w-[480px] sm:w-[86%] sm:max-w-[580px] z-50 bg-white/95 dark:bg-zinc-950/95 backdrop-blur-xl border border-zinc-200/50 dark:border-zinc-800/50 h-[64px] rounded-full flex items-center justify-around px-2 py-1 shadow-[0_10px_35px_rgba(0,0,0,0.1)] dark:shadow-[0_10px_35px_rgba(0,0,0,0.4)] md:hidden"
    >
      {navItems.map((item, idx) => {
        const Icon = item.icon
        const isActive = item.active

        return (
          <Link 
            key={idx} 
            href={item.href} 
            className="flex-1 flex flex-col justify-center h-full items-center select-none outline-none relative py-0.5"
            suppressHydrationWarning
          >
            <div className="flex flex-col items-center justify-center w-full relative">
              {/* Icon Container with Red Gradient for Active item */}
              <div
                className={cn(
                  "flex items-center justify-center h-7 w-11 rounded-full transition-all duration-300 active:scale-95",
                  isActive 
                    ? "bg-[#e20a22] text-white shadow-xs shadow-red-900/20" 
                    : "text-zinc-500 dark:text-zinc-400 hover:text-zinc-700"
                )}
              >
                <Icon
                  className={cn(
                    "h-4.5 w-4.5 transition-all duration-300",
                    isActive ? "stroke-[2.5]" : "stroke-[1.8]"
                  )}
                  fill="none"
                />
              </div>
              
              {/* Text Label - guaranteed to fit */}
              <span
                className={cn(
                  "text-[10px] mt-0.5 font-bold transition-all duration-300 leading-none",
                  isActive ? "text-[#e20a22] font-black" : "text-zinc-500 dark:text-zinc-400 font-medium"
                )}
              >
                {item.label}
              </span>
            </div>
          </Link>
        )
      })}
    </motion.div>
  )
}
