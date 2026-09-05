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
  Upload,
  Eye,
  EyeOff
} from 'lucide-react'
import { toast } from 'sonner'
import { PRESET_KITCHEN_PHOTOS } from '@/lib/preset-photos'
import { formatPrice, cn } from '@/lib/utils'
import { DEFAULT_CAFE_MENU_SECTIONS, DEFAULT_RESTAURANT_MENU_SECTIONS } from '@/lib/constants'

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
  variants?: any[] | null
  availableStartTime?: string | null
  availableEndTime?: string | null
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

interface RestaurantCatalogManagerProps {
  initialRestaurantId?: string
}

export function RestaurantCatalogManager({ initialRestaurantId }: RestaurantCatalogManagerProps = {}) {
  const { data: session } = useSession()
  const [products, setProducts] = useState<Product[]>([])
  const [categories, setCategories] = useState<Category[]>([])
  const [menuSections, setMenuSections] = useState<any[]>([])
  const [selectedSectionTag, setSelectedSectionTag] = useState('')
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
  const [availableStartTime, setAvailableStartTime] = useState('')
  const [availableEndTime, setAvailableEndTime] = useState('')
  const [uploadingImage, setUploadingImage] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  // Variant States
  const [hasVariants, setHasVariants] = useState(false)
  const [variants, setVariants] = useState<{ name: string; price: string; mrp: string; stock: string }[]>([])
  const [newVarName, setNewVarName] = useState('')
  const [newVarPrice, setNewVarPrice] = useState('')
  const [newVarMrp, setNewVarMrp] = useState('')
  const [newVarStock, setNewVarStock] = useState('999')

  // Media Library states
  const [showMediaLibrary, setShowMediaLibrary] = useState(false)
  const [mediaSearchQuery, setMediaSearchQuery] = useState('')
  const [globalProducts, setGlobalProducts] = useState<any[]>([])
  const [globalCategories, setGlobalCategories] = useState<any[]>([])

  // Fetch all store products & categories so local media gallery shows ALL photos in system
  useEffect(() => {
    Promise.all([
      fetch('/api/products?limit=2000&includeUnavailable=true&admin=true').then(r => r.ok ? r.json() : null),
      fetch('/api/restaurant-dashboard/products?restaurantId=ALL').then(r => r.ok ? r.json() : null),
      fetch('/api/categories').then(r => r.ok ? r.json() : null)
    ]).then(([prodData, restData, catData]) => {
      const allFetched = [
        ...(prodData?.products || []),
        ...(restData?.products || [])
      ]
      if (allFetched.length > 0) setGlobalProducts(allFetched)
      if (catData) {
        const catList = catData.categories || (Array.isArray(catData) ? catData : [])
        setGlobalCategories(catList)
      }
    }).catch(console.error)
  }, [])

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

    // 3. Add existing product photos from outlet catalog
    products.forEach((p) => {
      if (p.imageUrl && typeof p.imageUrl === 'string' && p.imageUrl.trim().length > 0) {
        const url = p.imageUrl.trim()
        if (!setOfImages.has(url)) {
          setOfImages.set(url, { url, name: p.name || 'Dish Photo', tags: p.tags || [] })
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

  const isAdmin = session?.user?.role === 'ADMIN'
  const assignedRestaurantId = (session?.user as any)?.assignedRestaurantId
  const [outlets, setOutlets] = useState<any[]>([])
  const [selectedOutletId, setSelectedOutletId] = useState<string>(initialRestaurantId || assignedRestaurantId || '')

  useEffect(() => {
    if (initialRestaurantId) {
      setSelectedOutletId(initialRestaurantId)
    } else if (assignedRestaurantId) {
      setSelectedOutletId(assignedRestaurantId)
    }
  }, [initialRestaurantId, assignedRestaurantId])

  useEffect(() => {
    fetch('/api/restaurants')
      .then(res => res.ok ? res.json() : null)
      .then(data => {
        const list = Array.isArray(data) ? data : (data?.restaurants || [])
        if (list.length > 0) {
          setOutlets(list)
          if (!selectedOutletId && !assignedRestaurantId && !initialRestaurantId) {
            const defaultId = list[0]?.id || ''
            setSelectedOutletId(defaultId)
          }
        }
      })
      .catch(console.error)
  }, [assignedRestaurantId, initialRestaurantId])

  const effectiveRestId = (!isAdmin && assignedRestaurantId) 
    ? assignedRestaurantId 
    : (selectedOutletId || initialRestaurantId || assignedRestaurantId || 'REST-101')

  const fetchCatalogAndCategories = async () => {
    try {
      setLoading(true)
      const url = `/api/restaurant-dashboard/products?restaurantId=${effectiveRestId}`

      const [prodRes, catRes, sectionsRes] = await Promise.all([
        fetch(url, { cache: 'no-store' }),
        fetch('/api/categories', { cache: 'no-store' }),
        effectiveRestId 
          ? fetch(`/api/restaurants/${effectiveRestId}/sections`, { cache: 'no-store' }).then(r => r.ok ? r.json() : null).catch(() => null)
          : Promise.resolve(null)
      ])

      if (!prodRes.ok) throw new Error('Failed to load products')
      const prodData = await prodRes.json()
      setProducts(prodData.products || [])

      if (sectionsRes && Array.isArray(sectionsRes) && sectionsRes.length > 0) {
        setMenuSections(sectionsRes.filter((s: any) => !s.disabled))
      } else if (prodData.restaurant) {
        const rawSecs = prodData.restaurant.menuSections
          ? (typeof prodData.restaurant.menuSections === 'string' ? JSON.parse(prodData.restaurant.menuSections) : prodData.restaurant.menuSections)
          : null
        const secs = rawSecs && Array.isArray(rawSecs) ? rawSecs : []
        setMenuSections(secs.filter((s: any) => !s.disabled))
      }

      if (catRes.ok) {
        const catData = await catRes.json()
        setCategories(catData.categories || (Array.isArray(catData) ? catData : []))
      }
    } catch (err) {
      console.error(err)
      toast.error('Failed to load menu items')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (effectiveRestId) {
      fetchCatalogAndCategories()
    }
  }, [effectiveRestId])

  // Open Form for Adding New Product
  const handleOpenAddForm = () => {
    setEditingProduct(null)
    setName('')
    setPrice('')
    setMrp('')
    setUnit('Serving')
    const defaultFoodCat = categories.find(c => c.slug === 'restaurant-food' || c.slug === 'restaurant' || c.name.toLowerCase().includes('fast food') || c.name.toLowerCase().includes('kitchen'))
    setCategoryId(defaultFoodCat?.id || categories[0]?.id || '')
    setSelectedSectionTag(menuSections[0]?.tag || '')
    setDescription('')
    setImageUrl('')
    setStock('999')
    setIsVeg(true)
    setAvailableStartTime('')
    setAvailableEndTime('')
    setHasVariants(false)
    setVariants([])
    setNewVarName('')
    setNewVarPrice('')
    setNewVarMrp('')
    setNewVarStock('999')
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
    const matchSec = menuSections.find(s => 
      s.id === (product as any).sectionId ||
      s.id === (product as any).menuSectionId ||
      product.tags?.includes(s.id) ||
      product.tags?.includes(s.tag) || 
      (s.matchTags && product.tags?.some((t: string) => s.matchTags.includes(t)))
    )
    setSelectedSectionTag(matchSec?.id || matchSec?.tag || menuSections[0]?.id || '')
    setDescription(product.description || '')
    setImageUrl(product.imageUrl || '')
    setStock(product.stock.toString())
    const isNonVeg = product.tags.some(t => t.toLowerCase() === 'non-veg' || t.toLowerCase() === 'nonveg')
    setIsVeg(!isNonVeg)
    setAvailableStartTime(product.availableStartTime || '')
    setAvailableEndTime(product.availableEndTime || '')

    const hasVars = Array.isArray(product.variants) && product.variants.length > 0
    setHasVariants(hasVars)
    setVariants(
      hasVars
        ? (product.variants as any[]).map(v => ({
            name: v.name || '',
            price: String(v.price ?? ''),
            mrp: String(v.mrp ?? v.price ?? ''),
            stock: String(v.stock ?? '999')
          }))
        : []
    )
    setNewVarName('')
    setNewVarPrice('')
    setNewVarMrp('')
    setNewVarStock('999')
    setIsFormOpen(true)
  }

  // Variant Helpers
  const handleAddVariant = () => {
    if (!newVarName.trim() || !newVarPrice) {
      toast.error('Please enter variant name and price')
      return
    }
    const priceVal = parseFloat(newVarPrice)
    if (isNaN(priceVal) || priceVal < 0) {
      toast.error('Invalid variant price')
      return
    }
    const mrpVal = newVarMrp ? parseFloat(newVarMrp) : priceVal

    setVariants(prev => [
      ...prev,
      {
        name: newVarName.trim(),
        price: String(priceVal),
        mrp: String(mrpVal),
        stock: newVarStock || '999'
      }
    ])

    setNewVarName('')
    setNewVarPrice('')
    setNewVarMrp('')
    setNewVarStock('999')
    toast.success(`Added variant "${newVarName.trim()}"`)
  }

  const handleRemoveVariant = (index: number) => {
    setVariants(prev => prev.filter((_, i) => i !== index))
  }

  const handleAddPresetVariants = (presetType: 'portion' | 'size' | 'weight') => {
    const baseP = parseFloat(price) || 100
    const baseMrp = parseFloat(mrp) || baseP
    if (presetType === 'portion') {
      setVariants([
        { name: 'Half', price: String(Math.round(baseP * 0.6)), mrp: String(Math.round(baseMrp * 0.6)), stock: '999' },
        { name: 'Full', price: String(baseP), mrp: String(baseMrp), stock: '999' }
      ])
      setHasVariants(true)
    } else if (presetType === 'size') {
      setVariants([
        { name: 'Small', price: String(Math.round(baseP * 0.75)), mrp: String(Math.round(baseMrp * 0.75)), stock: '999' },
        { name: 'Medium', price: String(baseP), mrp: String(baseMrp), stock: '999' },
        { name: 'Large', price: String(Math.round(baseP * 1.4)), mrp: String(Math.round(baseMrp * 1.4)), stock: '999' }
      ])
      setHasVariants(true)
    } else if (presetType === 'weight') {
      setVariants([
        { name: '250g', price: String(Math.round(baseP * 0.3)), mrp: String(Math.round(baseMrp * 0.3)), stock: '999' },
        { name: '500g', price: String(Math.round(baseP * 0.55)), mrp: String(Math.round(baseMrp * 0.55)), stock: '999' },
        { name: '1 kg', price: String(baseP), mrp: String(baseMrp), stock: '999' }
      ])
      setHasVariants(true)
    }
  }

  // Handle Form Submit (Add or Edit)
  const handleSubmitForm = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!name.trim()) {
      toast.error('Please enter dish name')
      return
    }

    if (hasVariants) {
      if (variants.length === 0) {
        toast.error('Please add at least one variant option or uncheck variants')
        return
      }
    } else {
      if (!price) {
        toast.error('Please fill in selling price')
        return
      }
    }

    setSubmitting(true)

    const formattedVariants = hasVariants
      ? variants.map(v => ({
          name: v.name.trim(),
          price: parseFloat(v.price) || 0,
          mrp: parseFloat(v.mrp) || parseFloat(v.price) || 0,
          stock: parseInt(v.stock) || 999
        }))
      : null

    const priceVal = hasVariants && formattedVariants && formattedVariants.length > 0
      ? formattedVariants[0].price
      : parseFloat(price || '0')

    const mrpVal = hasVariants && formattedVariants && formattedVariants.length > 0
      ? formattedVariants[0].mrp
      : (mrp ? parseFloat(mrp) : priceVal)

    const stockVal = hasVariants && formattedVariants && formattedVariants.length > 0
      ? formattedVariants.reduce((sum, v) => sum + (v.stock || 0), 0)
      : (parseInt(stock) || 999)

    const selectedSec = menuSections.find(s => s.id === selectedSectionTag || s.tag === selectedSectionTag)
    const sectionId = selectedSec?.id || selectedSectionTag
    const searchKeywords = selectedSec?.tags || selectedSec?.matchTags || []

    const tags = [
      sectionId,
      ...(selectedSec?.tag ? [selectedSec.tag] : []),
      ...searchKeywords,
      isVeg ? 'veg' : 'non-veg',
      'restaurant'
    ]

    const payload = {
      name: name.trim(),
      price: priceVal,
      mrp: mrpVal,
      unit: unit.trim() || '1 Serving',
      categoryId,
      sectionId,
      menuSectionId: sectionId,
      description: description.trim() || null,
      imageUrl: imageUrl.trim() || null,
      stock: stockVal,
      availableStartTime: availableStartTime.trim() || null,
      availableEndTime: availableEndTime.trim() || null,
      tags: [...new Set(tags.filter(Boolean))],
      variants: formattedVariants
    }

    const reqHeaders = {
      'Content-Type': 'application/json',
      ...(session?.user?.id ? { 'x-user-id': session.user.id } : {}),
      ...(session?.user?.role ? { 'x-user-role': session.user.role } : {}),
      ...(session?.user?.email ? { 'x-user-email': session.user.email } : {}),
      ...((session?.user as any)?.phone ? { 'x-user-phone': (session?.user as any).phone } : {}),
      ...((session?.user as any)?.assignedRestaurantId ? { 'x-restaurant-id': (session?.user as any).assignedRestaurantId } : {})
    }

    try {
      let res
      if (editingProduct) {
        // Edit Product
        res = await fetch(`/api/restaurant-dashboard/products/${editingProduct.id}`, {
          method: 'PATCH',
          headers: reqHeaders,
          body: JSON.stringify(payload)
        })
      } else {
        // Add Product
        res = await fetch('/api/restaurant-dashboard/products', {
          method: 'POST',
          headers: reqHeaders,
          body: JSON.stringify({
            ...payload,
            restaurantId: effectiveRestId || assignedRestaurantId
          })
        })
      }

      if (!res.ok) {
        const errorData = await res.json().catch(() => ({}))
        throw new Error(errorData.error || errorData.message || 'Operation failed')
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
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          ...(session?.user?.id ? { 'x-user-id': session.user.id } : {}),
          ...(session?.user?.role ? { 'x-user-role': session.user.role } : {}),
          ...(session?.user?.email ? { 'x-user-email': session.user.email } : {}),
          ...((session?.user as any)?.phone ? { 'x-user-phone': (session?.user as any).phone } : {}),
          ...((session?.user as any)?.assignedRestaurantId ? { 'x-restaurant-id': (session?.user as any).assignedRestaurantId } : {})
        }
      })

      if (res.ok) {
        toast.success(`"${product.name}" removed successfully!`)
        fetchCatalogAndCategories()
      } else {
        const errData = await res.json().catch(() => ({}))
        toast.error(errData.error || 'Failed to remove product')
      }
    } catch (err: any) {
      console.error(err)
      toast.error(err?.message || 'Failed to remove product')
    }
  }

  // Toggle Kitchen Stock (Ready vs Sold Out)
  const handleToggleStock = async (product: Product) => {
    const isCurrentlyOutOfStock = product.stock <= 0
    const newStock = isCurrentlyOutOfStock ? 999 : 0
    try {
      const res = await fetch(`/api/restaurant-dashboard/products/${product.id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          ...(session?.user?.id ? { 'x-user-id': session.user.id } : {}),
          ...(session?.user?.role ? { 'x-user-role': session.user.role } : {}),
          ...(session?.user?.email ? { 'x-user-email': session.user.email } : {}),
          ...((session?.user as any)?.phone ? { 'x-user-phone': (session?.user as any).phone } : {}),
          ...((session?.user as any)?.assignedRestaurantId ? { 'x-restaurant-id': (session?.user as any).assignedRestaurantId } : {})
        },
        body: JSON.stringify({ stock: newStock })
      })

      if (res.ok) {
        setProducts(prev => prev.map(p => p.id === product.id ? { ...p, stock: newStock } : p))
        toast.success(`"${product.name}" is now ${newStock > 0 ? '🟢 Kitchen Ready (In Stock)' : '🔴 Sold Out (Out of Stock)'}!`)
      } else {
        const errorData = await res.json().catch(() => ({}))
        toast.error(errorData.error || errorData.message || 'Failed to update kitchen stock')
      }
    } catch (err: any) {
      console.error(err)
      toast.error(err?.message || 'Failed to update kitchen stock')
    }
  }

  // Toggle Storefront Visibility (Show vs Hide)
  const handleToggleAvailability = async (product: Product) => {
    const newStatus = !product.isAvailable
    try {
      const res = await fetch(`/api/restaurant-dashboard/products/${product.id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          ...(session?.user?.id ? { 'x-user-id': session.user.id } : {}),
          ...(session?.user?.role ? { 'x-user-role': session.user.role } : {}),
          ...(session?.user?.email ? { 'x-user-email': session.user.email } : {}),
          ...((session?.user as any)?.phone ? { 'x-user-phone': (session?.user as any).phone } : {}),
          ...((session?.user as any)?.assignedRestaurantId ? { 'x-restaurant-id': (session?.user as any).assignedRestaurantId } : {})
        },
        body: JSON.stringify({ isAvailable: newStatus })
      })

      if (res.ok) {
        setProducts(prev => prev.map(p => p.id === product.id ? { ...p, isAvailable: newStatus } : p))
        toast.success(`"${product.name}" is now ${newStatus ? '👁️ Visible on storefront' : '🙈 Hidden from storefront'}!`)
      } else {
        const errorData = await res.json().catch(() => ({}))
        toast.error(errorData.error || errorData.message || 'Failed to toggle visibility')
      }
    } catch (err: any) {
      console.error(err)
      toast.error(err?.message || 'Failed to toggle visibility')
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
    <div className="space-y-4 sm:space-y-6 animate-fade-in">
      
      {/* Header controls */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 border-b border-border/40 pb-3.5 sm:pb-5">
        <div className="min-w-0">
          <h3 className="text-sm sm:text-base font-black text-text-primary uppercase tracking-tight truncate">Menu Catalog</h3>
          <p className="hidden sm:block text-xs text-text-secondary mt-0.5">Add new dishes, edit pricing, manage availability, and set photos.</p>
        </div>

        <div className="flex items-center gap-2.5 w-full sm:w-auto">
          {outlets.length > 0 && isAdmin && (
            <select
              value={selectedOutletId}
              onChange={(e) => setSelectedOutletId(e.target.value)}
              className="px-3 py-2 text-xs font-black bg-card border border-border rounded-xl text-text-primary focus:outline-none focus:ring-2 focus:ring-orange-500/30 cursor-pointer shadow-xs"
            >
              {outlets.map((o) => (
                <option key={o.id} value={o.id}>
                  🍽️ {o.name}
                </option>
              ))}
            </select>
          )}

          <button
            onClick={handleOpenAddForm}
            className="inline-flex items-center justify-center gap-1.5 sm:gap-2 px-3.5 sm:px-5 py-2 sm:py-2.5 bg-orange-600 hover:bg-orange-700 text-white font-black text-[11px] sm:text-xs uppercase tracking-wider rounded-xl sm:rounded-2xl transition-all cursor-pointer shadow-xs active:scale-95 shrink-0"
          >
            <Plus className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
            <span>Add Dish</span>
          </button>
        </div>
      </div>

      {/* Filters and search */}
      <div className="flex flex-col sm:flex-row gap-2.5 sm:gap-4 items-stretch sm:items-center justify-between">
        
        {/* Search */}
        <div className="relative w-full sm:max-w-xs">
          <Search className="absolute left-3 top-2.5 sm:top-3 h-3.5 w-3.5 sm:h-4 sm:w-4 text-text-muted" />
          <input
            type="text"
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            placeholder="Search dish or category..."
            className="w-full pl-8 sm:pl-10 pr-3 sm:pr-4 py-2 sm:py-2.5 bg-muted/40 border border-border/70 rounded-xl sm:rounded-2xl text-xs focus:outline-none focus:border-orange-500/50 transition-all font-semibold"
          />
        </div>

        {/* Filter buttons */}
        <div className="flex gap-1.5 sm:gap-2 overflow-x-auto pb-1 sm:pb-0 scrollbar-none shrink-0">
          <button
            onClick={() => setFilter('all')}
            className={`px-3 py-1.5 sm:px-4 sm:py-2 rounded-xl text-[11px] sm:text-xs font-black uppercase tracking-wider border transition-all cursor-pointer shrink-0 active:scale-95 ${
              filter === 'all'
                ? 'bg-orange-500/10 border-orange-500/30 text-orange-600'
                : 'bg-card border-border/70 text-text-secondary hover:bg-muted'
            }`}
          >
            All Items
          </button>
          <button
            onClick={() => setFilter('veg')}
            className={`px-3 py-1.5 sm:px-4 sm:py-2 rounded-xl text-[11px] sm:text-xs font-black uppercase tracking-wider border transition-all cursor-pointer shrink-0 active:scale-95 ${
              filter === 'veg'
                ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-600'
                : 'bg-card border-border/70 text-text-secondary hover:bg-muted'
            }`}
          >
            Veg 🟢
          </button>
          <button
            onClick={() => setFilter('nonveg')}
            className={`px-3 py-1.5 sm:px-4 sm:py-2 rounded-xl text-[11px] sm:text-xs font-black uppercase tracking-wider border transition-all cursor-pointer shrink-0 active:scale-95 ${
              filter === 'nonveg'
                ? 'bg-rose-500/10 border-rose-500/30 text-rose-600'
                : 'bg-card border-border/70 text-text-secondary hover:bg-muted'
            }`}
          >
            Non-Veg 🔴
          </button>
          <button
            onClick={() => setFilter('outofstock')}
            className={`px-3 py-1.5 sm:px-4 sm:py-2 rounded-xl text-[11px] sm:text-xs font-black uppercase tracking-wider border transition-all cursor-pointer shrink-0 active:scale-95 ${
              filter === 'outofstock'
                ? 'bg-zinc-500/10 border-zinc-500/30 text-zinc-600 dark:text-zinc-400'
                : 'bg-card border-border/70 text-text-secondary hover:bg-muted'
            }`}
          >
            Out of Stock
          </button>
        </div>

      </div>

      {/* Grid listing */}
      {filteredProducts.length === 0 ? (
        <div className="bg-card border border-border/70 rounded-2xl sm:rounded-3xl p-8 sm:p-12 text-center max-w-md mx-auto space-y-3">
          <p className="text-xs sm:text-sm font-bold text-text-secondary">No dishes found in your menu catalog.</p>
          <button
            onClick={handleOpenAddForm}
            className="text-[11px] sm:text-xs font-black text-orange-600 uppercase tracking-wider hover:underline cursor-pointer"
          >
            Create your first menu item now
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-3 gap-3 sm:gap-5">
          {filteredProducts.map(product => (
            <div 
              key={product.id} 
              className={`bg-card border rounded-2xl sm:rounded-3xl overflow-hidden shadow-2xs hover:shadow-md transition-all flex flex-col justify-between ${
                !product.isAvailable ? 'border-dashed opacity-75 border-border/80' : 'border-border/70'
              }`}
            >
              
              {/* Product Preview */}
              <div>
                
                {/* Photo */}
                <div className="h-32 sm:h-44 bg-zinc-100 dark:bg-zinc-800 relative overflow-hidden">
                  {product.imageUrl ? (
                    <img 
                      src={product.imageUrl} 
                      alt={product.name} 
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <div className="w-full h-full flex flex-col items-center justify-center text-text-muted gap-1.5 p-2">
                      <ImageIcon className="h-7 w-7 sm:h-10 sm:w-10 text-text-muted/40" />
                      <span className="text-[9px] sm:text-[10px] uppercase font-black tracking-widest text-text-muted/60">No Photo</span>
                    </div>
                  )}

                  {/* Veg/Non-Veg flag */}
                  <div className="absolute top-2 left-2">
                    <span className={`inline-flex items-center justify-center p-1 sm:p-1.5 rounded-lg border backdrop-blur-xs ${
                      product.tags.includes('non-veg') 
                        ? 'bg-rose-500/20 border-rose-500/30 text-rose-500' 
                        : 'bg-emerald-500/20 border-emerald-500/30 text-emerald-500'
                    }`}>
                      <span className={`h-2 w-2 sm:h-2.5 sm:w-2.5 rounded-full ${
                        product.tags.includes('non-veg') ? 'bg-rose-500' : 'bg-emerald-500'
                      }`} />
                    </span>
                  </div>

                  {/* Status Banner if hidden or sold out */}
                  {!product.isAvailable ? (
                    <div className="absolute inset-0 bg-black/75 backdrop-blur-xs flex items-center justify-center p-2 text-center">
                      <span className="bg-zinc-900 text-zinc-200 border border-zinc-700 font-black text-[9px] sm:text-[10px] uppercase tracking-wider px-2.5 py-0.5 sm:py-1 rounded-full shadow-lg">
                        🙈 Hidden from Shop
                      </span>
                    </div>
                  ) : product.stock <= 0 ? (
                    <div className="absolute inset-0 bg-black/55 backdrop-blur-xs flex items-center justify-center p-2 text-center">
                      <span className="bg-rose-600 text-white font-black text-[9px] sm:text-[10px] uppercase tracking-wider px-2.5 py-0.5 sm:py-1 rounded-full shadow-lg">
                        🔴 Sold Out
                      </span>
                    </div>
                  ) : null}
                </div>

                {/* Body details */}
                <div className="p-2.5 sm:p-4 space-y-1 sm:space-y-2">
                  <div className="flex justify-between items-start gap-1">
                    <h4 className="font-black text-text-primary text-xs sm:text-base tracking-tight leading-tight line-clamp-1" title={product.name}>{product.name}</h4>
                    <span className="text-[8px] sm:text-[10px] font-bold text-text-muted px-1.5 py-0.5 bg-muted rounded uppercase shrink-0">
                      {product.unit}
                    </span>
                  </div>
                  
                  <p className="hidden sm:block text-[11px] text-text-secondary leading-relaxed line-clamp-2">
                    {product.description || 'No description provided.'}
                  </p>

                  <div className="flex items-center gap-1 text-[9px] sm:text-xs text-text-secondary font-bold pt-0.5 flex-wrap">
                    {(() => {
                      const matchSec = menuSections.find(s => 
                        product.tags?.includes(s.tag) || (s.matchTags && product.tags?.some((t: string) => s.matchTags.includes(t)))
                      )
                      const label = matchSec ? matchSec.title : (product.category?.name && !['fruits & vegetables', 'fruits-vegetables'].includes(product.category.name.toLowerCase()) ? product.category.name : 'Restaurant Special')
                      return (
                        <span className="text-[8px] sm:text-[10px] font-black uppercase text-orange-600 bg-orange-500/10 px-1.5 py-0.5 rounded-md border border-orange-500/20 truncate">
                          {label}
                        </span>
                      )
                    })()}

                    {product.variants && Array.isArray(product.variants) && product.variants.length > 0 && (
                      <span className="text-[8px] sm:text-[10px] font-black uppercase text-blue-600 dark:text-blue-400 bg-blue-500/10 px-1.5 py-0.5 rounded-md border border-blue-500/20 truncate">
                        🏷️ {product.variants.length} Variants
                      </span>
                    )}
                    
                    {product.stock <= 0 ? (
                      <span className="text-[8px] sm:text-[10px] font-black uppercase text-rose-600 bg-rose-500/10 px-1.5 py-0.5 rounded-md border border-rose-500/20 shrink-0">
                        Sold Out
                      </span>
                    ) : (
                      <span className="text-[8px] sm:text-[10px] font-black uppercase text-emerald-600 bg-emerald-500/10 px-1.5 py-0.5 rounded-md border border-emerald-500/20 shrink-0">
                        In Stock
                      </span>
                    )}
                  </div>
                </div>

              </div>

              {/* Action Footer */}
              <div className="border-t border-border/40 p-2 sm:p-3.5 bg-muted/10 flex items-center justify-between gap-1.5">
                <div className="flex flex-col min-w-0">
                  {product.mrp && product.mrp > product.price && (
                    <span className="text-[9px] text-text-muted font-bold line-through leading-none mb-0.5">
                      {formatPrice(product.mrp)}
                    </span>
                  )}
                  <span className="text-xs sm:text-sm font-black text-text-primary flex items-center leading-none">
                    <IndianRupee className="h-3 w-3 sm:h-3.5 sm:w-3.5 shrink-0" />
                    {product.price}
                    {product.variants && Array.isArray(product.variants) && product.variants.length > 0 && (
                      <span className="text-[9px] text-text-muted font-bold ml-1 uppercase">onwards</span>
                    )}
                  </span>
                </div>

                <div className="flex items-center gap-1 sm:gap-1.5 shrink-0">
                  {/* 1. Kitchen Stock Toggle (Ready vs Sold Out) */}
                  <button
                    onClick={() => handleToggleStock(product)}
                    title={product.stock > 0 ? 'Kitchen Ready (Click to mark Sold Out)' : 'Sold Out (Click to mark Kitchen Ready)'}
                    className={cn(
                      "px-2 h-7 sm:h-9 rounded-lg sm:rounded-xl border flex items-center gap-1 font-extrabold text-[10px] sm:text-xs cursor-pointer transition-all active:scale-95",
                      product.stock > 0
                        ? "bg-emerald-500/10 border-emerald-500/30 text-emerald-600 hover:bg-emerald-500/20"
                        : "bg-rose-500/10 border-rose-500/30 text-rose-600 hover:bg-rose-500/20"
                    )}
                  >
                    <span className={cn("h-2 w-2 rounded-full", product.stock > 0 ? "bg-emerald-500 animate-pulse" : "bg-rose-500")} />
                    <span className="hidden sm:inline">{product.stock > 0 ? 'Ready' : 'Sold Out'}</span>
                  </button>

                  {/* 2. Storefront Visibility Toggle (Show vs Hide) */}
                  <button
                    onClick={() => handleToggleAvailability(product)}
                    title={product.isAvailable ? 'Visible on storefront (Click to Hide)' : 'Hidden from storefront (Click to Show)'}
                    className={cn(
                      "h-7 w-7 sm:h-9 sm:w-9 rounded-lg sm:rounded-xl border flex items-center justify-center cursor-pointer transition-all active:scale-95",
                      product.isAvailable
                        ? "bg-card border-border/70 text-emerald-500 hover:bg-muted"
                        : "bg-muted border-border text-text-muted hover:bg-muted/80"
                    )}
                  >
                    {product.isAvailable ? (
                      <Eye className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
                    ) : (
                      <EyeOff className="h-3.5 w-3.5 sm:h-4 sm:w-4 text-text-muted" />
                    )}
                  </button>

                  {/* 3. Edit */}
                  <button
                    onClick={() => handleOpenEditForm(product)}
                    title="Edit dish details"
                    className="h-7 w-7 sm:h-9 sm:w-9 rounded-lg sm:rounded-xl border border-border/70 bg-card text-text-secondary hover:text-orange-600 flex items-center justify-center hover:bg-muted cursor-pointer transition-all active:scale-95"
                  >
                    <Edit2 className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
                  </button>

                  {/* 4. Delete */}
                  <button
                    onClick={() => handleDeleteProduct(product)}
                    title="Delete dish"
                    className="h-7 w-7 sm:h-9 sm:w-9 rounded-lg sm:rounded-xl border border-border/70 bg-card text-text-secondary hover:text-rose-600 flex items-center justify-center hover:bg-muted cursor-pointer transition-all active:scale-95"
                  >
                    <Trash2 className="h-3.5 w-3.5 sm:h-4 sm:w-4" />
                  </button>
                </div>
              </div>

            </div>
          ))}
        </div>
      )}

      {/* Editor Modal */}
      {isFormOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/60 backdrop-blur-xs overflow-y-auto">
          <div className="bg-card border border-border/80 rounded-2xl sm:rounded-3xl w-full max-w-lg overflow-hidden shadow-2xl animate-scale-in my-auto max-h-[92vh] flex flex-col">
            
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
                    Base Selling Price {hasVariants ? '(Auto)' : '*'}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    value={price}
                    onChange={e => setPrice(e.target.value)}
                    placeholder="e.g. 120"
                    disabled={hasVariants && variants.length > 0}
                    className={`w-full px-4 py-2.5 bg-muted/40 border border-border rounded-2xl text-xs focus:outline-hidden focus:border-orange-500/50 transition-all font-semibold ${
                      hasVariants && variants.length > 0 ? 'opacity-70 cursor-not-allowed bg-muted/70' : ''
                    }`}
                    required={!hasVariants}
                  />
                </div>
                
                <div className="space-y-1.5">
                  <label className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-1">
                    <IndianRupee className="h-3.5 w-3.5" />
                    Base MRP (Optional)
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    value={mrp}
                    onChange={e => setMrp(e.target.value)}
                    placeholder="e.g. 150"
                    disabled={hasVariants && variants.length > 0}
                    className={`w-full px-4 py-2.5 bg-muted/40 border border-border rounded-2xl text-xs focus:outline-hidden focus:border-orange-500/50 transition-all font-semibold ${
                      hasVariants && variants.length > 0 ? 'opacity-70 cursor-not-allowed bg-muted/70' : ''
                    }`}
                  />
                </div>
              </div>

              {/* Variants Section */}
              <div className="space-y-3 bg-blue-500/5 dark:bg-blue-500/10 p-3.5 rounded-2xl border border-blue-500/20">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-black uppercase tracking-wider text-blue-600 dark:text-blue-400 flex items-center gap-2 cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={hasVariants}
                      onChange={(e) => {
                        setHasVariants(e.target.checked)
                        if (!e.target.checked) setVariants([])
                      }}
                      className="rounded border-border text-orange-600 focus:ring-orange-500 h-4 w-4 cursor-pointer"
                    />
                    <span>Dish Has Variants (Half/Full, Sizes, Weights)</span>
                  </label>
                  <span className="text-[10px] font-extrabold text-text-secondary">
                    {hasVariants ? `${variants.length} Added` : 'Disabled'}
                  </span>
                </div>

                {hasVariants && (
                  <div className="space-y-3 pt-2.5 border-t border-blue-500/15">
                    {/* Quick Presets */}
                    <div className="flex flex-wrap items-center gap-1.5">
                      <span className="text-[10px] font-bold text-text-secondary">Quick Presets:</span>
                      <button
                        type="button"
                        onClick={() => handleAddPresetVariants('portion')}
                        className="px-2 py-1 bg-card hover:bg-muted border border-border text-[10px] font-bold rounded-lg transition-all cursor-pointer"
                      >
                        + Half / Full
                      </button>
                      <button
                        type="button"
                        onClick={() => handleAddPresetVariants('size')}
                        className="px-2 py-1 bg-card hover:bg-muted border border-border text-[10px] font-bold rounded-lg transition-all cursor-pointer"
                      >
                        + Small / Med / Large
                      </button>
                      <button
                        type="button"
                        onClick={() => handleAddPresetVariants('weight')}
                        className="px-2 py-1 bg-card hover:bg-muted border border-border text-[10px] font-bold rounded-lg transition-all cursor-pointer"
                      >
                        + 250g / 500g / 1kg
                      </button>
                    </div>

                    {/* Added Variants List */}
                    {variants.length > 0 && (
                      <div className="space-y-1.5 max-h-44 overflow-y-auto pr-1">
                        {variants.map((v, idx) => (
                          <div key={idx} className="flex items-center justify-between bg-card border border-border/70 px-3 py-2 rounded-xl text-xs font-semibold">
                            <div className="flex items-center gap-2 min-w-0">
                              <span className="font-extrabold text-text-primary truncate">{v.name}</span>
                              <span className="text-[11px] text-text-muted">
                                ₹{v.price} {v.mrp && parseFloat(v.mrp) > parseFloat(v.price) ? `(MRP ₹${v.mrp})` : ''}
                              </span>
                            </div>
                            <button
                              type="button"
                              onClick={() => handleRemoveVariant(idx)}
                              className="text-[11px] text-rose-500 hover:text-rose-600 font-bold cursor-pointer shrink-0 ml-2 px-2 py-0.5 rounded-md hover:bg-rose-500/10"
                            >
                              Remove
                            </button>
                          </div>
                        ))}
                      </div>
                    )}

                    {/* Input Row for New Variant */}
                    <div className="grid grid-cols-12 gap-2 items-end pt-1">
                      <div className="col-span-4">
                        <label className="text-[10px] font-black uppercase text-text-muted block mb-1">Variant Name *</label>
                        <input
                          type="text"
                          value={newVarName}
                          onChange={(e) => setNewVarName(e.target.value)}
                          placeholder="e.g. Half / Small"
                          className="w-full px-2.5 py-1.5 text-xs rounded-xl border border-border bg-background focus:outline-none focus:border-orange-500 font-semibold"
                        />
                      </div>
                      <div className="col-span-3">
                        <label className="text-[10px] font-black uppercase text-text-muted block mb-1">Selling Price *</label>
                        <input
                          type="number"
                          value={newVarPrice}
                          onChange={(e) => setNewVarPrice(e.target.value)}
                          placeholder="₹ Price"
                          className="w-full px-2.5 py-1.5 text-xs rounded-xl border border-border bg-background focus:outline-none focus:border-orange-500 font-semibold"
                        />
                      </div>
                      <div className="col-span-3">
                        <label className="text-[10px] font-black uppercase text-text-muted block mb-1">MRP Price</label>
                        <input
                          type="number"
                          value={newVarMrp}
                          onChange={(e) => setNewVarMrp(e.target.value)}
                          placeholder="₹ MRP"
                          className="w-full px-2.5 py-1.5 text-xs rounded-xl border border-border bg-background focus:outline-none focus:border-orange-500 font-semibold"
                        />
                      </div>
                      <div className="col-span-2">
                        <button
                          type="button"
                          onClick={handleAddVariant}
                          className="w-full py-1.5 bg-orange-600 hover:bg-orange-700 text-white font-black text-xs rounded-xl transition-all cursor-pointer shadow-2xs"
                        >
                          + Add
                        </button>
                      </div>
                    </div>
                  </div>
                )}
              </div>

              <div className="grid grid-cols-2 gap-4">
                {/* Unit */}
                <div className="space-y-1.5">
                  <label className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-1.5">
                    <Sparkles className="h-3.5 w-3.5" />
                    Serving Unit
                  </label>
                  <input
                    type="text"
                    value={unit}
                    onChange={e => setUnit(e.target.value)}
                    placeholder="e.g. Serving, Plate, Piece (Optional)"
                    className="w-full px-4 py-2.5 bg-muted/40 border border-border rounded-2xl text-xs focus:outline-hidden focus:border-orange-500/50 transition-all font-semibold"
                  />
                </div>

                {/* Category / Menu Section selection */}
                <div className="space-y-1.5">
                  <label className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-1.5">
                    <Layers className="h-3.5 w-3.5" />
                    Menu Section *
                  </label>
                  {menuSections.length > 0 ? (
                    <select
                      value={selectedSectionTag}
                      onChange={e => {
                        setSelectedSectionTag(e.target.value)
                        const defaultFoodCat = categories.find(c => c.slug === 'restaurant-food' || c.slug === 'restaurant' || c.name.toLowerCase().includes('fast food') || c.name.toLowerCase().includes('kitchen'))
                        if (defaultFoodCat?.id) setCategoryId(defaultFoodCat.id)
                      }}
                      className="w-full px-4 py-2.5 bg-muted/40 border border-border rounded-2xl text-xs focus:outline-hidden focus:border-orange-500/50 transition-all font-semibold cursor-pointer"
                      required
                    >
                      <option value="" disabled>Select Menu Section</option>
                      {menuSections.map(sec => (
                        <option key={sec.id || sec.tag} value={sec.id || sec.tag}>
                          {sec.emoji ? `${sec.emoji} ` : ''}{sec.title} {sec.id ? `(ID: ${sec.id})` : ''}
                        </option>
                      ))}
                    </select>
                  ) : (
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
                  )}
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
                <div className="flex flex-wrap items-center gap-2">
                  <button
                    type="button"
                    onClick={() => fileInputRef.current?.click()}
                    disabled={uploadingImage}
                    className="px-3.5 py-2 bg-orange-500/10 hover:bg-orange-500/20 text-orange-600 border border-orange-500/30 text-xs font-black rounded-xl transition-all flex items-center gap-1.5 shrink-0 cursor-pointer shadow-xs"
                  >
                    <Upload className="h-3.5 w-3.5" />
                    {uploadingImage ? 'Uploading...' : 'Upload Photo'}
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowMediaLibrary(true)}
                    className="px-3.5 py-2 bg-amber-500/15 hover:bg-amber-500/25 text-amber-600 dark:text-amber-400 text-xs font-black rounded-xl border border-amber-500/30 transition-all flex items-center gap-1.5 shrink-0 cursor-pointer shadow-2xs"
                  >
                    🖼️ Choose from Photo Library
                  </button>
                  <input
                    type="text"
                    value={imageUrl}
                    onChange={e => setImageUrl(e.target.value)}
                    placeholder="Or paste photo URL..."
                    className="flex-1 min-w-[200px] px-3.5 py-2 bg-muted/40 border border-border rounded-xl text-xs focus:outline-none focus:border-orange-500/50 transition-all font-semibold"
                  />
                </div>
                {imageUrl && (
                  <div className="relative h-20 w-20 rounded-xl overflow-hidden border border-border mt-2 bg-muted">
                    <img src={imageUrl} alt="Dish Preview" className="w-full h-full object-cover" />
                  </div>
                )}
              </div>

              {/* Dish Timing Slot / Availability Hours */}
              <div className="space-y-1.5 bg-orange-500/5 p-3 rounded-2xl border border-orange-500/20">
                <label className="text-xs font-black uppercase tracking-wider text-orange-600 dark:text-orange-400 flex items-center justify-between">
                  <span className="flex items-center gap-1.5">
                    <span>⏰</span> Dish Serving Timing / Availability
                  </span>
                  <span className="text-[10px] font-extrabold text-text-secondary">
                    {(!availableStartTime && !availableEndTime) ? 'Available 24x7 / Store Hours' : `${availableStartTime || '00:00'} - ${availableEndTime || '23:59'}`}
                  </span>
                </label>
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-1.5 pt-1">
                  <button
                    type="button"
                    onClick={() => { setAvailableStartTime(''); setAvailableEndTime('') }}
                    className={`px-2.5 py-1.5 rounded-xl border text-[11px] font-bold transition-all cursor-pointer ${
                      !availableStartTime && !availableEndTime
                        ? 'bg-orange-500 text-white border-orange-600 shadow-xs'
                        : 'bg-card border-border text-text-secondary hover:bg-muted'
                    }`}
                  >
                    ⏰ All Day (Store Hours)
                  </button>
                  <button
                    type="button"
                    onClick={() => { setAvailableStartTime('07:00'); setAvailableEndTime('11:30') }}
                    className={`px-2.5 py-1.5 rounded-xl border text-[11px] font-bold transition-all cursor-pointer ${
                      availableStartTime === '07:00' && availableEndTime === '11:30'
                        ? 'bg-amber-500 text-white border-amber-600 shadow-xs'
                        : 'bg-card border-border text-text-secondary hover:bg-muted'
                    }`}
                  >
                    🌅 Breakfast (7 AM-11:30 AM)
                  </button>
                  <button
                    type="button"
                    onClick={() => { setAvailableStartTime('12:00'); setAvailableEndTime('16:00') }}
                    className={`px-2.5 py-1.5 rounded-xl border text-[11px] font-bold transition-all cursor-pointer ${
                      availableStartTime === '12:00' && availableEndTime === '16:00'
                        ? 'bg-blue-500 text-white border-blue-600 shadow-xs'
                        : 'bg-card border-border text-text-secondary hover:bg-muted'
                    }`}
                  >
                    ☀️ Lunch (12 PM-4 PM)
                  </button>
                  <button
                    type="button"
                    onClick={() => { setAvailableStartTime('16:00'); setAvailableEndTime('19:30') }}
                    className={`px-2.5 py-1.5 rounded-xl border text-[11px] font-bold transition-all cursor-pointer ${
                      availableStartTime === '16:00' && availableEndTime === '19:30'
                        ? 'bg-purple-500 text-white border-purple-600 shadow-xs'
                        : 'bg-card border-border text-text-secondary hover:bg-muted'
                    }`}
                  >
                    🌆 Evening (4 PM-7:30 PM)
                  </button>
                  <button
                    type="button"
                    onClick={() => { setAvailableStartTime('19:30'); setAvailableEndTime('23:30') }}
                    className={`px-2.5 py-1.5 rounded-xl border text-[11px] font-bold transition-all cursor-pointer ${
                      availableStartTime === '19:30' && availableEndTime === '23:30'
                        ? 'bg-indigo-500 text-white border-indigo-600 shadow-xs'
                        : 'bg-card border-border text-text-secondary hover:bg-muted'
                    }`}
                  >
                    🌙 Dinner (7:30 PM-11:30 PM)
                  </button>
                </div>
                <div className="flex items-center gap-2 pt-2 border-t border-orange-500/10">
                  <span className="text-[10px] font-extrabold text-text-secondary">Custom Hours:</span>
                  <input
                    type="time"
                    value={availableStartTime}
                    onChange={(e) => setAvailableStartTime(e.target.value)}
                    className="px-2 py-1 bg-background border border-border rounded-lg text-xs font-mono"
                  />
                  <span className="text-xs font-bold text-text-secondary">to</span>
                  <input
                    type="time"
                    value={availableEndTime}
                    onChange={(e) => setAvailableEndTime(e.target.value)}
                    className="px-2 py-1 bg-background border border-border rounded-lg text-xs font-mono"
                  />
                </div>
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

      {/* 🖼️ Media Photo Library Picker Modal */}
      {showMediaLibrary && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center bg-black/70 backdrop-blur-sm p-4 animate-in fade-in">
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
                      setImageUrl(img.url)
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
