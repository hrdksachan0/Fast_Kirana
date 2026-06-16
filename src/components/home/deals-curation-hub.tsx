'use client'

import { useState, useMemo, useEffect } from 'react'
import Link from 'next/link'
import { ProductCard } from '@/components/product/product-card'
import { cn } from '@/lib/utils'
import { ShoppingBag } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

interface DealsCurationHubProps {
  flashDeals: any[]
  bestSellers: any[]
  breakfastProducts: any[]
  lunchProducts: any[]
  teaProducts: any[]
  nightProducts: any[]
}

export function DealsCurationHub({
  flashDeals,
  bestSellers,
  breakfastProducts,
  lunchProducts,
  teaProducts,
  nightProducts
}: DealsCurationHubProps) {
  const [activeCuration, setActiveCuration] = useState<'all' | 'flash-deals' | 'best-in-town' | 'dynamic-craving'>('all')
  const [currentHour, setCurrentHour] = useState<number>(0) // default to 0 (Night Mode)
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
    const getISTHour = () => {
      const serverTime = new Date()
      // Indian Standard Time is UTC + 5.5 hours
      const istTime = new Date(serverTime.getTime() + (serverTime.getTimezoneOffset() * 60000) + (5.5 * 60 * 60 * 1000))
      return istTime.getHours()
    }
    setCurrentHour(getISTHour())
    
    // Periodically update the hour to keep the dynamic experience synced
    const interval = setInterval(() => {
      setCurrentHour(getISTHour())
    }, 60000)
    return () => clearInterval(interval)
  }, [])

  // Dynamic Craving configuration based on current hour
  const dynamicCravingConfig = useMemo(() => {
    // 6 AM - 11 AM: Breakfast Club
    if (currentHour >= 6 && currentHour < 11) {
      return {
        id: 'dynamic-craving' as const,
        title: 'Breakfast Club',
        subtitle: '🍳 Morning starts',
        image: '/breakfast_deals_badge.png',
        gradient: 'from-amber-400 via-orange-500 to-yellow-500',
        products: breakfastProducts,
        activeShadow: 'shadow-[0_12px_25px_-5px_rgba(245,158,11,0.35)] dark:shadow-[0_12px_25px_-5px_rgba(245,158,11,0.18)]',
        inactiveBg: 'bg-amber-500/[0.02] border-amber-500/10 dark:bg-amber-950/[0.06] dark:border-amber-900/20 text-text-primary',
        inactiveHover: 'hover:border-amber-500/30 hover:bg-amber-500/[0.06] dark:hover:border-amber-500/20',
        liveTag: '🍳 Breakfast Mode',
      }
    }
    // 11 AM - 4 PM: Lunch Specials
    else if (currentHour >= 11 && currentHour < 16) {
      return {
        id: 'dynamic-craving' as const,
        title: 'Lunch Specials',
        subtitle: '🍛 Lunch meals',
        image: '/lunch_deals_badge.png',
        gradient: 'from-emerald-500 via-teal-500 to-cyan-500',
        products: lunchProducts,
        activeShadow: 'shadow-[0_12px_25px_-5px_rgba(16,185,129,0.35)] dark:shadow-[0_12px_25px_-5px_rgba(16,185,129,0.18)]',
        inactiveBg: 'bg-emerald-500/[0.02] border-emerald-500/10 dark:bg-emerald-950/[0.06] dark:border-emerald-900/20 text-text-primary',
        inactiveHover: 'hover:border-emerald-500/30 hover:bg-emerald-500/[0.06] dark:hover:border-emerald-500/20',
        liveTag: '🍛 Lunch Mode',
      }
    }
    // 4 PM - 8 PM: Snack O'Clock
    else if (currentHour >= 16 && currentHour < 20) {
      return {
        id: 'dynamic-craving' as const,
        title: 'Snack O\'Clock',
        subtitle: '☕ Tea snacks',
        image: '/tea_deals_badge.png',
        gradient: 'from-rose-500 via-orange-500 to-amber-600',
        products: teaProducts,
        activeShadow: 'shadow-[0_12px_25px_-5px_rgba(244,63,94,0.35)] dark:shadow-[0_12px_25px_-5px_rgba(244,63,94,0.18)]',
        inactiveBg: 'bg-rose-500/[0.02] border-rose-500/10 dark:bg-rose-950/[0.06] dark:border-rose-900/20 text-text-primary',
        inactiveHover: 'hover:border-rose-500/30 hover:bg-rose-500/[0.06] dark:hover:border-rose-500/20',
        liveTag: '☕ Snacks Mode',
      }
    }
    // 8 PM - 5 AM: Night Cravings
    else {
      return {
        id: 'dynamic-craving' as const,
        title: 'Night Cravings',
        subtitle: '🌙 Midnight cravings',
        image: '/night_cravings_badge.png',
        gradient: 'from-purple-800 via-rose-700 to-amber-800',
        products: nightProducts,
        activeShadow: 'shadow-[0_12px_25px_-5px_rgba(139,92,246,0.35)] dark:shadow-[0_12px_25px_-5px_rgba(139,92,246,0.18)]',
        inactiveBg: 'bg-purple-500/[0.02] border-purple-500/10 dark:bg-purple-950/[0.06] dark:border-purple-900/20 text-text-primary',
        inactiveHover: 'hover:border-purple-500/30 hover:bg-purple-500/[0.06] dark:hover:border-purple-500/20',
        liveTag: '🌙 Cravings Mode',
      }
    }
  }, [currentHour, breakfastProducts, lunchProducts, teaProducts, nightProducts])

  // Combine products for "All Products" curation dynamically to ensure they stay up-to-date
  const allProducts = useMemo(() => {
    const combined = [...flashDeals, ...bestSellers, ...dynamicCravingConfig.products]
    const seen = new Set()
    return combined.filter((p) => {
      if (!p || !p.id) return false
      if (seen.has(p.id)) return false
      seen.add(p.id)
      return true
    })
  }, [flashDeals, bestSellers, dynamicCravingConfig.products])

  // All curation options with refined, vibrant gradients
  const curations = useMemo(() => [
    {
      id: 'all' as const,
      title: 'All Products',
      subtitle: '🔥 Mega collections',
      image: '/all_products_badge.png',
      gradient: 'from-indigo-600 via-indigo-500 to-purple-600',
      products: allProducts,
      activeShadow: 'shadow-[0_12px_25px_-5px_rgba(99,102,241,0.35)] dark:shadow-[0_12px_25px_-5px_rgba(99,102,241,0.18)]',
      inactiveBg: 'bg-indigo-500/[0.02] border-indigo-500/10 dark:bg-indigo-950/[0.06] dark:border-indigo-900/20 text-text-primary',
      inactiveHover: 'hover:border-indigo-500/30 hover:bg-indigo-500/[0.06] dark:hover:border-indigo-500/20',
    },
    {
      id: 'flash-deals' as const,
      title: 'Flash Deals',
      subtitle: '⚡ Instant discounts',
      image: '/flash_deals_badge.png',
      gradient: 'from-amber-500 via-orange-500 to-rose-500',
      products: flashDeals,
      activeShadow: 'shadow-[0_12px_25px_-5px_rgba(249,115,22,0.35)] dark:shadow-[0_12px_25px_-5px_rgba(249,115,22,0.18)]',
      inactiveBg: 'bg-orange-500/[0.02] border-orange-500/10 dark:bg-orange-950/[0.06] dark:border-orange-900/20 text-text-primary',
      inactiveHover: 'hover:border-orange-500/30 hover:bg-orange-500/[0.06] dark:hover:border-orange-500/20',
    },
    {
      id: 'best-in-town' as const,
      title: 'Best Sellers',
      subtitle: '🏆 Customer favorites',
      image: '/best_sellers_badge.png',
      gradient: 'from-blue-600 via-indigo-500 to-cyan-500',
      products: bestSellers,
      activeShadow: 'shadow-[0_12px_25px_-5px_rgba(37,99,235,0.35)] dark:shadow-[0_12px_25px_-5px_rgba(37,99,235,0.18)]',
      inactiveBg: 'bg-blue-500/[0.02] border-blue-500/10 dark:bg-blue-950/[0.06] dark:border-blue-900/20 text-text-primary',
      inactiveHover: 'hover:border-blue-500/30 hover:bg-blue-500/[0.06] dark:hover:border-blue-500/20',
    },
    {
      ...dynamicCravingConfig
    }
  ], [allProducts, flashDeals, bestSellers, dynamicCravingConfig])

  // Active curation data
  const currentCuration = useMemo(() => {
    return curations.find((c) => c.id === activeCuration) || curations[0]
  }, [activeCuration, curations])

  // Group products of the active curation by their category dynamically
  const groupedProducts = useMemo(() => {
    const groups: Record<string, { categoryName: string; categorySlug: string; products: any[] }> = {}
    currentCuration.products.forEach((product) => {
      const categoryName = product.category?.name || 'Other Essentials'
      const categorySlug = product.category?.slug || ''
      if (!groups[categoryName]) {
        groups[categoryName] = {
          categoryName,
          categorySlug,
          products: [],
        }
      }
      groups[categoryName].products.push(product)
    })
    return Object.values(groups)
  }, [currentCuration])

  return (
    <section className="relative py-6 md:py-10 space-y-6 rounded-3xl overflow-hidden px-4 md:px-6 transition-all duration-500 border border-zinc-100/80 dark:border-zinc-800/50 bg-white/40 dark:bg-zinc-900/20 backdrop-blur-md shadow-sm">
      {/* Dynamic ambient background glow */}
      <div 
        className={cn(
          "absolute inset-0 -z-20 opacity-[0.03] dark:opacity-[0.07] bg-gradient-to-tr transition-all duration-700 blur-[80px]",
          currentCuration.gradient
        )}
      />
      {/* Localized glows */}
      <div 
        className={cn(
          "absolute -top-10 -left-10 w-48 h-48 rounded-full -z-20 opacity-[0.04] dark:opacity-[0.08] bg-gradient-to-br transition-all duration-700 blur-[60px]",
          currentCuration.gradient
        )}
      />
      <div 
        className={cn(
          "absolute -bottom-10 -right-10 w-48 h-48 rounded-full -z-20 opacity-[0.04] dark:opacity-[0.08] bg-gradient-to-tl transition-all duration-700 blur-[60px]",
          currentCuration.gradient
        )}
      />

      {/* Dynamic Hub Title & Vibe Tag */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 px-1">
        <div className="flex items-center gap-2.5">
          <span className={cn(
            "h-6 w-1.5 rounded-full bg-gradient-to-b shrink-0 transition-all duration-500",
            currentCuration.gradient
          )} />
          <div>
            <h2 className="text-base md:text-xl font-black text-text-primary tracking-tight">
              Special Curations Hub
            </h2>
            <p className="text-[10px] md:text-xs text-text-secondary font-bold">
              Specially compiled deals & cravings categories
            </p>
          </div>
        </div>

        {/* Pulse timezone mode indicator */}
        {mounted && (
          <div className="flex items-center self-start sm:self-center">
            <span className={cn(
              "inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[10px] font-black text-white bg-gradient-to-r shadow-sm border border-white/10 select-none animate-pulse-gentle transition-all duration-500",
              dynamicCravingConfig.gradient
            )}>
              <span className="h-1.5 w-1.5 rounded-full bg-white animate-ping shrink-0" />
              {dynamicCravingConfig.liveTag} Active
            </span>
          </div>
        )}
      </div>

      {/* Premium Curation Tab Bar: Redesigned into Liquid-Glass Bubbles */}
      <div className="flex items-center gap-5 sm:gap-8 overflow-x-auto pb-4 pt-2.5 scrollbar-none px-1 select-none w-full justify-start sm:justify-center scroll-smooth snap-x snap-mandatory">
        {curations.map((c) => {
          const isActive = activeCuration === c.id
          return (
            <button
              key={c.id}
              onClick={() => setActiveCuration(c.id)}
              className="group flex flex-col items-center gap-2 cursor-pointer shrink-0 snap-start outline-none select-none active:scale-95 transition-transform duration-300"
            >
              {/* Glossy Liquid-Glassmorphic Bubble */}
              <motion.div
                animate={isActive ? { y: [0, -3, 0] } : { y: 0 }}
                transition={isActive ? { repeat: Infinity, duration: 3.5, ease: 'easeInOut' } : undefined}
                className={cn(
                  'relative w-16 h-16 sm:w-20 sm:h-20 rounded-full flex items-center justify-center transition-all duration-300 border overflow-hidden backdrop-blur-lg',
                  isActive
                    ? 'border-white/40 dark:border-white/10 scale-105 shadow-lg shadow-black/[0.05]'
                    : 'bg-white/40 dark:bg-zinc-900/40 border-zinc-200/50 dark:border-zinc-800/40 hover:border-zinc-300 dark:hover:border-zinc-700 hover:scale-102 shadow-sm shadow-black/[0.01]'
                )}
              >
                {/* 3D Glossy reflection overlays simulating a liquid glass dome */}
                <div className="absolute inset-0 bg-gradient-to-b from-white/20 via-transparent to-transparent pointer-events-none rounded-full" />
                <div className="absolute top-[1.5px] left-1/2 -translate-x-1/2 w-4/5 h-2/5 bg-gradient-to-b from-white/25 to-transparent blur-[0.5px] rounded-full pointer-events-none" />
                <div className="absolute inset-[1px] border border-white/25 dark:border-white/5 rounded-full pointer-events-none" />

                {/* Fluid background color blob inside the liquid glass */}
                {isActive && (
                  <motion.div
                    layoutId="activeCurationCircle"
                    className={cn(
                      'absolute inset-0 rounded-full bg-gradient-to-tr -z-10 opacity-90',
                      c.gradient
                    )}
                    transition={{ type: 'spring', stiffness: 280, damping: 24 }}
                  />
                )}

                {/* Floating 3D badge icon inside the liquid bubble */}
                {c.image && (
                  <img
                    src={c.image}
                    alt={c.title}
                    className="w-10 h-10 sm:w-12 sm:h-12 object-contain pointer-events-none transition-transform duration-500 group-hover:scale-110 group-hover:rotate-3 relative z-10 filter drop-shadow-[0_2.5px_6px_rgba(0,0,0,0.15)]"
                  />
                )}
              </motion.div>

              {/* Title Text Centered Below */}
              <span
                className={cn(
                  'text-[10px] sm:text-xs font-black tracking-tight transition-colors duration-300 max-w-[80px] sm:max-w-[100px] text-center line-clamp-2 leading-tight',
                  isActive
                    ? 'text-text-primary dark:text-white font-extrabold'
                    : 'text-text-secondary dark:text-zinc-400 group-hover:text-text-primary dark:group-hover:text-white'
                )}
              >
                {c.title}
              </span>

              {/* Bottom active underline indicator bar */}
              <div className="relative h-1 w-6 rounded-full overflow-hidden mt-0.5">
                {isActive && (
                  <motion.div
                    layoutId="activeCurationUnderline"
                    className={cn('absolute inset-0 bg-gradient-to-r', c.gradient)}
                    transition={{ type: 'spring', stiffness: 280, damping: 24 }}
                  />
                )}
              </div>
            </button>
          )
        })}
      </div>

      {/* Category-grouped Product Display Grid */}
      <div className="relative min-h-[250px] w-full">
        <AnimatePresence mode="wait">
          <motion.div
            key={activeCuration}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.2 }}
            className="w-full"
          >
            {currentCuration.products.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-16 border border-dashed border-zinc-200 dark:border-zinc-800 rounded-2xl text-center p-4 shadow-sm select-none">
                <ShoppingBag className="h-7 w-7 text-muted-foreground/60 mb-2 animate-pulse-gentle" />
                <h3 className="text-xs font-bold text-text-primary">No deals available</h3>
                <p className="text-[10px] text-text-secondary mt-0.5">Please check back later!</p>
              </div>
            ) : (
              <div className="space-y-6">
                {groupedProducts.map((group) => (
                  <div key={group.categoryName} className="space-y-2.5">
                    {/* Category Subheader */}
                    <div className="flex items-center justify-between px-1">
                      <div className="flex items-center gap-2">
                        <h3 className="text-xs sm:text-sm font-black text-text-primary tracking-tight">
                          {group.categoryName}
                        </h3>
                        <span className="inline-flex items-center justify-center px-1.5 py-0.5 rounded bg-zinc-100 dark:bg-zinc-800/80 text-[9px] font-bold text-text-secondary">
                          {group.products.length} {group.products.length === 1 ? 'item' : 'items'}
                        </span>
                      </div>
                      
                      {/* Interactive See All link */}
                      <Link
                        href={group.categorySlug ? `/categories/${group.categorySlug}` : '/categories'}
                        className="group/btn inline-flex items-center gap-0.5 text-[10px] sm:text-xs font-black text-primary hover:text-primary-hover transition-colors select-none"
                      >
                        See All
                        <span className="inline-block transition-transform duration-300 group-hover/btn:translate-x-0.5 font-normal">
                          →
                        </span>
                      </Link>
                    </div>

                    {/* Category Products Horizontal Snap Track */}
                    <div 
                      className="flex gap-2.5 md:gap-4 overflow-x-auto pb-2 md:pb-4 scroll-smooth snap-x snap-mandatory"
                      style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
                    >
                      {group.products.map((product) => (
                        <div 
                          key={product.id} 
                          className="w-[130px] min-[375px]:w-[140px] sm:w-[150px] md:w-[190px] flex-shrink-0 snap-start"
                        >
                          <ProductCard product={product} />
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </motion.div>
        </AnimatePresence>
      </div>
    </section>
  )
}
