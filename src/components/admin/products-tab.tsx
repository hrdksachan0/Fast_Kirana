'use client'

import { useMemo } from 'react'
import { toast } from 'sonner'
import {
  Loader2,
  Search,
  PlusCircle,
  X,
  Download,
  AlertCircle,
  Trash,
  FileText,
  SlidersHorizontal,
} from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { PRODUCT_TEMPLATES, DEFAULT_RESTAURANT_MENU_SECTIONS } from '@/lib/constants'
import { AdminCsvImport } from './admin-csv-import'

interface Product {
  id: string
  name: string
  description: string
  imageUrl: string
  categoryId: string
  restaurantId?: string
  mrp: number
  price: number
  unit: string
  stock: number
  isAvailable: boolean
  tags: string[]
  minStock: number
  expiryDate?: string
  costPrice: number
  location: string
  isFlashDeal: boolean
  isTopPick: boolean
  isBestSeller: boolean
  sortOrder: number
  barcode?: string
  category?: { name: string; slug: string }
  variants?: any[]
}

interface Category {
  id: string
  name: string
  slug: string
  parentId?: string | null
}

interface Restaurant {
  id: string
  name: string
  city?: string
  slug?: string
  menuSections?: any
}

interface MenuSection {
  tag: string
  title: string
  emoji: string
}

interface ProductsTabProps {
  products: Product[]
  categories: Category[]
  restaurantsList: Restaurant[]
  settingsMap: Record<string, string>
  filteredProducts: Product[]
  searchQuery: string
  selectedTypeFilter: string
  selectedCategoryFilter: string
  showAddProduct: boolean
  showSortManager: boolean
  showCsvImport: boolean
  showExportModal: boolean
  isExporting: boolean
  isCreatingProduct: boolean
  newProduct: any
  newProductType: 'grocery' | 'cafe' | 'restaurant'
  editProductType: 'grocery' | 'cafe' | 'restaurant'
  newProductVariants: any[]
  editProductVariants: any[]
  hasVariantsNew: boolean
  hasVariantsEdit: boolean
  newCustomTag: string
  editCustomTag: string
  isUploading: boolean
  productPage: number
  productTotal: number
  editingProduct: any
  savingProductId: string | null
  allProducts?: Product[]
  // Setters
  setShowAddProduct: (v: boolean) => void
  setShowSortManager: (v: boolean) => void
  setShowCsvImport: (v: boolean) => void
  setShowExportModal: (v: boolean) => void
  setNewProduct: (v: any) => void
  setNewProductType: (v: 'grocery' | 'cafe' | 'restaurant') => void
  setEditProductType: (v: 'grocery' | 'cafe' | 'restaurant') => void
  setNewProductVariants: (v: any[]) => void
  setEditProductVariants: (v: any[]) => void
  setHasVariantsNew: (v: boolean) => void
  setHasVariantsEdit: (v: boolean) => void
  setNewCustomTag: (v: string) => void
  setEditingProduct: (v: any) => void
  setProductPage: (v: number) => void
  setMediaTarget: (v: any) => void
  setShowMediaLibrary: (v: boolean) => void
  setProducts: (v: any[]) => void
  setAllProducts: (v: any[]) => void
  setSearchQuery: (v: string) => void
  setSelectedTypeFilter: (v: any) => void
  setSelectedCategoryFilter: (v: string) => void
  // Handlers
  handleNewProductTypeChange: (type: 'grocery' | 'cafe' | 'restaurant') => void
  handleEditProductTypeChange: (type: 'grocery' | 'cafe' | 'restaurant') => void
  applyProductTemplate: (templateId: string) => void
  toggleTag: (form: 'new' | 'edit', tag: string, checked: boolean) => void
  handleCreateCustomTag: (form: 'new' | 'edit', tagText: string) => void
  handleCreateProduct: (e: React.FormEvent) => void
  handleToggleProductAvailability: (productId: string, currentAvailable: boolean) => void
  handleDeleteProduct: (productId: string) => void
  startEditingProduct: (p: any) => void
  handleDuplicateProduct: (p: any) => void
  handleCloudinaryUpload: (file: File, onUploadSuccess: (url: string) => void) => void
  handleExportCsv: (type: 'all' | 'grocery' | 'cafe') => void
  handleReplenishCsv: () => void
  renderPagination: (
    currentPage: number,
    totalItems: number,
    itemsPerPage: number,
    onPageChange: (p: number) => void
  ) => React.ReactNode
}

