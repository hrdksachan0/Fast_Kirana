'use client'

import { useState, useMemo } from 'react'
import { PlusCircle, X, ImageIcon, Sparkles, Loader2, Trash, Search, FolderPlus, Tag } from 'lucide-react'
import { AnimatePresence, motion } from 'framer-motion'
import { Category } from '@prisma/client'

interface CategoryWithCount extends Category {
  _count?: { products: number }
}

interface CategoriesTabProps {
  categories: CategoryWithCount[]
  newCategory: { id?: string; name: string; imageUrl: string; sortOrder: string; parentId: string }
  showAddCategory: boolean
  editingCategory: any
  savingCategoryId: string | null
  deletingCategoryId: string | null
  categoryEditForm: { name: string; imageUrl: string; sortOrder: string; parentId: string }
  isCreatingCategory: boolean
  showMediaLibrary: boolean
  mediaTarget: string | null
  mediaSearchQuery: string
  setNewCategory: (v: any) => void
  setShowAddCategory: (v: boolean) => void
  setEditingCategory: (v: any) => void
  setCategoryEditForm: (v: any) => void
  setSavingCategoryId: (v: string | null) => void
  setDeletingCategoryId: (v: string | null) => void
  setMediaTarget: (v: any) => void
  setShowMediaLibrary: (v: boolean) => void
  handleCreateCategory: (e: React.FormEvent) => Promise<void>
  handleDeleteCategory: (id: string) => Promise<void>
  saveCategoryChanges: (e: React.FormEvent) => Promise<void>
  startEditingCategory: (c: any) => void
  handleImageFileChange: (form: 'new' | 'edit', e: React.ChangeEvent<HTMLInputElement>) => void
  selectedHubId?: string
  storeCategoryCount?: number
  productTotal?: number
  allProducts?: any[]
}

