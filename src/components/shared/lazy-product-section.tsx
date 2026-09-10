'use client'

import { useEffect, useRef, useState, useCallback, type ReactNode } from 'react'
import { cn } from '@/lib/utils'

const BATCH_SIZE = 12

interface LazyProductSectionProps {
  products: any[]
  renderItem: (product: any, index: number) => ReactNode
  containerClassName?: string
  itemClassName?: string
  horizontal?: boolean
  gapClassName?: string
  endCard?: ReactNode
}

export function LazyProductSection({
  products,
  renderItem,
  containerClassName = '',
  itemClassName = '',
  horizontal = true,
  gapClassName = 'gap-2.5 md:gap-4',
  endCard,
}: LazyProductSectionProps) {
  const [visibleCount, setVisibleCount] = useState(24)
  const [isLoading, setIsLoading] = useState(false)
  const sentinelRef = useRef<HTMLDivElement>(null)

  // For horizontal carousels, show all items in the shelf so horizontal scrolling accesses 100% of the subcategory inventory.
  // For vertical grids, paginate in batches of 24 as user scrolls down.
  const visibleProducts = horizontal ? products : products.slice(0, visibleCount)
  const hasMore = !horizontal && visibleCount < products.length

  const loadMore = useCallback(() => {
    if (isLoading || !hasMore) return
    setIsLoading(true)
    // Small delay to allow the browser to paint current items before adding more
    requestAnimationFrame(() => {
      setVisibleCount(prev => Math.min(prev + 24, products.length))
      setIsLoading(false)
    })
  }, [isLoading, hasMore, products.length])

  // Intersection Observer — auto-load more when sentinel is visible (primarily for vertical mode)
  useEffect(() => {
    if (horizontal) return
    const sentinel = sentinelRef.current
    if (!sentinel || !hasMore) return

    const observer = new IntersectionObserver(
      entries => {
        if (entries[0].isIntersecting) {
          loadMore()
        }
      },
      { rootMargin: '200px', threshold: 0 }
    )

    observer.observe(sentinel)
    return () => observer.disconnect()
  }, [hasMore, loadMore, horizontal])

  return (
    <div className={containerClassName}>
      <div
        className={cn(
          horizontal
            ? `flex ${gapClassName} overflow-x-auto pb-2 md:pb-3 scroll-smooth snap-x snap-mandatory`
            : `grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 ${gapClassName}`,
          { scrollbarWidth: 'none', msOverflowStyle: 'none' }
        )}
        style={horizontal ? { scrollbarWidth: 'none', msOverflowStyle: 'none' } : undefined}
      >
        {visibleProducts.map((product, index) => (
          <div
            key={product.id}
            className={cn(
              horizontal
                ? 'w-[130px] min-[375px]:w-[140px] sm:w-[150px] md:w-[190px] flex-shrink-0 snap-start'
                : 'min-w-0',
              itemClassName
            )}
          >
            {renderItem(product, index)}
          </div>
        ))}

        {/* Optional End Card for horizontal carousel (e.g. See All / Explore) */}
        {horizontal && endCard && (
          <div
            className={cn(
              'w-[130px] min-[375px]:w-[140px] sm:w-[150px] md:w-[190px] flex-shrink-0 snap-start',
              itemClassName
            )}
          >
            {endCard}
          </div>
        )}
      </div>

      {/* Load More trigger (vertical layout only) */}
      {!horizontal && hasMore && (
        <div
          ref={sentinelRef}
          className="flex items-center justify-center py-4"
        >
          {isLoading && (
            <div className="flex items-center gap-2 text-xs text-zinc-400">
              <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24" fill="none">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" />
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
              </svg>
              Loading more...
            </div>
          )}
          <span className="text-[10px] text-zinc-400">
            {visibleCount} of {products.length} items
          </span>
        </div>
      )}
    </div>
  )
}
