'use client'

import { useRef, useState, useEffect } from 'react'
import { ChevronLeft, ChevronRight, Sun, Utensils, Cookie, Moon } from 'lucide-react'
import { ProductCard } from '@/components/product/product-card'
import { Product } from '@/types'

interface TimeSuggestionsProps {
  products: Product[]
}

interface TimeConfig {
  icon: React.ReactNode
  title: string
  gradient: string
  bgTint: string
  filterFn: (product: Product) => boolean
}

function getTimeConfig(hour: number): TimeConfig {
  if (hour >= 6 && hour < 11) {
    // Morning 6-10 AM
    return {
      icon: <Sun className="h-5 w-5 text-amber-500 fill-amber-500/25 animate-spin-slow" />,
      title: 'Breakfast Essentials',
      gradient: 'from-amber-50 via-yellow-50 to-orange-50',
      bgTint: 'bg-gradient-to-r from-amber-50/80 via-yellow-50/60 to-orange-50/40',
      filterFn: (product: Product) => {
        const tags = product.tags?.map((t) => t.toLowerCase()) || []
        const categorySlug = product.category?.slug || ''
        return (
          tags.includes('breakfast') ||
          tags.includes('dairy') ||
          categorySlug === 'dairy-breakfast'
        )
      },
    }
  } else if (hour >= 11 && hour < 16) {
    // Afternoon 11 AM - 3 PM
    return {
      icon: <Utensils className="h-5 w-5 text-orange-500" />,
      title: 'Lunch Time Picks',
      gradient: 'from-stone-50 via-neutral-50 to-zinc-50',
      bgTint: 'bg-gradient-to-r from-stone-50/80 via-neutral-50/60 to-zinc-50/40',
      filterFn: (product: Product) => {
        const tags = product.tags?.map((t) => t.toLowerCase()) || []
        const categorySlug = product.category?.slug || ''
        return (
          categorySlug === 'atta-rice-dal' ||
          tags.includes('staples')
        )
      },
    }
  } else if (hour >= 16 && hour < 20) {
    // Evening 4-7 PM
    return {
      icon: <Cookie className="h-5 w-5 text-amber-600 fill-amber-600/10" />,
      title: "Snack O'Clock",
      gradient: 'from-orange-50 via-amber-50 to-red-50',
      bgTint: 'bg-gradient-to-r from-orange-50/80 via-amber-50/60 to-red-50/40',
      filterFn: (product: Product) => {
        const tags = product.tags?.map((t) => t.toLowerCase()) || []
        const categorySlug = product.category?.slug || ''
        return (
          categorySlug === 'snacks-munchies' ||
          tags.includes('snacks')
        )
      },
    }
  } else {
    // Night 8 PM - 5 AM
    return {
      icon: <Moon className="h-5 w-5 text-indigo-500 fill-indigo-500/25" />,
      title: 'Late Night Cravings',
      gradient: 'from-indigo-50 via-purple-50 to-blue-50',
      bgTint: 'bg-gradient-to-r from-indigo-50/80 via-purple-50/60 to-blue-50/40',
      filterFn: (product: Product) => {
        const tags = product.tags?.map((t) => t.toLowerCase()) || []
        const categorySlug = product.category?.slug || ''
        return (
          categorySlug === 'snacks-munchies' ||
          categorySlug === 'beverages' ||
          tags.includes('snacks') ||
          tags.includes('beverages')
        )
      },
    }
  }
}

export function TimeSuggestions({ products }: TimeSuggestionsProps) {
  const scrollRef = useRef<HTMLDivElement>(null)
  const [timeConfig, setTimeConfig] = useState<TimeConfig | null>(null)
  const [filteredProducts, setFilteredProducts] = useState<Product[]>([])

  useEffect(() => {
    const hour = new Date().getHours()
    const config = getTimeConfig(hour)

    let filtered = products.filter(config.filterFn)

    // Fallback: if less than 3 products match, show first 8
    if (filtered.length < 3) {
      filtered = products.slice(0, 8)
    }

    setTimeConfig(config)
    setFilteredProducts(filtered)
  }, [products])

  const scroll = (direction: 'left' | 'right') => {
    if (scrollRef.current) {
      const { scrollLeft, clientWidth } = scrollRef.current
      const scrollTo =
        direction === 'left'
          ? scrollLeft - clientWidth * 0.75
          : scrollLeft + clientWidth * 0.75
      scrollRef.current.scrollTo({ left: scrollTo, behavior: 'smooth' })
    }
  }

  // Don't render until client-side time config is ready
  if (!timeConfig || filteredProducts.length === 0) return null

  return (
    <section className="py-6">
      {/* Warm gradient background card */}
      <div className={`rounded-2xl ${timeConfig.bgTint} border border-border/30 p-4 md:p-5`}>
        {/* Section header */}
        <div className="flex items-center justify-between mb-4 px-1">
          <div>
            <h2 className="text-lg md:text-2xl font-black text-text-primary tracking-tight flex items-center gap-2">
              <span className="flex-shrink-0 flex items-center justify-center p-1.5 rounded-lg bg-white/60 shadow-sm border border-white/80">{timeConfig.icon}</span>
              <span>{timeConfig.title}</span>
            </h2>
            <p className="text-sm text-text-secondary mt-1">
              Curated picks for this time of day
            </p>
          </div>

          {/* Scroll buttons */}
          <div className="flex items-center gap-1.5">
            <button
              onClick={() => scroll('left')}
              className="flex h-8 w-8 items-center justify-center rounded-full border border-border bg-card text-text-primary hover:bg-muted transition-colors shadow-sm"
              aria-label="Scroll left"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
            <button
              onClick={() => scroll('right')}
              className="flex h-8 w-8 items-center justify-center rounded-full border border-border bg-card text-text-primary hover:bg-muted transition-colors shadow-sm"
              aria-label="Scroll right"
            >
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </div>

        {/* Horizontal product scroll */}
        <div
          ref={scrollRef}
          className="flex gap-4 overflow-x-auto pb-4 scrollbar-hide scroll-smooth snap-x snap-mandatory"
          style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
        >
          {filteredProducts.map((product, index) => (
            <div
              key={`${product.id}-${index}`}
              className="w-[180px] md:w-[210px] flex-shrink-0 snap-start"
            >
              <ProductCard product={product} />
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
