'use client'

import { useMemo } from 'react'
import { PlusCircle, X, ImageIcon, Sparkles, Loader2, Trash } from 'lucide-react'
import { AnimatePresence, motion } from 'framer-motion'
import { Category } from '@prisma/client'

interface CategoryWithCount extends Category {
  _count?: { products: number }
}

interface CategoriesTabProps {
  categories: CategoryWithCount[]
  newCategory: { name: string; imageUrl: string; sortOrder: string; parentId: string }
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
    return { storeCatIds: ids, storeProductCounts: counts }
  }, [allProducts])

  const filteredCategories: CategoryWithCount[] = useMemo(() => {
    const validCats = categories.filter((c) => c.slug !== 'cafe' && c.slug !== 'restaurant')
    if (isStoreScoped) {
      const storeCats = validCats.filter((c) => storeCatIds.has(c.id))
      // HUB FALLBACK: If store has stocked products, show store-active categories; otherwise show all master categories
      if (storeCats.length > 0) {
        return storeCats
      }
      return validCats
    }
    return validCats
  }, [categories, isStoreScoped, storeCatIds])

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Controls header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-card p-5 rounded-2xl border border-border shadow-sm">
        <div>
          <div className="flex items-center gap-2.5 flex-wrap">
            <h3 className="font-extrabold text-text-primary text-base flex items-center gap-2">
              <span>📁 Categories</span>
            </h3>
            {isStoreScoped ? (
              <span className="text-xs bg-primary/10 text-primary px-2.5 py-0.5 rounded-full font-bold">
                🏪 Store Categories: {filteredCategories.length} {storeCatIds.size === 0 && '(Catalog Default)'}
              </span>
            ) : (
              <span className="text-xs bg-primary/10 text-primary px-2.5 py-0.5 rounded-full font-bold">
                {filteredCategories.length} Total
              </span>
            )}
          </div>
          <p className="text-xs text-text-secondary mt-1">
            {isStoreScoped
              ? 'Showing categories available in this store outlet with fallback to master catalog.'
              : 'Manage product categories and upload category photos.'}
          </p>
        </div>

        <button
          onClick={() => {
            setShowAddCategory(!showAddCategory)
            setNewCategory({ name: '', imageUrl: '', sortOrder: '0', parentId: '' })
          }}
          className="flex items-center gap-1.5 px-4 py-2 bg-primary text-primary-foreground text-xs font-bold rounded-xl hover:bg-primary/95 transition-all shadow-xs cursor-pointer active:scale-98"
        >
          <PlusCircle className="h-4 w-4" />
          <span>{showAddCategory ? 'Close Form' : 'Add Category'}</span>
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
              <h4 className="font-extrabold text-text-primary text-sm">Create Category</h4>
              <span className="text-[10px] text-text-muted font-mono">POST /api/categories</span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="sm:col-span-2">
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Category Name *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Fresh Milk, Snacks, or Fruits & Vegetables"
                  value={newCategory.name}
                  onChange={(e) => setNewCategory({ ...newCategory, name: e.target.value })}
                  className="w-full px-3.5 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
              </div>

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
                  'Save Category'
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
                <p className="text-[10px] text-text-muted">ID: {editingCategory.id}</p>
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
        {filteredCategories.length === 0 ? (
          <div className="text-center py-12 px-4 bg-muted/10 rounded-2xl border border-dashed border-border/80 my-2">
            <div className="text-4xl mb-3">🏪</div>
            <h4 className="text-sm font-extrabold text-text-primary">
              {isStoreScoped ? 'New Store Setup — No Categories Found' : 'No Categories Found'}
            </h4>
            <p className="text-xs text-text-secondary max-w-md mx-auto mt-1 mb-2">
              {isStoreScoped
                ? 'This store has no active categories yet. Inward products or add a new category to get started.'
                : 'Get started by creating your first product category using the button above.'}
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-bold">
                  <th className="py-3 px-4">ID</th>
                  <th className="py-3 px-4">Photo / Icon</th>
                  <th className="py-3 px-4">Category Name</th>
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

                  return (
                    <tr key={c.id} className="hover:bg-muted/30 transition-colors bg-card">
                      <td className="py-3 px-4 font-mono text-[11px] font-bold text-primary">
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
                        <span className="font-black text-sm text-text-primary">
                          {c.name}
                        </span>
                      </td>

                      <td className="py-3 px-4 font-mono text-[10px] text-text-muted">{c.slug}</td>
                      <td className="py-3 px-4 text-center font-black">{c.sortOrder}</td>

                      <td className="py-3 px-4 text-center">
                        <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-black ${
                          directCount > 0 
                            ? 'bg-primary/10 text-primary' 
                            : 'bg-muted text-text-muted'
                        }`}>
                          {directCount} Products
                        </span>
                      </td>

                      <td className="py-3 px-4 text-right">
                        <div className="flex items-center justify-end gap-1.5">
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
