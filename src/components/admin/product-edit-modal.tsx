'use client'

import { useState, useMemo } from 'react'
import { toast } from 'sonner'
import { X, Loader2, Check } from 'lucide-react'

export interface ProductEditForm {
  name: string
  description: string
  imageUrl: string
  categoryId: string
  restaurantId: string
  mrp: string
  price: string
  unit: string
  stock: string
  isAvailable: boolean
  tags: string
  minStock: string
  expiryDate: string
  costPrice: string
  location: string
  isFlashDeal: boolean
  isTopPick: boolean
  isBestSeller: boolean
  sortOrder: string
  barcode: string
}

export interface ProductVariant {
  name: string
  mrp: string
  price: string
  costPrice: string
  stock: string
}

export interface MenuSection {
  tag: string
  title: string
  emoji: string
}

export interface Restaurant {
  id: string
  name: string
  city?: string
  slug?: string
  menuSections?: any
}

export interface Category {
  id: string
  name: string
  slug?: string
  parentId?: string
}

export interface ProductEditModalProps {
  editingProduct: any | null
  productEditForm: ProductEditForm
  saveProductChanges: (e: React.FormEvent) => Promise<void>
  setEditingProduct: (product: any | null) => void
  setProductEditForm: (form: ProductEditForm | ((prev: ProductEditForm) => ProductEditForm)) => void
  setHasVariantsEdit: (value: boolean) => void
  setEditProductVariants: (variants: ProductVariant[]) => void
  setNewCustomTag: (value: string) => void
  setShowMediaLibrary: (value: boolean) => void
  setMediaTarget: (target: 'newProduct' | 'editProduct' | 'newCategory' | 'editCategory' | 'category' | null) => void
  handleCloudinaryUpload: (file: File, onUploadSuccess: (url: string) => void) => Promise<void>
  handleCreateCustomTag: (form: 'new' | 'edit', tagText: string) => void
  toggleTag: (form: 'new' | 'edit', tag: string, checked: boolean) => void
  savingProductId: string | null
  isUploading: boolean
  isEditProductCafe: boolean
  isEditProductRestaurant: boolean
  restaurantsList: Restaurant[]
  categories: Category[]
  settingsMap: Record<string, string>
  editProductVariants: ProductVariant[]
  hasVariantsEdit: boolean
  newCustomTag: string
  RESTAURANT_MENU_SECTIONS: MenuSection[]
  PRESET_KITCHEN_PHOTOS: any[]
}

