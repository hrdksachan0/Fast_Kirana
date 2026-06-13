'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { Search, Loader2, Plus, Check, Trash2, Percent, Zap, Star, Trophy, Smartphone } from 'lucide-react'
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
  isTopPick: boolean
  isBestSeller: boolean
  category: {
    name: string
  }
}

type HighlightType = 'flash' | 'toppicks' | 'bestsellers'

export function AdminPromotions() {
  const [activeTab, setActiveTab] = useState<'highlights' | 'search'>('highlights')
  const [activeHighlightType, setActiveHighlightType] = useState<HighlightType>('flash')
  const [searchQuery, setSearchQuery] = useState('')
  
  // Lists for active items
  const [flashProducts, setFlashProducts] = useState<Product[]>([])
  const [topPickProducts, setTopPickProducts] = useState<Product[]>([])
  const [bestSellerProducts, setBestSellerProducts] = useState<Product[]>([])
  
  // Search results
  const [searchProducts, setSearchProducts] = useState<Product[]>([])
  
  const [isLoading, setIsLoading] = useState(false)
  const [togglingIdAndType, setTogglingIdAndType] = useState<{ id: string; type: HighlightType } | null>(null)

  useEffect(() => {
    fetchActivePromotions()
  }, [])

  const fetchActivePromotions = async () => {
    setIsLoading(true)
    try {
      const [flashRes, topRes, bestRes] = await Promise.all([
        fetch('/api/admin/products?flashDeals=true&limit=100').then(r => r.json()),
        fetch('/api/admin/products?topPicks=true&limit=100').then(r => r.json()),
        fetch('/api/admin/products?bestSellers=true&limit=100').then(r => r.json()),
      ])
      
      setFlashProducts(flashRes.products || [])
      setTopPickProducts(topRes.products || [])
      setBestSellerProducts(bestRes.products || [])
    } catch (err) {
      toast.error('Failed to load active promotional highlights')
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

  const toggleHighlight = async (product: Product, type: HighlightType) => {
    setTogglingIdAndType({ id: product.id, type })
    
    // Determine the field and new value
    let field = ''
    let newValue = false
    if (type === 'flash') {
      field = 'isFlashDeal'
      newValue = !product.isFlashDeal
    } else if (type === 'toppicks') {
      field = 'isTopPick'
      newValue = !product.isTopPick
    } else if (type === 'bestsellers') {
      field = 'isBestSeller'
      newValue = !product.isBestSeller
    }

    try {
      const res = await fetch(`/api/products/${product.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ [field]: newValue }),
      })

      if (res.ok) {
        // Construct the updated product locally
        const updatedProduct = { ...product, [field]: newValue }

        // Update Flash Deals state list
        if (type === 'flash') {
          setFlashProducts(prev => newValue ? [...prev, updatedProduct] : prev.filter(p => p.id !== product.id))
        } else if (type === 'toppicks') {
          setTopPickProducts(prev => newValue ? [...prev, updatedProduct] : prev.filter(p => p.id !== product.id))
        } else if (type === 'bestsellers') {
          setBestSellerProducts(prev => newValue ? [...prev, updatedProduct] : prev.filter(p => p.id !== product.id))
        }

        // Update search results list in-place
        setSearchProducts(prev =>
          prev.map(p => p.id === product.id ? { ...p, [field]: newValue } : p)
        )
        // Update other highlight lists in-place so state stays synchronized
        const updateInList = (list: Product[]) => list.map(p => p.id === product.id ? { ...p, [field]: newValue } : p)
        setFlashProducts(prev => updateInList(prev))
        setTopPickProducts(prev => updateInList(prev))
        setBestSellerProducts(prev => updateInList(prev))

        const label = type === 'flash' ? 'Flash Deal' : type === 'toppicks' ? 'Top Pick' : 'Best Seller'
        toast.success(
          newValue
            ? `✅ Pinned "${product.name}" to ${label}!`
            : `❌ Removed "${product.name}" from ${label}.`
        )
      } else {
        toast.error('Failed to update promotion details')
      }
    } catch (err) {
      toast.error('Connection error updating promotion')
    } finally {
      setTogglingIdAndType(null)
    }
  }

  // Get active list based on highlight tab
  const getActiveHighlightList = () => {
    if (activeHighlightType === 'flash') return flashProducts
    if (activeHighlightType === 'toppicks') return topPickProducts
    return bestSellerProducts
  }

  const displayedProducts = activeTab === 'highlights' ? getActiveHighlightList() : searchProducts

  return (
    <div className="space-y-6">
      {/* Tab controls */}
      <div className="flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4 border-b border-border/40 pb-4">
        <div className="flex flex-wrap gap-2">
          {/* Main Mode Toggles */}
          <div className="flex bg-muted/40 p-1 rounded-xl border border-border/40 gap-1">
            <button
              onClick={() => setActiveTab('highlights')}
              className={`flex items-center gap-1.5 px-4 py-2 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                activeTab === 'highlights'
                  ? 'bg-card text-primary shadow-sm border border-border/50'
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              <Zap className="h-3.5 w-3.5 fill-primary/5" />
              Storefront Highlights
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
              Search & Manage Pinned Items
            </button>
          </div>

          {/* Sub-tabs for Highlights Curation */}
          {activeTab === 'highlights' && (
            <div className="flex bg-muted/20 p-1 rounded-xl border border-border/20 gap-1">
              <button
                onClick={() => setActiveHighlightType('flash')}
                className={`flex items-center gap-1 px-3 py-1.5 text-[10px] font-extrabold rounded-lg transition-all cursor-pointer ${
                  activeHighlightType === 'flash'
                    ? 'bg-primary text-white shadow-sm'
                    : 'text-text-secondary hover:text-text-primary'
                }`}
              >
                <Zap className="h-3 w-3" />
                Flash Deals ({flashProducts.length})
              </button>
              <button
                onClick={() => setActiveHighlightType('toppicks')}
                className={`flex items-center gap-1 px-3 py-1.5 text-[10px] font-extrabold rounded-lg transition-all cursor-pointer ${
                  activeHighlightType === 'toppicks'
                    ? 'bg-primary text-white shadow-sm'
                    : 'text-text-secondary hover:text-text-primary'
                }`}
              >
                <Star className="h-3 w-3" />
                Top Picks ({topPickProducts.length})
              </button>
              <button
                onClick={() => setActiveHighlightType('bestsellers')}
                className={`flex items-center gap-1 px-3 py-1.5 text-[10px] font-extrabold rounded-lg transition-all cursor-pointer ${
                  activeHighlightType === 'bestsellers'
                    ? 'bg-primary text-white shadow-sm'
                    : 'text-text-secondary hover:text-text-primary'
                }`}
              >
                <Trophy className="h-3 w-3" />
                Best Sellers ({bestSellerProducts.length})
              </button>
            </div>
          )}
        </div>

        {/* Global Search query */}
        {activeTab === 'search' && (
          <form onSubmit={handleSearch} className="flex gap-2 w-full md:max-w-md">
            <div className="relative flex-1">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search products to pin to highlights..."
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

      {/* Grid view */}
      {isLoading && displayedProducts.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 gap-3">
          <Loader2 className="h-9 w-9 animate-spin text-primary" />
          <p className="text-xs font-bold text-text-secondary">Loading kirana inventory list...</p>
        </div>
      ) : displayedProducts.length === 0 ? (
        <div className="text-center py-20 border border-dashed border-border/50 rounded-2xl space-y-2.5 max-w-lg mx-auto">
          {activeTab === 'highlights' ? (
            <>
              {activeHighlightType === 'flash' && <Zap className="h-10 w-10 text-text-muted mx-auto opacity-30 animate-pulse" />}
              {activeHighlightType === 'toppicks' && <Star className="h-10 w-10 text-text-muted mx-auto opacity-30 animate-pulse" />}
              {activeHighlightType === 'bestsellers' && <Trophy className="h-10 w-10 text-text-muted mx-auto opacity-30 animate-pulse" />}
              <h5 className="font-extrabold text-text-primary text-sm">No Pinned Items</h5>
              <p className="text-xs text-text-muted px-6">
                {activeHighlightType === 'flash' && 'Default high-discount items (>10%) show on the homepage, but you can pin custom items.'}
                {activeHighlightType === 'toppicks' && 'Dynamic sales analytics items show on the homepage, but you can override and pin items.'}
                {activeHighlightType === 'bestsellers' && 'Newest products show on the homepage, but you can select custom best sellers.'}
              </p>
              <button
                onClick={() => setActiveTab('search')}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary text-xs font-bold rounded-lg mt-2 cursor-pointer transition-colors"
              >
                Search & Pin Items
              </button>
            </>
          ) : (
            <>
              <Search className="h-10 w-10 text-text-muted mx-auto opacity-30" />
              <h5 className="font-extrabold text-text-primary text-sm">Find Items to Crate/Pin</h5>
              <p className="text-xs text-text-muted px-6">
                Type the name of any product above to toggle its storefront highlight categories.
              </p>
            </>
          )}
        </div>
      ) : (
        /* Products Grid cards */
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          <AnimatePresence mode="popLayout">
            {displayedProducts.map((product) => {
              const isPinnedFlash = product.isFlashDeal
              const isPinnedTop = product.isTopPick
              const isPinnedBest = product.isBestSeller

              return (
                <motion.div
                  key={product.id}
                  layout
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.95 }}
                  className={`relative flex flex-col justify-between overflow-hidden rounded-2xl border bg-card p-4 transition-all shadow-sm ${
                    isPinnedFlash || isPinnedTop || isPinnedBest ? 'border-primary/20 ring-1 ring-primary/5' : 'border-border/60'
                  }`}
                >
                  {/* Discount Tag */}
                  {product.discount > 0 && (
                    <div className="absolute right-3.5 top-3.5 flex items-center gap-0.5 bg-rose-500/10 text-rose-600 dark:text-rose-400 px-2 py-0.5 rounded-full text-[9px] font-black">
                      <Percent className="h-2.5 w-2.5" />
                      {product.discount}% OFF
                    </div>
                  )}

                  {/* Core Product Info */}
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

                    <div className="flex items-baseline gap-1.5">
                      <span className="text-xs font-black text-text-primary">₹{product.price}</span>
                      {product.mrp > product.price && (
                        <span className="text-[10px] text-text-muted line-through font-medium">₹{product.mrp}</span>
                      )}
                    </div>
                  </div>

                  {/* Controls / Pin Switchers */}
                  <div className="mt-4 pt-3 border-t border-border/40 space-y-2">
                    {activeTab === 'highlights' ? (
                      /* Active List Layout: Show quick remove for the highlighted type */
                      <button
                        onClick={() => toggleHighlight(product, activeHighlightType)}
                        disabled={togglingIdAndType?.id === product.id}
                        className="w-full flex items-center justify-center gap-1.5 px-3 py-1.5 text-[10px] font-extrabold rounded-xl transition-all cursor-pointer bg-rose-500/10 hover:bg-rose-500/20 text-rose-600 dark:text-rose-400"
                      >
                        {togglingIdAndType?.id === product.id ? (
                          <Loader2 className="h-3 w-3 animate-spin" />
                        ) : (
                          <>
                            <Trash2 className="h-3 w-3" />
                            Remove from {activeHighlightType === 'flash' ? 'Flash Deals' : activeHighlightType === 'toppicks' ? 'Top Picks' : 'Best Sellers'}
                          </>
                        )}
                      </button>
                    ) : (
                      /* Search Layout: Show all three promotion toggle badges */
                      <div className="grid grid-cols-1 gap-1.5">
                        {/* Flash Deal Toggle */}
                        <button
                          onClick={() => toggleHighlight(product, 'flash')}
                          disabled={togglingIdAndType?.id === product.id}
                          className={`w-full flex items-center justify-between px-3 py-1.5 text-[9px] font-extrabold rounded-lg transition-all cursor-pointer ${
                            isPinnedFlash
                              ? 'bg-rose-500/10 text-rose-600 dark:text-rose-400'
                              : 'bg-muted/40 hover:bg-muted text-text-secondary'
                          }`}
                        >
                          <span className="flex items-center gap-1">
                            <Zap className="h-3.5 w-3.5" />
                            Flash Deal Promotion
                          </span>
                          {togglingIdAndType?.id === product.id && togglingIdAndType?.type === 'flash' ? (
                            <Loader2 className="h-3 w-3 animate-spin text-primary" />
                          ) : isPinnedFlash ? (
                            <Check className="h-3.5 w-3.5 text-rose-500" />
                          ) : (
                            <Plus className="h-3.5 w-3.5 text-text-muted" />
                          )}
                        </button>

                        {/* Top Pick Toggle */}
                        <button
                          onClick={() => toggleHighlight(product, 'toppicks')}
                          disabled={togglingIdAndType?.id === product.id}
                          className={`w-full flex items-center justify-between px-3 py-1.5 text-[9px] font-extrabold rounded-lg transition-all cursor-pointer ${
                            isPinnedTop
                              ? 'bg-amber-500/10 text-amber-600 dark:text-amber-400'
                              : 'bg-muted/40 hover:bg-muted text-text-secondary'
                          }`}
                        >
                          <span className="flex items-center gap-1">
                            <Star className="h-3.5 w-3.5" />
                            Top Pick Selection
                          </span>
                          {togglingIdAndType?.id === product.id && togglingIdAndType?.type === 'toppicks' ? (
                            <Loader2 className="h-3 w-3 animate-spin text-primary" />
                          ) : isPinnedTop ? (
                            <Check className="h-3.5 w-3.5 text-amber-500" />
                          ) : (
                            <Plus className="h-3.5 w-3.5 text-text-muted" />
                          )}
                        </button>

                        {/* Best Seller Toggle */}
                        <button
                          onClick={() => toggleHighlight(product, 'bestsellers')}
                          disabled={togglingIdAndType?.id === product.id}
                          className={`w-full flex items-center justify-between px-3 py-1.5 text-[9px] font-extrabold rounded-lg transition-all cursor-pointer ${
                            isPinnedBest
                              ? 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400'
                              : 'bg-muted/40 hover:bg-muted text-text-secondary'
                          }`}
                        >
                          <span className="flex items-center gap-1">
                            <Trophy className="h-3.5 w-3.5" />
                            Best Seller Tag
                          </span>
                          {togglingIdAndType?.id === product.id && togglingIdAndType?.type === 'bestsellers' ? (
                            <Loader2 className="h-3 w-3 animate-spin text-primary" />
                          ) : isPinnedBest ? (
                            <Check className="h-3.5 w-3.5 text-emerald-500" />
                          ) : (
                            <Plus className="h-3.5 w-3.5 text-text-muted" />
                          )}
                        </button>
                      </div>
                    )}
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
