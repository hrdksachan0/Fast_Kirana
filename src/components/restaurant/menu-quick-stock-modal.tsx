'use client'

import { useState, useEffect, useMemo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { X, Search, Utensils, Check, AlertCircle, Loader2, Sparkles, RefreshCw } from 'lucide-react'
import { toast } from 'sonner'
import { playCartPop } from '@/lib/audio'
import { triggerHaptic } from '@/lib/haptic'
import { formatPrice } from '@/lib/utils'

interface DishItem {
  id: string
  name: string
  price: number
  isAvailable: boolean
  stock: number
  imageUrl?: string | null
  tags?: string[]
  category?: {
    name: string
  }
}

interface MenuQuickStockModalProps {
  isOpen: boolean
  onClose: () => void
  restaurantId?: string
}

export function MenuQuickStockModal({ isOpen, onClose, restaurantId }: MenuQuickStockModalProps) {
  const [items, setItems] = useState<DishItem[]>([])
  const [loading, setLoading] = useState(true)
  const [searchQuery, setSearchQuery] = useState('')
  const [filter, setFilter] = useState<'ALL' | 'AVAILABLE' | 'OUT_OF_STOCK'>('ALL')
  const [togglingId, setTogglingId] = useState<string | null>(null)

  const fetchItems = async () => {
    setLoading(true)
    try {
      const url = restaurantId
        ? `/api/restaurant-dashboard/products?restaurantId=${restaurantId}`
        : '/api/restaurant-dashboard/products'
      const res = await fetch(url, { cache: 'no-store' })
      if (!res.ok) throw new Error('Failed to load menu')
      const data = await res.json()
      setItems(data.products || [])
    } catch (err) {
      console.error(err)
      toast.error('Failed to load dishes')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (isOpen) {
      fetchItems()
    }
  }, [isOpen, restaurantId])

  const toggleAvailability = async (item: DishItem) => {
    const newStatus = !item.isAvailable
    setTogglingId(item.id)
    
    // Optimistic UI update
    setItems(prev => prev.map(p => p.id === item.id ? { ...p, isAvailable: newStatus } : p))
    playCartPop()
    triggerHaptic('selection')

    try {
      const res = await fetch(`/api/restaurant-dashboard/products/${item.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isAvailable: newStatus })
      })

      if (!res.ok) {
        throw new Error('Failed to update status')
      }

      toast.success(`${item.name} is now ${newStatus ? 'IN STOCK 🟢' : 'OUT OF STOCK 🔴'}`)
    } catch (err) {
      // Revert optimistic update on failure
      setItems(prev => prev.map(p => p.id === item.id ? { ...p, isAvailable: !newStatus } : p))
      toast.error('Failed to update dish availability')
    } finally {
      setTogglingId(null)
    }
  }

  const filteredItems = useMemo(() => {
    return items.filter(item => {
      const matchesSearch = item.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        (item.category?.name && item.category.name.toLowerCase().includes(searchQuery.toLowerCase()))
      
      if (!matchesSearch) return false

      if (filter === 'AVAILABLE') return item.isAvailable
      if (filter === 'OUT_OF_STOCK') return !item.isAvailable
      return true
    })
  }, [items, searchQuery, filter])

  const totalCount = items.length
  const availableCount = items.filter(i => i.isAvailable).length
  const outOfStockCount = totalCount - availableCount

  if (!isOpen) return null

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/70 backdrop-blur-xs">
        <motion.div
          initial={{ opacity: 0, scale: 0.96, y: 10 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.96, y: 10 }}
          className="relative w-full max-w-3xl max-h-[90vh] bg-card border border-border/80 rounded-3xl shadow-2xl flex flex-col overflow-hidden"
        >
          {/* Modal Header */}
          <div className="p-4 sm:p-5 border-b border-border/60 flex items-center justify-between bg-muted/20">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded-2xl bg-red-500/10 text-red-500 flex items-center justify-center border border-red-500/20 shadow-inner">
                <Utensils className="h-5 w-5" />
              </div>
              <div>
                <h2 className="text-base sm:text-lg font-black text-text-primary uppercase tracking-tight flex items-center gap-2">
                  <span>Quick 86 / Stock-Out Controls</span>
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-red-500/10 text-red-600 font-bold border border-red-500/20">
                    Live
                  </span>
                </h2>
                <p className="text-[11px] text-text-secondary font-medium">
                  Toggle dish availability instantly during kitchen rush hours.
                </p>
              </div>
            </div>

            <button
              onClick={onClose}
              className="p-2 text-text-muted hover:text-text-primary hover:bg-muted rounded-xl transition-all cursor-pointer"
            >
              <X className="h-5 w-5" />
            </button>
          </div>

          {/* Quick Metrics & Filters Bar */}
          <div className="p-3 sm:p-4 border-b border-border/40 bg-card space-y-3">
            <div className="grid grid-cols-3 gap-2 text-center">
              <button
                onClick={() => setFilter('ALL')}
                className={`p-2 rounded-2xl border transition-all cursor-pointer ${
                  filter === 'ALL'
                    ? 'bg-red-500/10 border-red-500/30 text-red-600 shadow-xs'
                    : 'bg-muted/40 border-border/50 text-text-secondary hover:bg-muted'
                }`}
              >
                <div className="text-sm sm:text-base font-black">{totalCount}</div>
                <div className="text-[10px] uppercase font-bold tracking-wider">All Items</div>
              </button>

              <button
                onClick={() => setFilter('AVAILABLE')}
                className={`p-2 rounded-2xl border transition-all cursor-pointer ${
                  filter === 'AVAILABLE'
                    ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-600 shadow-xs'
                    : 'bg-muted/40 border-border/50 text-text-secondary hover:bg-muted'
                }`}
              >
                <div className="text-sm sm:text-base font-black text-emerald-600">{availableCount}</div>
                <div className="text-[10px] uppercase font-bold tracking-wider">In Stock</div>
              </button>

              <button
                onClick={() => setFilter('OUT_OF_STOCK')}
                className={`p-2 rounded-2xl border transition-all cursor-pointer ${
                  filter === 'OUT_OF_STOCK'
                    ? 'bg-rose-500/10 border-rose-500/30 text-rose-600 shadow-xs'
                    : 'bg-muted/40 border-border/50 text-text-secondary hover:bg-muted'
                }`}
              >
                <div className="text-sm sm:text-base font-black text-rose-600">{outOfStockCount}</div>
                <div className="text-[10px] uppercase font-bold tracking-wider">Out of Stock (86)</div>
              </button>
            </div>

            {/* Search Input & Refresh */}
            <div className="flex items-center gap-2">
              <div className="relative flex-1">
                <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted" />
                <input
                  type="text"
                  placeholder="Search dishes or categories..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full bg-muted/40 border border-border/70 rounded-xl pl-9 pr-4 py-2 text-xs font-semibold focus:outline-none focus:border-red-400"
                />
                {searchQuery && (
                  <button
                    onClick={() => setSearchQuery('')}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-text-muted hover:text-text-primary"
                  >
                    <X className="h-3.5 w-3.5" />
                  </button>
                )}
              </div>

              <button
                onClick={fetchItems}
                disabled={loading}
                className="p-2 rounded-xl border border-border/60 hover:bg-muted text-text-secondary hover:text-text-primary transition-all cursor-pointer disabled:opacity-50"
                title="Refresh Menu"
              >
                <RefreshCw className={`h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
              </button>
            </div>
          </div>

          {/* Dishes List */}
          <div className="flex-1 overflow-y-auto p-3 sm:p-4 divide-y divide-border/30">
            {loading ? (
              <div className="flex flex-col items-center justify-center py-16 gap-3">
                <Loader2 className="h-8 w-8 text-red-500 animate-spin" />
                <p className="text-xs text-text-secondary font-bold">Loading dishes...</p>
              </div>
            ) : filteredItems.length === 0 ? (
              <div className="py-16 text-center text-text-secondary space-y-2">
                <AlertCircle className="h-8 w-8 mx-auto text-text-muted" />
                <p className="text-xs font-bold">No menu items found</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 pt-1">
                {filteredItems.map((item) => (
                  <div
                    key={item.id}
                    className={`flex items-center justify-between p-3 rounded-2xl border transition-all ${
                      item.isAvailable
                        ? 'bg-card border-border/60 hover:border-border'
                        : 'bg-rose-500/5 border-rose-500/20 opacity-80'
                    }`}
                  >
                    <div className="min-w-0 pr-2">
                      <div className="flex items-center gap-1.5">
                        <span className={`h-2 w-2 rounded-full shrink-0 ${
                          item.isAvailable ? 'bg-emerald-500' : 'bg-rose-500'
                        }`} />
                        <h4 className="text-xs font-black text-text-primary truncate">
                          {item.name}
                        </h4>
                      </div>
                      <div className="flex items-center gap-2 mt-0.5 text-[10px] text-text-secondary font-medium">
                        <span>{formatPrice(item.price)}</span>
                        {item.category?.name && (
                          <>
                            <span>•</span>
                            <span className="truncate">{item.category.name}</span>
                          </>
                        )}
                      </div>
                    </div>

                    <button
                      onClick={() => toggleAvailability(item)}
                      disabled={togglingId === item.id}
                      className={`shrink-0 px-3 py-1.5 rounded-xl text-[11px] font-black tracking-wider uppercase transition-all cursor-pointer flex items-center gap-1.5 active:scale-95 ${
                        item.isAvailable
                          ? 'bg-emerald-500/10 text-emerald-600 hover:bg-emerald-500/20 border border-emerald-500/30'
                          : 'bg-rose-600 text-white hover:bg-rose-700 shadow-xs'
                      }`}
                    >
                      {togglingId === item.id ? (
                        <Loader2 className="h-3 w-3 animate-spin" />
                      ) : item.isAvailable ? (
                        <>
                          <Check className="h-3 w-3 stroke-[3]" />
                          <span>In Stock</span>
                        </>
                      ) : (
                        <>
                          <X className="h-3 w-3 stroke-[3]" />
                          <span>86 (Out)</span>
                        </>
                      )}
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Modal Footer */}
          <div className="p-3 sm:p-4 border-t border-border/60 bg-muted/10 flex items-center justify-between text-[11px] font-bold text-text-secondary">
            <span>💡 86 items to immediately hide them from customer ordering apps</span>
            <button
              onClick={onClose}
              className="px-4 py-2 bg-text-primary text-background font-black rounded-xl hover:opacity-90 transition-all cursor-pointer shadow-xs"
            >
              Done
            </button>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  )
}
