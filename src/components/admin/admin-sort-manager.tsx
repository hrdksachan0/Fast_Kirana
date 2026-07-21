'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { X, Save, RefreshCw, Layers, SlidersHorizontal, ListOrdered, ArrowDownUp } from 'lucide-react'
import { formatPrice } from '@/lib/utils'

interface AdminSortManagerProps {
  isOpen: boolean
  onClose: () => void
  categories: Array<{ id: string; name: string; slug: string }>
}

interface ProductItem {
  id: string
  name: string
  price: number
  stock: number
  isBestSeller: boolean
  sortOrder: number
  createdAt?: string
  category: {
    name: string
    slug: string
  }
}

const getSortedProducts = (items: ProductItem[], rule: string) => {
  const list = [...items]
  if (rule === 'best-seller') {
    return list.sort((a, b) => {
      if (a.isBestSeller && !b.isBestSeller) return -1
      if (!a.isBestSeller && b.isBestSeller) return 1
      if (b.sortOrder !== a.sortOrder) return b.sortOrder - a.sortOrder
      return new Date(b.createdAt || 0).getTime() - new Date(a.createdAt || 0).getTime()
    })
  } else if (rule === 'stock-desc') {
    return list.sort((a, b) => {
      if (b.stock !== a.stock) return b.stock - a.stock
      if (b.sortOrder !== a.sortOrder) return b.sortOrder - a.sortOrder
      return new Date(b.createdAt || 0).getTime() - new Date(a.createdAt || 0).getTime()
    })
  } else if (rule === 'price-asc') {
    return list.sort((a, b) => {
      if (a.price !== b.price) return a.price - b.price
      return b.sortOrder - a.sortOrder
    })
  } else if (rule === 'price-desc') {
    return list.sort((a, b) => {
      if (b.price !== a.price) return b.price - a.price
      return b.sortOrder - a.sortOrder
    })
  } else if (rule === 'newest') {
    return list.sort((a, b) => new Date(b.createdAt || 0).getTime() - new Date(a.createdAt || 0).getTime())
  }
  return list.sort((a, b) => b.sortOrder - a.sortOrder)
}