export function ProductEditModal({
  editingProduct,
  productEditForm,
  saveProductChanges,
  setEditingProduct,
  setProductEditForm,
  setHasVariantsEdit,
  setEditProductVariants,
  setNewCustomTag,
  setShowMediaLibrary,
  setMediaTarget,
  handleCloudinaryUpload,
  handleCreateCustomTag,
  toggleTag,
  savingProductId,
  isUploading,
  restaurantsList,
  categories,
  settingsMap,
  editProductVariants,
  hasVariantsEdit,
  newCustomTag,
  RESTAURANT_MENU_SECTIONS,
}: ProductEditModalProps) {
  const isRestaurantMode = !!productEditForm.restaurantId
  const selectedRestaurant = useMemo(() => {
    return restaurantsList.find((r) => r.id === productEditForm.restaurantId)
  }, [productEditForm.restaurantId, restaurantsList])

  // Resolve dynamic menu sections for the specific restaurant
  const resolvedMenuSections = useMemo(() => {
    if (!productEditForm.restaurantId) return RESTAURANT_MENU_SECTIONS
    if (selectedRestaurant?.menuSections) {
      try {
        const raw = typeof selectedRestaurant.menuSections === 'string'
          ? JSON.parse(selectedRestaurant.menuSections)
          : selectedRestaurant.menuSections
        if (Array.isArray(raw) && raw.length > 0) {
          return raw.filter((s: any) => !s.disabled)
        }
      } catch (e) {
        console.error('Error parsing restaurant menuSections:', e)
      }
    }
    return RESTAURANT_MENU_SECTIONS
  }, [productEditForm.restaurantId, selectedRestaurant, RESTAURANT_MENU_SECTIONS])

  // Margin calculation for grocery
  const marginPercent = useMemo(() => {
    const p = parseFloat(productEditForm.price) || 0
    const c = parseFloat(productEditForm.costPrice) || 0
    if (p > 0 && c > 0 && p >= c) {
      return (((p - c) / p) * 100).toFixed(1)
    }
    return null
  }, [productEditForm.price, productEditForm.costPrice])

  // Food type check (Veg vs Non-Veg)
  const isVegDish = useMemo(() => {
    const tagsLower = productEditForm.tags.toLowerCase()
    return tagsLower.includes('veg') && !tagsLower.includes('nonveg') && !tagsLower.includes('non-veg')
  }, [productEditForm.tags])

  const handleToggleVeg = (veg: boolean) => {
    let cleanTags = productEditForm.tags
      .split(',')
      .map(t => t.trim())
      .filter(t => t.toLowerCase() !== 'veg' && t.toLowerCase() !== 'nonveg' && t.toLowerCase() !== 'non-veg')
    
    cleanTags.push(veg ? 'veg' : 'nonveg')
    setProductEditForm({ ...productEditForm, tags: cleanTags.filter(Boolean).join(', ') })
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in p-3 sm:p-4">
      <div className="bg-card border border-border rounded-2xl shadow-2xl w-full max-w-2xl max-h-[92vh] flex flex-col overflow-hidden animate-scale-up">
        {/* Modal Header */}
        <div className="flex justify-between items-center px-5 py-4 border-b border-border bg-muted/20">
          <div>
            <h4 className="font-black text-text-primary text-sm sm:text-base leading-tight">
              Edit {isRestaurantMode ? 'Restaurant Dish' : 'Grocery Product'}: {editingProduct?.name}
            </h4>
            <p className="text-[11px] text-text-secondary">
              {isRestaurantMode ? `Outlet: ${selectedRestaurant?.name || 'Restaurant'}` : 'General Kirana Store Catalog'}
            </p>
          </div>
          <button
            onClick={() => setEditingProduct(null)}
            className="p-1.5 rounded-lg text-text-secondary hover:text-text-primary hover:bg-muted/40 transition-colors"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Modal Body / Form */}
        <form onSubmit={saveProductChanges} className="flex-1 overflow-y-auto p-5 space-y-5">
          {/* Card 1: Store / Outlet Assignment */}
          <div className="p-3.5 rounded-xl border border-primary/20 bg-primary/5 space-y-1.5">
            <label className="text-[10px] font-black text-primary uppercase tracking-wider block">
              Store / Restaurant Outlet Assignment *
            </label>
            <select
              value={productEditForm.restaurantId}
              onChange={(e) => {
                const newRestId = e.target.value
                setProductEditForm({
                  ...productEditForm,
                  restaurantId: newRestId,
                  unit: newRestId ? (productEditForm.unit || '1 Serving') : (productEditForm.unit || '1 kg'),
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

          {/* Card 2: Essential Details (Name, Photo, Description) */}
          <div className="p-4 rounded-xl border border-border bg-card space-y-3.5">
            <h5 className="text-xs font-black text-text-primary uppercase tracking-wider">
              📝 Core Information
            </h5>

            <div className="grid grid-cols-1 gap-3">
              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">
                  {isRestaurantMode ? 'Dish Name *' : 'Product Name *'}
                </label>
                <input
                  type="text"
                  required
                  value={productEditForm.name}
                  onChange={(e) => setProductEditForm({ ...productEditForm, name: e.target.value })}
                  placeholder={isRestaurantMode ? 'e.g. Paneer Butter Masala' : 'e.g. Tata Salt 1kg'}
                  className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
              </div>

              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">
                  {isRestaurantMode ? 'Dish Description / Ingredients' : 'Product Description'}
                </label>
                <textarea
                  rows={2}
                  value={productEditForm.description || ''}
                  onChange={(e) => setProductEditForm({ ...productEditForm, description: e.target.value })}
                  placeholder={isRestaurantMode ? 'e.g. Rich cashew tomato gravy with soft malai paneer cubes.' : 'Product details, manufacturer, and benefits.'}
                  className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-normal"
                />
              </div>

              {/* Photo Upload & Preview */}
              <div className="space-y-2">
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Photo / Image URL</label>
                <input
                  type="text"
                  placeholder="Paste image absolute URL..."
                  value={productEditForm.imageUrl}
                  onChange={(e) => setProductEditForm({ ...productEditForm, imageUrl: e.target.value })}
                  className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
                <div className="flex flex-wrap items-center gap-2">
                  <label
                    htmlFor="edit-product-image-file"
                    className="cursor-pointer px-3.5 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary text-xs font-black rounded-xl border border-primary/20 transition-all flex items-center gap-1.5"
                  >
                    {isUploading ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : '📤 Upload New Photo'}
                  </label>
                  <button
                    type="button"
                    onClick={() => {
                      setMediaTarget('editProduct')
                      setShowMediaLibrary(true)
                    }}
                    className="px-3.5 py-1.5 bg-amber-500/15 hover:bg-amber-500/25 text-amber-600 dark:text-amber-400 text-xs font-black rounded-xl border border-amber-500/30 transition-all flex items-center gap-1.5 cursor-pointer"
                  >
                    🖼️ Choose from Photo Library
                  </button>
                  <input
                    id="edit-product-image-file"
                    type="file"
                    accept="image/*"
                    onChange={(e) => {
                      const file = e.target.files?.[0]
                      if (file) {
                        handleCloudinaryUpload(file, (url) => {
                          setProductEditForm({ ...productEditForm, imageUrl: url })
                        })
                      }
                      e.target.value = ''
                    }}
                    className="sr-only"
                    disabled={isUploading}
                  />
                </div>
                {productEditForm.imageUrl && (
                  <div className="h-20 w-20 relative overflow-hidden rounded-xl border border-border bg-white/5 p-1 mt-1">
                    <img src={productEditForm.imageUrl} alt="Preview" className="h-full w-full object-contain" />
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Card 3A: GROCERY-SPECIFIC CONTROLS */}
          {!isRestaurantMode && (
            <div className="p-4 rounded-xl border border-border bg-card space-y-4">
              <h5 className="text-xs font-black text-primary uppercase tracking-wider">
                📦 Grocery Categories, Pricing & Warehouse Inventory
              </h5>

              {/* Main & Sub Categories */}
              {(() => {
                const currentCat = categories.find(c => c.id === productEditForm.categoryId)
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
                          setProductEditForm({ ...productEditForm, categoryId: newParentId })
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
                          setProductEditForm({ ...productEditForm, categoryId: subId || activeParentId })
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
                    required={!hasVariantsEdit}
                    value={productEditForm.mrp}
                    onChange={(e) => setProductEditForm({ ...productEditForm, mrp: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Selling Price (₹) *</label>
                  <input
                    type="number"
                    step="0.01"
                    required={!hasVariantsEdit}
                    value={productEditForm.price}
                    onChange={(e) => setProductEditForm({ ...productEditForm, price: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-bold text-primary"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">
                    Cost Price (₹) {marginPercent ? `(Margin: ${marginPercent}%)` : ''}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    value={productEditForm.costPrice}
                    onChange={(e) => setProductEditForm({ ...productEditForm, costPrice: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
              </div>

              {/* Inventory, Unit, Stock & Alerts */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Stock Quantity *</label>
                  <input
                    type="number"
                    required={!hasVariantsEdit}
                    value={productEditForm.stock}
                    onChange={(e) => setProductEditForm({ ...productEditForm, stock: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Min Stock Alert Level</label>
                  <input
                    type="number"
                    value={productEditForm.minStock}
                    onChange={(e) => setProductEditForm({ ...productEditForm, minStock: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Unit (e.g. 1 kg, 500 gm)</label>
                  <input
                    type="text"
                    value={productEditForm.unit}
                    onChange={(e) => setProductEditForm({ ...productEditForm, unit: e.target.value })}
                    placeholder="e.g. 1 kg, 12 pcs"
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
                    value={productEditForm.barcode}
                    onChange={(e) => setProductEditForm({ ...productEditForm, barcode: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Warehouse / Aisle Location</label>
                  <input
                    type="text"
                    placeholder="e.g. Aisle 3-B"
                    value={productEditForm.location || ''}
                    onChange={(e) => setProductEditForm({ ...productEditForm, location: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Expiry Date</label>
                  <input
                    type="date"
                    value={productEditForm.expiryDate ? productEditForm.expiryDate.split('T')[0] : ''}
                    onChange={(e) => setProductEditForm({ ...productEditForm, expiryDate: e.target.value })}
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
                  value={productEditForm.sortOrder}
                  onChange={(e) => setProductEditForm({ ...productEditForm, sortOrder: e.target.value })}
                  className="w-full bg-muted/20 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold text-text-primary"
                />
                <p className="text-[9px] text-text-muted">Higher numbers display first/on top in category listings. Default is 0.</p>
              </div>

              {/* Badges / Promotion flags */}
              <div className="pt-2 border-t border-border flex flex-wrap gap-4">
                <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={productEditForm.isAvailable}
                    onChange={(e) => setProductEditForm({ ...productEditForm, isAvailable: e.target.checked })}
                    className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                  />
                  <span>🟢 Available for Sale</span>
                </label>
                <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={productEditForm.isBestSeller}
                    onChange={(e) => setProductEditForm({ ...productEditForm, isBestSeller: e.target.checked })}
                    className="h-4 w-4 text-amber-500 focus:ring-amber-500 border-border rounded cursor-pointer"
                  />
                  <span>🏆 Best Seller</span>
                </label>
                <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={productEditForm.isTopPick}
                    onChange={(e) => setProductEditForm({ ...productEditForm, isTopPick: e.target.checked })}
                    className="h-4 w-4 text-indigo-500 focus:ring-indigo-500 border-border rounded cursor-pointer"
                  />
                  <span>⭐ Top Pick</span>
                </label>
                <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={productEditForm.isFlashDeal}
                    onChange={(e) => setProductEditForm({ ...productEditForm, isFlashDeal: e.target.checked })}
                    className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                  />
                  <span>⚡ Flash Deal</span>
                </label>
              </div>
            </div>
          )}

          {/* Card 3B: RESTAURANT-SPECIFIC CONTROLS */}
          {isRestaurantMode && (
            <div className="p-4 rounded-xl border border-amber-500/30 bg-amber-500/5 dark:bg-amber-955/15 space-y-4">
              <h5 className="text-xs font-black text-amber-600 dark:text-amber-400 uppercase tracking-wider">
                🍽️ Restaurant Menu & Kitchen Controls
              </h5>

              {/* Menu Section & Portion Unit */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">
                    Restaurant Menu Section * (Synced with {selectedRestaurant?.name || 'Outlet'})
                  </label>
                  <select
                    required
                    value={resolvedMenuSections.find(sec => productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes(sec.tag))?.tag || ''}
                    onChange={(e) => {
                      const val = e.target.value
                      const sectionValues = resolvedMenuSections.map(s => s.tag)
                      let cleanTags = productEditForm.tags
                        .split(',')
                        .map(t => t.trim())
                        .filter(t => t.length > 0 && !sectionValues.includes(t.toLowerCase()))

                      if (val) cleanTags.push(val)
                      if (!cleanTags.map(t => t.toLowerCase()).includes('restaurant')) cleanTags.push('restaurant')
                      setProductEditForm({ ...productEditForm, tags: cleanTags.join(', ') })
                    }}
                    className="w-full px-3 py-2 text-xs rounded-xl border border-amber-500/40 bg-card focus:outline-none focus:border-amber-500 font-black text-amber-600 dark:text-amber-400 cursor-pointer shadow-xs"
                  >
                    <option value="">-- Select Menu Section --</option>
                    {resolvedMenuSections.map((sec) => (
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
                    value={productEditForm.unit}
                    onChange={(e) => setProductEditForm({ ...productEditForm, unit: e.target.value })}
                    placeholder="e.g. 1 Plate, 1 Serving, 2 Pcs, 500 ml"
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
                    value={productEditForm.mrp}
                    onChange={(e) => setProductEditForm({ ...productEditForm, mrp: e.target.value })}
                    placeholder="e.g. 240"
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-amber-500 font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Restaurant Selling Price (₹) *</label>
                  <input
                    type="number"
                    step="0.01"
                    required={!hasVariantsEdit}
                    value={productEditForm.price}
                    onChange={(e) => setProductEditForm({ ...productEditForm, price: e.target.value })}
                    placeholder="e.g. 220"
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
                  value={productEditForm.sortOrder}
                  onChange={(e) => setProductEditForm({ ...productEditForm, sortOrder: e.target.value })}
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
                      onClick={() => handleToggleVeg(true)}
                      className={`px-2.5 py-1 rounded-md text-[11px] font-black transition-all cursor-pointer ${
                        isVegDish ? 'bg-emerald-500 text-white shadow-xs' : 'text-text-secondary hover:text-text-primary'
                      }`}
                    >
                      🟢 Pure Veg
                    </button>
                    <button
                      type="button"
                      onClick={() => handleToggleVeg(false)}
                      className={`px-2.5 py-1 rounded-md text-[11px] font-black transition-all cursor-pointer ${
                        !isVegDish ? 'bg-rose-500 text-white shadow-xs' : 'text-text-secondary hover:text-text-primary'
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
                      checked={parseInt(productEditForm.stock) > 0 || (productEditForm.stock === '' && productEditForm.isAvailable)}
                      onChange={(e) => {
                        const inStock = e.target.checked
                        setProductEditForm({
                          ...productEditForm,
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
                      checked={productEditForm.isAvailable}
                      onChange={(e) => setProductEditForm({ ...productEditForm, isAvailable: e.target.checked })}
                      className="h-4 w-4 text-blue-500 focus:ring-blue-500 border-border rounded cursor-pointer"
                    />
                    <span>👁️ Show on Storefront</span>
                  </label>
                  <label className="flex items-center gap-1.5 text-xs font-bold text-text-primary cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={productEditForm.isBestSeller}
                      onChange={(e) => setProductEditForm({ ...productEditForm, isBestSeller: e.target.checked })}
                      className="h-4 w-4 text-amber-500 focus:ring-amber-500 border-border rounded cursor-pointer"
                    />
                    <span>⭐ Chef Special</span>
                  </label>
                </div>
              </div>
            </div>
          )}

          {/* Card 4: Multi-Variants (Portions / Pack Sizes) */}
          <div className="p-4 rounded-xl border border-border bg-card space-y-3">
            <div className="flex items-center justify-between">
              <label className="text-xs font-bold text-text-primary flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={hasVariantsEdit}
                  onChange={(e) => setHasVariantsEdit(e.target.checked)}
                  className="rounded border-border text-primary focus:ring-primary h-4 w-4 cursor-pointer"
                />
                <span>{isRestaurantMode ? 'This dish has portion sizes (e.g. Half / Full)' : 'This product has multiple size/weight options (Variants)'}</span>
              </label>
            </div>

            {hasVariantsEdit && (
              <div className="space-y-3 pt-2 border-t border-border">
                {editProductVariants.length > 0 && (
                  <div className="space-y-2 max-h-56 overflow-y-auto pr-1">
                    {editProductVariants.map((v, idx) => (
                      <div key={idx} className="p-2.5 rounded-xl border border-border/80 bg-muted/15 space-y-1.5 shadow-2xs">
                        <div className="flex items-center justify-between gap-2">
                          <span className="text-[10px] font-black uppercase text-primary tracking-wider">Option #{idx + 1}</span>
                          <button
                            type="button"
                            onClick={() => setEditProductVariants(editProductVariants.filter((_, i) => i !== idx))}
                            className="text-[10px] text-rose-500 hover:text-rose-600 font-extrabold cursor-pointer"
                          >
                            Remove ✕
                          </button>
                        </div>
                        <div className={`grid grid-cols-2 ${!isRestaurantMode ? 'sm:grid-cols-4' : 'sm:grid-cols-3'} gap-2 items-center`}>
                          <div>
                            <label className="text-[9px] font-bold text-text-muted block mb-0.5">Name</label>
                            <input
                              type="text"
                              value={v.name}
                              onChange={(e) => {
                                const updated = [...editProductVariants]
                                updated[idx] = { ...updated[idx], name: e.target.value }
                                setEditProductVariants(updated)
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
                                const updated = [...editProductVariants]
                                updated[idx] = { ...updated[idx], mrp: e.target.value }
                                setEditProductVariants(updated)
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
                                const updated = [...editProductVariants]
                                updated[idx] = { ...updated[idx], price: e.target.value }
                                setEditProductVariants(updated)
                              }}
                              className="w-full px-2 py-1 text-xs font-extrabold text-accent rounded-lg border bg-background focus:outline-none focus:border-primary"
                            />
                          </div>
                          {!isRestaurantMode && (
                            <div>
                              <label className="text-[9px] font-bold text-text-muted block mb-0.5">Stock</label>
                              <input
                                type="number"
                                value={v.stock}
                                onChange={(e) => {
                                  const updated = [...editProductVariants]
                                  updated[idx] = { ...updated[idx], stock: e.target.value }
                                  setEditProductVariants(updated)
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

                <div className={`grid grid-cols-2 ${!isRestaurantMode ? 'sm:grid-cols-5' : 'sm:grid-cols-4'} gap-2 items-end`}>
                  <div>
                    <label className="text-[9px] font-bold text-text-secondary block mb-1">
                      {isRestaurantMode ? 'Portion Name (e.g. Half / Full)' : 'Variant Name'}
                    </label>
                    <input
                      type="text"
                      id="edit-var-name"
                      placeholder={isRestaurantMode ? 'Half Plate' : '500 gm'}
                      className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="text-[9px] font-bold text-text-secondary block mb-1">MRP Price (₹)</label>
                    <input
                      type="number"
                      id="edit-var-mrp"
                      placeholder="MRP"
                      className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none"
                    />
                  </div>
                  <div>
                    <label className="text-[9px] font-bold text-text-secondary block mb-1">Selling Price (₹) *</label>
                    <input
                      type="number"
                      id="edit-var-price"
                      placeholder="Price"
                      className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none font-bold"
                    />
                  </div>
                  {!isRestaurantMode && (
                    <div>
                      <label className="text-[9px] font-bold text-text-secondary block mb-1">Stock (Units)</label>
                      <input
                        type="number"
                        id="edit-var-stock"
                        placeholder="100"
                        defaultValue="100"
                        className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none font-bold"
                      />
                    </div>
                  )}
                  <div>
                    <button
                      type="button"
                      onClick={() => {
                        const nameInput = document.getElementById('edit-var-name') as HTMLInputElement
                        const mrpInput = document.getElementById('edit-var-mrp') as HTMLInputElement
                        const priceInput = document.getElementById('edit-var-price') as HTMLInputElement
                        const stockInput = document.getElementById('edit-var-stock') as HTMLInputElement | null

                        const name = nameInput.value.trim()
                        const mrp = mrpInput.value.trim() || priceInput.value.trim()
                        const price = priceInput.value.trim()
                        const stock = stockInput ? stockInput.value.trim() || '100' : (isRestaurantMode ? '9999' : '100')

                        if (!name || !price) {
                          toast.error('Please enter portion name and price')
                          return
                        }

                        const newVars = [...editProductVariants, { name, mrp, price, costPrice: '0', stock }]
                        newVars.sort((a, b) => (parseFloat(a.price) || 0) - (parseFloat(b.price) || 0))
                        setEditProductVariants(newVars)
                        nameInput.value = ''
                        mrpInput.value = ''
                        priceInput.value = ''
                        if (stockInput) stockInput.value = '100'
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

          {/* Card 5: Search Keywords & Custom Tags */}
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
                    handleCreateCustomTag('edit', newCustomTag)
                  }
                }}
                className="flex-1 px-3 py-1.5 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
              <button
                type="button"
                onClick={() => handleCreateCustomTag('edit', newCustomTag)}
                className="px-3 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary text-[10px] font-black rounded-xl border border-primary/20 transition-all cursor-pointer"
              >
                + Add Tag
              </button>
            </div>
            {productEditForm.tags.trim() && (
              <div className="flex flex-wrap gap-1.5 pt-1">
                {productEditForm.tags.split(',').map(t => t.trim()).filter(Boolean).map(tag => (
                  <span key={tag} className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-muted text-[11px] font-bold text-text-primary">
                    <span>{tag}</span>
                    <button
                      type="button"
                      onClick={() => toggleTag('edit', tag, false)}
                      className="text-text-muted hover:text-rose-500 font-extrabold text-[10px] ml-0.5 cursor-pointer"
                    >
                      ×
                    </button>
                  </span>
                ))}
              </div>
            )}
          </div>

          {/* Modal Footer / Save Actions */}
          <div className="flex items-center justify-end gap-3 pt-3 border-t border-border">
            <button
              type="button"
              onClick={() => setEditingProduct(null)}
              className="px-4 py-2 text-xs font-bold text-text-secondary hover:text-text-primary rounded-xl border border-border bg-card transition-colors cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={savingProductId !== null}
              className="px-6 py-2 text-xs font-black text-white bg-primary hover:bg-primary/90 rounded-xl transition-all shadow-md flex items-center gap-1.5 cursor-pointer disabled:opacity-50"
            >
              {savingProductId !== null ? (
                <>
                  <Loader2 className="h-3.5 w-3.5 animate-spin" />
                  <span>Saving...</span>
                </>
              ) : (
                <>
                  <Check className="h-4 w-4" />
                  <span>Save Changes</span>
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default ProductEditModal
