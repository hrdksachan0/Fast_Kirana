'use client'

import { useState, useEffect, useMemo, useRef } from 'react'
import { useSession } from 'next-auth/react'
import { 
  Plus, 
  Search, 
  Edit2, 
  Trash2, 
  Check, 
  X, 
  Loader2, 
  Image as ImageIcon, 
  Tag, 
  IndianRupee, 
  ToggleLeft, 
  ToggleRight, 
  Sparkles,
  Layers,
  FileText,
  Upload
} from 'lucide-react'
import { toast } from 'sonner'
import { formatPrice } from '@/lib/utils'

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
  tags: string[]
  unit: string
  category?: {
    id: string
    name: string
    slug: string
  }
}

interface Category {
  id: string
  name: string
  slug: string
}

export function RestaurantCatalogManager() {
  const { data: session } = useSession()
  const [products, setProducts] = useState<Product[]>([])
  const [categories, setCategories] = useState<Category[]>([])
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [filter, setFilter] = useState<'all' | 'veg' | 'nonveg' | 'outofstock'>('all')

  // Modals / Editor States
  const [isFormOpen, setIsFormOpen] = useState(false)
  const [editingProduct, setEditingProduct] = useState<Product | null>(null)

  // Form Fields
  const [name, setName] = useState('')
  const [price, setPrice] = useState('')
  const [mrp, setMrp] = useState('')
  const [unit, setUnit] = useState('Serving')
  const [categoryId, setCategoryId] = useState('')
  const [description, setDescription] = useState('')
  const [imageUrl, setImageUrl] = useState('')
  const [stock, setStock] = useState('999')
  const [isVeg, setIsVeg] = useState(true)
  const [uploadingImage, setUploadingImage] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const handleDishImageUpload = async (file: File) => {
    if (!file) return
    setUploadingImage(true)
    try {
      const data = new FormData()
      data.append('file', file)
      const res = await fetch('/api/upload', {
        method: 'POST',
        body: data
      })
      if (!res.ok) throw new Error('Upload failed')
      const json = await res.json()
      if (json.url) {
        setImageUrl(json.url)
        toast.success('Dish photo uploaded successfully!')
      }
    } catch (err) {
      console.error(err)
      toast.error('Failed to upload image')
    } finally {
      setUploadingImage(false)
    }
  }

  const assignedRestaurantId = (session?.user as any)?.assignedRestaurantId

  const fetchCatalogAndCategories = async () => {
    if (!assignedRestaurantId) {
      setLoading(false)
      return
    }

    try {
      const [prodRes, catRes] = await Promise.all([
        fetch('/api/restaurant-dashboard/products', { cache: 'no-store' }),
        fetch('/api/categories', { cache: 'no-store' })
      ])

      if (!prodRes.ok) throw new Error('Failed to load products')
      const prodData = await prodRes.json()
      setProducts(prodData.products || [])

      if (catRes.ok) {
        const catData = await catRes.json()
        // Filter categories: keep food-related categories
        const foodCategories = (catData.categories || catData || []).filter((c: any) => {
          const s = c.slug.toLowerCase()
          return s.includes('food') || s.includes('cafe') || s.includes('beverage') || 
                 s.includes('snack') || s.includes('pizza') || s.includes('burger') || 
                 s.includes('biryani') || s.includes('ice-cream') || s.includes('chinese') ||
                 s.includes('south-indian') || s.includes('sweet') || s.includes('roll')
        })
        
        // Fallback to all categories if filter resulted in empty list
        setCategories(foodCategories.length > 0 ? foodCategories : (catData.categories || catData || []))
      }
    } catch (err) {
      console.error(err)
      toast.error('Failed to load menu items')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchCatalogAndCategories()
  }, [assignedRestaurantId])

  // Open Form for Adding New Product
  const handleOpenAddForm = () => {
    setEditingProduct(null)
    setName('')
    setPrice('')
    setMrp('')
    setUnit('Serving')
    setCategoryId(categories[0]?.id || '')
    setDescription('')
    setImageUrl('')
    setStock('999')
    setIsVeg(true)
    setIsFormOpen(true)
  }

  // Open Form for Editing Existing Product
  const handleOpenEditForm = (product: Product) => {
    setEditingProduct(product)
    setName(product.name)
    setPrice(product.price.toString())
    setMrp(product.mrp.toString())
    setUnit(product.unit)
    setCategoryId(product.categoryId)
    setDescription(product.description || '')
    setImageUrl(product.imageUrl || '')
    setStock(product.stock.toString())
    setIsVeg(!product.tags.includes('non-veg'))
    setIsFormOpen(true)
  }

  // Handle Form Submit (Add or Edit)
  const handleSubmitForm = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!name.trim() || !price || !unit || !categoryId) {
      toast.error('Please fill all required fields')
      return
    }

    setSubmitting(true)
    const priceVal = parseFloat(price)
    const mrpVal = mrp ? parseFloat(mrp) : priceVal
    const stockVal = parseInt(stock) || 999
    const tags = isVeg ? ['veg'] : ['non-veg']

    // Add general restaurant tag for convenience
    tags.push('restaurant')

    const payload = {
      name: name.trim(),
      price: priceVal,
      mrp: mrpVal,
      unit,
      categoryId,
      description: description.trim() || null,
      imageUrl: imageUrl.trim() || null,
      stock: stockVal,
      tags,
    }

    try {
      let res
      if (editingProduct) {
        // Edit Product
        res = await fetch(`/api/restaurant-dashboard/products/${editingProduct.id}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        })
      } else {
        // Add Product
        res = await fetch('/api/restaurant-dashboard/products', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            ...payload,
            restaurantId: assignedRestaurantId
          })
        })
      }

      if (!res.ok) {
        const errorData = await res.json()
        throw new Error(errorData.error || 'Operation failed')
      }

      toast.success(editingProduct ? 'Menu item updated successfully!' : 'New menu item added successfully!')
      setIsFormOpen(false)
      fetchCatalogAndCategories()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Failed to save menu item')
    } finally {
      setSubmitting(false)
    }
  }

  // Handle Delete (Soft delete by turning availability off)
  const handleDeleteProduct = async (product: Product) => {
    const confirmed = window.confirm(`Are you sure you want to delete "${product.name}" from your storefront?`)
    if (!confirmed) return

    try {
      const res = await fetch(`/api/restaurant-dashboard/products/${product.id}`, {
        method: 'DELETE'
      })

      if (res.ok) {
        toast.success(`"${product.name}" removed successfully!`)
        fetchCatalogAndCategories()
      } else {
        toast.error('Failed to remove product')
      }
    } catch (err) {
      console.error(err)
      toast.error('Failed to remove product')
    }
  }

  // Toggle Availability
  const handleToggleAvailability = async (product: Product) => {
    const newStatus = !product.isAvailable
    try {
      const res = await fetch(`/api/restaurant-dashboard/products/${product.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isAvailable: newStatus })
      })

      if (res.ok) {
        setProducts(prev => prev.map(p => p.id === product.id ? { ...p, isAvailable: newStatus } : p))
        toast.success(`"${product.name}" is now ${newStatus ? 'active' : 'hidden'}!`)
      } else {
        toast.error('Failed to toggle status')
      }
    } catch (err) {
      console.error(err)
      toast.error('Failed to toggle status')
    }
  }

  const filteredProducts = useMemo(() => {
    return products.filter(p => {
      const matchesSearch = p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                            p.category?.name.toLowerCase().includes(searchQuery.toLowerCase())
      
      if (!matchesSearch) return false

      if (filter === 'veg') return !p.tags.includes('non-veg')
      if (filter === 'nonveg') return p.tags.includes('non-veg')
      if (filter === 'outofstock') return p.stock <= 0

      return true
    })
  }, [products, searchQuery, filter])

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-3">
        <Loader2 className="h-8 w-8 text-orange-500 animate-spin" />
        <p className="text-sm text-text-secondary font-bold">Loading Menu Catalog...</p>
      </div>
    )
  }

  return (
    <div className="space-y-6 animate-fade-in">
      
      {/* Header controls */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 border-b border-border/40 pb-5">
        <div className="space-y-1">
          <h3 className="text-base font-black text-text-primary uppercase tracking-tight">Menu Catalog</h3>
          <p className="text-xs text-text-secondary">Add new dishes, edit pricing, manage availability, and set photos.</p>
        </div>

        <button
          onClick={handleOpenAddForm}
          className="inline-flex items-center justify-center gap-2 px-5 py-2.5 bg-orange-600 hover:bg-orange-700 text-white font-black text-xs uppercase tracking-wider rounded-2xl transition-all cursor-pointer shadow-xs"
        >
          <Plus className="h-4 w-4" />
          Add New Dish
        </button>
      </div>

      {/* Filters and search */}
      <div className="flex flex-col md:flex-row gap-4 items-center justify-between">
        
        {/* Search */}
        <div className="relative w-full md:max-w-xs">
          <Search className="absolute left-3.5 top-3.5 h-4 w-4 text-text-muted" />
          <input
            type="text"
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            placeholder="Search dish or category..."
            className="w-full pl-10 pr-4 py-2.5 bg-muted/40 border border-border rounded-2xl text-xs focus:outline-hidden focus:border-orange-500/50 transition-all font-semibold"
          />
        </div>

        {/* Filter buttons */}
        <div className="flex gap-2 w-full md:w-auto overflow-x-auto pb-1 md:pb-0">
          <button
            onClick={() => setFilter('all')}
            className={`px-4 py-2 rounded-xl text-xs font-black uppercase tracking-wider border transition-all cursor-pointer ${
              filter === 'all'
                ? 'bg-orange-500/10 border-orange-500/30 text-orange-600'
                : 'bg-card border-border text-text-secondary'
            }`}
          >
            All Items
          </button>
          <button
            onClick={() => setFilter('veg')}
            className={`px-4 py-2 rounded-xl text-xs font-black uppercase tracking-wider border transition-all cursor-pointer ${
              filter === 'veg'
                ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-600'
                : 'bg-card border-border text-text-secondary'
            }`}
          >
            Veg 🟢
          </button>
          <button
            onClick={() => setFilter('nonveg')}
            className={`px-4 py-2 rounded-xl text-xs font-black uppercase tracking-wider border transition-all cursor-pointer ${
              filter === 'nonveg'
                ? 'bg-rose-500/10 border-rose-500/30 text-rose-600'
                : 'bg-card border-border text-text-secondary'
            }`}
          >
            Non-Veg 🔴
          </button>
          <button
            onClick={() => setFilter('outofstock')}
            className={`px-4 py-2 rounded-xl text-xs font-black uppercase tracking-wider border transition-all cursor-pointer ${
              filter === 'outofstock'
                ? 'bg-zinc-500/10 border-zinc-500/30 text-zinc-600 dark:text-zinc-400'
                : 'bg-card border-border text-text-secondary'
            }`}
          >
            Out of Stock
          </button>
        </div>

      </div>

      {/* Grid listing */}
      {filteredProducts.length === 0 ? (
        <div className="bg-card border border-border rounded-3xl p-12 text-center max-w-md mx-auto space-y-3">
          <p className="text-sm font-bold text-text-secondary">No dishes found in your menu catalog.</p>
          <button
            onClick={handleOpenAddForm}
            className="text-xs font-black text-orange-600 uppercase tracking-wider hover:underline"
          >
            Create your first menu item now
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredProducts.map(product => (
            <div 
              key={product.id} 
              className={`bg-card border rounded-3xl overflow-hidden shadow-xs hover:shadow-md transition-all flex flex-col justify-between ${
                !product.isAvailable ? 'border-dashed opacity-75' : 'border-border'
              }`}
            >
              
              {/* Product Preview */}
              <div>
                
                {/* Photo */}
                <div className="h-40 bg-zinc-100 dark:bg-zinc-800 relative overflow-hidden">
                  {product.imageUrl ? (
                    <img 
                      src={product.imageUrl} 
                      alt={product.name} 
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <div className="w-full h-full flex flex-col items-center justify-center text-text-muted gap-2">
                      <ImageIcon className="h-10 w-10 text-text-muted/40" />
                      <span className="text-[10px] uppercase font-black tracking-widest text-text-muted/60">No Photo</span>
                    </div>
                  )}

                  {/* Veg/Non-Veg flag */}
                  <div className="absolute top-3 left-3">
                    <span className={`inline-flex items-center justify-center p-1.5 rounded-lg border ${
                      product.tags.includes('non-veg') 
                        ? 'bg-rose-500/10 border-rose-500/20 text-rose-500' 
                        : 'bg-emerald-500/10 border-emerald-500/20 text-emerald-500'
                    }`}>
                      <span className={`h-2.5 w-2.5 rounded-full ${
                        product.tags.includes('non-veg') ? 'bg-rose-500' : 'bg-emerald-500'
                      }`} />
                    </span>
                  </div>

                  {/* Status Banner if hidden */}
                  {!product.isAvailable && (
                    <div className="absolute inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center">
                      <span className="bg-rose-600 text-white font-black text-[10px] uppercase tracking-widest px-3 py-1 rounded-full">
                        Hidden from Shop
                      </span>
                    </div>
                  )}
                </div>

                {/* Body details */}
                <div className="p-5 space-y-2">
                  <div className="flex justify-between items-start gap-2">
                    <h4 className="font-black text-text-primary text-sm sm:text-base tracking-tight leading-tight">{product.name}</h4>
                    <span className="text-[10px] font-bold text-text-muted px-2 py-0.5 bg-muted rounded-md uppercase shrink-0">
                      {product.unit}
                    </span>
                  </div>
                  
                  <p className="text-[11px] text-text-secondary leading-relaxed line-clamp-2">
                    {product.description || 'No description provided.'}
                  </p>

                  <div className="flex items-center gap-1.5 text-xs text-text-secondary font-bold pt-1.5">
                    <span className="text-[10px] font-black uppercase text-orange-600 bg-orange-500/10 px-2 py-0.5 rounded-md border border-orange-500/20">
                      {product.category?.name || 'Dish'}
                    </span>
                    
                    {product.stock <= 0 && (
                      <span className="text-[10px] font-black uppercase text-rose-600 bg-rose-500/10 px-2 py-0.5 rounded-md border border-rose-500/20">
                        Out of Stock
                      </span>
                    )}
                  </div>
                </div>

              </div>

              {/* Action Footer */}
              <div className="border-t border-border/40 p-4 bg-muted/10 flex items-center justify-between gap-3">
                <div className="flex flex-col">
                  <span className="text-[10px] text-text-muted font-bold line-through">
                    {formatPrice(product.mrp)}
                  </span>
                  <span className="text-sm font-black text-text-primary flex items-center">
                    <IndianRupee className="h-3.5 w-3.5" />
                    {product.price}
                  </span>
                </div>

                <div className="flex items-center gap-2">
                  
                  {/* Toggle Visibility */}
                  <button
                    onClick={() => handleToggleAvailability(product)}
                    title={product.isAvailable ? 'Hide from storefront' : 'Show on storefront'}
                    className="p-2 rounded-xl border border-border bg-card text-text-secondary hover:text-text-primary cursor-pointer hover:bg-muted"
                  >
                    {product.isAvailable ? (
                      <ToggleRight className="h-5 w-5 text-emerald-500" />
                    ) : (
                      <ToggleLeft className="h-5 w-5 text-text-muted" />
                    )}
                  </button>

                  {/* Edit */}
                  <button
                    onClick={() => handleOpenEditForm(product)}
                    title="Edit dish details"
                    className="p-2 rounded-xl border border-border bg-card text-text-secondary hover:text-orange-600 cursor-pointer hover:bg-muted"
                  >
                    <Edit2 className="h-4.5 w-4.5" />
                  </button>

                  {/* Delete */}
                  <button
                    onClick={() => handleDeleteProduct(product)}
                    title="Delete dish"
                    className="p-2 rounded-xl border border-border bg-card text-text-secondary hover:text-rose-600 cursor-pointer hover:bg-muted"
                  >
                    <Trash2 className="h-4.5 w-4.5" />
                  </button>

                </div>
              </div>

            </div>
          ))}
        </div>
      )}

      {/* Editor Modal */}
      {isFormOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs overflow-y-auto">
          <div className="bg-card border border-border rounded-3xl w-full max-w-lg overflow-hidden shadow-2xl animate-scale-in my-8 max-h-[90vh] flex flex-col">
            
            {/* Modal Header */}
            <div className="flex justify-between items-center px-6 py-5 border-b border-border/40 shrink-0">
              <div>
                <h3 className="text-base font-black text-text-primary uppercase tracking-tight">
                  {editingProduct ? 'Edit Menu Item' : 'Add New Menu Item'}
                </h3>
                <p className="text-[11px] text-text-secondary">Fill in the fields below to update your digital storefront.</p>
              </div>
              <button 
                onClick={() => setIsFormOpen(false)}
                className="h-8 w-8 rounded-xl border border-border flex items-center justify-center hover:bg-muted cursor-pointer text-text-muted hover:text-text-primary"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            {/* Modal Form Body */}
            <form onSubmit={handleSubmitForm} className="p-6 space-y-4 overflow-y-auto flex-1">
              
              {/* Item Name */}
              <div className="space-y-1.5">
                <label className="text-xs font-black uppercase tracking-wider text-text-primary">Dish Name *</label>
                <input
                  type="text"
                  value={name}
                  onChange={e => setName(e.target.value)}
                  placeholder="e.g. Masala Dosa, Cold Coffee"
                  className="w-full px-4 py-2.5 bg-muted/40 border border-border rounded-2xl text-xs focus:outline-hidden focus:border-orange-500/50 transition-all font-semibold"
                  required
                />
              </div>

              {/* Price & MRP */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <label className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-1">
                    <IndianRupee className="h-3.5 w-3.5" />
                    Selling Price *
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    value={price}
                    onChange={e => setPrice(e.target.value)}
                    placeholder="e.g. 120"
                    className="w-full px-4 py-2.5 bg-muted/40 border border-border rounded-2xl text-xs focus:outline-hidden focus:border-orange-500/50 transition-all font-semibold"
                    required
                  />
                </div>
                
                <div className="space-y-1.5">
                  <label className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-1">
                    <IndianRupee className="h-3.5 w-3.5" />
                    MRP (Optional)
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    value={mrp}
                    onChange={e => setMrp(e.target.value)}
                    placeholder="e.g. 150"
                    className="w-full px-4 py-2.5 bg-muted/40 border border-border rounded-2xl text-xs focus:outline-hidden focus:border-orange-500/50 transition-all font-semibold"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                {/* Unit */}
                <div className="space-y-1.5">
                  <label className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-1.5">
                    <Sparkles className="h-3.5 w-3.5" />
                    Serving Unit *
                  </label>
                  <input
                    type="text"
                    value={unit}
                    onChange={e => setUnit(e.target.value)}
                    placeholder="e.g. Serving, Plate, Piece"
                    className="w-full px-4 py-2.5 bg-muted/40 border border-border rounded-2xl text-xs focus:outline-hidden focus:border-orange-500/50 transition-all font-semibold"
                    required
                  />
                </div>

                {/* Category selection */}
                <div className="space-y-1.5">
                  <label className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-1.5">
                    <Layers className="h-3.5 w-3.5" />
                    Menu Section *
                  </label>
                  <select
                    value={categoryId}
                    onChange={e => setCategoryId(e.target.value)}
                    className="w-full px-4 py-2.5 bg-muted/40 border border-border rounded-2xl text-xs focus:outline-hidden focus:border-orange-500/50 transition-all font-semibold cursor-pointer"
                    required
                  >
                    <option value="" disabled>Select Menu Section</option>
                    {categories.map(cat => (
                      <option key={cat.id} value={cat.id}>{cat.name}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                {/* Stock */}
                <div className="space-y-1.5">
                  <label className="text-xs font-black uppercase tracking-wider text-text-primary">Stock Quantity</label>
                  <input
                    type="number"
                    value={stock}
                    onChange={e => setStock(e.target.value)}
                    placeholder="e.g. 999"
                    className="w-full px-4 py-2.5 bg-muted/40 border border-border rounded-2xl text-xs focus:outline-hidden focus:border-orange-500/50 transition-all font-semibold"
                  />
                </div>

                {/* Veg / Non-Veg Toggle */}
                <div className="space-y-1.5">
                  <label className="text-xs font-black uppercase tracking-wider text-text-primary">Food Category</label>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => setIsVeg(true)}
                      className={`flex-1 py-2.5 rounded-2xl border text-xs font-black uppercase tracking-wider transition-all cursor-pointer ${
                        isVeg 
                          ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-600' 
                          : 'bg-card border-border text-text-secondary'
                      }`}
                    >
                      Veg 🟢
                    </button>
                    <button
                      type="button"
                      onClick={() => setIsVeg(false)}
                      className={`flex-1 py-2.5 rounded-2xl border text-xs font-black uppercase tracking-wider transition-all cursor-pointer ${
                        !isVeg 
                          ? 'bg-rose-500/10 border-rose-500/30 text-rose-600' 
                          : 'bg-card border-border text-text-secondary'
                      }`}
                    >
                      Non-Veg 🔴
                    </button>
                  </div>
                </div>
              </div>

              {/* Image Upload / URL */}
              <div className="space-y-1.5">
                <label className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center justify-between">
                  <span className="flex items-center gap-1.5">
                    <ImageIcon className="h-4 w-4 text-text-muted" />
                    Dish Photo Image
                  </span>
                  {uploadingImage && <span className="text-[10px] text-orange-600 font-bold animate-pulse">Uploading photo...</span>}
                </label>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => {
                    const file = e.target.files?.[0]
                    if (file) handleDishImageUpload(file)
                  }}
                />
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => fileInputRef.current?.click()}
                    disabled={uploadingImage}
                    className="px-3.5 py-2 bg-orange-500/10 hover:bg-orange-500/20 text-orange-600 border border-orange-500/30 text-xs font-black rounded-xl transition-all flex items-center gap-1.5 shrink-0 cursor-pointer shadow-xs"
                  >
                    <Upload className="h-3.5 w-3.5" />
                    {uploadingImage ? 'Uploading...' : 'Upload Photo'}
                  </button>
                  <input
                    type="text"
                    value={imageUrl}
                    onChange={e => setImageUrl(e.target.value)}
                    placeholder="Or paste photo URL..."
                    className="w-full px-4 py-2 bg-muted/40 border border-border rounded-xl text-xs focus:outline-hidden focus:border-orange-500/50 transition-all font-semibold"
                  />
                </div>
                {imageUrl && (
                  <div className="relative h-20 w-20 rounded-xl overflow-hidden border border-border mt-2 bg-muted">
                    <img src={imageUrl} alt="Dish Preview" className="w-full h-full object-cover" />
                  </div>
                )}
              </div>

              {/* Description */}
              <div className="space-y-1.5">
                <label className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-1.5">
                  <FileText className="h-4 w-4 text-text-muted" />
                  Dish Description
                </label>
                <textarea
                  rows={2}
                  value={description}
                  onChange={e => setDescription(e.target.value)}
                  placeholder="e.g. Served hot with sambhar and coconut chutney."
                  className="w-full px-4 py-2.5 bg-muted/40 border border-border rounded-2xl text-xs focus:outline-hidden focus:border-orange-500/50 transition-all font-semibold leading-relaxed"
                />
              </div>

              {/* Footer buttons */}
              <div className="flex gap-3 justify-end pt-4 border-t border-border/40 shrink-0">
                <button
                  type="button"
                  onClick={() => setIsFormOpen(false)}
                  className="px-5 py-2.5 border border-border hover:bg-muted text-text-secondary font-black text-xs uppercase tracking-wider rounded-2xl transition-all cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="inline-flex items-center justify-center gap-2 px-5 py-2.5 bg-orange-600 hover:bg-orange-700 disabled:bg-orange-600/60 text-white font-black text-xs uppercase tracking-wider rounded-2xl transition-all cursor-pointer shadow-xs border border-orange-700/10"
                >
                  {submitting ? (
                    <>
                      <Loader2 className="h-3.5 w-3.5 animate-spin" />
                      Saving Item...
                    </>
                  ) : (
                    'Save Dish'
                  )}
                </button>
              </div>

            </form>

          </div>
        </div>
      )}

    </div>
  )
}
