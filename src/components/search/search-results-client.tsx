'use client'

import { useState, useMemo } from 'react'
import { ProductCard } from '@/components/product/product-card'
import { Product } from '@/types'
import { Store, Utensils, ShoppingBag } from 'lucide-react'
import { cn } from '@/lib/utils'

interface SearchResultsClientProps {
  products: Product[]
  query: string
}

export function SearchResultsClient({ products, query }: SearchResultsClientProps) {
  const [selectedOutlet, setSelectedOutlet] = useState<string>('all')

  // Extract unique restaurant outlets present in search results
  const outlets = useMemo(() => {
    const map = new Map<string, { id: string; name: string; count: number; isRestaurant: boolean }>()

    products.forEach(p => {
      const rest = (p as any).restaurant
      const isRest = Boolean(p.restaurantId || rest || p.category?.slug === 'restaurant' || p.tags?.includes('restaurant'))
      
      const outletId = p.restaurantId || (isRest ? 'restaurant-general' : 'kirana-grocery')
      const outletName = rest?.name || (isRest ? 'Restaurant Outlets' : 'FastKirana Store')

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

  // Filter products by selected outlet
  const filteredProducts = useMemo(() => {
    if (selectedOutlet === 'all') return products
    return products.filter(p => {
      const rest = (p as any).restaurant
      const isRest = Boolean(p.restaurantId || rest || p.category?.slug === 'restaurant' || p.tags?.includes('restaurant'))
      const outletId = p.restaurantId || (isRest ? 'restaurant-general' : 'kirana-grocery')
      return outletId === selectedOutlet
    })
  }, [products, selectedOutlet])

  return (
    <div className="space-y-4">
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

      {/* Results grid */}
      <div className="grid grid-cols-2 min-[375px]:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4 animate-fade-in px-1">
        {filteredProducts.map((product) => (
          <ProductCard key={product.id} product={product} />
        ))}
      </div>
    </div>
  )
}
