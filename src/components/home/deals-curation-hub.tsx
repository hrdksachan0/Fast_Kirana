'use client'

import { useState, useMemo } from 'react'
import Link from 'next/link'
import { ProductCard } from '@/components/product/product-card'
import { cn } from '@/lib/utils'
import { Sparkles, Zap, Trophy, Moon, ShoppingBag, ChevronRight } from 'lucide-react'

interface DealsCurationHubProps {
  flashDeals: any[]
  bestSellers: any[]
  nightCravings: any[]
}

export function DealsCurationHub({ flashDeals, bestSellers, nightCravings }: DealsCurationHubProps) {
  const [activeCuration, setActiveCuration] = useState<'all' | 'flash-deals' | 'best-in-town' | 'night-cravings'>('all')

  // Combine products for "All Products" curation without duplicates
  const allProducts = useMemo(() => {
    const combined = [...flashDeals, ...bestSellers, ...nightCravings]
    const seen = new Set()
    return combined.filter((p) => {
      if (!p || !p.id) return false
      if (seen.has(p.id)) return false
      seen.add(p.id)
      return true
    })
  }, [flashDeals, bestSellers, nightCravings])

  // Curation configurations
  const curations = useMemo(() => [
    {
      id: 'all' as const,
      title: 'All Products',
      subtitle: '🔥 Mega collections',
      image: '/all_products_badge.png',
      gradient: 'from-pink-600 via-purple-500 to-indigo-600',
      products: allProducts,
      activeShadow: 'shadow-[0_12px_25px_-5px_rgba(219,39,119,0.35)] dark:shadow-[0_12px_25px_-5px_rgba(219,39,119,0.18)]',
      inactiveBg: 'bg-pink-500/[0.02] border-pink-500/10 dark:bg-pink-950/[0.06] dark:border-pink-900/20 text-text-primary',
      inactiveHover: 'hover:border-pink-500/30 hover:bg-pink-500/[0.06] dark:hover:border-pink-500/20',
    },
    {
      id: 'flash-deals' as const,
      title: 'Flash Deals',
      subtitle: '⚡ Instant discounts',
      image: '/flash_deals_badge.png',
      gradient: 'from-orange-500 via-amber-500 to-rose-500',
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
      gradient: 'from-blue-600 via-indigo-500 to-violet-600',
      products: bestSellers,
      activeShadow: 'shadow-[0_12px_25px_-5px_rgba(59,130,246,0.35)] dark:shadow-[0_12px_25px_-5px_rgba(59,130,246,0.18)]',
      inactiveBg: 'bg-blue-500/[0.02] border-blue-500/10 dark:bg-blue-950/[0.06] dark:border-blue-900/20 text-text-primary',
      inactiveHover: 'hover:border-blue-500/30 hover:bg-blue-500/[0.06] dark:hover:border-blue-500/20',
    },
    {
      id: 'night-cravings' as const,
      title: 'Night Cravings',
      subtitle: '🌙 Midnight munchies',
      image: '/night_cravings_badge.png',
      gradient: 'from-purple-800 via-rose-700 to-amber-800',
      products: nightCravings,
      activeShadow: 'shadow-[0_12px_25px_-5px_rgba(139,92,246,0.35)] dark:shadow-[0_12px_25px_-5px_rgba(139,92,246,0.18)]',
      inactiveBg: 'bg-purple-500/[0.02] border-purple-500/10 dark:bg-purple-950/[0.06] dark:border-purple-900/20 text-text-primary',
      inactiveHover: 'hover:border-purple-500/30 hover:bg-purple-500/[0.06] dark:hover:border-purple-500/20',
    },
  ], [allProducts, flashDeals, bestSellers, nightCravings])

  // Active curation data
  const currentCuration = useMemo(() => {
    return curations.find((c) => c.id === activeCuration) || curations[0]
  }, [activeCuration, curations])

  return (
    <section className="py-4 md:py-8 space-y-5">
      {/* Dynamic Hub Title */}
      <div className="flex items-center gap-2 px-1">
        <span className="h-5.5 w-1.5 rounded-full bg-primary animate-pulse-gentle shrink-0" />
        <div>
          <h2 className="text-base md:text-xl font-black text-text-primary tracking-tight">
            Special Curations Hub
          </h2>
          <p className="text-[10px] md:text-xs text-text-secondary font-bold">
            Specially compiled deals & cravings categories
          </p>
        </div>
      </div>

      {/* Curation Selector Cards (2x2 grid) */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 px-1">
        {curations.map((c) => {
          const isActive = activeCuration === c.id
          return (
            <button
              key={c.id}
              onClick={() => {
                setActiveCuration(c.id)
              }}
              className={cn(
                'group relative flex flex-col justify-between overflow-hidden rounded-xl border p-2.5 text-left transition-all duration-300 active:scale-[0.98] cursor-pointer min-h-[95px] sm:min-h-[110px] hover:-translate-y-0.5',
                isActive
                  ? cn('border-transparent text-white', c.activeShadow)
                  : cn(c.inactiveBg, c.inactiveHover)
              )}
            >
              {/* Background gradient on active state */}
              <div
                className={cn(
                  'absolute inset-0 bg-gradient-to-br transition-opacity duration-300 z-0',
                  c.gradient,
                  isActive ? 'opacity-100' : 'opacity-0'
                )}
              />

              {/* Illustration graphic or fallback icon */}
              {c.image ? (
                <img
                  src={c.image}
                  alt={c.title}
                  className={cn(
                    'absolute right-0.5 bottom-0.5 w-12 h-12 sm:w-16 sm:h-16 object-contain pointer-events-none transition-all duration-500 group-hover:scale-115 group-hover:rotate-3 z-10',
                    isActive ? 'opacity-100' : 'opacity-85 dark:opacity-90'
                  )}
                />
              ) : (
                <ShoppingBag
                  className={cn(
                    'absolute -right-2.5 -bottom-2.5 w-14 h-14 sm:w-16 sm:h-16 stroke-[1.2] transition-all duration-500 group-hover:scale-110 group-hover:-rotate-6 z-10',
                    isActive ? 'text-white/20' : 'text-zinc-200 dark:text-zinc-800/60'
                  )}
                />
              )}

              {/* Top Row: Title */}
              <div className="relative z-20 flex justify-between items-start w-full">
                <span className={cn(
                  'text-[10px] sm:text-xs font-black tracking-tight leading-none',
                  isActive ? 'text-white/90' : 'text-text-secondary'
                )}>
                  {c.title}
                </span>
              </div>

              {/* Bottom Row: Subtitle & Translucent Status Badge */}
              <div className="relative z-20 w-full mt-auto max-w-[75%] space-y-1 text-left">
                <span className={cn(
                  'inline-block text-[7px] sm:text-[8px] font-black uppercase tracking-wider px-1.5 py-0.5 rounded-full',
                  isActive ? 'bg-white/20 text-white' : 'bg-muted text-text-muted'
                )}>
                  {isActive ? 'Active Selection' : 'Tap to View'}
                </span>
                <span className={cn(
                  'block text-[11px] sm:text-[13px] font-extrabold leading-tight tracking-tight truncate mt-0.5',
                  isActive ? 'text-white' : 'text-text-primary'
                )}>
                  {c.subtitle}
                </span>
              </div>
            </button>
          )
        })}
      </div>

      {/* Product Display: flat grid of curation products */}
      {currentCuration.products.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 border border-dashed border-zinc-200 dark:border-zinc-800 rounded-2xl text-center p-4 shadow-sm select-none">
          <ShoppingBag className="h-7 w-7 text-muted-foreground/60 mb-2 animate-pulse-gentle" />
          <h3 className="text-xs font-bold text-text-primary">No deals available</h3>
          <p className="text-[10px] text-text-secondary mt-0.5">Please check back later!</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 min-[375px]:grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4 px-1 transition-all duration-300">
          {currentCuration.products.map((product) => (
            <ProductCard product={product} key={product.id} />
          ))}
        </div>
      )}
    </section>
  )
}
