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

import { Plus, Loader2, Image as ImageIcon } from 'lucide-react'

import { PRESET_KITCHEN_PHOTOS } from '@/lib/preset-photos'

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

  // Dish Add/Edit Modal states
  const [showDishModal, setShowDishModal] = useState(false)
  const [editingDish, setEditingDish] = useState<Product | null>(null)
  const [savingDish, setSavingDish] = useState(false)
  const [isUploading, setIsUploading] = useState(false)

  // Media Library states
  const [showMediaLibrary, setShowMediaLibrary] = useState(false)
  const [mediaSearchQuery, setMediaSearchQuery] = useState('')
  const [globalProducts, setGlobalProducts] = useState<any[]>([])
  const [globalCategories, setGlobalCategories] = useState<any[]>([])

  const [restaurants, setRestaurants] = useState<any[]>([])
  const [selectedRestaurantId, setSelectedRestaurantId] = useState<string>('ALL')

  // Fetch all outlets dynamically
  useEffect(() => {
    fetch('/api/restaurants')
      .then(res => res.ok ? res.json() : null)
      .then(data => {
        if (data?.restaurants) {
          setRestaurants(data.restaurants)
        }
      })
      .catch(console.error)
  }, [])

  // Fetch all store products & categories so local media gallery shows ALL photos in system
  useEffect(() => {
    Promise.all([
      fetch('/api/products?limit=2000').then(r => r.ok ? r.json() : null),
      fetch('/api/categories').then(r => r.ok ? r.json() : null)
    ]).then(([prodData, catData]) => {
      if (prodData?.products) setGlobalProducts(prodData.products)
      if (catData) {
        const catList = catData.categories || (Array.isArray(catData) ? catData : [])
        setGlobalCategories(catList)
      }
    }).catch(console.error)
  }, [])

  const [dishForm, setDishForm] = useState({
    name: '',
    price: '',
    mrp: '',
    imageUrl: '',
    sectionTag: 'main-course',
  })

  const mediaImages = useMemo(() => {
    const setOfImages = new Map<string, { url: string; name: string; tags?: string[] }>()

    // 1. Add preset HD kitchen food photos
    PRESET_KITCHEN_PHOTOS.forEach((preset) => {
      if (preset.url) {
        setOfImages.set(preset.url, { url: preset.url, name: preset.name, tags: preset.tags })
      }
    })

    // 2. Add all global products from entire database (Beverages, Ice Creams, Dishes, Snacks, Grocery, etc.)
    globalProducts.forEach((p) => {
      if (p.imageUrl && typeof p.imageUrl === 'string' && p.imageUrl.trim().length > 0) {
        const url = p.imageUrl.trim()
        if (!setOfImages.has(url)) {
          setOfImages.set(url, { url, name: p.name || 'Product Image', tags: p.tags || [] })
        }
      }
    })

    // 3. Add outlet's own products
    products.forEach((p) => {
      if (p.imageUrl && typeof p.imageUrl === 'string' && p.imageUrl.trim().length > 0) {
        const url = p.imageUrl.trim()
        if (!setOfImages.has(url)) {
          setOfImages.set(url, { url, name: p.name || 'Dish Photo', tags: (p as any).tags || [] })
        }
      }
    })

    // 4. Add category photos
    globalCategories.forEach((c) => {
      if (c.imageUrl && typeof c.imageUrl === 'string' && c.imageUrl.trim().length > 0) {
        const url = c.imageUrl.trim()
        if (!setOfImages.has(url)) {
          setOfImages.set(url, { url, name: c.name || 'Category Image' })
        }
      }
    })

    return Array.from(setOfImages.values())
  }, [products, globalProducts, globalCategories])

  const filteredMediaImages = useMemo(() => {
    if (!mediaSearchQuery.trim()) return mediaImages
    const q = mediaSearchQuery.toLowerCase().trim()
    return mediaImages.filter(img => 
      img.name.toLowerCase().includes(q) || 
      img.url.toLowerCase().includes(q) ||
      (img.tags && img.tags.some(t => t.toLowerCase().includes(q)))
    )
  }, [mediaImages, mediaSearchQuery])

  const handleOpenAddDish = () => {
    setEditingDish(null)
    setDishForm({
      name: '',
      price: '',
      mrp: '',
      imageUrl: '',
      sectionTag: 'main-course',
    })
    setShowDishModal(true)
  }

  const handleOpenEditDish = (product: Product) => {
    setEditingDish(product)
    setDishForm({
      name: product.name || '',
      price: String(product.price || ''),
      mrp: String(product.mrp || ''),
      imageUrl: product.imageUrl || '',
      sectionTag: (product as any).tags?.[0] || 'main-course',
    })
    setShowDishModal(true)
  }

  const handleSaveDish = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!dishForm.name || !dishForm.price || !dishForm.mrp) {
      toast.error('Please fill in dish name, price, and MRP')
      return
    }

    // Determine which restaurant to assign this dish to
    const targetRestaurantId = selectedRestaurantId !== 'ALL' 
      ? selectedRestaurantId 
      : (restaurants.length > 0 ? restaurants[0].id : '')

    setSavingDish(true)
    try {
      if (editingDish) {
        // Edit existing dish — use restaurant-dashboard API for proper scoping
        const res = await fetch(`/api/restaurant-dashboard/products/${editingDish.id}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            name: dishForm.name,
            price: parseFloat(dishForm.price),
            mrp: parseFloat(dishForm.mrp),
            imageUrl: dishForm.imageUrl,
            tags: [dishForm.sectionTag, 'restaurant'],
          }),
        })
        if (!res.ok) {
          const errData = await res.json().catch(() => ({}))
          throw new Error(errData.error || 'Failed to update dish')
        }
        const data = await res.json()
        const updated = data.product || data
        setProducts(prev => prev.map(p => p.id === editingDish.id ? updated : p))
        toast.success(`Dish "${dishForm.name}" updated successfully! 🎉`)
      } else {
        // Add new dish — use restaurant-dashboard API which handles restaurantId properly
        const res = await fetch('/api/restaurant-dashboard/products', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            name: dishForm.name,
            price: parseFloat(dishForm.price),
            mrp: parseFloat(dishForm.mrp),
            imageUrl: dishForm.imageUrl,
            stock: 99999,
            isAvailable: true,
            tags: [dishForm.sectionTag, 'restaurant'],
            restaurantId: targetRestaurantId,
          }),
        })
        if (!res.ok) {
          const errData = await res.json().catch(() => ({}))
          throw new Error(errData.error || 'Failed to create dish')
        }
        const data = await res.json()
        const created = data.product || data
        setProducts(prev => [created, ...prev])
        toast.success(`New dish "${dishForm.name}" added to menu! 🎉`)
      }
      setShowDishModal(false)
    } catch (err: any) {
      toast.error(err.message || 'Error saving dish')
    } finally {
      setSavingDish(false)
    }
  }

  const handleCloudinaryUpload = async (file: File) => {
    setIsUploading(true)
    try {
      const formData = new FormData()
      formData.append('file', file)
      const res = await fetch('/api/upload', {
        method: 'POST',
        body: formData,
      })
      if (!res.ok) throw new Error('Upload failed')
      const data = await res.json()
      if (data.url) {
        setDishForm(prev => ({ ...prev, imageUrl: data.url }))
        toast.success('Photo uploaded successfully! 📸')
      }
    } catch (err) {
      toast.error('Failed to upload image')
    } finally {
      setIsUploading(false)
    }
  }

  const fetchRestaurantProducts = async () => {
    setLoading(true)
    try {
      // Use restaurant-dashboard API which properly scopes by restaurantId
      const restIdParam = selectedRestaurantId && selectedRestaurantId !== 'ALL' 
        ? `?restaurantId=${selectedRestaurantId}` 
        : ''
      const res = await fetch(`/api/restaurant-dashboard/products${restIdParam}`, { cache: 'no-store' })
      if (!res.ok) throw new Error('Failed to fetch catalog')
      const data = await res.json()
      setProducts(data.products || [])
    } catch (err) {
      toast.error('Failed to load Restaurant catalog')
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchRestaurantProducts()
  }, [selectedRestaurantId])

  const handleToggleAvailability = async (product: Product) => {
    setUpdatingId(product.id)
    const newStatus = !product.isAvailable
    try {
      const res = await fetch(`/api/restaurant-dashboard/products/${product.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isAvailable: newStatus }),
      })
      if (res.ok) {
        setProducts(prev => prev.map(p => p.id === product.id ? { ...p, isAvailable: newStatus } : p))
        toast.success(`"${product.name}" is now ${newStatus ? 'visible' : 'hidden'} on storefront!`)
      } else {
        const errData = await res.json().catch(() => ({}))
        toast.error(errData.error || 'Failed to update product status')
      }
    } catch (err: any) {
      toast.error(err?.message || 'Failed to update product status')
    } finally {
      setUpdatingId(null)
    }
  }

  const handleToggleStock = async (product: Product) => {
    setUpdatingId(product.id)
    const isCurrentlyInStock = product.stock > 0
    const newStock = isCurrentlyInStock ? 0 : 99999
    try {
      const res = await fetch(`/api/restaurant-dashboard/products/${product.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ stock: newStock }),
      })
      if (res.ok) {
        setProducts(prev => prev.map(p => p.id === product.id ? { ...p, stock: newStock } : p))
        toast.success(`"${product.name}" marked as ${newStock > 0 ? 'In Stock' : 'Sold Out'}!`)
      } else {
        const errData = await res.json().catch(() => ({}))
        toast.error(errData.error || 'Failed to update stock status')
      }
    } catch (err: any) {
      toast.error(err?.message || 'Failed to update stock status')
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
      const res = await fetch(`/api/restaurant-dashboard/products/${product.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ price: priceNum, mrp: mrpNum }),
      })
      if (res.ok) {
        setProducts(prev => prev.map(p => p.id === product.id ? { ...p, price: priceNum, mrp: mrpNum } : p))
        toast.success(`Price for "${product.name}" updated to ₹${priceNum}!`)
        setEditingPriceId(null)
      } else {
        const errData = await res.json().catch(() => ({}))
        toast.error(errData.error || 'Failed to update price')
      }
    } catch (err: any) {
      toast.error(err?.message || 'Failed to update price')
    } finally {
      setUpdatingId(null)
    }
  }



  const selectedRestaurant = useMemo(() => {
    return restaurants.find(r => r.id === selectedRestaurantId)
  }, [restaurants, selectedRestaurantId])

  const consoleTitle = selectedRestaurant 
    ? `${selectedRestaurant.name} Console`
    : 'All Restaurants & Outlets Console'

  const filteredList = useMemo(() => {
    return products.filter(p => {
      // 1. Outlet Filter
      if (selectedRestaurantId !== 'ALL') {
        const pRestId = (p as any).restaurantId || (p as any).restaurant?.id
        if (pRestId && pRestId !== selectedRestaurantId) return false
      }

      // 2. Search & Stock Filter
      const matchesSearch = p.name.toLowerCase().includes(searchQuery.toLowerCase()) || 
                            (p.category?.name || '').toLowerCase().includes(searchQuery.toLowerCase())
      
      if (!matchesSearch) return false
      
      if (filter === 'instock') return p.stock > 0
      if (filter === 'outofstock') return p.stock <= 0
      if (filter === 'hidden') return !p.isAvailable
      return true
    })
  }, [products, searchQuery, filter, selectedRestaurantId])

  return (
    <div className="space-y-6">
      {/* Console Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 bg-gradient-to-r from-red-500/10 via-rose-500/5 to-transparent p-6 rounded-3xl border border-border/40">
        <div className="space-y-1">
          <div className="flex items-center gap-2">
            <div className="h-8 w-8 rounded-xl bg-red-500/10 text-red-500 flex items-center justify-center">
              <Utensils className="h-4.5 w-4.5" />
            </div>
            <h2 className="text-xl font-black text-text-primary">{consoleTitle}</h2>
          </div>
          <p className="text-xs text-text-secondary">
            Manage live menu availability, kitchen stock status, and pricing for Restaurant meals, main courses, and combo deals.
          </p>
        </div>
        
        <div className="flex items-center gap-3 w-full md:w-auto">
          {/* Real-time Outlet Selector */}
          <select
            value={selectedRestaurantId}
            onChange={(e) => setSelectedRestaurantId(e.target.value)}
            className="px-3.5 py-2 text-xs font-black bg-card border border-border rounded-xl text-text-primary focus:outline-none focus:ring-2 focus:ring-red-500/30 cursor-pointer shadow-xs"
          >
            <option value="ALL">🍽️ All Outlets ({restaurants.length})</option>
            {restaurants.map((r) => (
              <option key={r.id} value={r.id}>
                {r.name}
              </option>
            ))}
          </select>

          <button
            onClick={fetchRestaurantProducts}
            disabled={loading}
            className="inline-flex items-center gap-1.5 px-4 py-2 text-xs font-black bg-card border border-border hover:bg-muted/40 text-text-primary rounded-xl transition-all cursor-pointer disabled:opacity-50 shrink-0"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${loading ? 'animate-spin' : ''}`} />
            Refresh Menu
          </button>
        </div>
      </div>

      {/* Sub-tab Navigation */}
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

      {activeSubTab === 'catalog' && (
        <>
          {/* Filters & Search */}
          <div className="flex flex-col sm:flex-row gap-3 items-center justify-between">
        <div className="flex gap-2 w-full sm:w-auto">
          <div className="relative w-full sm:w-80">
            <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted" />
            <input
              type="text"
              placeholder="Search Restaurant dishes, combos, main courses..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              className="w-full bg-card border border-border pl-10 pr-4 py-2.5 rounded-2xl text-xs focus:outline-none focus:border-primary font-medium"
            />
          </div>
          <button
            type="button"
            onClick={handleOpenAddDish}
            className="flex items-center gap-1.5 px-4 py-2.5 bg-gradient-to-r from-red-600 to-rose-600 hover:from-red-700 hover:to-rose-700 text-white text-xs font-black rounded-2xl shadow-md transition-all cursor-pointer whitespace-nowrap shrink-0"
          >
            <Plus className="h-4 w-4" />
            + Add New Dish
          </button>
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
                    <div className="space-y-1 flex-1 min-w-0">
                      <div className="flex items-center justify-between gap-1">
                        <h4 className="text-xs font-black text-text-primary line-clamp-1">{product.name}</h4>
                        <button
                          type="button"
                          onClick={() => handleOpenEditDish(product)}
                          className="text-[9px] font-black text-amber-600 dark:text-amber-400 bg-amber-500/10 hover:bg-amber-500/20 border border-amber-500/20 px-2 py-0.5 rounded-lg transition-all flex items-center gap-1 cursor-pointer shrink-0"
                          title="Edit Dish Photo & Details"
                        >
                          🖼️ Photo
                        </button>
                      </div>
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

      {/* Add / Edit Dish Modal */}
      {showDishModal && (
        <div className="fixed inset-0 z-[90] flex items-center justify-center bg-black/70 backdrop-blur-sm p-4 animate-in fade-in">
          <div className="bg-card border border-border rounded-3xl shadow-2xl w-full max-w-lg overflow-hidden flex flex-col">
            <div className="flex items-center justify-between p-5 border-b border-border bg-muted/20">
              <div className="flex items-center gap-2">
                <span className="text-xl">🍳</span>
                <h3 className="font-black text-text-primary text-base">
                  {editingDish ? `Edit "${editingDish.name}"` : 'Add New Restaurant Dish'}
                </h3>
              </div>
              <button onClick={() => setShowDishModal(false)} className="text-text-secondary hover:text-text-primary p-1 cursor-pointer">
                <X className="h-5 w-5" />
              </button>
            </div>

            <form onSubmit={handleSaveDish} className="p-5 space-y-4">
              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Dish Name *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Paneer Butter Masala, Chicken Biryani"
                  value={dishForm.name}
                  onChange={e => setDishForm({ ...dishForm, name: e.target.value })}
                  className="w-full px-3.5 py-2.5 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Selling Price (₹) *</label>
                  <input
                    type="number"
                    required
                    placeholder="e.g. 240"
                    value={dishForm.price}
                    onChange={e => setDishForm({ ...dishForm, price: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">MRP (₹) *</label>
                  <input
                    type="number"
                    required
                    placeholder="e.g. 290"
                    value={dishForm.mrp}
                    onChange={e => setDishForm({ ...dishForm, mrp: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
              </div>

              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Menu Section Tag *</label>
                <select
                  value={dishForm.sectionTag}
                  onChange={e => setDishForm({ ...dishForm, sectionTag: e.target.value })}
                  className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold cursor-pointer"
                >
                  <option value="main-course">🍛 Main Course</option>
                  <option value="starters">🍢 Starters & Snacks</option>
                  <option value="biryani">🍚 Biryani & Rice</option>
                  <option value="thali">🍱 Thali & Meals</option>
                  <option value="breads">🍞 Roti & Breads</option>
                  <option value="beverages">🥤 Beverages & Drinks</option>
                  <option value="dessert">🍨 Desserts & Sweets</option>
                </select>
              </div>

              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Dish Photo URL (Cloudinary / Library)</label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    placeholder="Photo URL..."
                    value={dishForm.imageUrl}
                    onChange={e => setDishForm({ ...dishForm, imageUrl: e.target.value })}
                    className="flex-1 px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                  <label
                    htmlFor="restaurant-dish-image-file"
                    className="cursor-pointer px-3 py-2 bg-primary/10 hover:bg-primary/20 text-primary text-[10px] font-black rounded-xl border border-primary/20 transition-all flex items-center gap-1.5 whitespace-nowrap"
                  >
                    {isUploading ? <Loader2 className="h-3 w-3 animate-spin" /> : 'Upload'}
                  </label>
                  <input
                    id="restaurant-dish-image-file"
                    type="file"
                    accept="image/*"
                    onChange={e => {
                      const file = e.target.files?.[0]
                      if (file) handleCloudinaryUpload(file)
                      e.target.value = ''
                    }}
                    className="sr-only"
                    disabled={isUploading}
                  />
                  <button
                    type="button"
                    onClick={() => setShowMediaLibrary(true)}
                    className="px-3 py-2 bg-amber-500/10 hover:bg-amber-500/20 text-amber-600 dark:text-amber-400 text-[10px] font-black rounded-xl border border-amber-500/20 transition-all flex items-center gap-1.5 whitespace-nowrap cursor-pointer"
                  >
                    🖼️ Library
                  </button>
                </div>
              </div>

              {dishForm.imageUrl && (
                <div className="h-24 w-full rounded-2xl bg-muted/30 border border-border/40 overflow-hidden flex items-center justify-center">
                  <img src={dishForm.imageUrl} alt="Dish Preview" className="h-full w-full object-contain p-1" />
                </div>
              )}

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setShowDishModal(false)}
                  className="px-4 py-2 text-xs font-bold border border-border rounded-xl hover:bg-muted transition-colors cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={savingDish}
                  className="px-5 py-2 text-xs font-black bg-primary text-white rounded-xl hover:bg-primary/95 shadow-md transition-all cursor-pointer flex items-center gap-1.5"
                >
                  {savingDish ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : (editingDish ? 'Save Changes' : '+ Add Dish')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* 🖼️ Media Library Photo Picker Modal */}
      {showMediaLibrary && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/70 backdrop-blur-sm p-4 animate-in fade-in">
          <div className="bg-card border border-border rounded-3xl shadow-2xl w-full max-w-3xl max-h-[85vh] flex flex-col p-5 space-y-4">
            <div className="flex items-center justify-between border-b border-border pb-3">
              <div className="flex items-center gap-2">
                <span className="text-xl">🖼️</span>
                <div>
                  <h3 className="font-extrabold text-text-primary text-sm sm:text-base">Kitchen Photo Library</h3>
                  <p className="text-[10px] text-text-secondary">Pick any existing dish photo from library ({filteredMediaImages.length} available)</p>
                </div>
              </div>
              <button onClick={() => setShowMediaLibrary(false)} className="text-text-secondary hover:text-text-primary p-1 cursor-pointer">
                <X className="h-5 w-5" />
              </button>
            </div>

            {/* Search filter input */}
            <div className="relative">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted" />
              <input
                type="text"
                placeholder="Search photo by dish name or keyword (e.g. paneer, biryani, thali)..."
                value={mediaSearchQuery}
                onChange={(e) => setMediaSearchQuery(e.target.value)}
                className="w-full bg-muted/20 border border-border pl-10 pr-4 py-2.5 rounded-2xl text-xs focus:outline-none focus:border-primary font-medium"
              />
            </div>

            {/* Photo Grid */}
            <div className="flex-1 overflow-y-auto grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-3 p-1 min-h-[250px]">
              {filteredMediaImages.length === 0 ? (
                <div className="col-span-full py-12 text-center text-xs font-bold text-text-muted">
                  No matching dish photos found. Try searching another keyword!
                </div>
              ) : (
                filteredMediaImages.map((img, idx) => (
                  <button
                    key={idx}
                    type="button"
                    onClick={() => {
                      setDishForm(prev => ({ ...prev, imageUrl: img.url }))
                      setShowMediaLibrary(false)
                      toast.success('Photo selected from library! 🖼️')
                    }}
                    className="group relative flex flex-col items-center border border-border/50 rounded-2xl p-2 bg-muted/10 hover:bg-primary/10 hover:border-primary transition-all cursor-pointer text-center"
                  >
                    <div className="h-16 w-16 relative overflow-hidden rounded-xl bg-white/5 flex items-center justify-center mb-1.5 border border-border/30">
                      <img src={img.url} alt={img.name} className="h-full w-full object-contain group-hover:scale-105 transition-transform" />
                    </div>
                    <span className="text-[9px] font-bold text-text-secondary truncate w-full group-hover:text-primary">{img.name}</span>
                  </button>
                ))
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