export function ProductsTab({
  products,
  categories,
  restaurantsList,
  settingsMap,
  filteredProducts,
  searchQuery,
  selectedTypeFilter,
  selectedCategoryFilter,
  showAddProduct,
  showSortManager,
  showCsvImport,
  showExportModal,
  isExporting,
  isCreatingProduct,
  newProduct,
  newProductType,
  editProductType,
  newProductVariants,
  editProductVariants,
  hasVariantsNew,
  hasVariantsEdit,
  newCustomTag,
  editCustomTag,
  isUploading,
  productPage,
  productTotal,
  editingProduct,
  savingProductId,
  setShowAddProduct,
  setShowSortManager,
  setShowCsvImport,
  setShowExportModal,
  setNewProduct,
  setNewProductType,
  setEditProductType,
  setNewProductVariants,
  setEditProductVariants,
  setHasVariantsNew,
  setHasVariantsEdit,
  setNewCustomTag,
  setEditingProduct,
  setProductPage,
  setMediaTarget,
  setShowMediaLibrary,
  setProducts,
  setAllProducts,
  allProducts = [],
  setSearchQuery,
  setSelectedTypeFilter,
  setSelectedCategoryFilter,
  handleNewProductTypeChange,
  handleEditProductTypeChange,
  applyProductTemplate,
  toggleTag,
  handleCreateCustomTag,
  handleCreateProduct,
  handleToggleProductAvailability,
  handleDeleteProduct,
  startEditingProduct,
  handleDuplicateProduct,
  handleCloudinaryUpload,
  handleExportCsv,
  handleReplenishCsv,
  renderPagination,
}: ProductsTabProps) {
  const RESTAURANT_MENU_SECTIONS = DEFAULT_RESTAURANT_MENU_SECTIONS

  // Resolve dynamic menu sections for new product based on selected restaurant
  const resolvedNewMenuSections = useMemo(() => {
    if (!newProduct.restaurantId) return RESTAURANT_MENU_SECTIONS
    const restaurant = restaurantsList.find((r: any) => r.id === newProduct.restaurantId) as any
    if (restaurant?.menuSections) {
      try {
        const raw = typeof restaurant.menuSections === 'string'
          ? JSON.parse(restaurant.menuSections)
          : restaurant.menuSections
        if (Array.isArray(raw) && raw.length > 0) {
          return raw.filter((s: any) => !s.disabled)
        }
      } catch (e) {
        console.error('Error parsing restaurant menuSections for new product:', e)
      }
    }
    return RESTAURANT_MENU_SECTIONS
  }, [newProduct.restaurantId, restaurantsList, RESTAURANT_MENU_SECTIONS])

  const isNewRestaurantMode = !!newProduct.restaurantId
  const selectedNewRestaurant = useMemo(() => {
    return restaurantsList.find((r: any) => r.id === newProduct.restaurantId)
  }, [newProduct.restaurantId, restaurantsList])

  const isNewVegDish = useMemo(() => {
    const tagsLower = (newProduct.tags || '').toLowerCase()
    return tagsLower.includes('veg') && !tagsLower.includes('nonveg') && !tagsLower.includes('non-veg')
  }, [newProduct.tags])

  const handleToggleNewVeg = (veg: boolean) => {
    let cleanTags = (newProduct.tags || '')
      .split(',')
      .map((t: string) => t.trim())
      .filter((t: string) => t.toLowerCase() !== 'veg' && t.toLowerCase() !== 'nonveg' && t.toLowerCase() !== 'non-veg')
    cleanTags.push(veg ? 'veg' : 'nonveg')
    setNewProduct({ ...newProduct, tags: cleanTags.filter(Boolean).join(', ') })
  }

  const newMarginPercent = useMemo(() => {
    const p = parseFloat(newProduct.price) || 0
    const c = parseFloat(newProduct.costPrice) || 0
    if (p > 0 && c > 0 && p >= c) {
      return (((p - c) / p) * 100).toFixed(1)
    }
    return null
  }, [newProduct.price, newProduct.costPrice])

  return (
    <div className="space-y-6 animate-fade-in">

      {/* Controls row */}
      <div className="bg-card p-4 rounded-2xl border border-border shadow-sm space-y-4">
        {/* Row 1: Search & Type & Category Filters */}
        <div className="flex flex-col md:flex-row gap-3 items-center justify-between">
          <div className="relative w-full md:max-w-md">
            <Search className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
            <input
              type="text"
              placeholder="Search products by name, ID, or barcode..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9 pr-4 py-2.5 w-full text-xs rounded-xl border border-border bg-muted/30 focus:outline-none focus:border-primary font-semibold"
            />
          </div>

          <div className="flex gap-3 w-full md:w-auto">
            <select
              value={selectedTypeFilter}
              onChange={(e) => setSelectedTypeFilter(e.target.value)}
              className="flex-1 md:flex-none px-3 py-2 text-xs rounded-xl border border-border bg-card font-bold text-text-secondary focus:outline-none cursor-pointer"
            >
              <option value="all">🌐 All Items (Catalog)</option>
              <option value="grocery">📦 Grocery Mart Only</option>
              <option value="restaurant">🍳 All Restaurants</option>
              {restaurantsList.map((r) => (
                <option key={r.id} value={r.id}>
                  🍽️ {r.name}
                </option>
              ))}
            </select>
            <select
              value={selectedCategoryFilter}
              onChange={(e) => setSelectedCategoryFilter(e.target.value)}
              className="flex-1 md:flex-none px-3 py-2 text-xs rounded-xl border border-border bg-card font-bold text-text-secondary focus:outline-none"
            >
              <option value="">All Categories</option>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </div>
        </div>

        {/* Row 2: Action Buttons */}
        <div className="flex flex-wrap gap-2 pt-2 border-t border-border/40">
          <button
            onClick={() => setShowAddProduct(!showAddProduct)}
            className="flex items-center gap-1.5 px-4 py-2 bg-primary text-primary-foreground text-xs font-bold rounded-xl hover:bg-primary/95 transition-all cursor-pointer"
          >
            <PlusCircle className="h-4 w-4" />
            Add New Product
          </button>
          <button
            onClick={() => { setShowSortManager(true) }}
            className="flex items-center gap-1.5 px-4 py-2 bg-zinc-800 hover:bg-zinc-700 dark:bg-zinc-700 dark:hover:bg-zinc-650 text-white text-xs font-bold rounded-xl transition-all cursor-pointer"
          >
            <SlidersHorizontal className="h-4 w-4" />
            ⚡ Sort & Position Manager
          </button>
          <button
            onClick={() => { setShowCsvImport(!showCsvImport); setShowExportModal(false); }}
            className="flex items-center gap-1.5 px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold rounded-xl transition-all cursor-pointer"
          >
            <FileText className="h-4 w-4" />
            📥 CSV Import
          </button>
          <button
            onClick={() => { setShowExportModal(!showExportModal); setShowCsvImport(false); }}
            className="flex items-center gap-1.5 px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold rounded-xl transition-all cursor-pointer"
          >
            <Download className="h-4 w-4" />
            📤 Export CSV
          </button>
          <button
            onClick={handleReplenishCsv}
            className="flex items-center gap-1.5 px-4 py-2 bg-amber-600 hover:bg-amber-500 text-white text-xs font-bold rounded-xl transition-all cursor-pointer shadow-sm"
          >
            <AlertCircle className="h-4 w-4" />
            ⚠️ Replenish CSV
          </button>
        </div>
      </div>

      {/* CSV Export Options Panel */}
      <AnimatePresence>
        {showExportModal && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            className="bg-card p-5 border border-border rounded-2xl shadow-sm space-y-4 animate-slide-up"
          >
            <div className="flex items-center justify-between border-b border-border/60 pb-2">
              <div>
                <h4 className="font-extrabold text-text-primary text-sm">Export Catalog Items</h4>
                <p className="text-[10px] text-text-secondary mt-0.5">Select category type to generate and download product CSV sheet.</p>
              </div>
              <button
                onClick={() => setShowExportModal(false)}
                className="p-1 rounded-lg hover:bg-muted text-text-secondary hover:text-text-primary cursor-pointer"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            <div className="flex flex-col sm:flex-row gap-3">
              <button
                disabled={isExporting}
                onClick={() => handleExportCsv('all')}
                className="flex-1 flex items-center justify-center gap-2 px-4 py-3 border border-border bg-muted/20 hover:bg-muted text-text-primary text-xs font-black rounded-xl transition-all cursor-pointer disabled:opacity-50"
              >
                All Catalog Items (All)
              </button>
              <button
                disabled={isExporting}
                onClick={() => handleExportCsv('grocery')}
                className="flex-1 flex items-center justify-center gap-2 px-4 py-3 border border-blue-500/20 bg-blue-500/5 hover:bg-blue-500/10 text-blue-600 dark:text-blue-400 text-xs font-black rounded-xl transition-all cursor-pointer disabled:opacity-50"
              >
                📦 Grocery Items Only
              </button>
              <button
                disabled={isExporting}
                onClick={() => handleExportCsv('cafe')}
                className="flex-1 flex items-center justify-center gap-2 px-4 py-3 border border-rose-500/20 bg-rose-500/5 hover:bg-rose-500/10 text-rose-600 dark:text-rose-400 text-xs font-black rounded-xl transition-all cursor-pointer disabled:opacity-50"
              >
                ☕ Cafe Items Only
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* CSV Bulk Import */}
      <AnimatePresence>
        {showCsvImport && (
          <AdminCsvImport
            categories={categories}
            onImportComplete={(imported) => {
              setProducts([...imported, ...products])
              setAllProducts([...imported.map((p: any) => ({ id: p.id, name: p.name, price: p.price, mrp: p.mrp, costPrice: p.costPrice ?? 0, stock: p.stock, minStock: p.minStock, isAvailable: p.isAvailable, tags: p.tags, variants: p.variants, category: { id: p.category?.id, name: p.category?.name, slug: p.category?.slug } })), ...allProducts])
            }}
            onClose={() => setShowCsvImport(false)}
          />
        )}
      </AnimatePresence>

      {/* Add Product Inline Form */}
      {showAddProduct && (
        <form
          id="add-product-form-container"
          onSubmit={handleCreateProduct}
          className="bg-card p-6 border border-border rounded-2xl shadow-xl space-y-5 animate-slide-up"
        >
          {/* Header */}
          <div className="border-b border-border/60 pb-3 flex flex-col md:flex-row md:items-center justify-between gap-3">
            <div>
              <h4 className="font-black text-text-primary text-base">
                Add New {isNewRestaurantMode ? 'Restaurant Dish' : 'Grocery Product'}
              </h4>
              <p className="text-[11px] text-text-secondary mt-0.5">
                {isNewRestaurantMode ? `Outlet: ${selectedNewRestaurant?.name || 'Restaurant'}` : 'Define your inventory item specs, MRP and FastKirana pricing.'}
              </p>
            </div>

            {/* Store / Outlet Selection */}
            <div className="p-3 rounded-xl border border-primary/20 bg-primary/5 min-w-[280px]">
              <label className="text-[10px] font-black text-primary uppercase tracking-wider block mb-1">
                Store / Restaurant Outlet Assignment *
              </label>
              <select
                value={newProduct.restaurantId}
                onChange={(e) => {
                  const newRestId = e.target.value
                  setNewProduct({
                    ...newProduct,
                    restaurantId: newRestId,
                    unit: newRestId ? (newProduct.unit || '1 Serving') : (newProduct.unit || '1 kg'),
                  })
                }}
                className="w-full px-3 py-2 text-xs rounded-xl border border-primary/30 bg-card focus:outline-none focus:border-primary font-bold text-text-primary cursor-pointer shadow-xs"
              >
                <option value="">🛒 General Kirana / Grocery Store</option>
                {restaurantsList.map((r) => (
                  <option key={r.id} value={r.id}>
                    🍽️ Restaurant: {r.name} ({r.city || 'Outlet'})
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Preset Product Templates (for Grocery) */}
          {!isNewRestaurantMode && (
            <div className="bg-muted/30 border border-border/40 rounded-xl p-3 space-y-2">
              <span className="text-[10px] font-extrabold text-text-secondary uppercase tracking-wider block">
                ⚡ Frictionless Presets (Pre-fill Form):
              </span>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                {PRODUCT_TEMPLATES.map((tmpl) => (
                  <button
                    key={tmpl.id}
                    type="button"
                    onClick={() => applyProductTemplate(tmpl.id)}
                    className="flex flex-col items-start p-2 bg-card hover:bg-muted/60 border border-border/50 rounded-xl text-left cursor-pointer transition-colors"
                  >
                    <span className="text-[11px] font-black text-text-primary">{tmpl.label}</span>
                    <span className="text-[9px] text-text-secondary truncate w-full mt-0.5">{tmpl.description}</span>
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Card 1: Core Details (Name, Photo, Description) */}
          <div className="p-4 rounded-xl border border-border bg-card space-y-3.5">
            <h5 className="text-xs font-black text-text-primary uppercase tracking-wider">
              📝 Core Information
            </h5>

            <div className="grid grid-cols-1 gap-3">
              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">
                  {isNewRestaurantMode ? 'Dish Name *' : 'Product Name *'}
                </label>
                <input
                  type="text"
                  required
                  placeholder={isNewRestaurantMode ? 'e.g. Paneer Butter Masala' : 'e.g. Fresh Red Apple'}
                  value={newProduct.name}
                  onChange={(e) => setNewProduct({ ...newProduct, name: e.target.value })}
                  className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
              </div>

              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">
                  {isNewRestaurantMode ? 'Dish Description / Ingredients' : 'Product Description'}
                </label>
                <input
                  type="text"
                  placeholder={isNewRestaurantMode ? 'e.g. Rich cashew gravy with soft paneer cubes.' : 'Product details, origin, health benefits...'}
                  value={newProduct.description}
                  onChange={(e) => setNewProduct({ ...newProduct, description: e.target.value })}
                  className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-normal"
                />
              </div>

              {/* Photo Upload & Preview */}
              <div className="space-y-2">
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Photo / Image URL</label>
                <input
                  type="text"
                  placeholder="Paste image absolute URL..."
                  value={newProduct.imageUrl}
                  onChange={(e) => setNewProduct({ ...newProduct, imageUrl: e.target.value })}
                  className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
                <div className="flex flex-wrap items-center gap-2">
                  <label
                    htmlFor="new-product-image-file"
                    className="cursor-pointer px-3.5 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary text-xs font-black rounded-xl border border-primary/20 transition-all flex items-center gap-1.5"
                  >
                    {isUploading ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : '📤 Upload New Photo'}
                  </label>
                  <button
                    type="button"
                    onClick={() => {
                      setMediaTarget('newProduct')
                      setShowMediaLibrary(true)
                    }}
                    className="px-3.5 py-1.5 bg-amber-500/15 hover:bg-amber-500/25 text-amber-600 dark:text-amber-400 text-xs font-black rounded-xl border border-amber-500/30 transition-all flex items-center gap-1.5 cursor-pointer shadow-2xs"
                  >
                    🖼️ Choose from Photo Library
                  </button>
                  <input
                    id="new-product-image-file"
                    type="file"
                    accept="image/*"
                    onChange={(e) => {
                      const file = e.target.files?.[0]
                      if (file) {
                        handleCloudinaryUpload(file, (url) => {
                          setNewProduct({ ...newProduct, imageUrl: url })
                        })
                      }
                      e.target.value = ''
                    }}
                    className="sr-only"
                    disabled={isUploading}
                  />
                </div>
                {newProduct.imageUrl && (
                  <div className="h-20 w-20 relative overflow-hidden rounded-xl border border-border bg-white/5 p-1 mt-1">
                    <img src={newProduct.imageUrl} alt="Preview" className="h-full w-full object-contain" />
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Card 2A: GROCERY-SPECIFIC CONTROLS */}
          {!isNewRestaurantMode && (
            <div className="p-4 rounded-xl border border-border bg-card space-y-4">
              <h5 className="text-xs font-black text-primary uppercase tracking-wider">
                📦 Grocery Categories, Pricing & Warehouse Inventory
              </h5>

              {/* Main & Sub Categories */}
              {(() => {
                const currentCat = categories.find(c => c.id === newProduct.categoryId)
                const activeParentId = currentCat ? (currentCat.parentId || currentCat.id) : ''
                const activeSubId = currentCat && currentCat.parentId ? currentCat.id : ''
                const parentCategories = categories.filter((c) => !c.parentId)
                const availableSubcategories = activeParentId
                  ? categories.filter((c) => c.parentId === activeParentId)
                  : []

                return (
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label className="text-[10px] font-bold text-text-secondary block mb-1">Main Category *</label>
                      <select
                        required
                        value={activeParentId}
                        onChange={(e) => {
                          const newParentId = e.target.value
                          setNewProduct({ ...newProduct, categoryId: newParentId })
                        }}
                        className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold cursor-pointer"
                      >
                        <option value="">-- Select Parent Category --</option>
                        {parentCategories.map((c) => (
                          <option key={c.id} value={c.id}>{c.name}</option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label className="text-[10px] font-bold text-text-secondary block mb-1">
                        Subcategory {availableSubcategories.length > 0 ? '(Recommended)' : '(Optional)'}
                      </label>
                      <select
                        value={activeSubId}
                        disabled={!activeParentId || availableSubcategories.length === 0}
                        onChange={(e) => {
                          const subId = e.target.value
                          setNewProduct({ ...newProduct, categoryId: subId || activeParentId })
                        }}
                        className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold cursor-pointer disabled:opacity-50"
                      >
                        <option value="">
                          {availableSubcategories.length === 0 ? '(No subcategories)' : '-- All / Main Category --'}
                        </option>
                        {availableSubcategories.map((sub) => (
                          <option key={sub.id} value={sub.id}>└ {sub.name}</option>
                        ))}
                      </select>
                    </div>
                  </div>
                )
              })()}

              {/* Pricing, Cost & Margin */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">MRP Price (₹) *</label>
                  <input
                    type="number"
                    step="0.01"
                    required={!hasVariantsNew}
                    placeholder="e.g. 100"
                    value={newProduct.mrp}
                    onChange={(e) => setNewProduct({ ...newProduct, mrp: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Selling Price (₹) *</label>
                  <input
                    type="number"
                    step="0.01"
                    required={!hasVariantsNew}
                    placeholder="e.g. 80"
                    value={newProduct.price}
                    onChange={(e) => setNewProduct({ ...newProduct, price: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-bold text-primary"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">
                    Cost Price (₹) {newMarginPercent ? `(Margin: ${newMarginPercent}%)` : ''}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    placeholder="e.g. 60"
                    value={newProduct.costPrice}
                    onChange={(e) => setNewProduct({ ...newProduct, costPrice: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
              </div>

              {/* Inventory, Unit, Stock & Alerts */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Initial Stock Quantity *</label>
                  <input
                    type="number"
                    required={!hasVariantsNew}
                    placeholder="e.g. 50"
                    value={newProduct.stock}
                    onChange={(e) => setNewProduct({ ...newProduct, stock: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Min Stock Alert Level</label>
                  <input
                    type="number"
                    placeholder="e.g. 10"
                    value={newProduct.minStock}
                    onChange={(e) => setNewProduct({ ...newProduct, minStock: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Unit (e.g. 1 kg, 500 gm)</label>
                  <input
                    type="text"
                    placeholder="e.g. 1 kg, 12 pcs"
                    value={newProduct.unit}
                    onChange={(e) => setNewProduct({ ...newProduct, unit: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
              </div>

              {/* Barcode, Aisle & Expiry */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Barcode (EAN / UPC)</label>
                  <input
                    type="text"
                    placeholder="Scan or enter barcode"
                    value={newProduct.barcode}
                    onChange={(e) => setNewProduct({ ...newProduct, barcode: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Warehouse / Aisle Location</label>
                  <input
                    type="text"
                    placeholder="e.g. Aisle 2-B"
                    value={newProduct.location}
                    onChange={(e) => setNewProduct({ ...newProduct, location: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Expiry Date</label>
                  <input
                    type="date"
                    value={newProduct.expiryDate}
                    onChange={(e) => setNewProduct({ ...newProduct, expiryDate: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
              </div>

              {/* Display Priority / Sort Order */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Display Priority / Sort Order</label>
                <input
                  type="number"
                  placeholder="e.g. 100 for top, -50 for bottom"
                  value={newProduct.sortOrder}
                  onChange={(e) => setNewProduct({ ...newProduct, sortOrder: e.target.value })}
                  className="w-full bg-muted/20 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold text-text-primary"
                />
                <p className="text-[9px] text-text-muted">Higher numbers display first/on top. Lower numbers display last. Default is 0.</p>
              </div>

              {/* Badges / Promotion flags */}
              <div className="pt-2 border-t border-border flex flex-wrap gap-4">
                <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={newProduct.isAvailable}
                    onChange={(e) => setNewProduct({ ...newProduct, isAvailable: e.target.checked })}
                    className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                  />
                  <span>🟢 Available for Sale</span>
                </label>
                <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={newProduct.isBestSeller}
                    onChange={(e) => setNewProduct({ ...newProduct, isBestSeller: e.target.checked })}
                    className="h-4 w-4 text-amber-500 focus:ring-amber-500 border-border rounded cursor-pointer"
                  />
                  <span>🏆 Best Seller</span>
                </label>
                <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={newProduct.isTopPick}
                    onChange={(e) => setNewProduct({ ...newProduct, isTopPick: e.target.checked })}
                    className="h-4 w-4 text-indigo-500 focus:ring-indigo-500 border-border rounded cursor-pointer"
                  />
                  <span>⭐ Top Pick</span>
                </label>
                <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={newProduct.isFlashDeal}
                    onChange={(e) => setNewProduct({ ...newProduct, isFlashDeal: e.target.checked })}
                    className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                  />
                  <span>⚡ Flash Deal</span>
                </label>
              </div>
            </div>
          )}

          {/* Card 2B: RESTAURANT-SPECIFIC CONTROLS */}
          {isNewRestaurantMode && (
            <div className="p-4 rounded-xl border border-amber-500/30 bg-amber-500/5 dark:bg-amber-955/15 space-y-4">
              <h5 className="text-xs font-black text-amber-600 dark:text-amber-400 uppercase tracking-wider">
                🍽️ Restaurant Menu & Kitchen Controls
              </h5>

              {/* Menu Section & Portion Unit */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">
                    Restaurant Menu Section * (Synced with {selectedNewRestaurant?.name || 'Outlet'})
                  </label>
                  <select
                    required
                    value={resolvedNewMenuSections.find((sec: any) => newProduct.tags.split(',').map((t: string) => t.trim().toLowerCase()).includes(sec.tag))?.tag || ''}
                    onChange={(e) => {
                      const val = e.target.value
                      const sectionValues = resolvedNewMenuSections.map((s: any) => s.tag)
                      let cleanTags = newProduct.tags
                        .split(',')
                        .map((t: string) => t.trim())
                        .filter((t: string) => t.length > 0 && !sectionValues.includes(t.toLowerCase()))

                      if (val) cleanTags.push(val)
                      if (!cleanTags.map((t: string) => t.toLowerCase()).includes('restaurant')) cleanTags.push('restaurant')
                      setNewProduct({ ...newProduct, tags: cleanTags.join(', ') })
                    }}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-amber-500/40 bg-card focus:outline-none focus:border-amber-500 font-black text-amber-600 dark:text-amber-400 cursor-pointer shadow-xs"
                  >
                    <option value="">-- Select Menu Section --</option>
                    {resolvedNewMenuSections.map((sec: any) => (
                      <option key={sec.tag} value={sec.tag}>
                        {sec.emoji} {sec.title}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Serving / Portion Specification</label>
                  <input
                    type="text"
                    placeholder="e.g. 1 Plate, 1 Serving, 2 Pcs, 500 ml"
                    value={newProduct.unit}
                    onChange={(e) => setNewProduct({ ...newProduct, unit: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-amber-500 font-semibold"
                  />
                </div>
              </div>

              {/* Pricing & Cost */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Menu MRP Price (₹)</label>
                  <input
                    type="number"
                    step="0.01"
                    placeholder="e.g. 240"
                    value={newProduct.mrp}
                    onChange={(e) => setNewProduct({ ...newProduct, mrp: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-amber-500 font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Restaurant Selling Price (₹) *</label>
                  <input
                    type="number"
                    step="0.01"
                    required={!hasVariantsNew}
                    placeholder="e.g. 220"
                    value={newProduct.price}
                    onChange={(e) => setNewProduct({ ...newProduct, price: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-amber-500 font-black text-amber-600 dark:text-amber-400"
                  />
                </div>
              </div>

              {/* Display Priority / Sort Order */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Menu Display Order</label>
                <input
                  type="number"
                  placeholder="e.g. 100 for top"
                  value={newProduct.sortOrder}
                  onChange={(e) => setNewProduct({ ...newProduct, sortOrder: e.target.value })}
                  className="w-full bg-card border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold text-text-primary"
                />
              </div>

              {/* Food Type (Veg / Non-Veg) & Kitchen Flags */}
              <div className="pt-2 border-t border-amber-500/20 flex flex-wrap items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                  <span className="text-[10px] font-bold text-text-secondary">Food Type:</span>
                  <div className="flex rounded-lg p-0.5 bg-muted/40 border border-border">
                    <button
                      type="button"
                      onClick={() => handleToggleNewVeg(true)}
                      className={`px-2.5 py-1 rounded-md text-[11px] font-black transition-all cursor-pointer ${
                        isNewVegDish ? 'bg-emerald-500 text-white shadow-xs' : 'text-text-secondary hover:text-text-primary'
                      }`}
                    >
                      🟢 Pure Veg
                    </button>
                    <button
                      type="button"
                      onClick={() => handleToggleNewVeg(false)}
                      className={`px-2.5 py-1 rounded-md text-[11px] font-black transition-all cursor-pointer ${
                        !isNewVegDish ? 'bg-rose-500 text-white shadow-xs' : 'text-text-secondary hover:text-text-primary'
                      }`}
                    >
                      🔴 Non-Veg
                    </button>
                  </div>
                </div>

                <div className="flex flex-wrap items-center gap-3 sm:gap-4">
                  <label className="flex items-center gap-1.5 text-xs font-bold text-text-primary cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={parseInt(newProduct.stock) > 0 || (newProduct.stock === '' && newProduct.isAvailable)}
                      onChange={(e) => {
                        const inStock = e.target.checked
                        setNewProduct({
                          ...newProduct,
                          stock: inStock ? '999' : '0'
                        })
                      }}
                      className="h-4 w-4 text-emerald-500 focus:ring-emerald-500 border-border rounded cursor-pointer"
                    />
                    <span>🍲 Kitchen Ready (In Stock)</span>
                  </label>
                  <label className="flex items-center gap-1.5 text-xs font-bold text-text-primary cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={newProduct.isAvailable}
                      onChange={(e) => setNewProduct({ ...newProduct, isAvailable: e.target.checked })}
                      className="h-4 w-4 text-blue-500 focus:ring-blue-500 border-border rounded cursor-pointer"
                    />
                    <span>👁️ Show on Storefront</span>
                  </label>
                  <label className="flex items-center gap-1.5 text-xs font-bold text-text-primary cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={newProduct.isBestSeller}
                      onChange={(e) => setNewProduct({ ...newProduct, isBestSeller: e.target.checked })}
                      className="h-4 w-4 text-amber-500 focus:ring-amber-500 border-border rounded cursor-pointer"
                    />
                    <span>⭐ Chef Special</span>
                  </label>
                </div>
              </div>
            </div>
          )}

          {/* Card 3: Multi-Variants (Portions / Pack Sizes) */}
          <div className="p-4 rounded-xl border border-border bg-card space-y-3">
            <div className="flex items-center justify-between">
              <label className="text-xs font-bold text-text-primary flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={hasVariantsNew}
                  onChange={(e) => setHasVariantsNew(e.target.checked)}
                  className="rounded border-border text-primary focus:ring-primary h-4 w-4 cursor-pointer"
                />
                <span>{isNewRestaurantMode ? 'This dish has portion sizes (e.g. Half / Full)' : 'This product has multiple size/weight options (Variants)'}</span>
              </label>
            </div>

            {hasVariantsNew && (
              <div className="space-y-3 pt-2 border-t border-border">
                {newProductVariants.length > 0 && (
                  <div className="space-y-2 max-h-56 overflow-y-auto pr-1">
                    {newProductVariants.map((v, idx) => (
                      <div key={idx} className="p-2.5 rounded-xl border border-border/80 bg-muted/15 space-y-1.5 shadow-2xs">
                        <div className="flex items-center justify-between gap-2">
                          <span className="text-[10px] font-black uppercase text-primary tracking-wider">Option #{idx + 1}</span>
                          <button
                            type="button"
                            onClick={() => setNewProductVariants(newProductVariants.filter((_, i) => i !== idx))}
                            className="text-[10px] text-rose-500 hover:text-rose-600 font-extrabold cursor-pointer"
                          >
                            Remove ✕
                          </button>
                        </div>
                        <div className={`grid grid-cols-2 ${!isNewRestaurantMode ? 'sm:grid-cols-4' : 'sm:grid-cols-3'} gap-2 items-center`}>
                          <div>
                            <label className="text-[9px] font-bold text-text-muted block mb-0.5">Name</label>
                            <input
                              type="text"
                              value={v.name}
                              onChange={(e) => {
                                const updated = [...newProductVariants]
                                updated[idx] = { ...updated[idx], name: e.target.value }
                                setNewProductVariants(updated)
                              }}
                              className="w-full px-2 py-1 text-xs font-bold rounded-lg border bg-background focus:outline-none focus:border-primary"
                            />
                          </div>
                          <div>
                            <label className="text-[9px] font-bold text-text-muted block mb-0.5">MRP (₹)</label>
                            <input
                              type="number"
                              value={v.mrp}
                              onChange={(e) => {
                                const updated = [...newProductVariants]
                                updated[idx] = { ...updated[idx], mrp: e.target.value }
                                setNewProductVariants(updated)
                              }}
                              className="w-full px-2 py-1 text-xs font-semibold rounded-lg border bg-background focus:outline-none focus:border-primary"
                            />
                          </div>
                          <div>
                            <label className="text-[9px] font-bold text-text-muted block mb-0.5">Selling Price (₹)</label>
                            <input
                              type="number"
                              value={v.price}
                              onChange={(e) => {
                                const updated = [...newProductVariants]
                                updated[idx] = { ...updated[idx], price: e.target.value }
                                setNewProductVariants(updated)
                              }}
                              className="w-full px-2 py-1 text-xs font-extrabold text-accent rounded-lg border bg-background focus:outline-none focus:border-primary"
                            />
                          </div>
                          {!isNewRestaurantMode && (
                            <div>
                              <label className="text-[9px] font-bold text-text-muted block mb-0.5">Stock</label>
                              <input
                                type="number"
                                value={v.stock}
                                onChange={(e) => {
                                  const updated = [...newProductVariants]
                                  updated[idx] = { ...updated[idx], stock: e.target.value }
                                  setNewProductVariants(updated)
                                }}
                                className="w-full px-2 py-1 text-xs font-bold rounded-lg border bg-background focus:outline-none focus:border-primary"
                              />
                            </div>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                )}

                <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 items-end">
                  <div>
                    <label className="text-[9px] font-bold text-text-secondary block mb-1">
                      {isNewRestaurantMode ? 'Portion Name (e.g. Half / Full)' : 'Variant Name'}
                    </label>
                    <input
                      type="text"
                      id="new-var-name"
                      placeholder={isNewRestaurantMode ? 'Half Plate' : '500 gm'}
                      className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="text-[9px] font-bold text-text-secondary block mb-1">MRP Price (₹)</label>
                    <input
                      type="number"
                      id="new-var-mrp"
                      placeholder="MRP"
                      className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="text-[9px] font-bold text-text-secondary block mb-1">Selling Price (₹) *</label>
                    <input
                      type="number"
                      id="new-var-price"
                      placeholder="Price"
                      className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none font-bold"
                    />
                  </div>
                  <div>
                    <button
                      type="button"
                      onClick={() => {
                        const nameInput = document.getElementById('new-var-name') as HTMLInputElement
                        const mrpInput = document.getElementById('new-var-mrp') as HTMLInputElement
                        const priceInput = document.getElementById('new-var-price') as HTMLInputElement

                        const name = nameInput.value.trim()
                        const mrp = mrpInput.value.trim() || priceInput.value.trim()
                        const price = priceInput.value.trim()

                        if (!name || !price) {
                          toast.error('Please enter portion name and price')
                          return
                        }

                        const newVars = [...newProductVariants, { name, mrp, price, costPrice: '0', stock: isNewRestaurantMode ? '9999' : '100' }]
                        newVars.sort((a, b) => (parseFloat(a.price) || 0) - (parseFloat(b.price) || 0))
                        setNewProductVariants(newVars)
                        nameInput.value = ''
                        mrpInput.value = ''
                        priceInput.value = ''
                      }}
                      className="w-full py-2 text-[10px] font-black bg-primary/10 hover:bg-primary/20 text-primary border border-primary/25 rounded-lg transition-colors cursor-pointer"
                    >
                      + Add Option
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Card 4: Search Keywords & Custom Tags */}
          <div className="p-4 rounded-xl border border-border bg-card space-y-2.5">
            <h5 className="text-xs font-black text-text-secondary uppercase tracking-wider">
              🏷️ Search Keywords & Tags (Customer Search Indexing)
            </h5>
            <div className="flex gap-2 max-w-md">
              <input
                type="text"
                placeholder="Add keyword (e.g. butter, tandoori, organic)"
                value={newCustomTag}
                onChange={(e) => setNewCustomTag(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault()
                    handleCreateCustomTag('new', newCustomTag)
                  }
                }}
                className="flex-1 px-3 py-1.5 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
              <button
                type="button"
                onClick={() => handleCreateCustomTag('new', newCustomTag)}
                className="px-3 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary text-[10px] font-black rounded-xl border border-primary/20 transition-all cursor-pointer"
              >
                + Add Tag
              </button>
            </div>
            {newProduct.tags.trim() && (
              <div className="flex flex-wrap gap-1.5 pt-1">
                {newProduct.tags.split(',').map((t: string) => t.trim()).filter(Boolean).map((tag: string) => (
                  <span key={tag} className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-muted text-[11px] font-bold text-text-primary">
                    <span>{tag}</span>
                    <button
                      type="button"
                      onClick={() => toggleTag('new', tag, false)}
                      className="text-text-muted hover:text-rose-500 font-extrabold text-[10px] ml-0.5 cursor-pointer"
                    >
                      ×
                    </button>
                  </span>
                ))}
              </div>
            )}
          </div>

          {/* Actions */}
          <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
            <button
              type="button"
              onClick={() => setShowAddProduct(false)}
              className="px-4 py-2 border border-border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isCreatingProduct}
              className="flex items-center gap-1.5 px-6 py-2 bg-primary text-white text-xs font-black rounded-xl hover:bg-primary/90 transition-all shadow-md cursor-pointer disabled:opacity-50"
            >
              {isCreatingProduct ? (
                <>
                  <Loader2 className="h-3.5 w-3.5 animate-spin" />
                  <span>Creating...</span>
                </>
              ) : (
                'Add Item'
              )}
            </button>
          </div>
        </form>
      )}

      {/* Products Inventory List */}
      <div className="bg-card border border-border rounded-2xl p-6 shadow-sm overflow-hidden">
        <h3 className="font-extrabold text-text-primary text-base mb-4">Stock Levels & Pricing</h3>

        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse text-xs">
            <thead>
              <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-bold">
                <th className="py-3 px-4">Item</th>
                <th className="py-3 px-4">Category</th>
                <th className="py-3 px-4 w-[110px]">MRP (₹)</th>
                <th className="py-3 px-4 w-[110px]">Price (₹)</th>
                <th className="py-3 px-4 w-[90px]">Stock</th>
                <th className="py-3 px-4 w-[110px]">Location</th>
                <th className="py-3 px-4 w-[100px] text-center">Status</th>
                <th className="py-3 px-4 text-right">Actions</th>

              </tr>
            </thead>
            <tbody className="divide-y divide-border/40 font-semibold">
              {filteredProducts.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-10 text-text-secondary">
                    No products found matching your search.
                  </td>
                </tr>

              ) : (
                filteredProducts.map((p) => {
                  const isLowStock = p.stock < 15

                  return (
                    <tr key={p.id} className="hover:bg-muted/30">
                      {/* Item Info */}
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-3">
                          <span className="text-xl h-9 w-9 bg-muted/60 flex items-center justify-center rounded-lg border">
                            {p.imageUrl && p.imageUrl.length < 5 ? p.imageUrl : '📦'}
                          </span>
                          <div>
                            <div className="font-bold text-text-primary">{p.name}</div>
                            <div className="text-[10px] text-text-muted font-normal flex items-center gap-1.5">
                              <span>{p.unit}</span>
                              {p.barcode && (
                                <span className="text-[9px] bg-blue-500/10 text-blue-600 dark:text-blue-450 px-1 py-0.5 rounded font-mono">
                                  {p.barcode}
                                </span>
                              )}
                            </div>
                          </div>
                        </div>
                      </td>

                      {/* Category */}
                      <td className="py-3 px-4">
                        <span className="bg-muted px-2 py-0.5 border border-border/80 text-[10px] text-text-secondary rounded font-bold uppercase tracking-wider">
                          {p.category?.name || 'General'}
                        </span>
                      </td>

                      {/* MRP */}
                      <td className="py-3 px-4 text-text-secondary">
                        <span>₹{p.mrp}</span>
                      </td>

                      {/* price */}
                      <td className="py-3 px-4">
                        <span className="text-accent font-extrabold">₹{p.price}</span>
                      </td>

                      {/* Stock */}
                      <td className="py-3 px-4">
                        {p.restaurantId ? (
                          p.stock <= 0 ? (
                            <span className="text-[10px] font-black text-rose-500 bg-rose-500/10 px-2 py-0.5 rounded-full border border-rose-500/20">
                              Sold Out
                            </span>
                          ) : (
                            <span className="text-[10px] font-black text-emerald-600 bg-emerald-500/10 px-2 py-0.5 rounded-full border border-emerald-500/20">
                              In Stock
                            </span>
                          )
                        ) : p.stock <= 0 ? (
                          <span className="text-[10px] font-black text-rose-500 bg-rose-500/10 px-2 py-0.5 rounded-full border border-rose-500/20">
                            Out of Stock
                          </span>
                        ) : (
                          <div className="flex items-center gap-1">
                            <span className={`font-bold ${isLowStock ? 'text-discount font-extrabold' : 'text-text-primary'}`}>
                              {p.stock}
                            </span>
                            {isLowStock && (
                              <span title="Low stock warning">
                                <AlertCircle className="h-3.5 w-3.5 text-discount" />
                              </span>
                            )}
                          </div>
                        )}
                      </td>

                      {/* Status */}
                      <td className="py-3 px-4 text-center">
                        <button
                          type="button"
                          onClick={() => handleToggleProductAvailability(p.id, p.isAvailable)}
                          className={`px-2.5 py-0.5 rounded-full text-[9px] font-black transition-all border cursor-pointer hover:scale-105 active:scale-95 ${
                            p.isAvailable
                              ? 'bg-accent/15 text-accent border-accent/30 hover:bg-accent/25'
                              : 'bg-muted text-text-muted border-border hover:bg-muted/80'
                          }`}
                          title={p.isAvailable ? "Click to Disable Product" : "Click to Enable Product"}
                        >
                          {p.isAvailable ? 'Active ✓' : 'Disabled ✗'}
                        </button>
                      </td>

                      {/* Actions */}
                      <td className="py-3 px-4 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          <button
                            onClick={() => handleDuplicateProduct(p)}
                            className="px-2.5 py-1 border border-border bg-blue-500/5 hover:bg-blue-500/10 text-[10px] font-bold rounded-lg text-blue-600 dark:text-blue-400 transition-all"
                            title="Duplicate / Copy Product"
                          >
                            Copy
                          </button>
                          <button
                            onClick={() => startEditingProduct(p)}
                            className="px-2.5 py-1 border border-border hover:bg-muted text-[10px] font-bold rounded-lg text-text-secondary transition-all"
                          >
                            Edit
                          </button>
                          <button
                            onClick={() => handleDeleteProduct(p.id)}
                            className="p-1.5 border border-border text-discount hover:bg-discount/10 hover:border-discount/20 rounded-lg transition-colors"
                          >
                            <Trash className="h-3.5 w-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
        {renderPagination(productPage, productTotal, 10, setProductPage)}
      </div>

    </div>
  )
}
