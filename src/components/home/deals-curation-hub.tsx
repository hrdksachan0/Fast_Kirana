'use client'

import { useState, useMemo, useEffect } from 'react'
import Link from 'next/link'
import { ProductCard } from '@/components/product/product-card'
import { cn } from '@/lib/utils'
import { ShoppingBag } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

// --- Custom Highly-Aesthetic Inline Vector SVG Icons ---

function AllProductsIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      <circle cx="32" cy="32" r="30" fill="#EEF2FF" />
      <path d="M18 24H46L44 48H20L18 24Z" fill="#818CF8" stroke="#4F46E5" strokeWidth="2.5" strokeLinejoin="round"/>
      <path d="M25 24V17C25 13.134 28.134 10 32 10C35.866 10 39 13.134 39 17V24" stroke="#4F46E5" strokeWidth="2.5" strokeLinecap="round"/>
      {/* Groceries inside the bag */}
      <circle cx="28" cy="22" r="6" fill="#F87171" />
      <path d="M29 16C29 16 31 14 31 12" stroke="#059669" strokeWidth="1.5" strokeLinecap="round"/>
      <rect x="34" y="15" width="8" height="12" rx="1" fill="#34D399" />
      <path d="M38 12V15" stroke="#047857" strokeWidth="2"/>
    </svg>
  )
}

function FlashDealsIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      {/* Red circular badge with sunburst notches */}
      <circle cx="32" cy="32" r="28" fill="#EF4444" />
      <circle cx="32" cy="32" r="24" fill="#DC2626" />
      {/* Inner glowing yellow lightning bolt */}
      <path d="M35 14L19 36H31L27 52L45 30H31L35 14Z" fill="#FBBF24" stroke="#F59E0B" strokeWidth="2.5" strokeLinejoin="round"/>
    </svg>
  )
}

function BestSellersIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      {/* Ribbon tails at the bottom */}
      <path d="M24 35L18 58L32 50L46 58L40 35" fill="#D97706" stroke="#B45309" strokeWidth="2" strokeLinejoin="round"/>
      <path d="M28 35L24 54L32 49L40 54L36 35" fill="#F59E0B" />
      {/* Golden scalloped circle */}
      <circle cx="32" cy="30" r="24" fill="#FBBF24" stroke="#D97706" strokeWidth="2.5" />
      <circle cx="32" cy="30" r="20" fill="#FCD34D" />
      
      {/* Star in Center */}
      <path d="M32 18L35 24H41L36 28L38 34L32 30L26 34L28 28L23 24H29L32 18Z" fill="#FFF" stroke="#D97706" strokeWidth="1.5" strokeLinejoin="round"/>
    </svg>
  )
}

function BreakfastIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      <circle cx="32" cy="32" r="30" fill="#FFFBEB" />
      {/* Frying pan with egg */}
      <circle cx="26" cy="36" r="14" fill="#4B5563" stroke="#1F2937" strokeWidth="2" />
      <path d="M36 46L48 58" stroke="#1F2937" strokeWidth="3.5" strokeLinecap="round" />
      {/* Fried Egg */}
      <path d="M26 28C22 28 20 31 20 34C20 37 23 40 26 40C29 40 31 38 32 35C33 32 30 28 26 28Z" fill="#F9FAFB" />
      <circle cx="25" cy="34" r="5" fill="#FBBF24" />
      {/* Steaming Coffee Cup */}
      <rect x="36" y="18" width="16" height="12" rx="3" fill="#D97706" stroke="#B45309" strokeWidth="2"/>
      <path d="M52 21C55 21 56 23 56 24C56 25 55 27 52 27" stroke="#B45309" strokeWidth="2" strokeLinecap="round"/>
      {/* Steam lines */}
      <path d="M40 10C40 10 41 12 41 14" stroke="#F59E0B" strokeWidth="1.5" strokeLinecap="round"/>
      <path d="M44 8C44 8 45 10 45 12" stroke="#F59E0B" strokeWidth="1.5" strokeLinecap="round"/>
      <path d="M48 10C48 10 49 12 49 14" stroke="#F59E0B" strokeWidth="1.5" strokeLinecap="round"/>
    </svg>
  )
}

function LunchIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      <circle cx="32" cy="32" r="30" fill="#ECFDF5" />
      {/* Steel Thali Plate */}
      <circle cx="32" cy="32" r="22" fill="#E5E7EB" stroke="#9CA3AF" strokeWidth="2.5" />
      {/* Bowls */}
      <circle cx="24" cy="22" r="6" fill="#F59E0B" stroke="#D97706" strokeWidth="1.5" />
      <circle cx="40" cy="22" r="6" fill="#EF4444" stroke="#DC2626" strokeWidth="1.5" />
      {/* Steamed Rice */}
      <path d="M22 36C22 36 25 30 32 30C39 30 42 36 42 36C42 36 39 40 32 40C25 40 22 36 22 36Z" fill="#FFF" stroke="#E5E7EB" strokeWidth="1" />
      <circle cx="32" cy="35" r="2" fill="#10B981" />
      {/* Roti */}
      <circle cx="26" cy="40" r="7" fill="#FDE047" stroke="#CA8A04" strokeWidth="1.5" opacity="0.9" />
    </svg>
  )
}

function TeaIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      <circle cx="32" cy="32" r="30" fill="#FFF1F2" />
      {/* Samosa */}
      <path d="M16 44L28 20L40 44Z" fill="#F59E0B" stroke="#D97706" strokeWidth="2" strokeLinejoin="round"/>
      <path d="M20 44L28 24L36 44Z" fill="#FCD34D" />
      {/* Tea Glass */}
      <path d="M42 22L46 44H34L38 22H42Z" fill="#FDBA74" stroke="#F97316" strokeWidth="2" strokeLinejoin="round"/>
      <rect x="36" y="24" width="8" height="10" fill="#EA580C" opacity="0.8"/>
      {/* Steam lines */}
      <path d="M38 14C38 14 39 16 39 18" stroke="#F97316" strokeWidth="1.5" strokeLinecap="round"/>
      <path d="M42 14C42 14 43 16 43 18" stroke="#F97316" strokeWidth="1.5" strokeLinecap="round"/>
    </svg>
  )
}

function NightIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      <circle cx="32" cy="32" r="30" fill="#FAF5FF" />
      {/* Crescent Moon */}
      <path d="M46 14C41.5 14 38 17.5 38 22C38 26.5 41.5 30 46 30C47.5 30 48.9 29.6 50 28.9C47.2 30.8 43.2 30.6 40.5 27.9C37.8 25.2 37.6 21.2 39.5 18.4C38.8 19.5 38.4 20.9 38.4 22.4" fill="#FBBF24" transform="translate(-10, -2)" opacity="0.95"/>
      {/* Ramen Bowl */}
      <path d="M18 34C18 34 18 48 32 48C46 48 46 34 18 34Z" fill="#EC4899" stroke="#DB2777" strokeWidth="2.5" strokeLinejoin="round"/>
      {/* Noodles & Steam */}
      <path d="M22 34C24 30 26 34 28 30C30 34 32 30 34 34C36 30 38 34 40 30" stroke="#FCD34D" strokeWidth="2" strokeLinecap="round"/>
      <path d="M28 24C28 24 29 20 29 22" stroke="#D8B4FE" strokeWidth="1.5" strokeLinecap="round"/>
      <path d="M34 24C34 24 35 20 35 22" stroke="#D8B4FE" strokeWidth="1.5" strokeLinecap="round"/>
      {/* Chopsticks */}
      <line x1="12" y1="28" x2="38" y2="38" stroke="#78350F" strokeWidth="2" strokeLinecap="round"/>
      <line x1="14" y1="25" x2="40" y2="35" stroke="#78350F" strokeWidth="2" strokeLinecap="round"/>
    </svg>
  )
}

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
        icon: BreakfastIcon,
        gradient: 'from-amber-400 via-orange-500 to-yellow-500',
        activeBorderColor: '#F59E0B',
        products: breakfastProducts,
        activeShadow: 'shadow-[0_12px_25px_-5px_rgba(245,158,11,0.22)]',
        inactiveBg: 'bg-amber-500/[0.02]',
        inactiveHover: 'hover:border-amber-500/20',
        liveTag: '🍳 Breakfast Mode',
      }
    }
    // 11 AM - 4 PM: Lunch Specials
    else if (currentHour >= 11 && currentHour < 16) {
      return {
        id: 'dynamic-craving' as const,
        title: 'Lunch Specials',
        subtitle: '🍛 Lunch meals',
        icon: LunchIcon,
        gradient: 'from-emerald-500 via-teal-500 to-cyan-500',
        activeBorderColor: '#10B981',
        products: lunchProducts,
        activeShadow: 'shadow-[0_12px_25px_-5px_rgba(16,185,129,0.22)]',
        inactiveBg: 'bg-emerald-500/[0.02]',
        inactiveHover: 'hover:border-emerald-500/20',
        liveTag: '🍛 Lunch Mode',
      }
    }
    // 4 PM - 8 PM: Snack O'Clock
    else if (currentHour >= 16 && currentHour < 20) {
      return {
        id: 'dynamic-craving' as const,
        title: 'Snack O\'Clock',
        subtitle: '☕ Tea snacks',
        icon: TeaIcon,
        gradient: 'from-rose-500 via-orange-500 to-amber-600',
        activeBorderColor: '#F43F5E',
        products: teaProducts,
        activeShadow: 'shadow-[0_12px_25px_-5px_rgba(244,63,94,0.22)]',
        inactiveBg: 'bg-rose-500/[0.02]',
        inactiveHover: 'hover:border-rose-500/20',
        liveTag: '☕ Snacks Mode',
      }
    }
    // 8 PM - 5 AM: Night Cravings
    else {
      return {
        id: 'dynamic-craving' as const,
        title: 'Night Cravings',
        subtitle: '🌙 Midnight cravings',
        icon: NightIcon,
        gradient: 'from-purple-800 via-rose-700 to-amber-800',
        activeBorderColor: '#8B5CF6',
        products: nightProducts,
        activeShadow: 'shadow-[0_12px_25px_-5px_rgba(139,92,246,0.22)]',
        inactiveBg: 'bg-purple-500/[0.02]',
        inactiveHover: 'hover:border-purple-500/20',
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
      icon: AllProductsIcon,
      gradient: 'from-indigo-600 via-indigo-500 to-purple-600',
      activeBorderColor: '#6366F1',
      products: allProducts,
      activeShadow: 'shadow-[0_12px_25px_-5px_rgba(99,102,241,0.22)]',
      inactiveBg: 'bg-indigo-500/[0.02]',
      inactiveHover: 'hover:border-indigo-500/20',
    },
    {
      id: 'flash-deals' as const,
      title: 'Flash Deals',
      subtitle: '⚡ Instant discounts',
      icon: FlashDealsIcon,
      gradient: 'from-amber-500 via-orange-500 to-rose-500',
      activeBorderColor: '#EF4444',
      products: flashDeals,
      activeShadow: 'shadow-[0_12px_25px_-5px_rgba(239,68,68,0.22)]',
      inactiveBg: 'bg-orange-500/[0.02]',
      inactiveHover: 'hover:border-orange-500/20',
    },
    {
      id: 'best-in-town' as const,
      title: 'Best Sellers',
      icon: BestSellersIcon,
      subtitle: '🏆 Customer favorites',
      gradient: 'from-blue-600 via-indigo-500 to-cyan-500',
      activeBorderColor: '#3B82F6',
      products: bestSellers,
      activeShadow: 'shadow-[0_12px_25px_-5px_rgba(59,130,246,0.22)]',
      inactiveBg: 'bg-blue-500/[0.02]',
      inactiveHover: 'hover:border-blue-500/20',
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

      {/* Premium Curation Tab Bar: Redesigned into minimal organic category circles */}
      <div className="flex items-center gap-6 sm:gap-10 overflow-x-auto pb-3.5 pt-2 select-none w-full justify-start sm:justify-center scroll-smooth snap-x snap-mandatory scrollbar-none px-1">
        {curations.map((c) => {
          const isActive = activeCuration === c.id
          return (
            <button
              key={c.id}
              onClick={() => setActiveCuration(c.id)}
              className="group flex flex-col items-center gap-2 cursor-pointer shrink-0 snap-start outline-none select-none active:scale-95 transition-transform duration-300"
            >
              {/* Clean minimal organic circle */}
              <div
                className={cn(
                  'relative w-16 h-16 sm:w-[72px] sm:h-[72px] rounded-full flex items-center justify-center transition-all duration-300 border bg-white dark:bg-zinc-950',
                  isActive
                    ? 'scale-105 shadow-md border-transparent'
                    : 'border-zinc-200/50 dark:border-zinc-800/40 hover:border-zinc-350 dark:hover:border-zinc-750 hover:scale-102 shadow-sm shadow-black/[0.005]'
                )}
                style={
                  isActive
                    ? {
                        boxShadow: `0 0 0 2.5px ${c.activeBorderColor}`,
                      }
                    : undefined
                }
              >
                {/* Custom Vector inline SVG icon */}
                {c.icon && (
                  <c.icon className="w-13 h-13 sm:w-[58px] sm:h-[58px] transition-transform duration-500 group-hover:scale-105 group-hover:rotate-2 relative z-10" />
                )}
              </div>

              {/* Title Text Centered Below */}
              <span
                className={cn(
                  'text-[10.5px] sm:text-xs font-black tracking-tight transition-colors duration-300 max-w-[85px] sm:max-w-[105px] text-center line-clamp-2 leading-tight',
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
