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
  const [activeCategory, setActiveCategory] = useState<string>('all')

  // Combine products for "All Offers" curation without duplicates
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
      image: '',
      gradient: 'from-pink-600 via-purple-500 to-indigo-600',
      iconColor: 'text-purple-500 bg-purple-500/10',
      description: 'All deals categorized for easy scrolling.',
      products: allProducts,
    },
    {
      id: 'flash-deals' as const,
      title: 'Flash Deals',
      subtitle: '⚡ Instant discounts',
      image: '/flash_deals_badge.png',
      gradient: 'from-orange-500 via-amber-500 to-rose-500',
      iconColor: 'text-amber-500 bg-amber-500/10',
      description: 'Grab deals before they expire!',
      products: flashDeals,
    },
    {
      id: 'best-in-town' as const,
      title: 'Best Sellers',
      subtitle: '🏆 Customer favorites',
      image: '/best_sellers_badge.png',
      gradient: 'from-blue-600 via-indigo-500 to-violet-600',
      iconColor: 'text-blue-500 bg-blue-500/10',
      description: 'Most loved items in your locality.',
      products: bestSellers,
    },
    {
      id: 'night-cravings' as const,
      title: 'Night Cravings',
      subtitle: '🌙 Midnight munchies',
      image: '/night_cravings_badge.png',
      gradient: 'from-purple-800 via-rose-700 to-amber-800',
      iconColor: 'text-purple-500 bg-purple-500/10',
      description: 'Snacks, ice creams & warm meals.',
      products: nightCravings,
    },
  ], [allProducts, flashDeals, bestSellers, nightCravings])

  // Category filters with visual representations
  const categoriesList = [
    { id: 'all', label: 'All Products', emoji: '❤️' },
    { id: 'cafe', label: 'Zepto Cafe', emoji: '☕' },
    { id: 'fruits-vegetables', label: 'Fruits & Veg', emoji: '🥦' },
    { id: 'dairy-breakfast', label: 'Milk & Dairy', emoji: '🥛' },
    { id: 'snacks-munchies', label: 'Snacks', emoji: '🍿' },
    { id: 'beverages', label: 'Beverages', emoji: '🥤' },
    { id: 'ice-cream', label: 'Ice-cream', emoji: '🍦' },
  ]

  // Active curation data
  const currentCuration = useMemo(() => {
    return curations.find((c) => c.id === activeCuration) || curations[0]
  }, [activeCuration, curations])

  // Group products by category buckets for category-wise display
  const groupedByCategory = useMemo(() => {
    const groups: { category: typeof categoriesList[0]; products: any[] }[] = []

    categoriesList.forEach((cat) => {
      if (cat.id === 'all') return

      const catProducts = currentCuration.products.filter((p) => {
        const slug = p.category?.slug || ''
        const tags = p.tags?.map((t: string) => t.toLowerCase()) || []

        if (cat.id === 'cafe') {
          return slug === 'cafe' || tags.includes('cafe')
        }
        if (cat.id === 'fruits-vegetables') {
          return slug === 'fruits-vegetables' || tags.includes('fruits') || tags.includes('vegetables')
        }
        if (cat.id === 'dairy-breakfast') {
          return slug === 'dairy-breakfast' || tags.includes('dairy') || tags.includes('breakfast')
        }
        if (cat.id === 'snacks-munchies') {
          return slug === 'snacks-munchies' || tags.includes('snacks') || tags.includes('munchies')
        }
        if (cat.id === 'beverages') {
          return slug === 'beverages' || tags.includes('beverages') || tags.includes('beverage')
        }
        if (cat.id === 'ice-cream') {
          return slug === 'ice-cream' || tags.includes('ice-cream') || tags.includes('icecream')
        }
        return slug === cat.id
      })

      if (catProducts.length > 0) {
        groups.push({
          category: cat,
          products: catProducts,
        })
      }
    })

    return groups
  }, [currentCuration, categoriesList])

  // Filter products by active category (used for single category views)
  const filteredProducts = useMemo(() => {
    const baseProducts = currentCuration.products
    if (activeCategory === 'all') return baseProducts

    return baseProducts.filter((product) => {
      const slug = product.category?.slug || ''
      const tags = product.tags?.map((t: string) => t.toLowerCase()) || []

      if (activeCategory === 'cafe') {
        return slug === 'cafe' || tags.includes('cafe')
      }
      if (activeCategory === 'fruits-vegetables') {
        return slug === 'fruits-vegetables' || tags.includes('fruits') || tags.includes('vegetables')
      }
      if (activeCategory === 'dairy-breakfast') {
        return slug === 'dairy-breakfast' || tags.includes('dairy') || tags.includes('breakfast')
      }
      if (activeCategory === 'snacks-munchies') {
        return slug === 'snacks-munchies' || tags.includes('snacks') || tags.includes('munchies')
      }
      if (activeCategory === 'beverages') {
        return slug === 'beverages' || tags.includes('beverages') || tags.includes('beverage')
      }
      if (activeCategory === 'ice-cream') {
        return slug === 'ice-cream' || tags.includes('ice-cream') || tags.includes('icecream')
      }
      return slug === activeCategory
    })
  }, [currentCuration, activeCategory])

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

      {/* Curation Selectors Grid (All, Flash Deals, Best Sellers, Night Cravings) */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 px-1">
        {curations.map((c) => {
          const isActive = activeCuration === c.id
          return (
            <button
              key={c.id}
              onClick={() => {
                setActiveCuration(c.id)
                setActiveCategory('all') // Reset subcategory filter when switching curation type
              }}
              className={cn(
                'group relative flex flex-col justify-between overflow-hidden rounded-xl border p-2.5 text-left transition-all duration-300 active:scale-95 cursor-pointer min-h-[92px] sm:min-h-[105px]',
                isActive
                  ? 'border-transparent text-white shadow-md'
                  : 'bg-card border-border hover:bg-muted text-text-primary hover:-translate-y-0.5'
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
                    'absolute right-0.5 bottom-0.5 w-11 h-11 sm:w-14 sm:h-14 object-contain pointer-events-none transition-all duration-500 group-hover:scale-110 group-hover:rotate-3 z-10',
                    isActive ? 'opacity-95' : 'opacity-70 dark:opacity-85'
                  )}
                  style={{ mixBlendMode: 'screen' }}
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

              {/* Bottom Row: Subtitle / Discount text */}
              <div className="relative z-20 w-full mt-auto max-w-[75%]">
                <span className="block text-[8px] sm:text-[9px] font-black uppercase tracking-wider text-white/70">
                  {isActive ? 'Active Selection' : 'Tap to View'}
                </span>
                <span className={cn(
                  'block text-[11px] sm:text-[13px] font-extrabold leading-tight tracking-tight mt-0.5 truncate',
                  isActive ? 'text-white' : 'text-text-primary'
                )}>
                  {c.subtitle}
                </span>
              </div>
            </button>
          )
        })}
      </div>

      {/* Horizontal Category Filters Row */}
      <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-none px-1 select-none snap-x snap-mandatory scroll-smooth">
        {categoriesList.map((cat) => {
          const isActive = activeCategory === cat.id
          // Count items under this category within current curation list
          const itemsCount = currentCuration.products.filter((p) => {
            const slug = p.category?.slug || ''
            const tags = p.tags?.map((t: string) => t.toLowerCase()) || []
            if (cat.id === 'all') return true
            if (cat.id === 'cafe') return slug === 'cafe' || tags.includes('cafe')
            if (cat.id === 'fruits-vegetables') return slug === 'fruits-vegetables' || tags.includes('fruits') || tags.includes('vegetables')
            if (cat.id === 'dairy-breakfast') return slug === 'dairy-breakfast' || tags.includes('dairy') || tags.includes('breakfast')
            if (cat.id === 'snacks-munchies') return slug === 'snacks-munchies' || tags.includes('snacks') || tags.includes('munchies')
            if (cat.id === 'beverages') return slug === 'beverages' || tags.includes('beverages') || tags.includes('beverage')
            if (cat.id === 'ice-cream') return slug === 'ice-cream' || tags.includes('ice-cream') || tags.includes('icecream')
            return slug === cat.id
          }).length

          // Render only categories that actually contain products in this curation list (or 'all' option)
          if (itemsCount === 0 && cat.id !== 'all') return null

          return (
            <button
              key={cat.id}
              onClick={() => setActiveCategory(cat.id)}
              className={cn(
                'flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-black transition-all shrink-0 whitespace-nowrap active:scale-95 shadow-sm snap-start border cursor-pointer',
                isActive
                  ? 'bg-primary text-white border-primary'
                  : 'bg-card border-border/80 text-text-secondary hover:bg-muted'
              )}
            >
              <span>{cat.emoji}</span>
              <span>{cat.label}</span>
              <span className={cn(
                'text-[8px] font-black px-1.5 py-0.5 rounded-full shrink-0 leading-none',
                isActive
                  ? 'bg-white/20 text-white'
                  : 'bg-muted-foreground/15 text-text-secondary'
              )}>
                {itemsCount}
              </span>
            </button>
          )
        })}
      </div>

      {/* Filtered Product Grid or Scrollable Categories depending on active tab */}
      {activeCategory === 'all' ? (
        groupedByCategory.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-12 border border-dashed border-zinc-200 dark:border-zinc-800 bg-zinc-50/20 dark:bg-zinc-900/5 rounded-2xl text-center p-4 shadow-sm select-none animate-fade-in">
            <ShoppingBag className="h-7 w-7 text-muted-foreground/60 mb-2 animate-pulse-gentle" />
            <h3 className="text-xs font-bold text-text-primary">No deals available</h3>
            <p className="text-[10px] text-text-secondary mt-0.5">Please check back later!</p>
          </div>
        ) : (
          <div className="space-y-6 md:space-y-8 select-none">
            {groupedByCategory.map((group) => (
              <div key={group.category.id} className="space-y-2.5">
                {/* Header */}
                <div className="flex justify-between items-center px-1 border-b border-border/40 pb-2 mb-2">
                  <div className="flex items-center gap-2">
                    <span className="flex items-center justify-center w-7 h-7 rounded-lg bg-zinc-100 dark:bg-zinc-900 text-sm shadow-sm select-none leading-none border border-border/40">
                      {group.category.emoji}
                    </span>
                    <h3 className="text-sm font-black text-text-primary tracking-tight">
                      {group.category.label}
                    </h3>
                  </div>
                  <Link
                    href={group.category.id === 'cafe' ? '/cafe' : `/category/${group.category.id}`}
                    className="text-[11px] font-black text-rose-600 dark:text-rose-400 hover:opacity-85 transition-colors flex items-center gap-0.5 select-none cursor-pointer"
                  >
                    <span>See All</span>
                    <ChevronRight size={11} strokeWidth={3} />
                  </Link>
                </div>

                {/* Horizontal Scroll Track on Mobile, Grid layout on Desktop */}
                <div className="flex md:grid md:grid-cols-4 lg:grid-cols-6 gap-3 overflow-x-auto md:overflow-visible pb-3 pt-1 scrollbar-none snap-x snap-mandatory scroll-smooth -mx-4 px-4 md:-mx-0 md:px-0">
                  {group.products.map((p) => (
                    <div key={p.id} className="w-[145px] sm:w-[165px] md:w-auto shrink-0 snap-start">
                      <ProductCard product={p} />
                    </div>
                  ))}
                  {/* See All Card at the end of mobile scroll row */}
                  <Link
                    href={group.category.id === 'cafe' ? '/cafe' : `/category/${group.category.id}`}
                    className="md:hidden w-[110px] sm:w-[130px] shrink-0 snap-start flex flex-col items-center justify-center border border-dashed border-border/85 rounded-xl bg-zinc-50/50 dark:bg-zinc-900/10 p-3 min-h-[200px] hover:bg-muted/40 transition-colors select-none cursor-pointer text-center"
                  >
                    <div className="h-8 w-8 rounded-full bg-rose-500/10 flex items-center justify-center text-rose-600 dark:text-rose-400 mb-2">
                      <ChevronRight size={16} strokeWidth={3} />
                    </div>
                    <span className="text-[10px] font-black text-text-primary">See All</span>
                    <span className="text-[8px] font-bold text-text-secondary mt-0.5 truncate max-w-full">
                      {group.category.label}
                    </span>
                  </Link>
                </div>
              </div>
            ))}
          </div>
        )
      ) : (
        filteredProducts.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-12 border border-dashed border-zinc-200 dark:border-zinc-800 bg-zinc-50/20 dark:bg-zinc-900/5 rounded-2xl text-center p-4 shadow-sm select-none animate-fade-in">
            <ShoppingBag className="h-7 w-7 text-muted-foreground/60 mb-2 animate-pulse-gentle" />
            <h3 className="text-xs font-bold text-text-primary">No deals available</h3>
            <p className="text-[10px] text-text-secondary mt-0.5">Try selecting another category!</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 min-[375px]:grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4 px-1 transition-all duration-300">
            {filteredProducts.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
        )
      )}
    </section>
  )
}
