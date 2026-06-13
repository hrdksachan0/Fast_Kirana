'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { Search, Loader2, Sparkles, Plus, Check, Trash2, Tag, Percent, Zap } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

interface Product {
  id: string
  name: string
  slug: string
  imageUrl: string | null
  mrp: number
  price: number
  discount: number
  unit: string
  stock: number
  isFlashDeal: boolean
  category: {
    name: string
  }
}

export function AdminFlashDeals() {
  const [activeTab, setActiveTab] = useState<'active' | 'search'>('active')
  const [searchQuery, setSearchQuery] = useState('')
  const [flashProducts, setFlashProducts] = useState<Product[]>([])
  const [searchProducts, setSearchProducts] = useState<Product[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [togglingProductId, setTogglingProductId] = useState<string | null>(null)

  useEffect(() => {
    fetchActiveFlashDeals()
  }, [])

  const fetchActiveFlashDeals = async () => {
    setIsLoading(true)
    try {
      const res = await fetch('/api/admin/products?flashDeals=true&limit=100')
      if (res.ok) {
        const data = await res.json()
        setFlashProducts(data.products || [])
      } else {
        toast.error('Failed to load active flash deals')
      }
    } catch (err) {
      toast.error('Error connecting to products API')
    } finally {
      setIsLoading(false)
    }
  }

  const handleSearch = async (e?: React.FormEvent) => {
    if (e) e.preventDefault()
    if (!searchQuery.trim()) return

    setIsLoading(true)
    try {
      const res = await fetch(`/api/admin/products?search=${encodeURIComponent(searchQuery)}&limit=50`)
      if (res.ok) {
        const data = await res.json()
        setSearchProducts(data.products || [])
      } else {
        toast.error('Search failed')
      }
    } catch (err) {
      toast.error('Error searching products')
    } finally {
      setIsLoading(false)
    }
  }

  const toggleFlashDeal = async (product: Product) => {
    setTogglingProductId(product.id)
    const newStatus = !product.isFlashDeal

    try {
      const res = await fetch(`/api/products/${product.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isFlashDeal: newStatus }),
      })

      if (res.ok) {
        // Update local lists
        setFlashProducts(prev => {
          if (newStatus) {
            if (!prev.some(p => p.id === product.id)) {
              return [...prev, { ...product, isFlashDeal: true }]
            }
            return prev
          } else {
            return prev.filter(p => p.id !== product.id)
          }
        })

        setSearchProducts(prev => 
          prev.map(p => p.id === product.id ? { ...p, isFlashDeal: newStatus } : p)
        )

        toast.success(
          newStatus
            ? `⚡ "${product.name}" added to Flash Deals!`
            : `❌ "${product.name}" removed from Flash Deals.`
        )
      } else {
        toast.error('Failed to update product details')
      }
    } catch (err) {
      toast.error('Network error updating product')
    } finally {
      setTogglingProductId(null)
    }
  }

  const displayedProducts = activeTab === 'active' ? flashProducts : searchProducts

  return (
    <div className="space-y-6">
      {/* Top controls and tab triggers */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4 border-b border-border/40 pb-4">
        {/* Navigation Tabs */}
        <div className="flex bg-muted/40 p-1 rounded-xl max-w-max border border-border/40 gap-1">
          <button
            onClick={() => setActiveTab('active')}
            className={`flex items-center gap-1.5 px-4 py-2 text-xs font-bold rounded-lg transition-all cursor-pointer ${
              activeTab === 'active'
                ? 'bg-card text-primary shadow-sm border border-border/50'
                : 'text-text-secondary hover:text-text-primary'
            }`}
          >
            <Zap className={`h-3.5 w-3.5 ${activeTab === 'active' ? 'fill-primary/10' : ''}`} />
            Active Flash Deals ({flashProducts.length})
          </button>
          <button
            onClick={() => setActiveTab('search')}
            className={`flex items-center gap-1.5 px-4 py-2 text-xs font-bold rounded-lg transition-all cursor-pointer ${
              activeTab === 'search'
                ? 'bg-card text-primary shadow-sm border border-border/50'
                : 'text-text-secondary hover:text-text-primary'
            }`}
          >
            <Search className="h-3.5 w-3.5" />
            Search Database
          </button>
        </div>

        {/* Dynamic Search box */}
        {activeTab === 'search' && (
          <form onSubmit={handleSearch} className="flex gap-2 w-full sm:max-w-md">
            <div className="relative flex-1">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search products by name or tag..."
                className="w-full pl-10 pr-4 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>
            <button
              type="submit"
              disabled={isLoading}
              className="px-4 py-2 bg-primary hover:bg-primary/95 text-white text-xs font-extrabold rounded-xl transition-all shadow-sm cursor-pointer disabled:opacity-50"
            >
              Search
            </button>
          </form>
        )}
      </div>

      {/* Loading indicator */}
      {isLoading && displayedProducts.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 gap-3">
          <Loader2 className="h-9 w-9 animate-spin text-primary" />
          <p className="text-xs font-bold text-text-secondary">Searching Kirana Inventory...</p>
        </div>
      ) : displayedProducts.length === 0 ? (
        /* Empty states */
        <div className="text-center py-20 border border-dashed border-border/50 rounded-2xl space-y-2.5 max-w-lg mx-auto">
          {activeTab === 'active' ? (
            <>
              <Zap className="h-10 w-10 text-text-muted mx-auto opacity-30 animate-pulse" />
              <h5 className="font-extrabold text-text-primary text-sm">No Active Flash Deals</h5>
              <p className="text-xs text-text-muted px-6">
                Products with discounts higher than 10% are shown as fallback on the home page automatically, but you can pin specific items here.
              </p>
              <button
                onClick={() => setActiveTab('search')}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary text-xs font-bold rounded-lg mt-2 cursor-pointer transition-colors"
              >
                Search & Pin Products
              </button>
            </>
          ) : (
            <>
              <Search className="h-10 w-10 text-text-muted mx-auto opacity-30" />
              <h5 className="font-extrabold text-text-primary text-sm">Find Products to Add</h5>
              <p className="text-xs text-text-muted px-6">
                Type the name of any product above to find it in the inventory database and toggle its Flash Deal setting.
              </p>
            </>
          )}
        </div>
      ) : (
        /* Products Grid */
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          <AnimatePresence mode="popLayout">
            {displayedProducts.map((product) => {
              const isPinned = product.isFlashDeal
              const isToggling = togglingProductId === product.id

              return (
                <motion.div
                  key={product.id}
                  layout
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.95 }}
                  className={`relative flex flex-col justify-between overflow-hidden rounded-2xl border bg-card p-4 transition-all shadow-sm ${
                    isPinned ? 'border-primary/30 ring-1 ring-primary/10' : 'border-border/60 hover:border-border'
                  }`}
                >
                  {/* Discount tag badge */}
                  {product.discount > 0 && (
                    <div className="absolute right-3.5 top-3.5 flex items-center gap-0.5 bg-rose-500/10 text-rose-600 dark:text-rose-400 px-2 py-0.5 rounded-full text-[9px] font-black">
                      <Percent className="h-2.5 w-2.5" />
                      {product.discount}% OFF
                    </div>
                  )}

                  {/* Product Details info */}
                  <div className="space-y-3">
                    <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-muted/40 border border-border/30 text-xl font-bold">
                      {product.imageUrl && product.imageUrl.length > 2 ? (
                        <img
                          src={product.imageUrl}
                          alt={product.name}
                          className="h-full w-full object-cover rounded-xl"
                          onError={(e) => {
                            (e.target as HTMLImageElement).src = ''
                            ;(e.target as HTMLImageElement).parentElement!.innerText = '📦'
                          }}
                        />
                      ) : (
                        '📦'
                      )}
                    </div>

                    <div>
                      <span className="text-[9px] bg-muted px-1.5 py-0.5 rounded font-extrabold text-text-secondary">
                        {product.category?.name || 'Uncategorized'}
                      </span>
                      <h4 className="font-extrabold text-xs text-text-primary mt-1 line-clamp-2 min-h-[32px]">
                        {product.name}
                      </h4>
                      <p className="text-[10px] text-text-muted mt-0.5">{product.unit} • Stock: {product.stock}</p>
                    </div>

                    {/* Price list */}
                    <div className="flex items-baseline gap-1.5">
                      <span className="text-xs font-black text-text-primary">₹{product.price}</span>
                      {product.mrp > product.price && (
                        <span className="text-[10px] text-text-muted line-through font-medium">₹{product.mrp}</span>
                      )}
                    </div>
                  </div>

                  {/* Toggle Button */}
                  <div className="mt-4 pt-3 border-t border-border/40">
                    <button
                      onClick={() => toggleFlashDeal(product)}
                      disabled={isToggling}
                      className={`w-full flex items-center justify-center gap-1.5 px-3 py-2 text-[10px] font-extrabold rounded-xl transition-all cursor-pointer disabled:opacity-50 ${
                        isPinned
                          ? 'bg-rose-500/10 hover:bg-rose-500/20 text-rose-600 dark:text-rose-400'
                          : 'bg-primary/5 hover:bg-primary/10 border border-primary/20 text-primary'
                      }`}
                    >
                      {isToggling ? (
                        <Loader2 className="h-3 w-3 animate-spin" />
                      ) : isPinned ? (
                        <>
                          <Trash2 className="h-3 w-3" />
                          Remove Flash Deal
                        </>
                      ) : (
                        <>
                          <Plus className="h-3.5 w-3.5" />
                          Pin Flash Deal
                        </>
                      )}
                    </button>
                  </div>
                </motion.div>
              )
            })}
          </AnimatePresence>
        </div>
      )}
    </div>
  )
}
