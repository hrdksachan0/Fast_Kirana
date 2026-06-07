'use client'

import { useRef } from 'react'
import { ChevronLeft, ChevronRight, Flame } from 'lucide-react'
import { ProductCard } from '@/components/product/product-card'
import { Product } from '@/types'

interface TrendingSectionProps {
  products: Product[]
}

/**
 * Generate a deterministic "random" number from a product ID string.
 * Returns a number between 200-500 to simulate "X ordered today".
 */
function getOrderCount(productId: string): number {
  let hash = 0
  for (let i = 0; i < productId.length; i++) {
    const char = productId.charCodeAt(i)
    hash = ((hash << 5) - hash) + char
    hash = hash & hash // Convert to 32bit integer
  }
  return 200 + (Math.abs(hash) % 301) // 200 to 500
}

export function TrendingSection({ products }: TrendingSectionProps) {
  const scrollRef = useRef<HTMLDivElement>(null)

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

  if (!products || products.length === 0) return null

  return (
    <section className="py-2.5 md:py-6">
      {/* Section header */}
      <div className="flex items-center justify-between mb-4 px-1">
        <div className="flex items-center gap-3">
          <div>
            <h2 className="text-lg md:text-2xl font-black text-text-primary tracking-tight flex items-center gap-2">
              <span className="flex-shrink-0 flex items-center justify-center p-1.5 rounded-lg bg-orange-500/10 border border-orange-500/20 text-orange-500">
                <Flame className="h-5 w-5 fill-current animate-pulse-gentle" />
              </span>
              <span>Trending in Your Town</span>
            </h2>
          </div>

          {/* Pulsing LIVE badge */}
          <div className="flex items-center gap-1.5 bg-accent/10 border border-accent/20 rounded-full px-2.5 py-1">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping-slow absolute inline-flex h-full w-full rounded-full bg-accent opacity-75" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-accent" />
            </span>
            <span className="text-[10px] font-extrabold text-accent uppercase tracking-widest">
              LIVE
            </span>
          </div>
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
        {products.map((product, index) => (
          <div
            key={`${product.id}-${index}`}
            className="w-[130px] min-[375px]:w-[140px] sm:w-[150px] md:w-[200px] flex-shrink-0 snap-start relative"
          >
            <ProductCard product={product} />
          </div>
        ))}
      </div>
    </section>
  )
}
