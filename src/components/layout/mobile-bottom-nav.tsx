'use client'

import { useState, useEffect, useRef, useMemo } from 'react'
import Link from 'next/link'
import { useRouter, usePathname } from 'next/navigation'
import { Home, Search, CircleUser, LayoutGrid, LucideIcon } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { useUIStore } from '@/stores/ui-store'
import { useCartStore } from '@/stores/cart-store'
import { cn } from '@/lib/utils'
import { triggerHaptic } from '@/lib/haptic'

interface NavItem {
  id: string
  label: string
  icon: LucideIcon
  href: string
  match: (path: string) => boolean
}

export function MobileBottomNav() {
  const router = useRouter()
  const pathname = usePathname()
  const isVisible = useUIStore((s) => s.isTabBarVisible)
  const setTabBarVisible = useUIStore((s) => s.setTabBarVisible)
  const lastScrollY = useRef(0)
  const idleTimerRef = useRef<NodeJS.Timeout | null>(null)

  const hasCartItems = useCartStore((s) => s.items.length > 0)

  // 4 Bottom Navigation Tabs: Home · Search · Category · Account
  const navTabs: NavItem[] = useMemo(() => [
    {
      id: 'home',
      label: 'Home',
      icon: Home,
      href: '/',
      match: (p: string) => p === '/' || p.startsWith('/?'),
    },
    {
      id: 'search',
      label: 'Search',
      icon: Search,
      href: '/search',
      match: (p: string) => p.startsWith('/search'),
    },
    {
      id: 'category',
      label: 'Category',
      icon: LayoutGrid,
      href: '/category',
      match: (p: string) => p.startsWith('/category'),
    },
    {
      id: 'account',
      label: 'Account',
      icon: CircleUser,
      href: '/account',
      match: (p: string) => p.startsWith('/account'),
    },
  ], [])

  // Find active tab index based on current URL path
  const activeIndex = useMemo(() => {
    if (!pathname) return 0
    const idx = navTabs.findIndex(tab => tab.match(pathname))
    return idx >= 0 ? idx : 0
  }, [pathname, navTabs])

  // Scroll detection to auto hide/show bottom navigation
  useEffect(() => {
    const handleScroll = () => {
      const currentScrollY = window.scrollY || document.documentElement.scrollTop
      const diff = currentScrollY - lastScrollY.current

      if (idleTimerRef.current) {
        clearTimeout(idleTimerRef.current)
      }

      if (hasCartItems) {
        setTabBarVisible(true)
        lastScrollY.current = currentScrollY
        return
      }

      if (currentScrollY <= 60) {
        setTabBarVisible(true)
      } else {
        if (diff > 8) {
          setTabBarVisible(false)
        } else if (diff < -8) {
          setTabBarVisible(true)
        }
      }

      lastScrollY.current = currentScrollY

      idleTimerRef.current = setTimeout(() => {
        setTabBarVisible(true)
      }, 300)
    }

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
  }, [setTabBarVisible, hasCartItems])

  // Suppress on ignored routes
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

  const handleTabClick = (tab: NavItem, idx: number) => {
    triggerHaptic('light')
    if (idx !== activeIndex) {
      router.push(tab.href)
    }
  }

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
        ease: [0.16, 1, 0.3, 1],
      }}
      style={{
        pointerEvents: isVisible ? 'auto' : 'none',
        bottom: 'calc(12px + env(safe-area-inset-bottom, 0px))',
      }}
      className="fixed left-1/2 -translate-x-1/2 w-[92%] max-w-[390px] sm:w-[84%] sm:max-w-[440px] z-50 bg-white/95 dark:bg-zinc-950/95 backdrop-blur-2xl border border-zinc-200/80 dark:border-zinc-800/80 h-[58px] rounded-full shadow-[0_10px_35px_rgba(0,0,0,0.08),0_2px_10px_rgba(243,59,48,0.08)] dark:shadow-[0_10px_35px_rgba(0,0,0,0.4)] md:hidden px-1.5 flex items-center select-none overflow-hidden"
    >
      {/* 
        =====================================================================
        ACTIVE INDICATOR: Pure Liquid Crystal / Clear Water Droplet Flow
        - Natural translucent water bubble effect (No red tint in the liquid)
        - Snaps back with liquid jelly elastic bounce
        =====================================================================
      */}
      <div className="absolute inset-x-1.5 inset-y-0 pointer-events-none flex items-center">
        <motion.div
          className="relative flex items-center justify-center"
          style={{
            width: '25%', // Exactly 1/4th of the 4 tabs
          }}
          animate={{
            x: `${activeIndex * 100}%`,
          }}
          transition={{
            type: 'spring',
            stiffness: 350,
            damping: 24,
            mass: 0.7,
            restDelta: 0.001,
          }}
        >
          {/* Pure Clear Water Droplet Pill with Specular Highlights */}
          <motion.div 
            key={activeIndex}
            initial={{ scaleX: 1.4, scaleY: 0.75, borderRadius: '40px' }}
            animate={{ scaleX: 1, scaleY: 1, borderRadius: '24px' }}
            transition={{
              type: 'spring',
              stiffness: 400,
              damping: 18,
              mass: 0.6,
            }}
            className="w-13 h-10.5 rounded-[24px] bg-gradient-to-b from-white/90 via-zinc-100/60 to-zinc-200/40 dark:from-white/15 dark:via-white/10 dark:to-transparent flex items-center justify-center shadow-[0_4px_16px_rgba(0,0,0,0.06),inset_0_1.5px_2px_rgba(255,255,255,0.95),inset_0_-1px_2px_rgba(0,0,0,0.04)] dark:shadow-[0_4px_16px_rgba(0,0,0,0.4),inset_0_1px_1px_rgba(255,255,255,0.15)] border border-zinc-200/90 dark:border-white/15 backdrop-blur-md relative"
          >
            {/* Water Caustic Light Droplet Highlight */}
            <motion.div 
              initial={{ scale: 0.4, opacity: 0.9 }}
              animate={{ scale: [0.6, 1.1, 1], opacity: [0.7, 1, 0.85] }}
              transition={{ duration: 0.4, ease: 'easeOut' }}
              className="absolute top-1 inset-x-2 h-2 rounded-full bg-gradient-to-b from-white/95 to-transparent blur-[0.5px]"
            />
          </motion.div>
        </motion.div>
      </div>

      {/* 4 Interactive Navigation Tabs (Home, Search, Category, Account) */}
      <div className="relative z-10 w-full h-full flex items-center justify-between">
        {navTabs.map((tab, idx) => {
          const Icon = tab.icon
          const isActive = idx === activeIndex

          return (
            <Link
              key={tab.id}
              href={tab.href}
              onClick={() => triggerHaptic('light')}
              className="flex-1 flex flex-col justify-center h-full items-center select-none outline-none relative py-1 cursor-pointer"
              aria-label={tab.label}
              aria-current={isActive ? 'page' : undefined}
              prefetch={true}
            >
              <div className="flex flex-col items-center justify-center w-full relative">
                {/* Icon Container with Elastic Jelly Bounce Pop */}
                <div className="flex items-center justify-center h-7 w-7 relative">
                  <motion.div
                    animate={{
                      scale: isActive ? 1.08 : 1,
                      y: isActive ? -0.5 : 0,
                    }}
                    transition={{
                      type: 'spring',
                      stiffness: 450,
                      damping: 20,
                    }}
                    className={cn(
                      "flex items-center justify-center transition-all duration-300",
                      isActive
                        ? "text-[#F33B30] drop-shadow-[0_1px_4px_rgba(243,59,48,0.3)]"
                        : "text-zinc-400 dark:text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300"
                    )}
                  >
                    <Icon
                      className={cn(
                        "h-5 w-5 transition-all duration-300",
                        isActive ? "stroke-[1.8]" : "stroke-[1.6]"
                      )}
                      fill="none"
                    />
                  </motion.div>
                </div>

                {/* Text Label - Clean Red Accent on Active */}
                <motion.span
                  animate={{
                    scale: isActive ? 1.03 : 1,
                  }}
                  transition={{
                    type: 'spring',
                    stiffness: 400,
                    damping: 22,
                  }}
                  className={cn(
                    "text-[9.5px] min-[375px]:text-[10px] mt-0.5 tracking-tight transition-colors duration-300 leading-none",
                    isActive
                      ? "text-[#F33B30] font-bold"
                      : "text-zinc-400 dark:text-zinc-500 font-medium"
                  )}
                >
                  {tab.label}
                </motion.span>
              </div>
            </Link>
          )
        })}
      </div>
    </motion.div>
  )
}

