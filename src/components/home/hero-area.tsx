'use client'

import { useState, useEffect, useMemo } from 'react'
import { useSession } from 'next-auth/react'
import { Sun, Utensils, Cookie, Moon, Coffee, ShieldAlert } from 'lucide-react'
import { HeroBanner } from './hero-banner'
import { cn } from '@/lib/utils'
import { useUIStore } from '@/stores/ui-store'
import { motion } from 'framer-motion'

interface HeroAreaProps {
  initialBanners?: any[]
}

interface ThemeConfig {
  greeting: string
  subtitle: string
  icon: React.ReactNode
  modeLabel: string
  gradient: string // light mode gradient classes
  darkGradient: string // dark mode gradient classes
  border: string
  darkBorder: string
  accentColor: string
}

export function HeroArea({ initialBanners }: HeroAreaProps) {
  const { data: session } = useSession()
  const [mounted, setMounted] = useState(false)
  const [currentHour, setCurrentHour] = useState<number>(8) // Default to 8 AM (Morning) for SSR fallback

  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)
  const cafeOpen = useUIStore((s) => s.cafeOpen)

  useEffect(() => {
    setMounted(true)
    const getISTHour = () => {
      const serverTime = new Date()
      // Indian Standard Time is UTC + 5.5 hours
      const istTime = new Date(serverTime.getTime() + (serverTime.getTimezoneOffset() * 60000) + (5.5 * 60 * 60 * 1000))
      return istTime.getHours()
    }
    setCurrentHour(getISTHour())

    // Update hour periodically to keep theme in sync
    const interval = setInterval(() => {
      setCurrentHour(getISTHour())
    }, 60000)
    return () => clearInterval(interval)
  }, [])

  const themeConfig = useMemo<ThemeConfig>(() => {
    const name = session?.user?.name
    const firstName = name ? name.split(' ')[0] : ''
    const welcome = firstName ? `Hey ${firstName}, ` : ''

    // CASE 1: Both Grocery and Cafe are closed
    if (mounted && !groceryMartOpen && !cafeOpen) {
      return {
        greeting: `We're resting right now 💤`,
        subtitle: 'FastKirana Cafe & Mart are resting. We will be back to serve you fresh & hot goodies soon!',
        icon: <ShieldAlert className="h-4 w-4 text-rose-500 animate-pulse" />,
        modeLabel: 'Store Closed',
        gradient: 'from-zinc-100 via-stone-50 to-zinc-50',
        darkGradient: 'dark:from-zinc-950/20 dark:via-zinc-900/10 dark:to-zinc-900/5',
        border: 'border-zinc-200/50',
        darkBorder: 'dark:border-zinc-800/30',
        accentColor: 'text-rose-600 dark:text-rose-400',
      }
    }

    // 6 AM - 11 AM: Morning Mode
    if (currentHour >= 6 && currentHour < 11) {
      const isCafeClosed = mounted && !cafeOpen
      const isMartClosed = mounted && !groceryMartOpen

      return {
        greeting: `${welcome}Good morning, let's get breakfast! 🌅`,
        subtitle: isMartClosed 
          ? 'Grocery Mart is resting, but our Cafe is firing up fresh hot brews and breakfast specials! ☕✨'
          : isCafeClosed
          ? 'Cafe is taking a break, but Grocery Mart is wide open and delivering fresh milk & fruits! 🥛📦'
          : 'Fresh milk, fruits, hot brews, and breakfast essentials delivered in minutes.',
        icon: isMartClosed ? <Coffee className="h-4 w-4 text-amber-500 animate-pulse" /> : <Sun className="h-4 w-4 text-amber-500 fill-amber-500/20" />,
        modeLabel: isMartClosed ? 'Cafe Open • Mart Closed' : isCafeClosed ? 'Mart Open • Cafe Closed' : 'Morning Mode',
        gradient: 'from-amber-100/50 via-yellow-50/40 to-orange-100/30',
        darkGradient: 'dark:from-amber-950/20 dark:via-yellow-950/10 dark:to-zinc-900/10',
        border: 'border-amber-200/40',
        darkBorder: 'dark:border-amber-900/20',
        accentColor: 'text-amber-600 dark:text-amber-400',
      }
    }
    // 11 AM - 4 PM: Lunch Mode
    else if (currentHour >= 11 && currentHour < 16) {
      const isCafeClosed = mounted && !cafeOpen
      const isMartClosed = mounted && !groceryMartOpen

      return {
        greeting: `${welcome}Good afternoon! Ready for lunch? 🍛`,
        subtitle: isMartClosed
          ? 'Grocery Mart is resting, but our Cafe is cooking delicious hot lunch dishes and rolls! 🥡✨'
          : isCafeClosed
          ? 'Cafe is taking a break, but Grocery Mart is delivering lunch staples, dal, and rice! 🌾📦'
          : 'Atta, rice, dal, fresh vegetables, and delicious hot rolls delivered fast.',
        icon: isMartClosed ? <Coffee className="h-4 w-4 text-emerald-500 animate-pulse" /> : <Utensils className="h-4 w-4 text-emerald-500" />,
        modeLabel: isMartClosed ? 'Cafe Open • Mart Closed' : isCafeClosed ? 'Mart Open • Cafe Closed' : 'Lunch Mode',
        gradient: 'from-emerald-50 via-teal-50/60 to-cyan-50/40',
        darkGradient: 'dark:from-emerald-950/20 dark:via-teal-950/10 dark:to-zinc-900/10',
        border: 'border-emerald-200/30',
        darkBorder: 'dark:border-emerald-900/25',
        accentColor: 'text-emerald-600 dark:text-emerald-400',
      }
    }
    // 4 PM - 8 PM: Evening Snacks Mode
    else if (currentHour >= 16 && currentHour < 20) {
      const isCafeClosed = mounted && !cafeOpen
      const isMartClosed = mounted && !groceryMartOpen

      return {
        greeting: `${welcome}It's snack o'clock! Tea & snacks are ready ☕`,
        subtitle: isMartClosed
          ? 'Grocery Mart is taking a break, but our Cafe is steaming hot chai & fresh samosas! ☕🥟'
          : isCafeClosed
          ? 'Cafe is resting, but Grocery Mart is delivering chips, biscuits, and munchies! 🍿📦'
          : 'Samosas, munchies, chips, and chilled soft drinks ready for tea time.',
        icon: isMartClosed ? <Coffee className="h-4 w-4 text-orange-500 animate-pulse" /> : <Cookie className="h-4 w-4 text-orange-500 fill-orange-500/10" />,
        modeLabel: isMartClosed ? 'Cafe Open • Mart Closed' : isCafeClosed ? 'Mart Open • Cafe Closed' : 'Tea & Snacks Mode',
        gradient: 'from-orange-100/40 via-rose-50/40 to-amber-100/30',
        darkGradient: 'dark:from-orange-950/25 dark:via-rose-950/15 dark:to-zinc-900/10',
        border: 'border-orange-200/30',
        darkBorder: 'dark:border-rose-900/20',
        accentColor: 'text-orange-600 dark:text-orange-400',
      }
    }
    // 8 PM - 5 AM: Late Night Cravings Mode
    else {
      const isCafeClosed = mounted && !cafeOpen
      const isMartClosed = mounted && !groceryMartOpen

      return {
        greeting: `${welcome}Late night cravings? We got you! 🌙`,
        subtitle: isMartClosed
          ? 'Grocery Mart is closed. Cafe is open to deliver hot night snacks & dessert cravings! 🍧✨'
          : isCafeClosed
          ? 'Cafe kitchen is resting, but Grocery Mart is active for ice cream, drinks & munchies! 🍦📦'
          : 'Indulge in ice creams, chocolates, late night munchies, and cafe specialties.',
        icon: isMartClosed ? <Coffee className="h-4 w-4 text-indigo-500 animate-pulse" /> : <Moon className="h-4 w-4 text-indigo-500 fill-indigo-500/20" />,
        modeLabel: isMartClosed ? 'Cafe Open • Mart Closed' : isCafeClosed ? 'Mart Open • Cafe Closed' : 'Cravings Mode',
        gradient: 'from-indigo-100/60 via-purple-50/50 to-pink-100/30',
        darkGradient: 'dark:from-indigo-950/30 dark:via-purple-950/20 dark:to-zinc-900/10',
        border: 'border-indigo-200/40',
        darkBorder: 'dark:border-indigo-900/20',
        accentColor: 'text-indigo-600 dark:text-indigo-400',
      }
    }
  }, [currentHour, session, groceryMartOpen, cafeOpen, mounted])

  // Soft fallback for SSR to prevent layout shifting
  const currentGradient = mounted
    ? `${themeConfig.gradient} ${themeConfig.darkGradient}`
    : 'from-zinc-100 via-stone-50 to-zinc-50 dark:from-zinc-950/20 dark:via-zinc-900/10 dark:to-zinc-900/5'
  const currentBorder = mounted
    ? `${themeConfig.border} ${themeConfig.darkBorder}`
    : 'border-zinc-200/50 dark:border-zinc-800/30'

  return (
    <div
      className={cn(
        "w-full rounded-3xl p-4 md:p-6 border bg-gradient-to-br transition-all duration-1000 ease-in-out shadow-xs space-y-4 md:space-y-6 overflow-hidden relative",
        currentGradient,
        currentBorder
      )}
    >
      {/* Decorative subtle ambient glows */}
      <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 dark:bg-white/[0.02] rounded-full blur-xl pointer-events-none" />
      <div className="absolute bottom-0 left-0 w-32 h-32 bg-white/10 dark:bg-white/[0.02] rounded-full blur-xl pointer-events-none" />

      {/* Greeting Header */}
      <div className="flex flex-col gap-1.5 text-left relative z-10 min-h-[64px] justify-center">
        {mounted ? (
          <motion.div
            initial={{ opacity: 0, y: 4 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.4, ease: 'easeOut' }}
            className="space-y-1"
          >
            <div className="flex items-center gap-2">
              {/* Animated/Glowing Mode Indicator Pill */}
              <span
                className={cn(
                  "inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[9px] md:text-[10px] font-black tracking-wider uppercase border bg-white/60 dark:bg-black/30 backdrop-blur-xs shadow-xs",
                  themeConfig.accentColor
                )}
              >
                {themeConfig.icon}
                {themeConfig.modeLabel}
              </span>
              <span className="flex h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
            </div>

            <h1 className="text-base min-[375px]:text-lg sm:text-2xl md:text-3xl font-black text-text-primary tracking-tight leading-tight select-none">
              {themeConfig.greeting}
            </h1>
            <p className="text-[10px] min-[375px]:text-[11px] sm:text-xs md:text-sm text-text-secondary max-w-2xl font-bold leading-relaxed">
              {themeConfig.subtitle}
            </p>
          </motion.div>
        ) : (
          /* Subtle skeleton to maintain height and prevent shifting / layout flicker */
          <div className="space-y-2 animate-pulse">
            <div className="flex items-center gap-2">
              <div className="h-4.5 w-24 bg-zinc-200/50 dark:bg-zinc-800/40 rounded-full" />
              <div className="h-1.5 w-1.5 bg-zinc-200/50 dark:bg-zinc-800/40 rounded-full" />
            </div>
            <div className="h-7 w-64 bg-zinc-200/60 dark:bg-zinc-800/50 rounded-lg" />
            <div className="h-3 w-80 bg-zinc-200/40 dark:bg-zinc-800/30 rounded-md" />
          </div>
        )}
      </div>

      {/* Hero Banner Component */}
      <div className="relative z-10">
        <HeroBanner initialBanners={initialBanners} />
      </div>
    </div>
  )
}
