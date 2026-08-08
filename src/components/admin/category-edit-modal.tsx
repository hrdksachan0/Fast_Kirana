'use client'

import { useState, useEffect, useCallback } from 'react'
import { X, Loader2 } from 'lucide-react'
import { formatDisplayEmail } from '@/lib/utils'
import { toast } from 'sonner'

interface Category {
  id: string
  name: string
  parentId: string | null
  slug: string
}

interface CategoryEditModalProps {
  editingCategory: { id: string; name: string } | null
  categoryEditForm: {
    name: string
    imageUrl: string
    parentId: string
    sortOrder: string
  }
  categories: Category[]
  savingCategoryId: string | null
  handleImageFileChange: (target: any, e: React.ChangeEvent<HTMLInputElement>) => void
  saveCategoryChanges: (e: React.FormEvent) => Promise<void>
  setEditingCategory: (c: any) => void
  setCategoryEditForm: (f: any) => void
}

export function CategoryEditModal({
  editingCategory,
  categoryEditForm,
  categories,
  savingCategoryId,
  handleImageFileChange,
  saveCategoryChanges,
  setEditingCategory,
  setCategoryEditForm,
}: CategoryEditModalProps) {
  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      setEditingCategory(null)
    }
  }, [setEditingCategory])

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="category-edit-title"
      onKeyDown={handleKeyDown}
    >
      <div className="bg-card border border-border rounded-2xl shadow-xl w-full max-w-md p-6 animate-scale-up space-y-4">
        <div className="flex justify-between items-center border-b border-border/60 pb-3">
          <h4 id="category-edit-title" className="font-extrabold text-text-primary text-base">Edit Category</h4>
          <button onClick={() => setEditingCategory(null)} className="text-text-secondary hover:text-text-primary" aria-label="Close category edit dialog">
            <X className="h-5 w-5" />
          </button>
        </div>
        <form onSubmit={saveCategoryChanges} className="space-y-4">
          <div className="space-y-3">
            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Category Name *</label>
              <input
                type="text"
                required
                value={categoryEditForm.name}
                onChange={(e) => setCategoryEditForm({ ...categoryEditForm, name: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>
            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Category Image / Icon</label>
              <div className="flex items-center gap-3 bg-muted/10 p-3 rounded-xl border border-dashed border-border/80">
                <div className="relative h-12 w-12 bg-muted/50 border flex items-center justify-center rounded-xl overflow-hidden shrink-0">
                  {categoryEditForm.imageUrl && (categoryEditForm.imageUrl.startsWith('data:image/') || categoryEditForm.imageUrl.startsWith('/') || categoryEditForm.imageUrl.startsWith('http')) ? (
                    <img src={categoryEditForm.imageUrl} alt="Preview" className="h-full w-full object-cover" />
                  ) : categoryEditForm.imageUrl && categoryEditForm.imageUrl.length < 5 ? (
                    <span className="text-xl">{categoryEditForm.imageUrl}</span>
                  ) : (
                    <span className="text-lg text-text-secondary">📁</span>
                  )}

                  {categoryEditForm.imageUrl && (
                    <button
                      type="button"
                      onClick={() => setCategoryEditForm({ ...categoryEditForm, imageUrl: '' })}
                      className="absolute -top-1 -right-1 bg-discount text-white rounded-full p-0.5 shadow hover:bg-discount/90 transition-colors"
                    >
                      <X className="h-3 w-3" />
                    </button>
                  )}
                </div>

                <div className="flex-1 space-y-1.5">
                  <div className="flex items-center gap-2">
                    <label
                      htmlFor="edit-category-image-file"
                      className="cursor-pointer px-3 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary text-[10px] font-bold rounded-lg border border-primary/20 transition-all"
                    >
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
                    <span className="text-[9px] text-text-secondary">Max size 2MB</span>
                  </div>

                  <div className="relative">
                    <input
                      type="text"
                      placeholder="Or type Emoji (e.g. 🍫)"
                      value={categoryEditForm.imageUrl.startsWith('data:image/') ? '' : categoryEditForm.imageUrl}
                      onChange={(e) => setCategoryEditForm({ ...categoryEditForm, imageUrl: e.target.value })}
                      className="w-full px-2.5 py-1 text-[11px] rounded-lg border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    />
                  </div>
                </div>
              </div>
            </div>
            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Parent Category (optional)</label>
              <select
                value={categoryEditForm.parentId}
                onChange={(e) => setCategoryEditForm({ ...categoryEditForm, parentId: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              >
                <option value="">None (Root Category)</option>
                {categories
                  .filter(c => c.slug !== 'cafe' && c.slug !== 'restaurant' && c.id !== editingCategory?.id && !c.parentId)
                  .map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
              </select>
            </div>

            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Sort Order Weight</label>
              <input
                type="number"
                value={categoryEditForm.sortOrder}
                onChange={(e) => setCategoryEditForm({ ...categoryEditForm, sortOrder: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>
          </div>
          <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
            <button
              type="button"
              onClick={() => setEditingCategory(null)}
              className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={savingCategoryId === editingCategory?.id}
              className="flex items-center gap-1 px-5 py-2 bg-accent text-white text-xs font-bold rounded-xl hover:bg-accent/90 transition-all shadow-sm font-semibold"
            >
              {savingCategoryId === editingCategory?.id ? (
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
