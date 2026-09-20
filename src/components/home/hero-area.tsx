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

function formatTime12h(timeStr?: string): string {
  if (!timeStr) return ''
  const [hStr, mStr] = timeStr.split(':')
  const h = parseInt(hStr, 10)
  if (isNaN(h)) return timeStr
  const m = parseInt(mStr, 10) || 0
  const ampm = h >= 12 ? 'PM' : 'AM'
  const h12 = h % 12 === 0 ? 12 : h % 12
  const mPad = m === 0 ? '' : `:${String(m).padStart(2, '0')}`
  return `${h12}${mPad} ${ampm}`
}

export function HeroArea({ initialBanners }: HeroAreaProps) {

  const { data: session, status } = useSession()
  const [mounted, setMounted] = useState(false)
  const [currentHour, setCurrentHour] = useState<number>(8) // Default to 8 AM (Morning) for SSR fallback
  const groceryMartOpen = useUIStore((s) => s.groceryMartOpen)
  const cafeOpen = useUIStore((s) => s.cafeOpen)
  const settings = useUIStore((s) => s.settings) || {}
  const isReady = mounted && status !== 'loading' && Object.keys(settings).length > 0


  useEffect(() => {
    setMounted(true)
    const getISTHour = () => {
      const formatter = new Intl.DateTimeFormat('en-US', {
        timeZone: 'Asia/Kolkata',
        hour: 'numeric',
        hour12: false
      })
      const parts = formatter.formatToParts(new Date())
      return parseInt(parts.find(p => p.type === 'hour')?.value || '0', 10)
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

    // CASE 1: Grocery Mart Closed
    if (mounted && !groceryMartOpen) {
      return {
        greeting: settings.hero_greeting_closed || `${welcome}We're resting right now 💤`,
        subtitle: settings.hero_subtitle_closed || 'FastKirana Grocery Mart is taking a break. We will be back soon to deliver fresh essentials!',
        icon: <ShieldAlert className="h-4 w-4 text-rose-500 shrink-0" />,
        modeLabel: '🔒 GROCERY MART CLOSED',
        gradient: 'from-zinc-100 via-stone-50 to-zinc-50',
        darkGradient: 'dark:from-zinc-950/20 dark:via-zinc-900/10 dark:to-zinc-900/5',
        border: 'border-zinc-200/50',
        darkBorder: 'dark:border-zinc-800/30',
        accentColor: 'text-rose-600 dark:text-rose-400',
      }
    }

    // 6 AM - 11 AM: Morning Mode
    if (currentHour >= 6 && currentHour < 11) {
      return {
        greeting: `${welcome}${settings.hero_greeting_morning || "Good morning, fresh groceries ready! 🌅"}`,
        subtitle: settings.hero_subtitle_morning_both_open || settings.hero_subtitle_morning_cafe_closed || 'Fresh milk, fruits, vegetables, and breakfast grocery essentials delivered to your doorstep in minutes.',
        icon: <Sun className="h-4 w-4 text-amber-500 fill-amber-500/20 shrink-0" />,
        modeLabel: '⚡ GROCERY MART • ONLINE',
        gradient: 'from-amber-100/50 via-yellow-50/40 to-orange-100/30',
        darkGradient: 'dark:from-amber-950/20 dark:via-yellow-950/10 dark:to-zinc-900/10',
        border: 'border-amber-200/40',
        darkBorder: 'dark:border-amber-900/20',
        accentColor: 'text-amber-600 dark:text-amber-400',
      }
    }
    // 11 AM - 4 PM: Lunch & Staples Mode
    else if (currentHour >= 11 && currentHour < 16) {
      return {
        greeting: `${welcome}${settings.hero_greeting_afternoon || "Good afternoon! Cooking essentials ready 🌾"}`,
        subtitle: settings.hero_subtitle_afternoon_both_open || settings.hero_subtitle_afternoon_cafe_closed || 'Atta, rice, dal, fresh vegetables, oils, and kitchen staples delivered super fast.',
        icon: <Utensils className="h-4 w-4 text-emerald-500 shrink-0" />,
        modeLabel: '⚡ GROCERY MART • ONLINE',
        gradient: 'from-emerald-50 via-teal-50/60 to-cyan-50/40',
        darkGradient: 'dark:from-emerald-950/20 dark:via-teal-950/10 dark:to-zinc-900/10',
        border: 'border-emerald-200/30',
        darkBorder: 'dark:border-emerald-900/25',
        accentColor: 'text-emerald-600 dark:text-emerald-400',
      }
    }
    // 4 PM - 8 PM: Evening Munchies Mode
    else if (currentHour >= 16 && currentHour < 20) {
      return {
        greeting: `${welcome}${settings.hero_greeting_evening || "Evening snacks & munchies ready 🍿"}`,
        subtitle: settings.hero_subtitle_evening_both_open || settings.hero_subtitle_evening_cafe_closed || 'Chips, biscuits, munchies, chilled soft drinks, and evening grocery essentials delivered in minutes.',
        icon: <Cookie className="h-4 w-4 text-orange-500 fill-orange-500/10 shrink-0" />,
        modeLabel: '⚡ GROCERY MART • ONLINE',
        gradient: 'from-orange-100/40 via-rose-50/40 to-amber-100/30',
        darkGradient: 'dark:from-orange-950/25 dark:via-rose-950/15 dark:to-zinc-900/10',
        border: 'border-orange-200/30',
        darkBorder: 'dark:border-rose-900/20',
        accentColor: 'text-orange-600 dark:text-orange-400',
      }
    }
    // 8 PM - 5 AM: Night Cravings Mode
    else {
      return {
        greeting: `${welcome}${settings.hero_greeting_night || "Late night snacks & ice creams? We got you! 🌙"}`,
        subtitle: settings.hero_subtitle_night_both_open || settings.hero_subtitle_night_cafe_closed || 'Chocolates, ice creams, cold drinks, late night munchies, and instant grocery essentials.',
        icon: <Moon className="h-4 w-4 text-amber-500 fill-amber-500/20 shrink-0" />,
        modeLabel: '⚡ GROCERY MART • ONLINE',
        gradient: 'from-slate-100/80 via-zinc-100/60 to-amber-50/40',
        darkGradient: 'dark:from-slate-950/50 dark:via-zinc-900/40 dark:to-zinc-950/20',
        border: 'border-slate-200/60',
        darkBorder: 'dark:border-slate-800/40',
        accentColor: 'text-slate-800 dark:text-slate-200',
      }
    }
  }, [currentHour, session, groceryMartOpen, mounted, settings])

  // Soft fallback for SSR to prevent layout shifting
  const currentGradient = mounted
    ? `${themeConfig.gradient} ${themeConfig.darkGradient}`
    : 'from-zinc-100 via-stone-50 to-zinc-50 dark:from-zinc-950/20 dark:via-zinc-900/10 dark:to-zinc-900/5'
  const currentBorder = mounted
    ? `${themeConfig.border} ${themeConfig.darkBorder}`
    : 'border-zinc-200/50 dark:border-zinc-800/30'

  return (
    <div className="w-full flex flex-col gap-3 sm:gap-4 my-1">
      {/* Greeting Header Bar */}
      <div
        className={cn(
          "w-full rounded-2xl p-3.5 sm:p-5 border bg-gradient-to-br transition-all duration-700 ease-in-out shadow-2xs relative overflow-hidden",
          currentGradient,
          currentBorder
        )}
      >
        {/* Subtle background glow */}
        <div className="absolute top-0 right-0 w-28 h-28 bg-white/10 dark:bg-white/[0.02] rounded-full blur-xl pointer-events-none" />

        <div className="flex flex-col gap-1 text-left relative z-10 justify-center">
          {isReady ? (
            <motion.div
              initial={{ opacity: 0, y: 4 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.4, ease: 'easeOut' }}
              className="space-y-1"
            >
              <div className="flex items-center gap-2">
                {/* Mode Indicator Pill */}
                <span
                  className={cn(
                    "inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[9px] md:text-[10px] font-black tracking-wider uppercase border bg-white/70 dark:bg-black/40 backdrop-blur-xs shadow-3xs",
                    themeConfig.accentColor
                  )}
                >
                  {themeConfig.icon}
                  {themeConfig.modeLabel}
                </span>
                <span className="flex h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
              </div>

              <h1 className="text-sm min-[375px]:text-base sm:text-xl md:text-2xl font-black text-text-primary tracking-tight leading-tight select-none">
                {themeConfig.greeting}
              </h1>
              <p className="text-[10px] sm:text-xs text-text-secondary max-w-xl font-bold leading-relaxed line-clamp-1">
                {themeConfig.subtitle}
              </p>

              {/* Timings Badge */}
              <div className="flex flex-wrap gap-2 pt-1">
                <span className="inline-flex items-center gap-1 bg-emerald-500/10 border border-emerald-500/20 text-emerald-700 dark:text-emerald-400 px-2 py-0.5 rounded-md text-[9px] font-black uppercase tracking-wider">
                  🛒 GROCERY MART: {formatTime12h(settings.grocery_open_time || '06:00')} - {formatTime12h(settings.grocery_close_time || '23:59')}
                </span>
              </div>
            </motion.div>
          ) : (
            <div className="space-y-2 animate-pulse">
              <div className="h-4 w-24 bg-zinc-200/50 dark:bg-zinc-800/40 rounded-full" />
              <div className="h-6 w-56 bg-zinc-200/60 dark:bg-zinc-800/50 rounded-lg" />
            </div>
          )}
        </div>
      </div>

      {/* Standalone Hero Banner Slider */}
      <div className="w-full relative z-10">
        <HeroBanner initialBanners={initialBanners} />
      </div>
    </div>
  )
}
