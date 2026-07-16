'use client'

import { useRef } from 'react'
import Link from 'next/link'
import { ChevronLeft, ChevronRight } from 'lucide-react'
import { ProductCard } from '@/components/product/product-card'
import { Product } from '@/types'

interface ProductScrollSectionProps {
  title: string
  subtitle?: string
  products: Product[]
  rightElement?: React.ReactNode
  href?: string
}

export function ProductScrollSection({
  title,
  subtitle,
  products,
  rightElement,
  href,
}: ProductScrollSectionProps) {
  const scrollRef = useRef<HTMLDivElement>(null)

  const scroll = (direction: 'left' | 'right') => {
    if (scrollRef.current) {
      const { scrollLeft, clientWidth } = scrollRef.current
      const scrollTo = direction === 'left' ? scrollLeft - clientWidth * 0.75 : scrollLeft + clientWidth * 0.75
      scrollRef.current.scrollTo({ left: scrollTo, behavior: 'smooth' })
    }
  }

  if (!products || products.length === 0) return null

  return (
    <section className="py-1.5 md:py-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 mb-4 px-1">
        <div>
          <h2 className="text-lg md:text-2xl font-black text-text-primary tracking-tight">{title}</h2>
          {subtitle && <p className="text-xs md:text-sm text-text-secondary mt-0.5">{subtitle}</p>}
        </div>
        <div className="flex items-center justify-between sm:justify-end gap-3 w-full sm:w-auto">
          {rightElement}
          {href && (
            <Link
              href={href}
              className="text-[9px] sm:text-[10px] font-black uppercase tracking-wider px-3 py-1.5 rounded-full border border-accent/20 bg-accent/5 text-accent hover:bg-accent/15 transition-all duration-300 shadow-[0_1.5px_4px_rgba(0,0,0,0.015)] active:scale-95 whitespace-nowrap"
            >
              See All →
            </Link>
          )}
          <div className="hidden sm:flex items-center gap-1.5">
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
      </div>

      <div
        ref={scrollRef}
        className="flex gap-2.5 md:gap-4 overflow-x-auto pb-2 md:pb-4 scrollbar-hide scroll-smooth snap-x snap-mandatory"
        style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
      >
        {products.map((product, index) => (
          <div key={`${product.id}-${index}`} className="w-[130px] min-[375px]:w-[140px] sm:w-[150px] md:w-[200px] flex-shrink-0 snap-start">
            <ProductCard product={product} />
          </div>
        ))}
      </div>
    </section>
  )
}