export function AdminSortManager({ isOpen, onClose, categories }: AdminSortManagerProps) {
  const [selectedCategorySlug, setSelectedCategorySlug] = useState('')
  const [products, setProducts] = useState<ProductItem[]>([])
  const [sortRule, setSortRule] = useState('manual')
  
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [modifiedPositions, setModifiedPositions] = useState<Record<string, number>>({})

  // Fetch products and sorting rule when category selection changes
  useEffect(() => {
    if (!selectedCategorySlug) {
      setProducts([])
      return
    }

    async function loadCategoryData() {
      setLoading(true)
      try {
        // 1. Fetch category sort rule
        const ruleRes = await fetch(`/api/admin/categories/sort-rule?categorySlug=${selectedCategorySlug}`)
        const ruleData = await ruleRes.json()
        const activeRule = ruleData.rule || 'manual'
        setSortRule(activeRule)

        // 2. Fetch all products in category
        const prodRes = await fetch(`/api/products?category=${selectedCategorySlug}&admin=true&limit=500`)
        const prodData = await prodRes.json()
        const dbProducts = prodData.products || prodData || []
        
        // Sort initially based on active rule
        const sorted = getSortedProducts(dbProducts, activeRule)
        setProducts(sorted)
        
        // Reset modified positions map
        const initialMap: Record<string, number> = {}
        sorted.forEach((p: ProductItem) => {
          initialMap[p.id] = p.sortOrder ?? 0
        })
        setModifiedPositions(initialMap)
      } catch (err) {
        toast.error('Failed to load category products')
      } finally {
        setLoading(false)
      }
    }

    loadCategoryData()
  }, [selectedCategorySlug])

  // Save Auto-Sort Rule (Way 3) and automatically sequence the positions
  const handleSaveRule = async (newRule: string) => {
    setSortRule(newRule)
    setSaving(true)
    try {
      // 1. Sort products list in the UI based on the new rule
      const sorted = getSortedProducts(products, newRule)
      setProducts(sorted)

      // 2. Automatically assign positions (100, 99, 98...) matching the new sequence
      const updatedMap: Record<string, number> = {}
      sorted.forEach((p, idx) => {
        updatedMap[p.id] = 100 - idx
      })
      setModifiedPositions(updatedMap)

      // 3. Save sorting rule to settings
      const ruleRes = await fetch('/api/admin/categories/sort-rule', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ categorySlug: selectedCategorySlug, rule: newRule })
      })
      if (!ruleRes.ok) throw new Error('Failed to save sorting rule')

      // 4. Save the auto-sequenced positions to DB if rule is not manual
      if (newRule !== 'manual') {
        const positionsArray = Object.entries(updatedMap).map(([id, sortOrder]) => ({
          id,
          sortOrder
        }))
        const sortRes = await fetch('/api/admin/products/bulk-sort', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ positions: positionsArray })
        })
        if (!sortRes.ok) throw new Error('Failed to save auto-sequenced product positions')
      }

      toast.success(newRule === 'manual' 
        ? 'Switched to Manual Sort! You can now adjust indices and click Save.' 
        : `Default sorting rule updated to "${newRule}" and product positions auto-sequenced!`
      )
    } catch (err: any) {
      toast.error(err.message || 'Failed to save sorting rule')
    } finally {
      setSaving(false)
    }
  }

  // Update position value locally (Way 4)
  const handlePositionChange = (productId: string, val: string) => {
    const num = parseInt(val) || 0
    setModifiedPositions(prev => ({
      ...prev,
      [productId]: num
    }))
  }

  // Sequential sorting helper button (Way 4 helper)
  const handleAssignSequential = () => {
    const updatedMap: Record<string, number> = {}
    // Assign from 100 downwards (e.g. 100, 99, 98...)
    products.forEach((p, idx) => {
      updatedMap[p.id] = 100 - idx
    })
    setModifiedPositions(updatedMap)
    toast.success('Assigned sequential positions! Click Save to write changes.')
  }

  // Save modified positions in bulk (Way 4 bulk update)
  const handleSavePositions = async () => {
    setSaving(true)
    try {
      const positionsArray = Object.entries(modifiedPositions).map(([id, sortOrder]) => ({
        id,
        sortOrder
      }))

      if (positionsArray.length === 0) {
        toast.warning('No position changes to save.')
        setSaving(false)
        return
      }

      const res = await fetch('/api/admin/products/bulk-sort', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ positions: positionsArray })
      })

      if (!res.ok) {
        const errData = await res.json().catch(() => ({}))
        throw new Error(errData.error || 'Server returned an error')
      }
      
      toast.success('Successfully updated all product positions!')
      
      // Update local state with saved values
      setProducts(prev => 
        prev.map(p => ({
          ...p,
          sortOrder: modifiedPositions[p.id] ?? p.sortOrder
        })).sort((a, b) => (modifiedPositions[b.id] ?? b.sortOrder) - (modifiedPositions[a.id] ?? a.sortOrder))
      )
    } catch (err: any) {
      toast.error(err.message || 'Failed to save product positions')
    } finally {
      setSaving(false)
    }
  }

  const handleSaveClick = async () => {
    if (sortRule === 'manual') {
      await handleSavePositions()
    } else {
      await handleSaveRule(sortRule)
      onClose()
    }
  }

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 overflow-hidden flex items-center justify-center bg-black/50 backdrop-blur-xs animate-fade-in p-4">
      <div className="bg-card border border-border rounded-3xl w-full max-w-4xl h-[85vh] flex flex-col shadow-2xl relative">
        {/* Header */}
        <div className="flex items-center justify-between border-b border-border/60 px-6 py-4.5">
          <div className="flex items-center gap-2">
            <SlidersHorizontal className="h-5 w-5 text-primary" />
            <div>
              <h2 className="text-sm sm:text-base font-black text-text-primary">Product Sort & Position Manager</h2>
              <p className="text-[10px] text-text-secondary mt-0.5">Control sorting rules and bulk-position 200+ products in a grid</p>
            </div>
          </div>
          <button 
            onClick={onClose}
            className="p-1.5 hover:bg-muted/80 rounded-xl transition-all cursor-pointer"
          >
            <X className="h-4.5 w-4.5 text-text-secondary" />
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6 space-y-6">
          {/* Controls Row */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 bg-muted/20 p-4.5 rounded-2xl border border-border/40">
            {/* Category Select */}
            <div className="space-y-1.5 text-left">
              <label className="text-[10px] font-black text-text-secondary uppercase tracking-wider block">1. Select Category</label>
              <div className="relative">
                <Layers className="absolute left-3.5 top-2.5 h-4.5 w-4.5 text-text-muted" />
                <select
                  value={selectedCategorySlug}
                  onChange={(e) => setSelectedCategorySlug(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 text-xs rounded-xl border border-border bg-card font-bold text-text-secondary focus:outline-none"
                >
                  <option value="">-- Choose Category --</option>
                  {categories.map((c) => (
                    <option key={c.id} value={c.slug}>
                      {c.name} ({c.slug})
                    </option>
                  ))}
                </select>
              </div>
            </div>

            {/* Sorting Rule Select (Way 3) */}
            <div className="space-y-1.5 text-left">
              <label className="text-[10px] font-black text-text-secondary uppercase tracking-wider block">2. Category Default Sorting Rule</label>
              <div className="relative">
                <ArrowDownUp className="absolute left-3.5 top-2.5 h-4.5 w-4.5 text-text-muted" />
                <select
                  value={sortRule}
                  disabled={!selectedCategorySlug}
                  onChange={(e) => handleSaveRule(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 text-xs rounded-xl border border-border bg-card font-bold text-text-secondary focus:outline-none disabled:opacity-50"
                >
                  <option value="manual">Manual Sort (Uses sortOrder value below)</option>
                  <option value="best-seller">Best Sellers First 🔥</option>
                  <option value="stock-desc">High Stock First 📦</option>
                  <option value="price-asc">Price: Low to High 💸</option>
                  <option value="price-desc">Price: High to Low 💰</option>
                  <option value="newest">Newest Added First 🆕</option>
                </select>
              </div>
            </div>
          </div>

          {/* Table Container (Way 4) */}
          {selectedCategorySlug && (
            <div className="space-y-4">
              <div className="flex justify-between items-center px-1">
                <h3 className="text-xs font-black text-text-primary uppercase tracking-wider flex items-center gap-1.5">
                  <ListOrdered className="h-4 w-4 text-primary" />
                  Product Sheet ({products.length} Items found)
                </h3>
                {sortRule === 'manual' && (
                  <button
                    onClick={handleAssignSequential}
                    className="px-3.5 py-1.5 text-[10px] font-black border border-amber-500/25 bg-amber-500/10 text-amber-600 rounded-xl hover:bg-amber-500/20 active:scale-95 transition-all cursor-pointer"
                  >
                    ⚡ Auto-Set Sequence (100, 99, 98...)
                  </button>
                )}
              </div>

              {loading ? (
                <div className="h-48 flex flex-col items-center justify-center gap-2">
                  <RefreshCw className="h-6 w-6 text-primary animate-spin" />
                  <p className="text-[10px] font-extrabold text-text-secondary">Loading product sheet...</p>
                </div>
              ) : products.length === 0 ? (
                <div className="h-48 flex items-center justify-center text-xs text-text-secondary font-bold border border-dashed border-border/50 rounded-2xl">
                  No products in this category.
                </div>
              ) : (
                <div className="border border-border rounded-2xl overflow-hidden shadow-xs">
                  <div className="max-h-[40vh] overflow-y-auto relative bg-card">
                    {/* Header */}
                    <div className="bg-zinc-100 dark:bg-zinc-800/80 backdrop-blur-xs font-black text-text-secondary border-b border-border/60 sticky top-0 z-20 select-none py-3 px-4 grid grid-cols-12 items-center text-xs">
                      <div className="col-span-5">Product Name</div>
                      <div className="col-span-2 text-center">Price</div>
                      <div className="col-span-1 text-center">Stock</div>
                      <div className="col-span-2 text-center">Best Seller</div>
                      <div className="col-span-2 text-center">Position Index</div>
                    </div>
                    {/* Body */}
                    <div className="divide-y divide-border/40 font-semibold text-text-secondary bg-card">
                      {products.map((p) => (
                        <div key={p.id} className="hover:bg-muted/10 transition-colors py-2.5 px-4 grid grid-cols-12 items-center text-xs">
                          <div className="col-span-5 font-bold text-text-primary truncate pr-2" title={p.name}>
                            {p.name}
                          </div>
                          <div className="col-span-2 text-center text-text-primary font-bold">{formatPrice(p.price)}</div>
                          <div className="col-span-1 text-center">{p.stock}</div>
                          <div className="col-span-2 text-center">{p.isBestSeller ? '🔥 Yes' : 'No'}</div>
                          <div className="col-span-2 flex justify-center">
                            <input
                              type="number"
                              disabled={sortRule !== 'manual'}
                              value={modifiedPositions[p.id] ?? 0}
                              onChange={(e) => handlePositionChange(p.id, e.target.value)}
                              className="w-20 px-2 py-1 text-center font-bold text-text-primary border border-border rounded-lg bg-muted/30 focus:outline-none focus:border-primary disabled:opacity-50 disabled:bg-muted/10 text-xs"
                            />
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="border-t border-border/60 px-6 py-4 flex justify-between items-center">
          <span className="text-[9px] font-black text-text-muted select-none">
            {sortRule !== 'manual' && '⚠️ Auto-Sorting rule is ACTIVE. Product positions will be handled automatically.'}
          </span>
          <div className="flex gap-2">
            <button
              onClick={onClose}
              className="px-4 py-2 border border-border hover:bg-muted/80 text-text-primary text-xs font-black rounded-xl transition-all cursor-pointer"
            >
              Cancel
            </button>
            <button
              onClick={handleSaveClick}
              disabled={saving || !selectedCategorySlug}
              className="flex items-center gap-1.5 px-4 py-2 bg-primary text-primary-foreground text-xs font-black rounded-xl hover:bg-primary/95 transition-all disabled:opacity-50 cursor-pointer shadow-sm"
            >
              {saving ? (
                <>
                  <RefreshCw className="h-4 w-4 animate-spin" />
                  Saving...
                </>
              ) : (
                <>
                  <Save className="h-4 w-4" />
                  {sortRule === 'manual' ? 'Save Positions' : 'Save Sorting Rule'}
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