export function CategoriesTab({
  categories,
  newCategory,
  showAddCategory,
  editingCategory,
  savingCategoryId,
  deletingCategoryId,
  categoryEditForm,
  isCreatingCategory,
  showMediaLibrary,
  mediaTarget,
  mediaSearchQuery,
  setNewCategory,
  setShowAddCategory,
  setEditingCategory,
  setCategoryEditForm,
  setSavingCategoryId,
  setDeletingCategoryId,
  setMediaTarget,
  setShowMediaLibrary,
  handleCreateCategory,
  handleDeleteCategory,
  saveCategoryChanges,
  startEditingCategory,
  handleImageFileChange,
  selectedHubId,
  storeCategoryCount,
  productTotal,
  allProducts,
}: CategoriesTabProps) {
  const isStoreScoped = Boolean(selectedHubId && selectedHubId !== 'all')
  const [categorySearch, setCategorySearch] = useState('')
  const [levelFilter, setLevelFilter] = useState<'all' | 'root' | 'sub'>('all')

  // Top-level categories available for parent assignment
  const rootCategories = useMemo(() => {
    return categories
      .filter((c) => !c.parentId && c.slug !== 'cafe' && c.slug !== 'restaurant')
      .sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0))
  }, [categories])

  const { storeCatIds, storeProductCounts } = useMemo(() => {
    const ids = new Set<string>()
    const counts: Record<string, number> = {}
    if (!allProducts || allProducts.length === 0) {
      return { storeCatIds: ids, storeProductCounts: counts }
    }
    for (const p of allProducts) {
      const catId = p.categoryId ? String(p.categoryId) : null
      if (catId) {
        ids.add(catId)
        counts[catId] = (counts[catId] || 0) + 1
      }
    }
    // Also include parent IDs if any subcategory has stock in this store
    for (const c of categories) {
      if (c.parentId && ids.has(c.id)) {
        ids.add(c.parentId)
      }
    }
    return { storeCatIds: ids, storeProductCounts: counts }
  }, [allProducts, categories])

  const filteredCategories: CategoryWithCount[] = useMemo(() => {
    let validCats = categories.filter((c) => c.slug !== 'cafe' && c.slug !== 'restaurant')
    if (isStoreScoped) {
      const storeCats = validCats.filter((c) => storeCatIds.has(c.id))
      if (storeCats.length > 0) {
        validCats = storeCats
      }
    }

    if (levelFilter === 'root') {
      validCats = validCats.filter((c) => !c.parentId)
    } else if (levelFilter === 'sub') {
      validCats = validCats.filter((c) => Boolean(c.parentId))
    }

    if (categorySearch.trim()) {
      const q = categorySearch.trim().toLowerCase()
      validCats = validCats.filter(
        (c) =>
          c.name.toLowerCase().includes(q) ||
          c.slug.toLowerCase().includes(q) ||
          c.id.toLowerCase().includes(q)
      )
    }

    return validCats
  }, [categories, isStoreScoped, storeCatIds, levelFilter, categorySearch])

  // Count breakdown
  const rootCount = useMemo(() => categories.filter((c) => !c.parentId && c.slug !== 'cafe' && c.slug !== 'restaurant').length, [categories])
  const subCount = useMemo(() => categories.filter((c) => Boolean(c.parentId) && c.slug !== 'cafe' && c.slug !== 'restaurant').length, [categories])

  const openAddSubcategoryFor = (parentCatId: string) => {
    setNewCategory({
      id: '',
      name: '',
      imageUrl: '',
      sortOrder: '0',
      parentId: parentCatId,
    })
    setShowAddCategory(true)
    window.scrollTo({ top: 120, behavior: 'smooth' })
  }

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Controls header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-card p-5 rounded-2xl border border-border shadow-sm">
        <div>
          <div className="flex items-center gap-2.5 flex-wrap">
            <h3 className="font-extrabold text-text-primary text-base flex items-center gap-2">
              <span>📁 Category & Subcategory Management</span>
            </h3>
            {isStoreScoped ? (
              <span className="text-xs bg-primary/10 text-primary px-2.5 py-0.5 rounded-full font-bold">
                🏪 Store Categories: {filteredCategories.length} {storeCatIds.size === 0 && '(Catalog Default)'}
              </span>
            ) : (
              <div className="flex items-center gap-1.5 flex-wrap">
                <span className="text-xs bg-primary/10 text-primary px-2.5 py-0.5 rounded-full font-bold">
                  {categories.length} Total
                </span>
                <span className="text-xs bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 px-2 py-0.5 rounded-full font-bold border border-emerald-500/20">
                  {rootCount} Top-Level
                </span>
                <span className="text-xs bg-amber-500/10 text-amber-600 dark:text-amber-400 px-2 py-0.5 rounded-full font-bold border border-amber-500/20">
                  {subCount} Subcategories
                </span>
              </div>
            )}
          </div>
          <p className="text-xs text-text-secondary mt-1">
            {isStoreScoped
              ? 'Showing categories available in this store outlet with fallback to master catalog.'
              : 'Organize systematic categories and subcategories (e.g. Fruits & Vegetables ➔ Fresh Fruits / Fresh Vegetables).'}
          </p>
        </div>

        <button
          onClick={() => {
            setShowAddCategory(!showAddCategory)
            if (!showAddCategory) {
              setNewCategory({ id: '', name: '', imageUrl: '', sortOrder: '0', parentId: '' })
            }
          }}
          className="flex items-center gap-1.5 px-4 py-2 bg-primary text-primary-foreground text-xs font-bold rounded-xl hover:bg-primary/95 transition-all shadow-xs cursor-pointer active:scale-98"
        >
          <PlusCircle className="h-4 w-4" />
          <span>{showAddCategory ? 'Close Form' : 'Add Category / Subcategory'}</span>
        </button>
      </div>

      {/* Add Category Form */}
      <AnimatePresence>
        {showAddCategory && (
          <motion.form
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            onSubmit={handleCreateCategory}
            className="bg-card p-6 border border-border rounded-2xl shadow-md space-y-5 max-w-xl animate-slide-up"
          >
            <div className="border-b border-border/60 pb-3 flex justify-between items-center">
              <div>
                <h4 className="font-extrabold text-text-primary text-sm">
                  {newCategory.parentId ? 'Create New Subcategory' : 'Create Category'}
                </h4>
                {newCategory.parentId && (
                  <p className="text-[10px] text-amber-600 dark:text-amber-400 font-bold mt-0.5">
                    ↳ Parent: {categories.find((c) => c.id === newCategory.parentId)?.name || newCategory.parentId}
                  </p>
                )}
              </div>
              <span className="text-[10px] text-text-muted font-mono">POST /api/categories</span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {/* Category Level / Parent Selector */}
              <div className="sm:col-span-2">
                <label className="text-[10px] font-bold text-text-secondary block mb-1">
                  Parent Category (Hierarchy Level) *
                </label>
                <select
                  value={newCategory.parentId || ''}
                  onChange={(e) => setNewCategory({ ...newCategory, parentId: e.target.value })}
                  className="w-full px-3.5 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                >
                  <option value="">📂 None (Create as Top-Level Category)</option>
                  {rootCategories.map((c) => (
                    <option key={c.id} value={c.id}>
                      📁 {c.name} ({c.id})
                    </option>
                  ))}
                </select>
                {newCategory.parentId ? (
                  <p className="text-[10px] text-amber-600 dark:text-amber-400 font-medium mt-1">
                    ↳ Will be created as a systematic subcategory under &ldquo;{categories.find((c) => c.id === newCategory.parentId)?.name}&rdquo;
                  </p>
                ) : (
                  <p className="text-[10px] text-text-muted mt-1">
                    Will appear on the main navigation rail as a primary root category.
                  </p>
                )}
              </div>

              {/* Category Name */}
              <div className="sm:col-span-2">
                <label className="text-[10px] font-bold text-text-secondary block mb-1">
                  {newCategory.parentId ? 'Subcategory Name *' : 'Category Name *'}
                </label>
                <input
                  type="text"
                  required
                  placeholder={
                    newCategory.parentId
                      ? 'e.g. Fresh Fruits, Oils & Ghee, Dals & Pulses'
                      : 'e.g. Fruits & Vegetables, Kitchen & Ration, Snacks & Munchies'
                  }
                  value={newCategory.name}
                  onChange={(e) => setNewCategory({ ...newCategory, name: e.target.value })}
                  className="w-full px-3.5 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
              </div>

              {/* Optional Custom Category ID */}
              <div className="sm:col-span-2">
                <label className="text-[10px] font-bold text-text-secondary block mb-1">
                  Category ID (Optional — leave blank to auto-generate)
                </label>
                <input
                  type="text"
                  placeholder={newCategory.parentId ? 'e.g. SUB-101-03 or SUB-113-06' : 'e.g. CAT-117'}
                  value={newCategory.id || ''}
                  onChange={(e) => setNewCategory({ ...newCategory, id: e.target.value.toUpperCase().trim() })}
                  className="w-full px-3.5 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-mono font-semibold"
                />
                <p className="text-[10px] text-text-muted mt-1">
                  Optional systematic code (e.g. SUB-XXX-YY). If left blank, a unique ID is auto-assigned.
                </p>
              </div>

              {/* Photo / Icon */}
              <div className="sm:col-span-2">
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Category Photo / Icon</label>
                <div className="flex flex-col sm:flex-row items-center gap-3 bg-muted/10 p-3.5 rounded-xl border border-dashed border-border/80">
                  <div className="relative h-14 w-14 bg-card border flex items-center justify-center rounded-xl overflow-hidden shrink-0 shadow-2xs">
                    {newCategory.imageUrl && (newCategory.imageUrl.startsWith('data:image/') || newCategory.imageUrl.startsWith('/') || newCategory.imageUrl.startsWith('http')) ? (
                      <img src={newCategory.imageUrl} alt="Preview" className="h-full w-full object-cover" />
                    ) : newCategory.imageUrl && newCategory.imageUrl.length < 5 ? (
                      <span className="text-2xl">{newCategory.imageUrl}</span>
                    ) : (
                      <span className="text-xl text-text-secondary">📦</span>
                    )}

                    {newCategory.imageUrl && (
                      <button
                        type="button"
                        onClick={() => setNewCategory({ ...newCategory, imageUrl: '' })}
                        className="absolute -top-1 -right-1 bg-discount text-white rounded-full p-0.5 shadow hover:bg-discount/90 transition-colors"
                      >
                        <X className="h-3 w-3" />
                      </button>
                    )}
                  </div>

                  <div className="flex-1 w-full space-y-2">
                    <div className="flex flex-wrap items-center gap-2">
                      <label
                        htmlFor="new-category-image-file"
                        className="cursor-pointer px-3 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary text-[10px] font-bold rounded-lg border border-primary/20 transition-all inline-flex items-center gap-1"
                      >
                        <ImageIcon className="h-3 w-3" />
                        Upload Photo
                      </label>
                      <input
                        id="new-category-image-file"
                        type="file"
                        accept="image/*"
                        onChange={(e) => {
                          handleImageFileChange('new', e)
                          e.target.value = ''
                        }}
                        className="sr-only"
                      />

                      <button
                        type="button"
                        onClick={() => {
                          setMediaTarget('newCategory')
                          setShowMediaLibrary(true)
                        }}
                        className="px-3 py-1.5 bg-amber-500/10 hover:bg-amber-500/20 text-amber-600 dark:text-amber-400 text-[10px] font-bold rounded-lg border border-amber-500/20 transition-all inline-flex items-center gap-1 cursor-pointer"
                      >
                        <Sparkles className="h-3 w-3" />
                        Pick from Photo Library
                      </button>
                    </div>

                    <input
                      type="text"
                      placeholder="Or type Emoji icon (e.g. 🍫 or 🥛)"
                      value={newCategory.imageUrl.startsWith('data:image/') || newCategory.imageUrl.startsWith('http') ? '' : newCategory.imageUrl}
                      onChange={(e) => setNewCategory({ ...newCategory, imageUrl: e.target.value })}
                      className="w-full px-3 py-1.5 text-[11px] rounded-lg border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    />
                  </div>
                </div>
              </div>

              {/* Sort Order */}
              <div className="sm:col-span-2">
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Sort Order Weight</label>
                <input
                  type="number"
                  placeholder="e.g. 10"
                  value={newCategory.sortOrder}
                  onChange={(e) => setNewCategory({ ...newCategory, sortOrder: e.target.value })}
                  className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
              </div>
            </div>

            <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
              <button
                type="button"
                onClick={() => setShowAddCategory(false)}
                className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isCreatingCategory}
                className="flex items-center gap-1.5 px-5 py-2 bg-primary text-white text-xs font-bold rounded-xl hover:bg-primary/95 transition-all shadow-xs cursor-pointer active:scale-98"
              >
                {isCreatingCategory ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    Creating...
                  </>
                ) : (
                  newCategory.parentId ? 'Create Subcategory' : 'Create Category'
                )}
              </button>
            </div>
          </motion.form>
        )}
      </AnimatePresence>

      {/* Edit Category Modal */}
      {editingCategory && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <form
            onSubmit={saveCategoryChanges}
            className="bg-card p-6 border border-border rounded-3xl shadow-xl space-y-5 max-w-lg w-full animate-scale-in"
          >
            <div className="border-b border-border/60 pb-3 flex justify-between items-center">
              <div>
                <h4 className="font-black text-text-primary text-base">Edit Category</h4>
                <p className="text-[10px] text-text-muted font-mono">ID: {editingCategory.id}</p>
              </div>
              <button
                type="button"
                onClick={() => setEditingCategory(null)}
                className="text-text-secondary hover:text-text-primary p-1 cursor-pointer"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            <div className="space-y-4">
              {/* Parent Category in Edit */}
              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">
                  Parent Category (Hierarchy Level)
                </label>
                <select
                  value={categoryEditForm.parentId || ''}
                  onChange={(e) => setCategoryEditForm({ ...categoryEditForm, parentId: e.target.value })}
                  className="w-full px-3.5 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                >
                  <option value="">📂 None (Top-Level Category)</option>
                  {rootCategories
                    .filter((c) => c.id !== editingCategory.id)
                    .map((c) => (
                      <option key={c.id} value={c.id}>
                        📁 {c.name} ({c.id})
                      </option>
                    ))}
                </select>
              </div>

              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Category Name *</label>
                <input
                  type="text"
                  required
                  value={categoryEditForm.name}
                  onChange={(e) => setCategoryEditForm({ ...categoryEditForm, name: e.target.value })}
                  className="w-full px-3.5 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
              </div>

              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Category Photo / Icon</label>
                <div className="flex items-center gap-3 bg-muted/10 p-3 rounded-xl border border-dashed border-border/80">
                  <div className="relative h-14 w-14 bg-card border flex items-center justify-center rounded-xl overflow-hidden shrink-0 shadow-2xs">
                    {categoryEditForm.imageUrl && (categoryEditForm.imageUrl.startsWith('data:image/') || categoryEditForm.imageUrl.startsWith('/') || categoryEditForm.imageUrl.startsWith('http')) ? (
                      <img src={categoryEditForm.imageUrl} alt="Preview" className="h-full w-full object-cover" />
                    ) : categoryEditForm.imageUrl && categoryEditForm.imageUrl.length < 5 ? (
                      <span className="text-2xl">{categoryEditForm.imageUrl}</span>
                    ) : (
                      <span className="text-xl text-text-secondary">📦</span>
                    )}
                  </div>

                  <div className="flex-1 space-y-2">
                    <div className="flex flex-wrap items-center gap-2">
                      <label
                        htmlFor="edit-category-image-file"
                        className="cursor-pointer px-3 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary text-[10px] font-bold rounded-lg border border-primary/20 transition-all inline-flex items-center gap-1"
                      >
                        <ImageIcon className="h-3 w-3" />
                        Upload Photo
                      </label>
                      <input
                        id="edit-category-image-file"
                        type="file"
                        accept="image/*"
                        onChange={(e) => {
                          handleImageFileChange('edit', e)
                          e.target.value = ''
                        }}
                        className="sr-only"
                      />

                      <button
                        type="button"
                        onClick={() => {
                          setMediaTarget('editCategory')
                          setShowMediaLibrary(true)
                        }}
                        className="px-3 py-1.5 bg-amber-500/10 hover:bg-amber-500/20 text-amber-600 dark:text-amber-400 text-[10px] font-bold rounded-lg border border-amber-500/20 transition-all inline-flex items-center gap-1 cursor-pointer"
                      >
                        <Sparkles className="h-3 w-3" />
                        Pick from Photo Library
                      </button>
                    </div>

                    <input
                      type="text"
                      placeholder="Or type Emoji (e.g. 🍫)"
                      value={categoryEditForm.imageUrl.startsWith('data:image/') || categoryEditForm.imageUrl.startsWith('http') ? '' : categoryEditForm.imageUrl}
                      onChange={(e) => setCategoryEditForm({ ...categoryEditForm, imageUrl: e.target.value })}
                      className="w-full px-3 py-1.5 text-[11px] rounded-lg border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    />
                  </div>
                </div>
              </div>

              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Sort Order Weight</label>
                <input
                  type="number"
                  value={categoryEditForm.sortOrder}
                  onChange={(e) => setCategoryEditForm({ ...categoryEditForm, sortOrder: e.target.value })}
                  className="w-full px-3.5 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
              </div>
            </div>

            <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
              <button
                type="button"
                onClick={() => setEditingCategory(null)}
                className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={savingCategoryId === editingCategory.id}
                className="flex items-center gap-1.5 px-5 py-2 bg-primary text-white text-xs font-bold rounded-xl hover:bg-primary/95 transition-all shadow-xs cursor-pointer active:scale-98"
              >
                {savingCategoryId === editingCategory.id ? (
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
      )}

      {/* Categories Tree List Table */}
      <div className="bg-card border border-border rounded-2xl p-5 shadow-sm overflow-hidden space-y-4">
        {/* Table Filters & Search Bar */}
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3 pb-2 border-b border-border/40">
          <div className="flex items-center gap-1.5 bg-muted/30 p-1 rounded-xl border border-border/60">
            <button
              type="button"
              onClick={() => setLevelFilter('all')}
              className={`px-3 py-1 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                levelFilter === 'all'
                  ? 'bg-primary text-primary-foreground shadow-xs'
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              All ({categories.length})
            </button>
            <button
              type="button"
              onClick={() => setLevelFilter('root')}
              className={`px-3 py-1 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                levelFilter === 'root'
                  ? 'bg-primary text-primary-foreground shadow-xs'
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              Top-Level ({rootCount})
            </button>
            <button
              type="button"
              onClick={() => setLevelFilter('sub')}
              className={`px-3 py-1 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                levelFilter === 'sub'
                  ? 'bg-primary text-primary-foreground shadow-xs'
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              Subcategories ({subCount})
            </button>
          </div>

          <div className="relative flex-1 sm:max-w-xs">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-text-muted" />
            <input
              type="text"
              placeholder="Search by name, ID, or slug..."
              value={categorySearch}
              onChange={(e) => setCategorySearch(e.target.value)}
              className="w-full pl-9 pr-3 py-1.5 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
            />
            {categorySearch && (
              <button
                type="button"
                onClick={() => setCategorySearch('')}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-text-muted hover:text-text-primary"
              >
                <X className="h-3 w-3" />
              </button>
            )}
          </div>
        </div>

        {filteredCategories.length === 0 ? (
          <div className="text-center py-12 px-4 bg-muted/10 rounded-2xl border border-dashed border-border/80 my-2">
            <div className="text-4xl mb-3">🏪</div>
            <h4 className="text-sm font-extrabold text-text-primary">
              {isStoreScoped ? 'New Store Setup — No Categories Found' : 'No Categories Match'}
            </h4>
            <p className="text-xs text-text-secondary max-w-md mx-auto mt-1 mb-2">
              {isStoreScoped
                ? 'This store has no active categories yet. Inward products or add a new category to get started.'
                : 'Try adjusting your search query or level filter.'}
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-bold">
                  <th className="py-3 px-4">ID</th>
                  <th className="py-3 px-4">Photo / Icon</th>
                  <th className="py-3 px-4">Category Name & Hierarchy</th>
                  <th className="py-3 px-4">Slug Identifier</th>
                  <th className="py-3 px-4 text-center">Sort Order</th>
                  <th className="py-3 px-4 text-center">Items Stocked</th>
                  <th className="py-3 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/40 font-semibold text-text-primary">
                {filteredCategories.map((c) => {
                  const directCount = isStoreScoped
                    ? storeProductCounts[c.id] || 0
                    : c._count?.products || 0

                  const parentCategory = c.parentId ? categories.find((p) => p.id === c.parentId) : null
                  const childCategories = categories.filter((ch) => ch.parentId === c.id)

                  // Sum products across child subcategories
                  const childIds = childCategories.map((ch) => ch.id)
                  const subProductsTotal = childIds.reduce((sum, chId) => {
                    return (
                      sum +
                      (isStoreScoped
                        ? storeProductCounts[chId] || 0
                        : categories.find((k) => k.id === chId)?._count?.products || 0)
                    )
                  }, 0)
                  const combinedCount = directCount + subProductsTotal

                  return (
                    <tr key={c.id} className="hover:bg-muted/30 transition-colors bg-card">
                      <td className="py-3 px-4 font-mono text-[11px] font-bold text-primary whitespace-nowrap">
                        {c.id}
                      </td>

                      <td className="py-3 px-4">
                        <span className="h-9 w-9 bg-muted/50 border flex items-center justify-center rounded-xl overflow-hidden shadow-2xs">
                          {c.imageUrl && (c.imageUrl.startsWith('data:image/') || c.imageUrl.startsWith('/') || c.imageUrl.startsWith('http')) ? (
                            <img src={c.imageUrl} alt={c.name} className="h-full w-full object-cover" />
                          ) : c.imageUrl && c.imageUrl.length < 5 ? (
                            <span className="text-lg">{c.imageUrl}</span>
                          ) : (
                            <span className="text-base">📦</span>
                          )}
                        </span>
                      </td>

                      <td className="py-3 px-4">
                        <div className="space-y-1">
                          <div className="flex items-center gap-1.5 flex-wrap">
                            <span className="font-black text-sm text-text-primary">
                              {c.name}
                            </span>
                            {c.parentId ? (
                              <span className="inline-flex items-center gap-1 text-[10px] font-bold text-amber-600 dark:text-amber-400 bg-amber-500/10 px-2 py-0.5 rounded-full border border-amber-500/20 whitespace-nowrap">
                                ↳ Subcategory of {parentCategory?.name || c.parentId}
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1 text-[10px] font-bold text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded-full border border-emerald-500/20 whitespace-nowrap">
                                Top-Level ({childCategories.length} Subs)
                              </span>
                            )}
                          </div>
                          {childCategories.length > 0 && (
                            <div className="flex items-center gap-1 flex-wrap text-[10px] text-text-muted">
                              <span className="font-bold">Subcategories:</span>
                              {childCategories.map((sc) => (
                                <span key={sc.id} className="bg-muted/40 px-1.5 py-0.2 rounded border border-border/50 font-mono">
                                  {sc.name}
                                </span>
                              ))}
                            </div>
                          )}
                        </div>
                      </td>

                      <td className="py-3 px-4 font-mono text-[10px] text-text-muted">{c.slug}</td>
                      <td className="py-3 px-4 text-center font-black">{c.sortOrder}</td>

                      <td className="py-3 px-4 text-center">
                        <div>
                          <span
                            className={`px-2.5 py-0.5 rounded-full text-[10px] font-black ${
                              combinedCount > 0
                                ? 'bg-primary/10 text-primary'
                                : 'bg-muted text-text-muted'
                            }`}
                          >
                            {combinedCount} Products
                          </span>
                          {subProductsTotal > 0 && (
                            <span className="block text-[9px] text-text-muted mt-0.5">
                              ({directCount} direct, {subProductsTotal} in subs)
                            </span>
                          )}
                        </div>
                      </td>

                      <td className="py-3 px-4 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          {!c.parentId && (
                            <button
                              type="button"
                              onClick={() => openAddSubcategoryFor(c.id)}
                              title={`Add Subcategory under ${c.name}`}
                              className="px-2 py-1 bg-amber-500/10 hover:bg-amber-500/20 text-amber-600 dark:text-amber-400 border border-amber-500/20 text-[10px] font-bold rounded-lg transition-all cursor-pointer inline-flex items-center gap-1"
                            >
                              <FolderPlus className="h-3 w-3" />
                              <span>+ Sub</span>
                            </button>
                          )}

                          <button
                            type="button"
                            onClick={() => startEditingCategory(c)}
                            className="px-2.5 py-1 border border-border hover:bg-muted text-[10px] font-bold rounded-lg text-text-secondary transition-all cursor-pointer"
                          >
                            Edit
                          </button>

                          <button
                            type="button"
                            onClick={() => handleDeleteCategory(c.id)}
                            disabled={deletingCategoryId === c.id}
                            className="p-1.5 border border-border text-discount hover:bg-discount/10 hover:border-discount/20 rounded-lg transition-colors inline-flex items-center justify-center cursor-pointer"
                          >
                            {deletingCategoryId === c.id ? (
                              <Loader2 className="h-3.5 w-3.5 animate-spin" />
                            ) : (
                              <Trash className="h-3.5 w-3.5" />
                            )}
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
