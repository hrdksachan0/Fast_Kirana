'use client'

import { useState, useMemo } from 'react'
import { ProductCard } from '@/components/product/product-card'
import { Product } from '@/types'
import { Store, Utensils, ShoppingBag, SlidersHorizontal, X } from 'lucide-react'
import { cn } from '@/lib/utils'

interface SearchResultsClientProps {
  products: Product[]
  query: string
}

export function SearchResultsClient({ products, query }: SearchResultsClientProps) {
  const [selectedOutlet, setSelectedOutlet] = useState<string>('all')
  const [selectedCategory, setSelectedCategory] = useState<string>('all')
  const [sortBy, setSortBy] = useState<string>('relevance')
  const [priceRange, setPriceRange] = useState<{ min: string; max: string }>({ min: '', max: '' })
  const [showFilters, setShowFilters] = useState(false)
  const [inStockOnly, setInStockOnly] = useState(false)

  // Extract unique categories and outlets
  const categories = useMemo(() => {
    const map = new Map<string, { id: string; name: string; count: number }>()
    products.forEach(p => {
      if (p.category?.id) {
        if (!map.has(p.category.id)) {
          map.set(p.category.id, { id: p.category.id, name: p.category.name, count: 1 })
        } else {
          map.get(p.category.id)!.count++
        }
      }
    })
    return Array.from(map.values()).sort((a, b) => b.count - a.count)
  }, [products])

  // Extract unique restaurants/outlets
  const outlets = useMemo(() => {
    const map = new Map<string, { id: string; name: string; count: number; isRestaurant: boolean }>()

    products.forEach(p => {
      const rest = (p as any).restaurant
      const isRest = Boolean(p.restaurantId || rest || p.category?.slug === 'restaurant' || p.tags?.includes('restaurant'))

      const outletId = p.restaurantId || (isRest ? 'restaurant-general' : 'kirana-grocery')
      
      let outletName = rest?.name || (p as any).restaurantName
      if (!outletName) {
        if (outletId === 'kirana-grocery') outletName = 'FastKirana Store'
        else if (outletId === 'as-restaurant' || outletId === 'as-cafe') outletName = 'A.S Restaurant'
        else if (outletId === 'wedson' || outletId === 'restaurant-kitchen') outletName = 'Wedson Restaurant'
        else outletName = isRest ? 'Restaurant Outlets' : 'FastKirana Store'
      }

      if (!map.has(outletId)) {
        map.set(outletId, {
          id: outletId,
          name: outletName,
          count: 1,
          isRestaurant: isRest,
        })
      } else {
        map.get(outletId)!.count += 1
      }
    })

    return Array.from(map.values())
  }, [products])

  // Filter and sort products
  const filteredProducts = useMemo(() => {
    let result = [...products]

    // Filter by outlet
    if (selectedOutlet !== 'all') {
      result = result.filter(p => {
        const rest = (p as any).restaurant
        const isRest = Boolean(p.restaurantId || rest || p.category?.slug === 'restaurant' || p.tags?.includes('restaurant'))
        const outletId = p.restaurantId || (isRest ? 'restaurant-general' : 'kirana-grocery')
        return outletId === selectedOutlet
      })
    }

    // Filter by category
    if (selectedCategory !== 'all') {
      result = result.filter(p => p.category?.id === selectedCategory)
    }

    // Filter in-stock only
    if (inStockOnly) {
      result = result.filter(p => (p.stock || 0) > 0 && p.isAvailable !== false)
    }

    // Filter by price range
    const minPrice = priceRange.min ? parseFloat(priceRange.min) : 0
    const maxPrice = priceRange.max ? parseFloat(priceRange.max) : Infinity
    if (minPrice > 0 || maxPrice < Infinity) {
      result = result.filter(p => {
        const price = p.price || 0
        return price >= minPrice && price <= maxPrice
      })
    }

    // Sort
    switch (sortBy) {
      case 'price-low':
        result.sort((a, b) => (a.price || 0) - (b.price || 0))
        break
      case 'price-high':
        result.sort((a, b) => (b.price || 0) - (a.price || 0))
        break
      case 'discount':
        result.sort((a, b) => (b.discount || 0) - (a.discount || 0))
        break
      case 'name':
        result.sort((a, b) => a.name.localeCompare(b.name))
        break
      case 'relevance':
      default:
        break
    }

    return result
  }, [products, selectedOutlet, selectedCategory, sortBy, priceRange, inStockOnly])

  const hasActiveFilters = selectedCategory !== 'all' || priceRange.min || priceRange.max || inStockOnly || sortBy !== 'relevance'

  const clearFilters = () => {
    setSelectedCategory('all')
    setPriceRange({ min: '', max: '' })
    setInStockOnly(false)
    setSortBy('relevance')
  }

  // Group products by outlet/restaurant
  const groupedProducts = useMemo(() => {
    const groups: Record<string, { name: string; isRestaurant: boolean; items: Product[] }> = {}
    
    filteredProducts.forEach(p => {
      const rest = (p as any).restaurant
      const isRest = Boolean(p.restaurantId || rest || p.category?.slug === 'restaurant' || p.tags?.includes('restaurant'))
      
      const outletId = p.restaurantId || (isRest ? 'restaurant-general' : 'kirana-grocery')
      
      let outletName = rest?.name || (p as any).restaurantName
      if (!outletName) {
        if (outletId === 'kirana-grocery') outletName = 'FastKirana Store (Grocery)'
        else if (outletId === 'as-restaurant' || outletId === 'as-cafe') outletName = 'A.S Restaurant'
        else if (outletId === 'wedson' || outletId === 'restaurant-kitchen') outletName = 'Wedson Restaurant'
        else outletName = isRest ? 'Restaurant Outlets' : 'FastKirana Store (Grocery)'
      }

      if (!groups[outletId]) {
        groups[outletId] = {
          name: outletName,
          isRestaurant: isRest,
          items: []
        }
      }
      groups[outletId].items.push(p)
    })
    
    return Object.entries(groups).map(([id, g]) => ({ id, ...g }))
  }, [filteredProducts])

  return (
    <div className="space-y-4">
      {/* Filter Toggle & Active Filters Bar */}
      <div className="flex items-center gap-2">
        <button
          onClick={() => setShowFilters(!showFilters)}
          className={cn(
            "flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer border",
            showFilters || hasActiveFilters
              ? "bg-primary text-primary-foreground border-primary"
              : "bg-card text-text-secondary border-border hover:bg-muted/50"
          )}
        >
          <SlidersHorizontal className="w-3.5 h-3.5" />
          Filters
          {hasActiveFilters && (
            <span className="h-4 w-4 rounded-full bg-white/20 text-[10px] flex items-center justify-center">
              {[selectedCategory !== 'all', !!priceRange.min, !!priceRange.max, inStockOnly, sortBy !== 'relevance'].filter(Boolean).length}
            </span>
          )}
        </button>

        {hasActiveFilters && (
          <button
            onClick={clearFilters}
            className="flex items-center gap-1 px-2 py-1.5 rounded-lg text-xs font-semibold text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition-all cursor-pointer"
          >
            <X className="w-3.5 h-3.5" />
            Clear all
          </button>
        )}

        <span className="text-[10px] text-text-secondary ml-auto">
          {filteredProducts.length} of {products.length} results
        </span>
      </div>

      {/* Filters Panel */}
      {showFilters && (
        <div className="bg-card border border-border rounded-2xl p-4 space-y-4 animate-fade-in">
          {/* Sort */}
          <div>
            <label className="text-[10px] font-bold text-text-secondary block mb-1.5">Sort by</label>
            <select
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
              className="w-full px-3 py-1.5 text-xs rounded-lg border bg-muted/20 focus:outline-none focus:border-primary font-semibold cursor-pointer"
            >
              <option value="relevance">Relevance</option>
              <option value="price-low">Price: Low to High</option>
              <option value="price-high">Price: High to Low</option>
              <option value="discount">Highest Discount</option>
              <option value="name">Name (A-Z)</option>
            </select>
          </div>

          {/* Category Filter */}
          {categories.length > 1 && (
            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1.5">Category</label>
              <div className="flex flex-wrap gap-1.5">
                <button
                  onClick={() => setSelectedCategory('all')}
                  className={cn(
                    "px-3 py-1 rounded-lg text-[11px] font-bold transition-all cursor-pointer",
                    selectedCategory === 'all'
                      ? "bg-primary text-primary-foreground"
                      : "bg-muted/40 text-text-secondary hover:bg-muted"
                  )}
                >
                  All
                </button>
                {categories.map(cat => (
                  <button
                    key={cat.id}
                    onClick={() => setSelectedCategory(cat.id)}
                    className={cn(
                      "px-3 py-1 rounded-lg text-[11px] font-bold transition-all cursor-pointer",
                      selectedCategory === cat.id
                        ? "bg-primary text-primary-foreground"
                        : "bg-muted/40 text-text-secondary hover:bg-muted"
                    )}
                  >
                    {cat.name} ({cat.count})
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Price Range */}
          <div>
            <label className="text-[10px] font-bold text-text-secondary block mb-1.5">Price Range (₹)</label>
            <div className="flex items-center gap-2">
              <input
                type="number"
                placeholder="Min"
                value={priceRange.min}
                onChange={(e) => setPriceRange(prev => ({ ...prev, min: e.target.value }))}
                className="w-full px-3 py-1.5 text-xs rounded-lg border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                min="0"
              />
              <span className="text-text-secondary text-xs">—</span>
              <input
                type="number"
                placeholder="Max"
                value={priceRange.max}
                onChange={(e) => setPriceRange(prev => ({ ...prev, max: e.target.value }))}
                className="w-full px-3 py-1.5 text-xs rounded-lg border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                min="0"
              />
            </div>
          </div>

          {/* In Stock Only */}
          <div className="flex items-center gap-2">
            <input
              type="checkbox"
              id="inStockOnly"
              checked={inStockOnly}
              onChange={(e) => setInStockOnly(e.target.checked)}
              className="h-4 w-4 rounded border-border text-primary focus:ring-primary cursor-pointer"
            />
            <label htmlFor="inStockOnly" className="text-xs font-semibold text-text-primary cursor-pointer">
              In stock only
            </label>
          </div>
        </div>
      )}

      {/* Restaurant / Store Filter Pills (Show if products come from multiple sources) */}
      {outlets.length > 1 && (
        <div className="flex items-center gap-1.5 overflow-x-auto pb-2 pt-1 scrollbar-none select-none">
          <button
            type="button"
            onClick={() => setSelectedOutlet('all')}
            className={cn(
              "flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-black transition-all shrink-0 cursor-pointer border shadow-2xs",
              selectedOutlet === 'all'
                ? "bg-zinc-900 text-white dark:bg-white dark:text-zinc-900 border-transparent"
                : "bg-card text-text-secondary border-border hover:bg-muted/50"
            )}
          >
            <ShoppingBag className="w-3.5 h-3.5" />
            All Results ({products.length})
          </button>

          {outlets.map(out => (
            <button
              key={out.id}
              type="button"
              onClick={() => setSelectedOutlet(out.id)}
              className={cn(
                "flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-black transition-all shrink-0 cursor-pointer border shadow-2xs",
                selectedOutlet === out.id
                  ? out.isRestaurant
                    ? "bg-red-600 text-white border-transparent"
                    : "bg-emerald-600 text-white border-transparent"
                  : "bg-card text-text-secondary border-border hover:bg-muted/50"
              )}
            >
              {out.isRestaurant ? <Utensils className="w-3.5 h-3.5" /> : <Store className="w-3.5 h-3.5" />}
              {out.name} ({out.count})
            </button>
          ))}
        </div>
      )}

      {/* Results rendering (Grouped when All selected, otherwise flat) */}
      {selectedOutlet === 'all' ? (
        <div className="space-y-6">
          {groupedProducts.map(group => (
            <div key={group.id} className="space-y-2.5">
              <div className="flex items-center gap-2 border-b border-border/40 pb-1.5 pt-1">
                <span className={cn(
                  "px-2 py-0.5 rounded text-[8px] font-black uppercase text-white tracking-wider",
                  group.isRestaurant ? "bg-red-500" : "bg-emerald-500"
                )}>
                  {group.isRestaurant ? 'Kitchen' : 'Store'}
                </span>
                <h3 className="text-xs font-black text-text-primary tracking-tight">
                  {group.name}
                </h3>
                <span className="text-[10px] text-text-muted font-bold">
                  ({group.items.length} {group.items.length === 1 ? 'item' : 'items'})
                </span>
              </div>
              <div className="grid grid-cols-2 min-[375px]:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4 px-1">
                {group.items.map((product) => (
                  <ProductCard key={product.id} product={product} />
                ))}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-2 min-[375px]:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4 animate-fade-in px-1">
          {filteredProducts.map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      )}

      {/* No results message */}
      {filteredProducts.length === 0 && (
        <div className="text-center py-16 border border-dashed border-border bg-card rounded-2xl p-6">
          <span className="text-4xl mb-2 block">🔍</span>
          <h3 className="text-sm font-bold text-text-primary">No results found</h3>
          <p className="text-xs text-text-secondary mt-1">
            Try adjusting your filters or search for something else
          </p>
          <button
            onClick={clearFilters}
            className="mt-4 inline-block bg-primary text-white text-xs font-bold px-4 py-2 rounded-xl cursor-pointer"
          >
            Clear filters
          </button>
        </div>
      )}
    </div>
  )
}
