'use client'

import { useState, useEffect, useMemo } from 'react'
import { Search, ToggleLeft, ToggleRight, Check, X, Sparkles, SlidersHorizontal, RefreshCw, Utensils, IndianRupee } from 'lucide-react'
import { toast } from 'sonner'
import { formatPrice } from '@/lib/utils'
import { RestaurantPayoutsLedger } from './restaurant-payouts-ledger'

interface Product {
  id: string
  name: string
  slug: string
  description: string | null
  imageUrl: string | null
  categoryId: string
  mrp: number
  price: number
  stock: number
  isAvailable: boolean
  category?: {
    name: string
    slug: string
  }
}

interface AdminRestaurantConsoleProps {
  isAdmin?: boolean
}

export function AdminRestaurantConsole({ isAdmin = false }: AdminRestaurantConsoleProps) {
  const [products, setProducts] = useState<Product[]>([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [filter, setFilter] = useState<'all' | 'instock' | 'outofstock' | 'hidden'>('all')
  const [activeSubTab, setActiveSubTab] = useState<'catalog' | 'payouts'>('catalog')
  const [updatingId, setUpdatingId] = useState<string | null>(null)
  const [editingPriceId, setEditingPriceId] = useState<string | null>(null)
  const [editPriceVal, setEditPriceVal] = useState('')
  const [editMrpVal, setEditMrpVal] = useState('')

  const fetchRestaurantProducts = async () => {
    setLoading(true)
    try {
      const res = await fetch('/api/products?limit=1000', { cache: 'no-store' })
      if (!res.ok) throw new Error('Failed to fetch catalog')
      const data = await res.json()
      
      // Filter only Restaurant items
      const restaurantList = (data.products || []).filter((p: any) => {
        const slug = p.category?.slug || ''
        const tags = p.tags || []
        return slug === 'restaurant' || tags.includes('restaurant')
      })
      setProducts(restaurantList)
    } catch (err) {
      toast.error('Failed to load Restaurant catalog')
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchRestaurantProducts()
  }, [])

  const handleToggleAvailability = async (product: Product) => {
    setUpdatingId(product.id)
    const newStatus = !product.isAvailable
    try {
      const res = await fetch(`/api/products/${product.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isAvailable: newStatus }),
      })
      if (res.ok) {
        setProducts(prev => prev.map(p => p.id === product.id ? { ...p, isAvailable: newStatus } : p))
        toast.success(`"${product.name}" is now ${newStatus ? 'visible' : 'hidden'} on storefront!`)
      } else {
        toast.error('Failed to update product status')
      }
    } catch (err) {
      toast.error('Failed to update product status')
    } finally {
      setUpdatingId(null)
    }
  }

  const handleToggleStock = async (product: Product) => {
    setUpdatingId(product.id)
    const isCurrentlyInStock = product.stock > 0
    const newStock = isCurrentlyInStock ? 0 : 99999
    try {
      const res = await fetch(`/api/products/${product.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ stock: newStock }),
      })
      if (res.ok) {
        setProducts(prev => prev.map(p => p.id === product.id ? { ...p, stock: newStock } : p))
        toast.success(`"${product.name}" marked as ${newStock > 0 ? 'In Stock' : 'Sold Out'}!`)
      } else {
        toast.error('Failed to update stock status')
      }
    } catch (err) {
      toast.error('Failed to update stock status')
    } finally {
      setUpdatingId(null)
    }
  }

  const handleSavePrice = async (product: Product) => {
    const priceNum = parseFloat(editPriceVal)
    const mrpNum = parseFloat(editMrpVal)
    if (isNaN(priceNum) || isNaN(mrpNum) || priceNum < 0 || mrpNum < priceNum) {
      toast.error('Please enter valid prices (MRP must be >= price)')
      return
    }

    setUpdatingId(product.id)
    try {
      const res = await fetch(`/api/products/${product.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ price: priceNum, mrp: mrpNum }),
      })
      if (res.ok) {
        setProducts(prev => prev.map(p => p.id === product.id ? { ...p, price: priceNum, mrp: mrpNum } : p))
        toast.success(`Price updated for "${product.name}"!`)
        setEditingPriceId(null)
      } else {
        toast.error('Failed to save prices')
      }
    } catch (err) {
      toast.error('Failed to save prices')
    } finally {
      setUpdatingId(null)
    }
  }

  const filteredList = useMemo(() => {
    return products.filter(p => {
      const matchesSearch = p.name.toLowerCase().includes(searchQuery.toLowerCase()) || 
                            p.category?.name.toLowerCase().includes(searchQuery.toLowerCase())
      
      if (!matchesSearch) return false
      
      if (filter === 'instock') return p.stock > 0
      if (filter === 'outofstock') return p.stock <= 0
      if (filter === 'hidden') return !p.isAvailable
      return true
    })
  }, [products, searchQuery, filter])

  return (
    <div className="space-y-6">
      {/* Console Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 bg-gradient-to-r from-red-500/10 via-rose-500/5 to-transparent p-6 rounded-3xl border border-border/40">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <div className="h-8 w-8 rounded-xl bg-red-500/10 text-red-500 flex items-center justify-center">
              <Utensils className="h-4.5 w-4.5" />
            </div>
            <h2 className="text-xl font-black text-text-primary">Wedson Restaurant Kitchen Console</h2>
          </div>
          <p className="text-xs text-text-secondary">
            Manage live menu availability, kitchen stock status, and pricing for Restaurant meals, main courses, and combo deals.
          </p>
        </div>
        
        <button
          onClick={fetchRestaurantProducts}
          disabled={loading}
          className="inline-flex items-center gap-1.5 px-4 py-2 text-xs font-black bg-card border border-border hover:bg-muted/40 text-text-primary rounded-xl transition-all cursor-pointer disabled:opacity-50"
        >
          <RefreshCw className={`h-3.5 w-3.5 ${loading ? 'animate-spin' : ''}`} />
          Refresh Menu
        </button>
      </div>

      {/* Sub-tab Navigation */}
      {isAdmin && (
        <div className="flex border-b border-border/40 gap-4 pb-1">
          <button
            onClick={() => setActiveSubTab('catalog')}
            className={`flex items-center gap-2 pb-3 px-1 text-xs font-black uppercase tracking-wider transition-all border-b-2 cursor-pointer ${
              activeSubTab === 'catalog' 
                ? 'border-red-650 text-red-600' 
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            <Utensils className="h-4 w-4" />
            Menu Catalog
          </button>
          <button
            onClick={() => setActiveSubTab('payouts')}
            className={`flex items-center gap-2 pb-3 px-1 text-xs font-black uppercase tracking-wider transition-all border-b-2 cursor-pointer ${
              activeSubTab === 'payouts' 
                ? 'border-red-650 text-red-600' 
                : 'border-transparent text-text-secondary hover:text-text-primary'
            }`}
          >
            <IndianRupee className="h-4 w-4" />
            Payouts Ledger
          </button>
        </div>
      )}

      {activeSubTab === 'catalog' && (
        <>
          {/* Filters & Search */}
          <div className="flex flex-col sm:flex-row gap-3 items-center justify-between">
        <div className="relative w-full sm:max-w-md">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted" />
          <input
            type="text"
            placeholder="Search Restaurant dishes, combos, main courses..."
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            className="w-full bg-card border border-border pl-10 pr-4 py-2.5 rounded-2xl text-xs focus:outline-none focus:border-primary font-medium"
          />
        </div>

        <div className="flex bg-muted/40 p-1 rounded-xl border border-border/40 gap-1 overflow-x-auto w-full sm:w-auto">
          {(['all', 'instock', 'outofstock', 'hidden'] as const).map(tab => (
            <button
              key={tab}
              onClick={() => setFilter(tab)}
              className={`px-3 py-1.5 text-[10px] font-black rounded-lg transition-all uppercase tracking-wider cursor-pointer ${
                filter === tab 
                  ? 'bg-card text-primary shadow-sm border border-border/55' 
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              {tab === 'all' && `All (${products.length})`}
              {tab === 'instock' && `In Stock (${products.filter(p => p.stock > 0).length})`}
              {tab === 'outofstock' && `Sold Out (${products.filter(p => p.stock <= 0).length})`}
              {tab === 'hidden' && `Hidden (${products.filter(p => !p.isAvailable).length})`}
            </button>
          ))}
        </div>
      </div>

      {/* Products Grid */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-20 gap-3">
          <RefreshCw className="h-8 w-8 text-primary animate-spin" />
          <p className="text-xs text-text-secondary font-bold">Syncing Restaurant kitchen items...</p>
        </div>
      ) : filteredList.length === 0 ? (
        <div className="text-center py-16 bg-muted/10 rounded-3xl border border-dashed border-border/60">
          <Utensils className="h-10 w-10 text-text-muted mx-auto mb-2.5 opacity-60" />
          <p className="text-sm font-black text-text-primary">No dishes found</p>
          <p className="text-xs text-text-secondary mt-1">Try adjusting your filters or search query</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {filteredList.map(product => {
            const isInStock = product.stock > 0
            const isEditing = editingPriceId === product.id

            return (
              <div 
                key={product.id}
                className={`bg-card border rounded-3xl p-4 shadow-sm flex flex-col justify-between transition-all ${
                  product.isAvailable ? 'border-border/50' : 'border-rose-500/20 bg-rose-500/[0.01]'
                }`}
              >
                <div>
                  <div className="flex gap-3">
                    <div className="h-14 w-14 shrink-0 rounded-2xl bg-muted overflow-hidden relative border border-border/40">
                      {product.imageUrl ? (
                        <img 
                          src={product.imageUrl} 
                          alt={product.name} 
                          className="h-full w-full object-cover"
                        />
                      ) : (
                        <div className="h-full w-full flex items-center justify-center text-xl bg-gradient-to-tr from-red-100 to-rose-50 dark:from-zinc-900 dark:to-zinc-800">
                          🍳
                        </div>
                      )}
                    </div>
                    <div className="space-y-1">
                      <h4 className="text-xs font-black text-text-primary line-clamp-1">{product.name}</h4>
                      <div className="flex items-center gap-1.5">
                        <span className="text-[9px] bg-red-500/10 text-red-600 px-2 py-0.5 rounded-full font-bold uppercase">
                          {product.category?.name || 'Restaurant'}
                        </span>
                        {!product.isAvailable && (
                          <span className="text-[9px] bg-rose-500/10 text-rose-600 px-2 py-0.5 rounded-full font-bold uppercase">
                            Hidden
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Operational Control Badges */}
                  <div className="grid grid-cols-2 gap-2 mt-4">
                    <div className="bg-muted/30 p-2 rounded-2xl border border-border/30 text-center space-y-1">
                      <span className="text-[9px] font-extrabold uppercase tracking-wider text-text-secondary">Kitchen Stock</span>
                      <div className="flex items-center justify-center gap-1">
                        <span className={`h-1.5 w-1.5 rounded-full ${isInStock ? 'bg-emerald-500' : 'bg-rose-500'}`} />
                        <span className="text-xs font-black text-text-primary">{isInStock ? 'IN STOCK' : 'SOLD OUT'}</span>
                      </div>
                    </div>
                    <div className="bg-muted/30 p-2 rounded-2xl border border-border/30 text-center space-y-1">
                      <span className="text-[9px] font-extrabold uppercase tracking-wider text-text-secondary">Store Visibility</span>
                      <div className="flex items-center justify-center gap-1">
                        <span className={`h-1.5 w-1.5 rounded-full ${product.isAvailable ? 'bg-emerald-500' : 'bg-zinc-400'}`} />
                        <span className="text-xs font-black text-text-primary">{product.isAvailable ? 'VISIBLE' : 'HIDDEN'}</span>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="mt-4 pt-3 border-t border-border/40 space-y-3">
                  {/* Inline Price Editor */}
                  <div className="flex justify-between items-center">
                    <div className="space-y-0.5">
                      <span className="text-[9px] font-extrabold uppercase tracking-wider text-text-secondary">Pricing</span>
                      {!isEditing ? (
                        <div className="flex items-baseline gap-1.5">
                          <span className="text-xs font-black text-primary">{formatPrice(product.price)}</span>
                          {product.mrp > product.price && (
                            <span className="text-[10px] text-text-muted line-through">{formatPrice(product.mrp)}</span>
                          )}
                        </div>
                      ) : (
                        <div className="flex gap-1.5 max-w-[160px]">
                          <div className="relative">
                            <span className="absolute left-1.5 top-1/2 -translate-y-1/2 text-[9px] font-bold text-text-muted">₹</span>
                            <input
                              type="number"
                              value={editPriceVal}
                              onChange={e => setEditPriceVal(e.target.value)}
                              placeholder="Price"
                              className="w-16 bg-muted/60 pl-4 pr-1 py-1 rounded-lg text-xs font-bold focus:outline-none focus:border-primary"
                            />
                          </div>
                          <div className="relative">
                            <span className="absolute left-1.5 top-1/2 -translate-y-1/2 text-[9px] font-bold text-text-muted">₹</span>
                            <input
                              type="number"
                              value={editMrpVal}
                              onChange={e => setEditMrpVal(e.target.value)}
                              placeholder="MRP"
                              className="w-16 bg-muted/60 pl-4 pr-1 py-1 rounded-lg text-xs font-bold focus:outline-none focus:border-primary"
                            />
                          </div>
                        </div>
                      )}
                    </div>

                    {!isEditing ? (
                      <button
                        onClick={() => {
                          setEditingPriceId(product.id)
                          setEditPriceVal(product.price.toString())
                          setEditMrpVal(product.mrp.toString())
                        }}
                        className="px-2.5 py-1 text-[10px] font-extrabold border border-border hover:bg-muted/40 rounded-lg text-text-primary transition-all cursor-pointer"
                      >
                        Edit Price
                      </button>
                    ) : (
                      <div className="flex gap-1">
                        <button
                          onClick={() => handleSavePrice(product)}
                          disabled={updatingId === product.id}
                          className="p-1 text-emerald-600 bg-emerald-500/10 hover:bg-emerald-500/20 rounded-lg transition-all cursor-pointer"
                        >
                          <Check className="h-4.5 w-4.5" />
                        </button>
                        <button
                          onClick={() => setEditingPriceId(null)}
                          className="p-1 text-rose-600 bg-rose-500/10 hover:bg-rose-500/20 rounded-lg transition-all cursor-pointer"
                        >
                          <X className="h-4.5 w-4.5" />
                        </button>
                      </div>
                    )}
                  </div>

                  {/* Chef Toggles */}
                  <div className="flex gap-2">
                    <button
                      onClick={() => handleToggleStock(product)}
                      disabled={updatingId === product.id}
                      className={`flex-1 py-2 text-[10px] font-extrabold rounded-xl transition-all cursor-pointer select-none border flex items-center justify-center gap-1.5 ${
                        isInStock 
                          ? 'bg-rose-500/10 hover:bg-rose-500/20 border-rose-500/20 text-rose-600' 
                          : 'bg-emerald-500/10 hover:bg-emerald-500/20 border-emerald-500/20 text-emerald-600'
                      }`}
                    >
                      {isInStock ? <X className="h-3.5 w-3.5" /> : <Check className="h-3.5 w-3.5" />}
                      {isInStock ? 'Mark Sold Out' : 'Mark In Stock'}
                    </button>

                    <button
                      onClick={() => handleToggleAvailability(product)}
                      disabled={updatingId === product.id}
                      className={`flex-1 py-2 text-[10px] font-extrabold rounded-xl transition-all cursor-pointer select-none border flex items-center justify-center gap-1.5 ${
                        product.isAvailable
                          ? 'bg-zinc-100 hover:bg-zinc-200 border-zinc-200 text-zinc-700 dark:bg-zinc-800 dark:hover:bg-zinc-700 dark:border-zinc-700 dark:text-zinc-300'
                          : 'bg-primary text-white border-primary hover:bg-primary/95 shadow-sm'
                      }`}
                    >
                      {product.isAvailable ? 'Hide from Menu' : 'Show on Menu'}
                    </button>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}
        </>
      )}

      {activeSubTab === 'payouts' && (
        <RestaurantPayoutsLedger isAdmin={isAdmin} />
      )}
    </div>
  )
}
