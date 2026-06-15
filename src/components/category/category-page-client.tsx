'use client'

import { useState, useMemo, useEffect } from 'react'
import Link from 'next/link'
import { ProductCard } from '@/components/product/product-card'
import { Category, Product } from '@/types'
import { cn } from '@/lib/utils'
import { ShoppingBag, Search, X } from 'lucide-react'

interface CategoryPageClientProps {
  categories: Category[]
  initialProducts: Product[]
  activeCategory: Category
  countsMap: Record<string, number>
}

export function CategoryPageClient({
  categories,
  initialProducts,
  activeCategory,
  countsMap,
}: CategoryPageClientProps) {
  const [searchQuery, setSearchQuery] = useState('')
  const [sort, setSort] = useState<string>('popularity')
  const [vegFilter, setVegFilter] = useState<'all' | 'veg' | 'nonveg'>('all')
  const [showPriceFilter, setShowPriceFilter] = useState(false)

  const maxPriceOfCategory = useMemo(() => {
    if (initialProducts.length === 0) return 1000
    return Math.max(...initialProducts.map((p) => p.price))
  }, [initialProducts])

  const [maxPrice, setMaxPrice] = useState<number>(1000)

  // Reset maxPrice when switching categories
  useEffect(() => {
    setMaxPrice(maxPriceOfCategory)
  }, [maxPriceOfCategory])

  // Center active category tab on mobile horizontal scroll bar on mount
  useEffect(() => {
    const activeTabEl = document.getElementById(`category-tab-${activeCategory.slug}`)
    const containerEl = document.getElementById('mobile-category-scrollbar')
    if (activeTabEl && containerEl) {
      const timer = setTimeout(() => {
        const containerWidth = containerEl.clientWidth
        const tabOffsetLeft = activeTabEl.offsetLeft
        const tabWidth = activeTabEl.clientWidth
        const targetScrollLeft = tabOffsetLeft - (containerWidth / 2) + (tabWidth / 2)
        
        containerEl.scrollTo({
          left: targetScrollLeft,
          behavior: 'auto'
        })
      }, 50)
      return () => clearTimeout(timer)
    }
  }, [activeCategory.slug])

  const sortOptions = [
    { label: 'Popularity', value: 'popularity' },
    { label: 'Price: Low to High', value: 'price-asc' },
    { label: 'Price: High to Low', value: 'price-desc' },
    { label: 'Big Discounts', value: 'discount-desc' },
  ]

  // Filter and sort products in memory
  const processedProducts = useMemo(() => {
    let result = [...initialProducts]

    // 1. Filter by search query
    if (searchQuery.trim()) {
      const words = searchQuery.toLowerCase().trim().split(/\s+/).filter(Boolean)
      result = result.filter((p) =>
        words.every((word) =>
          p.name.toLowerCase().includes(word) ||
          (p.description && p.description.toLowerCase().includes(word)) ||
          p.tags.some((t) => t.toLowerCase().includes(word))
        )
      )
    }

    // 2. Filter by Veg/Non-Veg
    if (vegFilter === 'veg') {
      result = result.filter((p) => {
        const tags = p.tags?.map((t) => t.toLowerCase()) || []
        const isNonVeg = tags.includes('nonveg') || tags.includes('non-veg') || tags.includes('chicken') || tags.includes('egg') || tags.includes('mutton') || tags.includes('meat')
        return !isNonVeg
      })
    } else if (vegFilter === 'nonveg') {
      result = result.filter((p) => {
        const tags = p.tags?.map((t) => t.toLowerCase()) || []
        return tags.includes('nonveg') || tags.includes('non-veg') || tags.includes('chicken') || tags.includes('egg') || tags.includes('mutton') || tags.includes('meat')
      })
    }

    // 3. Filter by Price Limit
    result = result.filter((p) => p.price <= maxPrice)

    // 4. Sort results
    if (sort === 'price-asc') {
      result.sort((a, b) => a.price - b.price)
    } else if (sort === 'price-desc') {
      result.sort((a, b) => b.price - a.price)
    } else if (sort === 'discount-desc') {
      result.sort((a, b) => b.discount - a.discount)
    }

    return result
  }, [initialProducts, searchQuery, vegFilter, maxPrice, sort])

  return (
    <div className="container mx-auto px-2 min-[375px]:px-4 py-4 min-[375px]:py-6 max-w-7xl">
      <div className="flex flex-col md:flex-row gap-6">
        {/* Desktop Left Sidebar: Categories Navigation */}
        <aside className="hidden md:block w-64 flex-shrink-0 border border-border bg-card p-4 rounded-2xl h-fit sticky top-[96px] shadow-sm">
          <h3 className="font-bold text-text-primary text-base mb-4 px-2">Categories</h3>
          <div className="space-y-1.5">
            {categories.map((cat) => {
              const isActive = cat.slug === activeCategory.slug
              return (
                <Link
                  key={cat.id}
                  href={`/category/${cat.slug}`}
                  className={cn(
                    'flex items-center gap-3 w-full px-3 py-2 text-sm font-semibold rounded-xl transition-all duration-200 group',
                    isActive
                      ? 'bg-primary text-primary-foreground shadow-sm scale-[1.02]'
                      : 'text-text-secondary hover:bg-muted hover:text-text-primary'
                  )}
                >
                  <span className="h-5 w-5 flex items-center justify-center shrink-0 overflow-hidden" role="img" aria-label={cat.name}>
                    {cat.imageUrl && (cat.imageUrl.startsWith('data:image/') || cat.imageUrl.startsWith('/') || cat.imageUrl.startsWith('http')) ? (
                      <img src={cat.imageUrl} alt={cat.name} className="h-full w-full object-cover rounded" />
                    ) : (
                      <span className="text-base leading-none">{cat.imageUrl || '🛒'}</span>
                    )}
                  </span>
                  <span className="truncate">{cat.name}</span>
                  <span
                    className={cn(
                      'ml-auto text-[10px] font-extrabold px-1.5 py-0.5 rounded-full border transition-colors shrink-0',
                      isActive
                        ? 'bg-primary-foreground/20 text-primary-foreground border-primary-foreground/10'
                        : 'bg-muted text-text-secondary border-border group-hover:bg-background group-hover:text-text-primary'
                    )}
                  >
                    {countsMap[cat.id] || 0}
                  </span>
                </Link>
              )
            })}
          </div>
        </aside>

        {/* Right Section: Header and Product Grid */}
        <main className="flex-grow space-y-6">
          {/* Mobile Category Horizontal Scrollbar */}
          <div id="mobile-category-scrollbar" className="md:hidden overflow-x-auto flex gap-2 pb-2 scrollbar-hide">
            {categories.map((cat) => {
              const isActive = cat.slug === activeCategory.slug
              return (
                <Link
                  key={cat.id}
                  id={`category-tab-${cat.slug}`}
                  href={`/category/${cat.slug}`}
                  className={cn(
                    'flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold rounded-full border whitespace-nowrap flex-shrink-0 transition-colors',
                    isActive
                      ? 'bg-primary text-primary-foreground border-primary'
                      : 'bg-card text-text-secondary border-border hover:bg-muted'
                  )}
                >
                  <span className="h-4 w-4 flex items-center justify-center shrink-0 overflow-hidden">
                    {cat.imageUrl && (cat.imageUrl.startsWith('data:image/') || cat.imageUrl.startsWith('/') || cat.imageUrl.startsWith('http')) ? (
                      <img src={cat.imageUrl} alt={cat.name} className="h-full w-full object-cover rounded-sm" />
                    ) : (
                      <span className="text-xs leading-none">{cat.imageUrl || '🛒'}</span>
                    )}
                  </span>
                  <span>
                    {cat.name}{' '}
                    <span className="opacity-80 font-normal">
                      ({countsMap[cat.id] || 0})
                    </span>
                  </span>
                </Link>
              )
            })}
          </div>

          {/* Category Header */}
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 border-b border-border/60 pb-4">
            <div>
              <div className="flex items-center gap-3">
                <span className="h-10 w-10 flex items-center justify-center shrink-0 overflow-hidden" role="img" aria-label={activeCategory.name}>
                  {activeCategory.imageUrl && (activeCategory.imageUrl.startsWith('data:image/') || activeCategory.imageUrl.startsWith('/') || activeCategory.imageUrl.startsWith('http')) ? (
                    <img src={activeCategory.imageUrl} alt={activeCategory.name} className="h-full w-full object-cover rounded-lg" />
                  ) : (
                    <span className="text-3xl leading-none">{activeCategory.imageUrl || '🛒'}</span>
                  )}
                </span>
                <div>
                  <h1 className="text-lg md:text-2xl font-extrabold text-text-primary tracking-tight">
                    {activeCategory.name}
                  </h1>
                  <p className="text-xs text-text-secondary mt-0.5">
                    Showing {processedProducts.length} of {initialProducts.length}{' '}
                    products
                  </p>
                </div>
              </div>
            </div>

            {/* Sorting Actions */}
            <div className="flex flex-col sm:flex-row sm:items-center gap-2 w-full sm:w-auto">
              <span className="text-xs font-bold text-text-secondary hidden sm:inline">
                Sort By:
              </span>
              <div className="flex overflow-x-auto gap-1 bg-muted p-1 rounded-xl scrollbar-none w-full sm:w-auto">
                {sortOptions.map((opt) => {
                  const isActive = sort === opt.value
                  return (
                    <button
                      key={opt.label}
                      type="button"
                      onClick={() => setSort(opt.value)}
                      className={cn(
                        'px-3 py-1.5 text-xs font-bold rounded-lg transition-colors whitespace-nowrap flex-shrink-0 cursor-pointer',
                        isActive
                          ? 'bg-card text-text-primary shadow-sm'
                          : 'text-text-secondary hover:text-text-primary'
                      )}
                    >
                      {opt.label}
                    </button>
                  )
                })}
              </div>
            </div>
          </div>

          {/* Search Bar and Dynamic Filters Row */}
          <div className="space-y-3">
            <div className="flex flex-col md:flex-row gap-3 items-stretch md:items-center">
              {/* Search Bar */}
              <div className="relative flex-1 max-w-md bg-card rounded-xl border border-border shadow-sm overflow-hidden group">
                <Search className="absolute left-3.5 top-3.5 h-4 w-4 text-text-muted transition-colors group-focus-within:text-primary" />
                <input
                  type="text"
                  placeholder={`Search in ${activeCategory.name}...`}
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full bg-transparent border-0 pl-10 pr-10 py-3 text-xs focus:outline-none focus:ring-0 font-semibold text-text-primary placeholder:text-text-muted"
                />
                {searchQuery && (
                  <button
                    type="button"
                    onClick={() => setSearchQuery('')}
                    className="absolute right-3 top-3 p-0.5 hover:bg-muted text-text-secondary hover:text-text-primary rounded-full transition-colors"
                  >
                    <X className="h-3.5 w-3.5" />
                  </button>
                )}
              </div>

              {/* Dynamic Filter Pills */}
              <div className="flex items-center gap-2 overflow-x-auto pb-1 md:pb-0 scrollbar-none select-none">
                <button
                  type="button"
                  onClick={() => setShowPriceFilter(!showPriceFilter)}
                  className={cn(
                    'px-3.5 py-2 rounded-full border text-xs font-black flex items-center gap-1.5 transition-all select-none cursor-pointer',
                    maxPrice < maxPriceOfCategory
                      ? 'bg-primary/10 border-primary/30 text-primary font-extrabold shadow-sm'
                      : 'bg-card border-border hover:bg-muted text-text-secondary'
                  )}
                >
                  <span className="text-[10px] font-black">₹</span>
                  <span>Under ₹{maxPrice}</span>
                  <span className={cn('text-[9px] transition-transform duration-200', showPriceFilter ? 'rotate-180' : '')}>▼</span>
                </button>
              </div>
            </div>

            {/* Price Limit Slider Panel */}
            {showPriceFilter && (
              <div className="bg-card border border-border/60 p-4 rounded-2xl shadow-sm space-y-3 max-w-xs animate-slide-down text-left">
                <div className="flex justify-between text-[10px] font-black text-text-muted uppercase tracking-wider">
                  <span>Min: ₹0</span>
                  <span>Max: ₹{maxPriceOfCategory}</span>
                </div>
                <input
                  type="range"
                  min={0}
                  max={maxPriceOfCategory}
                  value={maxPrice}
                  onChange={(e) => setMaxPrice(Number(e.target.value))}
                  className="w-full accent-primary h-1 bg-muted rounded-lg appearance-none cursor-pointer"
                />
                <div className="flex justify-between items-center text-xs font-bold pt-1 border-t border-border/30">
                  <span className="text-text-muted">Show products up to:</span>
                  <span className="text-primary font-extrabold">₹{maxPrice}</span>
                </div>
              </div>
            )}
          </div>

          {/* Products Catalog Grid */}
          {processedProducts.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 border border-dashed border-border bg-card rounded-2xl text-center p-6 shadow-sm">
              <div className="w-16 h-16 bg-muted/40 rounded-full flex items-center justify-center mx-auto text-muted-foreground mb-4">
                <ShoppingBag className="h-8 w-8 animate-pulse-gentle" />
              </div>
              <h2 className="text-base font-bold text-text-primary">
                No products found
              </h2>
              <p className="text-xs text-text-secondary mt-1">
                {searchQuery
                  ? 'Try adjusting your search keywords to find what you are looking for.'
                  : 'We are currently restocking this category. Please check back soon!'}
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-2 min-[375px]:grid-cols-3 sm:grid-cols-3 lg:grid-cols-4 gap-2 md:gap-4">
              {processedProducts.map((product) => (
                <ProductCard key={product.id} product={product} />
              ))}
            </div>
          )}
        </main>
      </div>
    </div>
  )
}
