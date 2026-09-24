'use client'

import { useState, useMemo } from 'react'
import { useSession } from 'next-auth/react'
import { toast } from 'sonner'

interface UseAdminCategoriesProps {
  initialCategories?: any[]
}

export function useAdminCategories({ initialCategories }: UseAdminCategoriesProps = {}) {
  const { data: session } = useSession()
  const authHeaders = useMemo(() => ({
    'Content-Type': 'application/json',
    ...(session?.user?.id ? { 'x-user-id': session.user.id } : {}),
    ...((session?.user as any)?.role ? { 'x-user-role': (session?.user as any).role } : { 'x-user-role': 'ADMIN' }),
    ...(session?.user?.email ? { 'x-user-email': session.user.email } : {}),
    ...((session?.user as any)?.phone ? { 'x-user-phone': (session?.user as any).phone } : {}),
  }), [session])

  const [categories, setCategories] = useState(initialCategories || [])
  const [categorySubView, setCategorySubView] = useState<'grocery' | 'cafe' | 'restaurant'>('grocery')
  const [showAddCategory, setShowAddCategory] = useState(false)
  const [isCreatingCategory, setIsCreatingCategory] = useState(false)
  const [newCategory, setNewCategory] = useState({
    name: '',
    imageUrl: '',
    sortOrder: '0',
    parentId: '',
  })

  // Modal Edit states for Categories
  const [editingCategory, setEditingCategory] = useState<any | null>(null)
  const [savingCategoryId, setSavingCategoryId] = useState<string | null>(null)
  const [deletingCategoryId, setDeletingCategoryId] = useState<string | null>(null)
  const [categoryEditForm, setCategoryEditForm] = useState({
    name: '',
    imageUrl: '',
    sortOrder: '0',
    parentId: '',
  })

  const handleCreateCategory = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newCategory.name) {
      toast.error('Please enter a category name')
      return
    }

    setIsCreatingCategory(true)
    try {
      const res = await fetch('/api/categories', {
        method: 'POST',
        headers: authHeaders,
        body: JSON.stringify({
          name: newCategory.name,
          imageUrl: newCategory.imageUrl,
          sortOrder: newCategory.sortOrder,
          parentId: newCategory.parentId || null,
        }),
      })

      if (res.ok) {
        const created = await res.json()
        const formattedCreated = {
          ...created,
          _count: { products: 0 }
        }
        setCategories([...categories, formattedCreated])
        toast.success(`Category "${created.name}" created successfully!`)
        setShowAddCategory(false)
        setNewCategory({ name: '', imageUrl: '', sortOrder: '0', parentId: '' })
      } else {
        toast.error('Failed to create category')
      }
    } catch (err) {
      toast.error('Error creating category')
    } finally {
      setIsCreatingCategory(false)
    }
  }

  const startEditingCategory = (c: any) => {
    setEditingCategory(c)
    setCategoryEditForm({
      name: c.name || '',
      imageUrl: c.imageUrl || '',
      sortOrder: String(c.sortOrder || '0'),
      parentId: c.parentId || '',
    })
  }

  const saveCategoryChanges = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!editingCategory) return

    setSavingCategoryId(editingCategory.id)
    try {
      const res = await fetch(`/api/categories/${editingCategory.id}`, {
        method: 'PATCH',
        headers: authHeaders,
        body: JSON.stringify({
          name: categoryEditForm.name,
          imageUrl: categoryEditForm.imageUrl,
          sortOrder: parseInt(categoryEditForm.sortOrder) || 0,
          parentId: categoryEditForm.parentId || null,
        }),
      })

      if (res.ok) {
        const updated = await res.json()
        setCategories(categories.map((c) => (c.id === editingCategory.id ? { ...c, ...updated } : c)))
        toast.success('Category updated successfully!')
        setEditingCategory(null)
      } else {
        const err = await res.json()
        toast.error(err.error || 'Failed to update category')
      }
    } catch (err) {
      toast.error('Error updating category')
    } finally {
      setSavingCategoryId(null)
    }
  }

  const handleDeleteCategory = async (categoryId: string) => {
    if (!confirm('Are you sure you want to delete this category? This action cannot be undone.')) {
      return
    }
    setDeletingCategoryId(categoryId)
    try {
      const res = await fetch(`/api/categories/${categoryId}`, {
        method: 'DELETE',
        headers: authHeaders,
      })

      if (res.ok) {
        setCategories(categories.filter((c) => c.id !== categoryId))
        toast.success('Category deleted successfully!')
      } else {
        const err = await res.json()
        toast.error(err.error || 'Failed to delete category')
      }
    } catch (err) {
      toast.error('Error deleting category')
    } finally {
      setDeletingCategoryId(null)
    }
  }

  return {
    categories,
    setCategories,
    categorySubView,
    setCategorySubView,
    showAddCategory,
    setShowAddCategory,
    isCreatingCategory,
    newCategory,
    setNewCategory,
    editingCategory,
    setEditingCategory,
    savingCategoryId,
    setSavingCategoryId,
    deletingCategoryId,
    setDeletingCategoryId,
    categoryEditForm,
    setCategoryEditForm,
    handleCreateCategory,
    startEditingCategory,
    saveCategoryChanges,
    handleDeleteCategory,
  }
}
