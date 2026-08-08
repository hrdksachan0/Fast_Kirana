'use client'

import { useState, useMemo } from 'react'
import { toast } from 'sonner'
import { X, Loader2 } from 'lucide-react'

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
  newCustomTag: string
  RESTAURANT_MENU_SECTIONS: MenuSection[]
  PRESET_KITCHEN_PHOTOS: any[]
}

function ProductEditModal({
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
  isEditProductCafe,
  isEditProductRestaurant,
  restaurantsList,
  categories,
  settingsMap,
  editProductVariants,
  newCustomTag,
  RESTAURANT_MENU_SECTIONS,
}: ProductEditModalProps) {
  const hasVariantsEdit = useMemo(() => editProductVariants.length > 0 || productEditForm.tags.includes('variant'), [editProductVariants, productEditForm])

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in p-4">
      <div className="bg-card border border-border rounded-2xl shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto p-6 animate-scale-up space-y-4">
        <div className="flex justify-between items-center border-b border-border/60 pb-3">
          <h4 className="font-extrabold text-text-primary text-base">Edit Product: {editingProduct?.name}</h4>
          <button onClick={() => setEditingProduct(null)} className="text-text-secondary hover:text-text-primary">
            <X className="h-5 w-5" />
          </button>
        </div>
        <form onSubmit={saveProductChanges} className="space-y-4">
          {/* Store / Outlet Selector */}
          <div className="bg-primary/5 border border-primary/20 rounded-xl p-3">
            <label className="text-[10px] font-bold text-text-secondary block mb-1">Assign to Store / Restaurant Outlet *</label>
            <select
              value={productEditForm.restaurantId}
              onChange={(e) => setProductEditForm({ ...productEditForm, restaurantId: e.target.value })}
              className="w-full px-3 py-2 text-xs rounded-xl border border-primary/30 bg-card focus:outline-none focus:border-primary font-bold text-text-primary cursor-pointer shadow-2xs"
            >
              <option value="">🛒 General Kirana / Grocery Store</option>
              {restaurantsList.map((r) => (
                <option key={r.id} value={r.id}>
                  🍽️ Restaurant: {r.name} ({r.city || 'Outlet'})
                </option>
              ))}
            </select>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Product Name *</label>
              <input
                type="text"
                required
                value={productEditForm.name}
                onChange={(e) => setProductEditForm({ ...productEditForm, name: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>
            {!productEditForm.restaurantId ? (() => {
              const currentCat = categories.find(c => c.id === productEditForm.categoryId)
              const activeParentId = currentCat ? (currentCat.parentId || currentCat.id) : ''
              const activeSubId = currentCat && currentCat.parentId ? currentCat.id : ''

              const parentCategories = categories.filter((c) => {
                const slug = (c.slug || '').toLowerCase()
                const name = (c.name || '').toLowerCase()
                return !c.parentId && slug !== 'cafe' && slug !== 'restaurant' && !name.includes('fastkirana restaurant') && !name.includes('fastkirana cafe')
              })

              const availableSubcategories = activeParentId
                ? categories.filter((c) => c.parentId === activeParentId)
                : []

              return (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 col-span-1 sm:col-span-2">
                  <div>
                    <label className="text-[10px] font-bold text-text-secondary block mb-1">Main Category *</label>
                    <select
                      required={!productEditForm.restaurantId}
                      value={activeParentId}
                      onChange={(e) => {
                        const newParentId = e.target.value
                        setProductEditForm({ ...productEditForm, categoryId: newParentId })
                      }}
                      className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold cursor-pointer"
                    >
                      <option value="">-- Select Parent Category --</option>
                      {parentCategories.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name}
                        </option>
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
                        {availableSubcategories.length === 0
                          ? '(No subcategories created yet)'
                          : '-- All / Main Category --'}
                      </option>
                      {availableSubcategories.map((sub) => (
                        <option key={sub.id} value={sub.id}>
                          └ {sub.name}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
              )
            })() : (
              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Restaurant Menu Section *</label>
                <select
                  required
                  value={RESTAURANT_MENU_SECTIONS.find(sec => productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes(sec.tag))?.tag || ''}
                  onChange={(e) => {
                    const val = e.target.value;
                    const sectionValues = RESTAURANT_MENU_SECTIONS.map(s => s.tag);
                    let cleanTags = productEditForm.tags
                      .split(',')
                      .map(t => t.trim())
                      .filter(t => t.length > 0 && !sectionValues.includes(t.toLowerCase()));

                    if (val) {
                      cleanTags.push(val);
                    }
                    if (!cleanTags.map(t => t.toLowerCase()).includes('restaurant')) {
                      cleanTags.push('restaurant');
                    }
                    setProductEditForm({ ...productEditForm, tags: cleanTags.join(', ') });
                  }}
                  className="w-full px-3 py-2 text-xs rounded-xl border border-amber-500/30 bg-amber-500/5 dark:bg-amber-955/15 focus:outline-none focus:border-amber-500 font-extrabold text-amber-600 dark:text-amber-400 cursor-pointer"
                >
                  <option value="" className="text-text-primary font-normal">-- Select Menu Section --</option>
                  {RESTAURANT_MENU_SECTIONS.map((sec) => (
                    <option key={sec.tag} value={sec.tag} className="text-text-primary font-semibold">
                      {sec.emoji} {sec.title}
                    </option>
                  ))}
                </select>
              </div>
            )}

            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Unit Specification</label>
              <input
                type="text"
                value={productEditForm.unit}
                onChange={(e) => setProductEditForm({ ...productEditForm, unit: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>
            {!hasVariantsEdit && (
              <>
                {!productEditForm.restaurantId && !isEditProductCafe && !isEditProductRestaurant && (
                  <div>
                    <label className="text-[10px] font-bold text-text-secondary block mb-1">Stock Qty *</label>
                    <input
                      type="number"
                      required={!hasVariantsEdit && !productEditForm.restaurantId}
                      value={productEditForm.stock}
                      onChange={(e) => setProductEditForm({ ...productEditForm, stock: e.target.value })}
                      className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    />
                  </div>
                )}
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">MRP Price (INR) *</label>
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
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">FastKirana Discounted Price (INR) *</label>
                  <input
                    type="number"
                    step="0.01"
                    required={!hasVariantsEdit}
                    value={productEditForm.price}
                    onChange={(e) => {
                      const val = e.target.value
                      let calculatedCost = productEditForm.costPrice
                      if (isEditProductCafe || isEditProductRestaurant) {
                        const marginKey = isEditProductCafe ? 'cafe_default_margin' : 'restaurant_default_margin'
                        const marginPercent = parseFloat(settingsMap[marginKey] || '30')
                        const priceNum = parseFloat(val) || 0
                        calculatedCost = (priceNum * (1 - marginPercent / 100)).toFixed(2)
                      }
                      setProductEditForm({ ...productEditForm, price: val, costPrice: calculatedCost })
                    }}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
              </>
            )}

            <div className="md:col-span-2 border border-border/60 bg-muted/5 p-4 rounded-xl space-y-3">
              <div className="flex items-center justify-between">
                <label className="text-xs font-bold text-text-primary flex items-center gap-1.5 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={hasVariantsEdit}
                    onChange={(e) => setHasVariantsEdit(e.target.checked)}
                    className="rounded border-border text-primary focus:ring-primary h-4 w-4"
                  />
                  This product has multiple size/weight variations (Variants)
                </label>
              </div>

              {hasVariantsEdit && (
                <div className="space-y-3 pt-2 border-t border-border/60">
                  {editProductVariants.length > 0 && (
                    <div className="space-y-1.5 max-h-40 overflow-y-auto pr-1">
                      {editProductVariants.map((v, idx) => (
                        <div key={idx} className="flex justify-between items-center bg-card border border-border/50 px-3 py-1.5 rounded-lg text-xs font-semibold">
                          <span>{v.name} (Price: ₹{v.price}, MRP: ₹{v.mrp}, Cost: ₹{v.costPrice || 0}, Stock: {v.stock})</span>
                          <button
                            type="button"
                            onClick={() => setEditProductVariants(editProductVariants.filter((_, i) => i !== idx))}
                            className="text-[10px] text-red-500 hover:text-red-600 font-bold cursor-pointer"
                          >
                            Remove
                          </button>
                        </div>
                      ))}
                    </div>
                  )}

                  <div className="grid grid-cols-5 gap-2 items-end">
                    <div>
                      <label className="text-[9px] font-bold text-text-secondary block mb-1">Variant Name</label>
                      <input
                        type="text"
                        id="edit-var-name"
                        placeholder="e.g. Small, 500g"
                        className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none"
                      />
                    </div>
                    <div>
                      <label className="text-[9px] font-bold text-text-secondary block mb-1">MRP Price</label>
                      <input
                        type="number"
                        id="edit-var-mrp"
                        placeholder="MRP"
                        className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none"
                      />
                    </div>
                    <div>
                      <label className="text-[9px] font-bold text-text-secondary block mb-1">Selling Price</label>
                      <input
                        type="number"
                        id="edit-var-price"
                        placeholder="Selling"
                        onChange={(e) => {
                          if (isEditProductCafe || isEditProductRestaurant) {
                            const costInput = document.getElementById('edit-var-cost') as HTMLInputElement
                            if (costInput) {
                              const marginKey = isEditProductCafe ? 'cafe_default_margin' : 'restaurant_default_margin'
                              const marginPercent = parseFloat(settingsMap[marginKey] || '30')
                              const priceVal = parseFloat(e.target.value) || 0
                              costInput.value = (priceVal * (1 - marginPercent / 100)).toFixed(2)
                            }
                          }
                        }}
                        className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none"
                      />
                    </div>
                    <div>
                      <label className="text-[9px] font-bold text-text-secondary block mb-1">Cost Price</label>
                      <input
                        type="number"
                        id="edit-var-cost"
                        placeholder="Cost"
                        className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none"
                      />
                    </div>
                    <div>
                      <label className="text-[9px] font-bold text-text-secondary block mb-1">Stock</label>
                      <input
                        type="number"
                        id="edit-var-stock"
                        placeholder="Qty"
                        className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none"
                      />
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      const nameInput = document.getElementById('edit-var-name') as HTMLInputElement
                      const mrpInput = document.getElementById('edit-var-mrp') as HTMLInputElement
                      const priceInput = document.getElementById('edit-var-price') as HTMLInputElement
                      const costInput = document.getElementById('edit-var-cost') as HTMLInputElement
                      const stockInput = document.getElementById('edit-var-stock') as HTMLInputElement

                      const name = nameInput.value.trim()
                      const mrp = mrpInput.value.trim()
                      const price = priceInput.value.trim()
                      const costPrice = costInput.value.trim() || '0'
                      const stock = stockInput.value.trim()

                      if (!name || !mrp || !price || !stock) {
                        toast.error('Please fill in all variant fields')
                        return
                      }

                      const newVars = [...editProductVariants, { name, mrp, price, costPrice, stock }]
                      newVars.sort((a, b) => (parseFloat(a.price) || 0) - (parseFloat(b.price) || 0))
                      setEditProductVariants(newVars)
                      nameInput.value = ''
                      mrpInput.value = ''
                      priceInput.value = ''
                      costInput.value = ''
                      stockInput.value = ''
                    }}
                    className="w-full py-1.5 text-[10px] font-bold bg-primary/10 hover:bg-primary/20 text-primary border border-primary/25 rounded-lg transition-colors cursor-pointer"
                  >
                    + Add Variant Option
                  </button>
                </div>
              )}
            </div>
            <div className="space-y-2">
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Product Photo / Image (Cloudinary)</label>
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
                  className="cursor-pointer px-3.5 py-2 bg-primary/10 hover:bg-primary/20 text-primary text-xs font-black rounded-xl border border-primary/20 transition-all flex items-center gap-1.5 whitespace-nowrap"
                >
                  {isUploading ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : '📤 Upload File'}
                </label>
                <button
                  type="button"
                  onClick={() => {
                    setMediaTarget('editProduct')
                    setShowMediaLibrary(true)
                  }}
                  className="px-3.5 py-2 bg-amber-500/15 hover:bg-amber-500/25 text-amber-600 dark:text-amber-400 text-xs font-black rounded-xl border border-amber-500/30 transition-all flex items-center gap-1.5 whitespace-nowrap cursor-pointer shadow-2xs"
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
            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Tags (comma-separated)</label>
              <input
                type="text"
                value={productEditForm.tags}
                onChange={(e) => setProductEditForm({ ...productEditForm, tags: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>
            {!isEditProductCafe && !isEditProductRestaurant && (
              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Min Stock Alert Level</label>
                <input
                  type="number"
                  value={productEditForm.minStock}
                  onChange={(e) => setProductEditForm({ ...productEditForm, minStock: e.target.value })}
                  className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
              </div>
            )}
            {!isEditProductCafe && !isEditProductRestaurant && (
              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Barcode (EAN/UPC)</label>
                <input
                  type="text"
                  placeholder="Scan or enter barcode"
                  value={productEditForm.barcode}
                  onChange={(e) => setProductEditForm({ ...productEditForm, barcode: e.target.value })}
                  className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
              </div>
            )}
            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Cost Price (INR)</label>
              <input
                type="number"
                step="0.01"
                value={productEditForm.costPrice}
                onChange={(e) => setProductEditForm({ ...productEditForm, costPrice: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>
            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Aisle/Shelf Location</label>
              <input
                type="text"
                placeholder="e.g. Aisle 2-B"
                value={productEditForm.location || ''}
                onChange={(e) => setProductEditForm({ ...productEditForm, location: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>

            {!isEditProductCafe && !isEditProductRestaurant && (
              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Expiry Date</label>
                <input
                  type="date"
                  value={productEditForm.expiryDate ? productEditForm.expiryDate.split('T')[0] : ''}
                  onChange={(e) => setProductEditForm({ ...productEditForm, expiryDate: e.target.value })}
                  className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
              </div>
            )}

            <div className="md:col-span-2 flex flex-wrap gap-x-6 gap-y-2 pt-2 border-t border-border/40">
              <span className="text-[10px] font-extrabold text-text-secondary block w-full">Quick Tags / Smart Features</span>

              {/* Common tags */}
              <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('popular')}
                  onChange={(e) => toggleTag('edit', 'popular', e.target.checked)}
                  className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                />
                <span>🔥 Trending (Popular)</span>
              </label>
              <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('cafe')}
                  onChange={(e) => toggleTag('edit', 'cafe', e.target.checked)}
                  className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                />
                <span>☕ Cafe Item</span>
              </label>

              {/* Cafe specific tags */}
              {isEditProductCafe ? (
                <>
                  <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('sandwiches')}
                      onChange={(e) => toggleTag('edit', 'sandwiches', e.target.checked)}
                      className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                    />
                    <span>🥪 Cafe: Sandwiches</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('italian-pasta')}
                      onChange={(e) => toggleTag('edit', 'italian-pasta', e.target.checked)}
                      className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                    />
                    <span>🍝 Cafe: Italian Pasta</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('bombay-bites')}
                      onChange={(e) => toggleTag('edit', 'bombay-bites', e.target.checked)}
                      className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                    />
                    <span>🥪 Cafe: Bombay Bites</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('rice-dishes')}
                      onChange={(e) => toggleTag('edit', 'rice-dishes', e.target.checked)}
                      className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                    />
                    <span>🍚 Cafe: Rice Dishes</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('shakes')}
                      onChange={(e) => toggleTag('edit', 'shakes', e.target.checked)}
                      className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                    />
                    <span>🥤 Cafe: Shakes</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('mocktails')}
                      onChange={(e) => toggleTag('edit', 'mocktails', e.target.checked)}
                      className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                    />
                    <span>🍹 Cafe: Mocktails</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('cold-coffee')}
                      onChange={(e) => toggleTag('edit', 'cold-coffee', e.target.checked)}
                      className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                    />
                    <span>🧋 Cafe: Cold Coffee</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('frankie-rolls')}
                      onChange={(e) => toggleTag('edit', 'frankie-rolls', e.target.checked)}
                      className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                    />
                    <span>🌯 Cafe: Frankie Rolls</span>
                  </label>
                </>
              ) : (
                <>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('hot-beverage')}
                      onChange={(e) => toggleTag('edit', 'hot-beverage', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>☕ Hot Beverage</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('hot-bite')}
                      onChange={(e) => toggleTag('edit', 'hot-bite', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>🥟 Hot Bite / Snack</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('chinese')}
                      onChange={(e) => toggleTag('edit', 'chinese', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>🥡 Chinese</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('south-indian')}
                      onChange={(e) => toggleTag('edit', 'south-indian', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>🍛 South Indian</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('breakfast')}
                      onChange={(e) => toggleTag('edit', 'breakfast', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>🍳 Breakfast Essential</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('snacks')}
                      onChange={(e) => toggleTag('edit', 'snacks', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>🍿 Snacks</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('dairy')}
                      onChange={(e) => toggleTag('edit', 'dairy', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>🥛 Dairy</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('staples')}
                      onChange={(e) => toggleTag('edit', 'staples', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>🌾 Staples</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('beverages')}
                      onChange={(e) => toggleTag('edit', 'beverages', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>🥤 Beverages</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('late-night')}
                      onChange={(e) => toggleTag('edit', 'late-night', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>🌙 Late Night Craving</span>
                  </label>
                </>
              )}
            </div>

            {/* Custom Tag Creator */}
            <div className="md:col-span-3 pt-3 border-t border-border/20 flex flex-col gap-2">
              <span className="text-[10px] font-extrabold text-text-secondary block">Custom Tags Creator</span>
              <div className="flex gap-2 max-w-sm">
                <input
                  type="text"
                  placeholder="Type custom tag (e.g. sugar-free, organic)"
                  value={newCustomTag}
                  onChange={(e) => setNewCustomTag(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      e.preventDefault();
                      handleCreateCustomTag('edit', newCustomTag);
                    }
                  }}
                  className="flex-1 px-3 py-1.5 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
                <button
                  type="button"
                  onClick={() => handleCreateCustomTag('edit', newCustomTag)}
                  className="px-3 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary text-[10px] font-black rounded-xl border border-primary/20 transition-all"
                >
                  Add Tag
                </button>
              </div>
              {productEditForm.tags.trim() && (
                <div className="flex flex-wrap gap-1.5 mt-1">
                  {productEditForm.tags.split(',').map(t => t.trim()).filter(Boolean).map(tag => (
                    <span key={tag} className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-muted text-[10px] font-bold text-text-primary">
                      <span>{tag}</span>
                      <button
                        type="button"
                        onClick={() => toggleTag('edit', tag, false)}
                        className="text-text-muted hover:text-rose-500 font-extrabold text-[9px] ml-0.5"
                      >
                        ×
                      </button>
                    </span>
                  ))}
                </div>
              )}
            </div>
          </div>
          <div>
            <label className="text-[10px] font-bold text-text-secondary block mb-1">Description</label>
            <textarea
              rows={3}
              value={productEditForm.description}
              onChange={(e) => setProductEditForm({ ...productEditForm, description: e.target.value })}
              className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
            />
          </div>
          <div className="flex flex-col gap-2 pt-3 border-t border-border/20">
            <p className="text-[10px] font-extrabold text-text-secondary uppercase tracking-wider">Promotional Highlight Placements</p>
            <div className="flex flex-wrap items-center gap-6">
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="editIsAvailable"
                  checked={productEditForm.isAvailable}
                  onChange={(e) => setProductEditForm({ ...productEditForm, isAvailable: e.target.checked })}
                  className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                />
                <label htmlFor="editIsAvailable" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                  Available for Sale
                </label>
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="editIsFlashDeal"
                  checked={productEditForm.isFlashDeal}
                  onChange={(e) => setProductEditForm({ ...productEditForm, isFlashDeal: e.target.checked })}
                  className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                />
                <label htmlFor="editIsFlashDeal" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                  ⚡ Flash Deal
                </label>
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="editIsTopPick"
                  checked={productEditForm.isTopPick}
                  onChange={(e) => setProductEditForm({ ...productEditForm, isTopPick: e.target.checked })}
                  className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                />
                <label htmlFor="editIsTopPick" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                  ⭐ Top Pick
                </label>
              </div>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="editIsBestSeller"
                  checked={productEditForm.isBestSeller}
                  onChange={(e) => setProductEditForm({ ...productEditForm, isBestSeller: e.target.checked })}
                  className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                />
                <label htmlFor="editIsBestSeller" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                  🏆 Best Seller
                </label>
              </div>
            </div>
          </div>

          {/* Display Priority / Sort Order */}
          <div className="space-y-1.5">
            <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Display Priority / Sort Order</label>
            <input
              type="number"
              placeholder="e.g. 100 for top, -50 for bottom"
              value={productEditForm.sortOrder}
              onChange={(e) => setProductEditForm({ ...productEditForm, sortOrder: e.target.value })}
              className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold text-text-primary"
            />
            <p className="text-[9px] text-text-muted mt-0.5">Higher numbers display first/on top. Lower numbers display last. Default is 0.</p>
          </div>

          <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
            <button
              type="button"
              onClick={() => setEditingProduct(null)}
              className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={savingProductId === editingProduct?.id}
              className="flex items-center gap-1 px-5 py-2 bg-accent text-white text-xs font-bold rounded-xl hover:bg-accent/90 transition-all shadow-sm font-semibold"
            >
              {savingProductId === editingProduct?.id ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Saving...
                </>
              ) : (
                'Save Changes'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default ProductEditModal
export { ProductEditModal }
