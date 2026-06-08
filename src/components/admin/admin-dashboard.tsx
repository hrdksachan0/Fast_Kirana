'use client'

import { useState, useEffect } from 'react'
import { formatPrice } from '@/lib/utils'
import { ORDER_STATUS_LABELS } from '@/lib/constants'
import { toast } from 'sonner'
import { 
  Loader2, 
  Search, 
  Plus, 
  Save, 
  Trash, 
  ShoppingBag, 
  Package, 
  Layers, 
  Users, 
  PlusCircle, 
  Check, 
  X,
  TrendingUp,
  AlertCircle,
  Star,
  Ticket,
  Eye,
  ToggleLeft,
  ToggleRight,
  Pencil,
  Calendar,
  Percent,
  IndianRupee,
  MessageSquare,
  SlidersHorizontal,
  FileText,
  Building2,
  Image,
  Settings,
  Volume2,
  VolumeX,
  Clock,
  Utensils,
} from 'lucide-react'
import Link from 'next/link'
import { motion, AnimatePresence } from 'framer-motion'
import { AdminAnalytics } from './admin-analytics'
import { AdminAlerts } from './admin-alerts'
import { AdminBulkUpdate } from './admin-bulk-update'
import { AdminReports } from './admin-reports'
import { AdminInward } from './admin-inward'
import { AdminBanners } from './admin-banners'
import { AdminSettings } from './admin-settings'

interface AdminDashboardProps {
  initialOrders: any[]
  initialProducts: any[]
  initialCategories: any[]
  initialUsers: any[]
  initialReviews: any[]
  initialCoupons: any[]
  stats: {
    revenue: number
    orderCount: number
    userCount: number
    lowStockCount: number
  }
}

type TabType = 'orders' | 'products' | 'categories' | 'users' | 'reviews' | 'coupons' | 'analytics' | 'alerts' | 'bulk-update' | 'reports' | 'inward' | 'banners' | 'settings'

export function AdminDashboard({
  initialOrders,
  initialProducts,
  initialCategories,
  initialUsers,
  initialReviews,
  initialCoupons,
  stats
}: AdminDashboardProps) {
  const [activeTab, setActiveTab] = useState<TabType>('analytics')
  
  // States for Orders
  const [orders, setOrders] = useState(initialOrders)
  const [updatingOrderId, setUpdatingOrderId] = useState<string | null>(null)
  const [isChimeMuted, setIsChimeMuted] = useState(false)
  const [orderStatusFilter, setOrderStatusFilter] = useState('ALL')
  const [orderSearchQuery, setOrderSearchQuery] = useState('')
  const [isUploading, setIsUploading] = useState(false)
  const [settingsMap, setSettingsMap] = useState<Record<string, string>>({})

  // Fetch settings on mount to retrieve Cloudinary credentials
  useEffect(() => {
    const fetchSettings = async () => {
      try {
        const res = await fetch('/api/settings')
        if (res.ok) {
          const data = await res.json()
          setSettingsMap(data)
        }
      } catch (err) {
        console.error('Failed to load settings:', err)
      }
    }
    fetchSettings()
  }, [])

  const handleCloudinaryUpload = async (file: File, onUploadSuccess: (url: string) => void) => {
    const cloudName = settingsMap['cloudinary_cloud_name']
    const uploadPreset = settingsMap['cloudinary_upload_preset']

    if (!cloudName || !uploadPreset) {
      toast.error('Cloudinary not configured! Go to the "Store Settings" tab to set Cloudinary Cloud Name and Preset first.')
      return
    }

    setIsUploading(true)
    const formData = new FormData()
    formData.append('file', file)
    formData.append('upload_preset', uploadPreset)

    try {
      const res = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/image/upload`, {
        method: 'POST',
        body: formData,
      })

      if (res.ok) {
        const data = await res.json()
        onUploadSuccess(data.secure_url)
        toast.success('Image uploaded to Cloudinary successfully!')
      } else {
        const errData = await res.json()
        toast.error(`Cloudinary upload failed: ${errData.error?.message || 'Check credentials'}`)
      }
    } catch (err) {
      console.error(err)
      toast.error('Could not connect to Cloudinary.')
    } finally {
      setIsUploading(false)
    }
  }

  // Web Audio API warning chime synthesizer
  const playWarningChime = () => {
    try {
      const AudioContextClass = window.AudioContext || (window as any).webkitAudioContext
      if (!AudioContextClass) return
      const ctx = new AudioContextClass()
      const now = ctx.currentTime
      
      // Tone 1: 550Hz soft warning beep
      const osc1 = ctx.createOscillator()
      const gain1 = ctx.createGain()
      osc1.type = 'sine'
      osc1.frequency.setValueAtTime(550, now)
      gain1.gain.setValueAtTime(0, now)
      gain1.gain.linearRampToValueAtTime(0.08, now + 0.05)
      gain1.gain.exponentialRampToValueAtTime(0.0001, now + 0.35)
      
      osc1.connect(gain1)
      gain1.connect(ctx.destination)
      osc1.start(now)
      osc1.stop(now + 0.35)
      
      // Tone 2: 660Hz slightly offset
      const osc2 = ctx.createOscillator()
      const gain2 = ctx.createGain()
      osc2.type = 'sine'
      osc2.frequency.setValueAtTime(660, now + 0.15)
      gain2.gain.setValueAtTime(0, now + 0.15)
      gain2.gain.linearRampToValueAtTime(0.08, now + 0.20)
      gain2.gain.exponentialRampToValueAtTime(0.0001, now + 0.5)
      
      osc2.connect(gain2)
      gain2.connect(ctx.destination)
      osc2.start(now + 0.15)
      osc2.stop(now + 0.5)
    } catch (err) {
      console.warn('AudioContext failed to play:', err)
    }
  }

  // Live polling for admin orders (every 30 seconds)
  useEffect(() => {
    const fetchOrders = async () => {
      try {
        const res = await fetch('/api/orders?all=true')
        if (res.ok) {
          const data = await res.json()
          setOrders(data)
        }
      } catch (err) {
        console.error('Failed to poll orders:', err)
      }
    }

    const interval = setInterval(fetchOrders, 30000)
    return () => clearInterval(interval)
  }, [])

  // Warning chime manager
  useEffect(() => {
    if (isChimeMuted) return

    const delayedOrdersCount = orders.filter((order) => {
      if (order.status === 'PENDING') {
        const diffMs = new Date().getTime() - new Date(order.createdAt).getTime()
        return diffMs > 10 * 60 * 1000
      }
      if (order.status === 'PACKED') {
        const baseTime = order.updatedAt || order.createdAt
        const diffMs = new Date().getTime() - new Date(baseTime).getTime()
        return diffMs > 10 * 60 * 1000
      }
      if (order.status === 'CONFIRMED') {
        const isCafe = order.shopName === 'FastKirana Cafe Kitchen'
        const baseTime = order.updatedAt || order.createdAt
        const diffMs = new Date().getTime() - new Date(baseTime).getTime()
        if (isCafe) {
          return diffMs > 30 * 60 * 1000 // Cafe Chef delay (30 mins after accept)
        } else {
          return diffMs > 10 * 60 * 1000 // Grocery Picker delay (10 mins after accept)
        }
      }
      return false
    }).length

    if (delayedOrdersCount === 0) return

    // Play right away
    playWarningChime()

    // Play periodically every 20 seconds
    const chimeInterval = setInterval(playWarningChime, 20000)
    return () => clearInterval(chimeInterval)
  }, [orders, isChimeMuted])

  // Filter delayed orders
  const delayedOrders = orders.filter((order) => {
    if (order.status === 'PENDING') {
      const diffMs = new Date().getTime() - new Date(order.createdAt).getTime()
      return diffMs > 10 * 60 * 1000
    }
    if (order.status === 'PACKED') {
      const baseTime = order.updatedAt || order.createdAt
      const diffMs = new Date().getTime() - new Date(baseTime).getTime()
      return diffMs > 10 * 60 * 1000
    }
    if (order.status === 'CONFIRMED') {
      const isCafe = order.shopName === 'FastKirana Cafe Kitchen'
      const baseTime = order.updatedAt || order.createdAt
      const diffMs = new Date().getTime() - new Date(baseTime).getTime()
      if (isCafe) {
        return diffMs > 30 * 60 * 1000
      } else {
        return diffMs > 10 * 60 * 1000
      }
    }
    return false
  })

  // Count types of delays
  const pickerDelays = delayedOrders.filter(o => 
    (o.status === 'PENDING' && o.shopName !== 'FastKirana Cafe Kitchen') ||
    (o.status === 'CONFIRMED' && o.shopName !== 'FastKirana Cafe Kitchen')
  )
  const chefDelays = delayedOrders.filter(o => 
    (o.status === 'PENDING' && o.shopName === 'FastKirana Cafe Kitchen') ||
    (o.status === 'CONFIRMED' && o.shopName === 'FastKirana Cafe Kitchen')
  )
  const riderDelays = delayedOrders.filter(o => o.status === 'PACKED')

  // States for Products
  const [products, setProducts] = useState(initialProducts)
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedCategoryFilter, setSelectedCategoryFilter] = useState('')
  
  // Modal Edit states for Products
  const [editingProduct, setEditingProduct] = useState<any | null>(null)
  const [savingProductId, setSavingProductId] = useState<string | null>(null)
  const [productEditForm, setProductEditForm] = useState({
    name: '',
    description: '',
    imageUrl: '',
    categoryId: '',
    mrp: '',
    price: '',
    unit: '',
    stock: '',
    isAvailable: true,
    tags: '',
    minStock: '10',
    expiryDate: '',
    costPrice: '0',
  })
  
  // State for Add Product Form
  const [showAddProduct, setShowAddProduct] = useState(false)
  const [isCreatingProduct, setIsCreatingProduct] = useState(false)
  const [newProduct, setNewProduct] = useState({
    name: '',
    description: '',
    imageUrl: '',
    categoryId: initialCategories[0]?.id || '',
    mrp: '',
    price: '',
    unit: '',
    stock: '',
    isAvailable: true,
    tags: '',
    minStock: '10',
    expiryDate: '',
    costPrice: '0',
  })

  // States for Categories
  const [categories, setCategories] = useState(initialCategories)
  const [showAddCategory, setShowAddCategory] = useState(false)
  const [isCreatingCategory, setIsCreatingCategory] = useState(false)
  const [newCategory, setNewCategory] = useState({
    name: '',
    imageUrl: '',
    sortOrder: '0',
  })
  
  // Modal Edit states for Categories
  const [editingCategory, setEditingCategory] = useState<any | null>(null)
  const [savingCategoryId, setSavingCategoryId] = useState<string | null>(null)
  const [deletingCategoryId, setDeletingCategoryId] = useState<string | null>(null)
  const [categoryEditForm, setCategoryEditForm] = useState({
    name: '',
    imageUrl: '',
    sortOrder: '0',
  })

  // States for Users
  const [users, setUsers] = useState(initialUsers)
  const [updatingUserRoleId, setUpdatingUserRoleId] = useState<string | null>(null)
  const [settingPasswordUserId, setSettingPasswordUserId] = useState<string | null>(null)
  const [passwordInput, setPasswordInput] = useState('')
  const [savingPasswordId, setSavingPasswordId] = useState<string | null>(null)

  // States for Reviews
  const [reviews, setReviews] = useState(initialReviews)
  const [deletingReviewId, setDeletingReviewId] = useState<string | null>(null)
  const [reviewSearch, setReviewSearch] = useState('')
  
  // Modal Edit states for Reviews
  const [editingReview, setEditingReview] = useState<any | null>(null)
  const [savingReviewId, setSavingReviewId] = useState<string | null>(null)
  const [reviewEditForm, setReviewEditForm] = useState({
    rating: 5,
    comment: '',
  })

  // States for Coupons
  const [coupons, setCoupons] = useState(initialCoupons)
  const [showAddCoupon, setShowAddCoupon] = useState(false)
  const [isCreatingCoupon, setIsCreatingCoupon] = useState(false)
  const [deletingCouponId, setDeletingCouponId] = useState<string | null>(null)
  const [newCoupon, setNewCoupon] = useState({
    code: '',
    discountType: 'PERCENT',
    value: '',
    minOrder: '',
    maxDiscount: '',
    maxUses: '',
    isActive: true,
    expiresAt: '',
  })
  
  // Modal Edit states for Coupons
  const [editingCoupon, setEditingCoupon] = useState<any | null>(null)
  const [savingCouponId, setSavingCouponId] = useState<string | null>(null)
  const [couponEditForm, setCouponEditForm] = useState({
    code: '',
    discountType: 'PERCENT',
    value: '',
    minOrder: '',
    maxDiscount: '',
    maxUses: '',
    isActive: true,
    expiresAt: '',
  })

  const toggleTag = (form: 'new' | 'edit', tag: string, checked: boolean) => {
    const currentForm = form === 'new' ? newProduct : productEditForm
    const setForm = form === 'new' ? setNewProduct : setProductEditForm
    
    let tagsList = currentForm.tags
      .split(',')
      .map((t) => t.trim())
      .filter((t) => t.length > 0 && t.toLowerCase() !== tag.toLowerCase())
      
    if (checked) {
      tagsList.push(tag)
    }
    
    setForm({
      ...currentForm,
      tags: tagsList.join(', ')
    })
  }

  const handleImageFileChange = (form: 'new' | 'edit', e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    const reader = new FileReader()
    reader.onloadend = () => {
      const base64String = reader.result as string
      if (form === 'new') {
        setNewCategory({ ...newCategory, imageUrl: base64String })
      } else {
        setCategoryEditForm({ ...categoryEditForm, imageUrl: base64String })
      }
    }
    reader.readAsDataURL(file)
  }

  // ----------------------------------------------------
  // Handlers for Orders
  // ----------------------------------------------------
  const handleOrderStatusChange = async (orderId: string, newStatus: string) => {
    setUpdatingOrderId(orderId)
    try {
      const res = await fetch(`/api/orders/${orderId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: newStatus }),
      })

      if (res.ok) {
        const updated = await res.json()
        setOrders(orders.map((o) => (o.id === orderId ? { ...o, status: updated.status } : o)))
        toast.success(`Order status updated to ${ORDER_STATUS_LABELS[newStatus]}`)
      } else {
        toast.error('Failed to update order status')
      }
    } catch (err) {
      toast.error('Failed to update status')
    } finally {
      setUpdatingOrderId(null)
    }
  }

  const handleUserRoleChange = async (userId: string, newRole: string) => {
    setUpdatingUserRoleId(userId)
    try {
      const res = await fetch('/api/admin/users', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, role: newRole }),
      })

      if (res.ok) {
        setUsers(users.map((u) => (u.id === userId ? { ...u, role: newRole } : u)))
        toast.success('User role updated successfully!')
      } else {
        toast.error('Failed to update user role')
      }
    } catch (err) {
      toast.error('Error updating user role')
    } finally {
      setUpdatingUserRoleId(null)
    }
  }

  const handleSetPassword = async (userId: string) => {
    if (!passwordInput || passwordInput.length < 6) {
      toast.error('Password must be at least 6 characters')
      return
    }
    setSavingPasswordId(userId)
    try {
      const res = await fetch('/api/admin/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, password: passwordInput }),
      })
      if (res.ok) {
        toast.success('Password set successfully! Worker can now login.')
        setSettingPasswordUserId(null)
        setPasswordInput('')
      } else {
        const data = await res.json()
        toast.error(data.error || 'Failed to set password')
      }
    } catch (err) {
      toast.error('Error setting password')
    } finally {
      setSavingPasswordId(null)
    }
  }

  // ----------------------------------------------------
  // Handlers for Product Management (Modal Edit & Create)
  // ----------------------------------------------------
  const startEditingProduct = (p: any) => {
    setEditingProduct(p)
    setProductEditForm({
      name: p.name || '',
      description: p.description || '',
      imageUrl: p.imageUrl || '',
      categoryId: p.categoryId || '',
      mrp: String(p.mrp || ''),
      price: String(p.price || ''),
      unit: p.unit || '',
      stock: String(p.stock || ''),
      isAvailable: p.isAvailable !== false,
      tags: p.tags ? p.tags.join(', ') : '',
      minStock: String(p.minStock ?? 10),
      expiryDate: p.expiryDate ? String(p.expiryDate) : '',
      costPrice: String(p.costPrice ?? 0),
    })
  }

  const saveProductChanges = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!editingProduct) return

    setSavingProductId(editingProduct.id)
    try {
      const tagsArray = productEditForm.tags
        ? productEditForm.tags.split(',').map((t) => t.trim()).filter((t) => t.length > 0)
        : []

      const res = await fetch(`/api/products/${editingProduct.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: productEditForm.name,
          description: productEditForm.description,
          imageUrl: productEditForm.imageUrl,
          categoryId: productEditForm.categoryId,
          mrp: parseFloat(productEditForm.mrp) || 0,
          price: parseFloat(productEditForm.price) || 0,
          unit: productEditForm.unit,
          stock: parseInt(productEditForm.stock) || 0,
          isAvailable: productEditForm.isAvailable,
          tags: tagsArray,
          minStock: parseInt(productEditForm.minStock) || 10,
          expiryDate: productEditForm.expiryDate ? new Date(productEditForm.expiryDate).toISOString() : null,
          costPrice: parseFloat(productEditForm.costPrice) || 0,
        }),
      })

      if (res.ok) {
        const updated = await res.json()
        setProducts(products.map((p) => (p.id === editingProduct.id ? updated : p)))
        toast.success('Product updated successfully!')
        setEditingProduct(null)
      } else {
        toast.error('Failed to update product details')
      }
    } catch (err) {
      toast.error('Error saving product changes')
    } finally {
      setSavingProductId(null)
    }
  }

  const handleCreateProduct = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newProduct.name || !newProduct.categoryId || !newProduct.price || !newProduct.mrp || !newProduct.unit) {
      toast.error('Please fill in all required fields')
      return
    }

    setIsCreatingProduct(true)
    try {
      const tagsArray = newProduct.tags
        ? newProduct.tags.split(',').map((t) => t.trim()).filter((t) => t.length > 0)
        : []

      const res = await fetch('/api/products', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...newProduct,
          mrp: parseFloat(newProduct.mrp),
          price: parseFloat(newProduct.price),
          stock: parseInt(newProduct.stock) || 0,
          minStock: parseInt(newProduct.minStock) || 10,
          expiryDate: newProduct.expiryDate ? new Date(newProduct.expiryDate).toISOString() : null,
          costPrice: parseFloat(newProduct.costPrice) || 0,
          tags: tagsArray,
        }),
      })

      if (res.ok) {
        const created = await res.json()
        setProducts([created, ...products])
        toast.success(`Product "${created.name}" created successfully!`)
        setShowAddProduct(false)
        setNewProduct({
          name: '',
          description: '',
          imageUrl: '',
          categoryId: initialCategories[0]?.id || '',
          mrp: '',
          price: '',
          unit: '',
          stock: '',
          isAvailable: true,
          tags: '',
          minStock: '10',
          expiryDate: '',
          costPrice: '0',
        })
      } else {
        const errData = await res.json()
        toast.error(errData.error || 'Failed to create product')
      }
    } catch (err) {
      toast.error('Error creating product')
    } finally {
      setIsCreatingProduct(false)
    }
  }

  const handleDeleteProduct = async (productId: string) => {
    if (!confirm('Are you sure you want to delete this product? If it has order history, it will be soft-disabled instead.')) {
      return
    }

    try {
      const res = await fetch(`/api/products/${productId}`, {
        method: 'DELETE',
      })

      if (res.ok) {
        const data = await res.json()
        if (data.product) {
          // Soft delete case (availability set to false)
          setProducts(products.map((p) => (p.id === productId ? data.product : p)))
          toast.success('Product soft-deleted (made unavailable) due to sales history.')
        } else {
          // Hard delete case
          setProducts(products.filter((p) => p.id !== productId))
          toast.success('Product deleted successfully.')
        }
      } else {
        toast.error('Failed to delete product')
      }
    } catch (err) {
      toast.error('Error deleting product')
    }
  }

  // ----------------------------------------------------
  // Handlers for Category Management
  // ----------------------------------------------------
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
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newCategory),
      })

      if (res.ok) {
        const created = await res.json()
        // Map to format containing _count
        const formattedCreated = {
          ...created,
          _count: { products: 0 }
        }
        setCategories([...categories, formattedCreated])
        toast.success(`Category "${created.name}" created successfully!`)
        setShowAddCategory(false)
        setNewCategory({ name: '', imageUrl: '', sortOrder: '0' })
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
    })
  }

  const saveCategoryChanges = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!editingCategory) return

    setSavingCategoryId(editingCategory.id)
    try {
      const res = await fetch(`/api/categories/${editingCategory.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: categoryEditForm.name,
          imageUrl: categoryEditForm.imageUrl,
          sortOrder: parseInt(categoryEditForm.sortOrder) || 0,
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

  // ----------------------------------------------------
  // Handlers for Reviews Management
  // ----------------------------------------------------
  const startEditingReview = (r: any) => {
    setEditingReview(r)
    setReviewEditForm({
      rating: r.rating || 5,
      comment: r.comment || '',
    })
  }

  const saveReviewChanges = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!editingReview) return

    setSavingReviewId(editingReview.id)
    try {
      const res = await fetch('/api/admin/reviews', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          reviewId: editingReview.id,
          rating: reviewEditForm.rating,
          comment: reviewEditForm.comment,
        }),
      })

      if (res.ok) {
        const updated = await res.json()
        setReviews(reviews.map((r: any) => (r.id === editingReview.id ? { ...r, rating: updated.rating, comment: updated.comment } : r)))
        toast.success('Review updated successfully!')
        setEditingReview(null)
      } else {
        toast.error('Failed to update review')
      }
    } catch (err) {
      toast.error('Error saving review changes')
    } finally {
      setSavingReviewId(null)
    }
  }

  const handleDeleteReview = async (reviewId: string) => {
    if (!confirm('Delete this customer review? This action cannot be undone.')) return
    setDeletingReviewId(reviewId)
    try {
      const res = await fetch('/api/admin/reviews', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reviewId }),
      })
      if (res.ok) {
        setReviews(reviews.filter((r: any) => r.id !== reviewId))
        toast.success('Review deleted successfully')
      } else {
        toast.error('Failed to delete review')
      }
    } catch (err) {
      toast.error('Error deleting review')
    } finally {
      setDeletingReviewId(null)
    }
  }

  // Filtered reviews
  const filteredReviews = reviews.filter((r: any) => {
    if (!reviewSearch) return true
    const q = reviewSearch.toLowerCase()
    return (
      r.user.name?.toLowerCase().includes(q) ||
      r.user.email?.toLowerCase().includes(q) ||
      r.product.name?.toLowerCase().includes(q) ||
      r.comment?.toLowerCase().includes(q)
    )
  })

  // Star render helper
  const renderStars = (rating: number) => {
    return Array.from({ length: 5 }, (_, i) => (
      <Star
        key={i}
        className={`h-3.5 w-3.5 ${
          i < rating
            ? 'text-yellow-500 fill-yellow-500'
            : 'text-border'
        }`}
      />
    ))
  }

  // Average rating
  const avgRating = reviews.length > 0
    ? (reviews.reduce((sum: number, r: any) => sum + r.rating, 0) / reviews.length).toFixed(1)
    : '0.0'

  // ----------------------------------------------------
  // Handlers for Coupons / Offers Management
  // ----------------------------------------------------
  const handleCreateCoupon = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newCoupon.code || !newCoupon.value) {
      toast.error('Coupon code and discount value are required')
      return
    }

    setIsCreatingCoupon(true)
    try {
      const res = await fetch('/api/admin/coupons', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newCoupon),
      })

      if (res.ok) {
        const created = await res.json()
        setCoupons([created, ...coupons])
        toast.success(`Coupon "${created.code}" created!`)
        setShowAddCoupon(false)
        setNewCoupon({
          code: '',
          discountType: 'PERCENT',
          value: '',
          minOrder: '',
          maxDiscount: '',
          maxUses: '',
          isActive: true,
          expiresAt: '',
        })
      } else {
        const errData = await res.json()
        toast.error(errData.error || 'Failed to create coupon')
      }
    } catch (err) {
      toast.error('Error creating coupon')
    } finally {
      setIsCreatingCoupon(false)
    }
  }

  const startEditingCoupon = (c: any) => {
    setEditingCoupon(c)
    setCouponEditForm({
      code: c.code || '',
      discountType: c.discountType || 'PERCENT',
      value: String(c.value || ''),
      minOrder: String(c.minOrder || ''),
      maxDiscount: c.maxDiscount ? String(c.maxDiscount) : '',
      maxUses: c.maxUses ? String(c.maxUses) : '',
      expiresAt: c.expiresAt ? c.expiresAt.slice(0, 10) : '',
      isActive: c.isActive !== false,
    })
  }

  const saveCouponChanges = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!editingCoupon) return

    setSavingCouponId(editingCoupon.id)
    try {
      const res = await fetch('/api/admin/coupons', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          couponId: editingCoupon.id,
          code: couponEditForm.code,
          discountType: couponEditForm.discountType,
          value: parseFloat(couponEditForm.value) || 0,
          minOrder: parseFloat(couponEditForm.minOrder) || 0,
          maxDiscount: couponEditForm.maxDiscount ? parseFloat(couponEditForm.maxDiscount) : null,
          maxUses: couponEditForm.maxUses ? parseInt(couponEditForm.maxUses) : null,
          expiresAt: couponEditForm.expiresAt || null,
          isActive: couponEditForm.isActive,
        }),
      })

      if (res.ok) {
        const updated = await res.json()
        setCoupons(coupons.map((c: any) => (c.id === editingCoupon.id ? { ...c, ...updated } : c)))
        toast.success('Coupon updated successfully!')
        setEditingCoupon(null)
      } else {
        const err = await res.json()
        toast.error(err.error || 'Failed to update coupon')
      }
    } catch (err) {
      toast.error('Error saving coupon changes')
    } finally {
      setSavingCouponId(null)
    }
  }

  const handleToggleCoupon = async (couponId: string, currentActive: boolean) => {
    setSavingCouponId(couponId)
    try {
      const res = await fetch('/api/admin/coupons', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ couponId, isActive: !currentActive }),
      })

      if (res.ok) {
        const updated = await res.json()
        setCoupons(coupons.map((c: any) => (c.id === couponId ? { ...c, ...updated } : c)))
        toast.success(`Coupon ${!currentActive ? 'activated' : 'deactivated'}`)
      } else {
        toast.error('Failed to toggle coupon')
      }
    } catch (err) {
      toast.error('Error toggling coupon')
    } finally {
      setSavingCouponId(null)
    }
  }

  const handleDeleteCoupon = async (couponId: string) => {
    if (!confirm('Delete this coupon permanently?')) return
    setDeletingCouponId(couponId)
    try {
      const res = await fetch('/api/admin/coupons', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ couponId }),
      })
      if (res.ok) {
        setCoupons(coupons.filter((c: any) => c.id !== couponId))
        toast.success('Coupon deleted')
      } else {
        toast.error('Failed to delete coupon')
      }
    } catch (err) {
      toast.error('Error deleting coupon')
    } finally {
      setDeletingCouponId(null)
    }
  }

  // Filtered Products
  const filteredProducts = products.filter((p) => {
    const matchesSearch = 
      p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (p.description && p.description.toLowerCase().includes(searchQuery.toLowerCase()))
    
    const matchesCategory = 
      !selectedCategoryFilter || p.categoryId === selectedCategoryFilter
      
    return matchesSearch && matchesCategory
  })

  const tabConfig: { key: TabType; label: string; icon: any; count?: number }[] = [
    { key: 'analytics', label: 'Analytics', icon: TrendingUp },
    { key: 'alerts', label: 'Alerts', icon: AlertCircle, count: stats.lowStockCount },
    { key: 'inward', label: 'Inward Items (GRN)', icon: Building2 },
    { key: 'bulk-update', label: 'Bulk Update', icon: SlidersHorizontal },
    { key: 'reports', label: 'Reports', icon: FileText },
    { key: 'orders', label: 'Orders', icon: ShoppingBag, count: orders.length },
    { key: 'products', label: 'Products', icon: Package, count: products.length },
    { key: 'categories', label: 'Categories', icon: Layers, count: categories.length },
    { key: 'users', label: 'Customers', icon: Users, count: users.length },
    { key: 'reviews', label: 'Reviews', icon: Star, count: reviews.length },
    { key: 'coupons', label: 'Offers', icon: Ticket, count: coupons.length },
    { key: 'banners', label: 'Promo Banners', icon: Image },
    { key: 'settings', label: 'Store Settings', icon: Settings },
  ]

  return (
    <div className="space-y-6">
      
      {/* Delayed Action Warning Alert Banner */}
      {delayedOrders.length > 0 && (
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="relative overflow-hidden rounded-2xl border border-rose-500/20 bg-gradient-to-r from-rose-500/10 via-amber-500/5 to-rose-500/10 p-5 shadow-lg backdrop-blur-md animate-glow-pulse"
        >
          {/* Decorative glowing pulse */}
          <div className="absolute right-0 top-0 -mr-6 -mt-6 h-24 w-24 rounded-full bg-rose-500/10 blur-xl animate-pulse" />
          
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div className="flex items-start gap-3.5">
              <div className="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-rose-500/10 text-rose-500">
                <AlertCircle className="h-5 w-5 animate-bounce-subtle" />
                <span className="absolute -right-0.5 -top-0.5 flex h-2.5 w-2.5">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-rose-400 opacity-75"></span>
                  <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-rose-500"></span>
                </span>
              </div>
              <div>
                <h3 className="text-sm font-black text-rose-500 flex items-center gap-2">
                  Operational Bottlenecks Detected
                  <span className="rounded-full bg-rose-500/10 px-2.5 py-0.5 text-xs font-bold text-rose-600">
                    {delayedOrders.length} {delayedOrders.length === 1 ? 'order' : 'orders'} delayed
                  </span>
                </h3>
                <p className="text-xs text-text-secondary mt-0.5 max-w-2xl font-medium">
                  The following orders have exceeded the 10-minute queue limit. Please coordinate with staff immediately to prevent service level degradation.
                </p>
              </div>
            </div>
            
            {/* Control buttons */}
            <div className="flex items-center gap-2 self-end md:self-center">
              <button
                onClick={() => setIsChimeMuted(!isChimeMuted)}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-xs font-bold transition-all ${
                  isChimeMuted 
                    ? 'bg-muted/80 border-border/80 text-text-secondary hover:text-text-primary hover:bg-muted' 
                    : 'bg-rose-500/10 border-rose-500/30 text-rose-600 hover:bg-rose-500/20'
                }`}
              >
                {isChimeMuted ? (
                  <>
                    <VolumeX className="h-3.5 w-3.5" />
                    <span>Muted</span>
                  </>
                ) : (
                  <>
                    <Volume2 className="h-3.5 w-3.5 animate-pulse" />
                    <span>Alert Active</span>
                  </>
                )}
              </button>
            </div>
          </div>

          {/* Breakdown Pills */}
          <div className="flex flex-wrap gap-2 mt-4">
            {pickerDelays.length > 0 && (
              <div className="flex items-center gap-1.5 rounded-lg bg-amber-500/10 border border-amber-500/20 px-2.5 py-1 text-xs font-semibold text-amber-600">
                <ShoppingBag className="h-3.5 w-3.5" />
                <span>Grocery Picker Delay: {pickerDelays.length}</span>
              </div>
            )}
            {chefDelays.length > 0 && (
              <div className="flex items-center gap-1.5 rounded-lg bg-orange-500/10 border border-orange-500/20 px-2.5 py-1 text-xs font-semibold text-orange-600">
                <Utensils className="h-3.5 w-3.5" />
                <span>Cafe Chef Delay: {chefDelays.length}</span>
              </div>
            )}
            {riderDelays.length > 0 && (
              <div className="flex items-center gap-1.5 rounded-lg bg-rose-500/10 border border-rose-500/20 px-2.5 py-1 text-xs font-semibold text-rose-600">
                <Clock className="h-3.5 w-3.5" />
                <span>Rider Dispatch Delay: {riderDelays.length}</span>
              </div>
            )}
          </div>

          {/* List of delayed orders */}
          <div className="mt-4 border-t border-rose-500/10 pt-3">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2 max-h-48 overflow-y-auto pr-1 scrollbar-none">
              {delayedOrders.map((order) => {
                const isCafe = order.shopName === 'FastKirana Cafe Kitchen'
                const isPacked = order.status === 'PACKED'
                const baseTime = order.status === 'PENDING' ? order.createdAt : (order.updatedAt || order.createdAt)
                const delayMin = Math.floor((new Date().getTime() - new Date(baseTime).getTime()) / 60000)
                
                let delayType = 'Grocery Picker'
                let delayColor = 'border-amber-500/20 bg-amber-500/5 text-amber-700 dark:text-amber-400'
                if (isPacked) {
                  delayType = 'Rider Delivery'
                  delayColor = 'border-rose-500/20 bg-rose-500/5 text-rose-700 dark:text-rose-400'
                } else if (isCafe) {
                  delayType = 'Cafe Chef'
                  delayColor = 'border-orange-500/20 bg-orange-500/5 text-orange-700 dark:text-orange-400'
                }

                return (
                  <div 
                    key={order.id}
                    className={`flex items-center justify-between rounded-xl border p-2.5 text-xs font-medium ${delayColor}`}
                  >
                    <div className="flex flex-col gap-0.5">
                      <span className="font-bold">Order #{order.id.slice(0, 8)}</span>
                      <span className="text-[10px] opacity-80">{delayType} • {order.userName || order.userEmail || 'Guest'}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="rounded bg-black/5 px-1.5 py-0.5 text-[10px] font-black">
                        {delayMin}m delay
                      </span>
                      <button
                        onClick={() => {
                          setActiveTab('orders')
                          setSearchQuery(order.id)
                        }}
                        className="rounded-lg bg-card p-1 text-text-primary shadow-sm hover:bg-muted transition-colors border border-border/40"
                        title="View order"
                      >
                        <Eye className="h-3.5 w-3.5" />
                      </button>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        </motion.div>
      )}

      {/* Navigation tabs */}
      <div className="flex border-b border-border/60 overflow-x-auto whitespace-nowrap scrollbar-none gap-1.5 p-1 bg-muted/30 rounded-xl max-w-max relative">
        {tabConfig.map((tab) => {
          const TabIcon = tab.icon
          const isActive = activeTab === tab.key
          return (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              className={`relative flex items-center gap-1.5 px-3 py-2 text-[11px] font-bold rounded-lg transition-all cursor-pointer select-none ${
                isActive
                  ? 'text-primary'
                  : 'text-text-secondary hover:text-text-primary'
              }`}
            >
              {isActive && (
                <motion.div
                  layoutId="activeTabBackground"
                  className="absolute inset-0 bg-card shadow-sm border border-border/50 rounded-lg -z-10"
                  transition={{ type: 'spring', stiffness: 380, damping: 30 }}
                />
              )}
              <TabIcon className="h-3.5 w-3.5 z-10" />
              <span className="z-10">{tab.label} {tab.count !== undefined ? `(${tab.count})` : ''}</span>
            </button>
          )
        })}
      </div>

      <AnimatePresence mode="wait">
        <motion.div
          key={activeTab}
          initial={{ opacity: 0, y: 15 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -15 }}
          transition={{ duration: 0.25, ease: 'easeInOut' }}
          className="w-full"
        >
          {activeTab === 'orders' && (() => {
            const filteredOrders = orders.filter((o) => {
              const matchesFilter = orderStatusFilter === 'ALL' || o.status === orderStatusFilter
              const matchesSearch = 
                orderSearchQuery.trim() === '' || 
                o.id.toLowerCase().includes(orderSearchQuery.toLowerCase()) || 
                (o.userName && o.userName.toLowerCase().includes(orderSearchQuery.toLowerCase())) || 
                (o.userEmail && o.userEmail.toLowerCase().includes(orderSearchQuery.toLowerCase()))
              return matchesFilter && matchesSearch
            })
            const activeOrdersCount = orders.filter(o => o.status === 'PENDING' || o.status === 'CONFIRMED').length

            return (
              <div className="bg-card border border-border rounded-2xl p-6 shadow-sm overflow-hidden animate-fade-in">
                <div className="flex justify-between items-center mb-4">
                  <h3 className="font-extrabold text-text-primary text-base">Store Orders</h3>
                  <span className="text-[10px] bg-primary/10 text-primary px-2.5 py-1 rounded-full font-bold">
                    Showing {filteredOrders.length} of {orders.length} orders
                  </span>
                </div>

                {/* Direct Load Alert Banner inside the Orders Card */}
                {activeOrdersCount >= 10 && (
                  <div className="mb-5 p-4 rounded-xl border border-rose-500/20 bg-gradient-to-r from-rose-500/10 via-amber-500/5 to-rose-500/10 text-xs animate-glow-pulse">
                    <div className="flex items-start gap-2.5">
                      <span className="text-sm">🔥</span>
                      <div>
                        <h4 className="font-extrabold text-rose-500">Peak Load Alert: {activeOrdersCount} Active Orders</h4>
                        <p className="text-[10px] text-text-secondary mt-0.5 font-bold">
                          Staff allocation is recommended to maintain the 10-minute delivery SLA. 
                          Go to the <button onClick={() => setActiveTab('users')} className="text-primary hover:underline font-extrabold cursor-pointer">Customers tab</button> to assign idle staff to **Picker (Grocery)** or **Chef (Cafe Kitchen)** roles.
                        </p>
                      </div>
                    </div>
                  </div>
                )}

                {/* Filters and Search Row */}
                <div className="flex flex-col md:flex-row gap-3 items-center justify-between mb-4 border-b border-border/40 pb-4">
                  <div className="flex flex-wrap gap-1.5 w-full md:w-auto">
                    {[
                      { key: 'ALL', label: 'All', color: 'bg-muted' },
                      { key: 'PENDING', label: 'Placed (New)', color: 'bg-amber-500/10 text-amber-600 border border-amber-500/20' },
                      { key: 'CONFIRMED', label: 'Confirmed', color: 'bg-blue-500/10 text-blue-600 border border-blue-500/20' },
                      { key: 'PACKED', label: 'Packed', color: 'bg-[#00b140]/10 text-[#00b140] border border-[#00b140]/20' },
                      { key: 'SHIPPED', label: 'On the Way', color: 'bg-purple-500/10 text-purple-600 border border-purple-500/20' },
                      { key: 'DELIVERED', label: 'Delivered', color: 'bg-zinc-500/10 text-zinc-600 border border-zinc-500/20' },
                      { key: 'CANCELLED', label: 'Cancelled', color: 'bg-rose-500/10 text-rose-600 border border-rose-500/20' },
                    ].map((pill) => {
                      const count = pill.key === 'ALL' ? orders.length : orders.filter(o => o.status === pill.key).length
                      const isActive = orderStatusFilter === pill.key
                      return (
                        <button
                          key={pill.key}
                          type="button"
                          onClick={() => setOrderStatusFilter(pill.key)}
                          className={`px-2.5 py-1 text-[10px] font-black rounded-lg transition-all cursor-pointer border ${
                            isActive 
                              ? 'bg-primary text-white border-primary shadow-sm' 
                              : 'bg-card border-border hover:bg-muted text-text-secondary'
                          }`}
                        >
                          {pill.label} ({count})
                        </button>
                      )
                    })}
                  </div>
                  <div className="relative w-full md:w-64">
                    <Search className="absolute left-3 top-2.5 h-3.5 w-3.5 text-text-muted" />
                    <input
                      type="text"
                      placeholder="Search orders..."
                      value={orderSearchQuery}
                      onChange={(e) => setOrderSearchQuery(e.target.value)}
                      className="pl-9 pr-4 py-2 w-full text-[10px] rounded-xl border border-border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    />
                  </div>
                </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-bold">
                  <th className="py-3 px-4">Order ID</th>
                  <th className="py-3 px-4">Customer</th>
                  <th className="py-3 px-4">Address</th>
                  <th className="py-3 px-4">Total</th>
                  <th className="py-3 px-4">Status</th>
                  <th className="py-3 px-4">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/40 font-semibold">
                {filteredOrders.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="text-center py-10 text-text-secondary text-[11px] font-bold">
                      No matching orders found.
                    </td>
                  </tr>
                ) : (
                  filteredOrders.map((o) => (
                    <tr key={o.id} className="hover:bg-muted/30">
                      <td className="py-3 px-4 font-mono font-bold text-[10px]">{o.id}</td>
                      <td className="py-3 px-4">
                        <div className="font-bold">{o.userName || 'No Name'}</div>
                        <div className="text-[10px] text-text-muted font-normal">{o.userEmail}</div>
                        {o.isB2B && o.shopName && (
                          <div className="text-[10px] text-primary font-bold mt-1 bg-primary/5 px-2 py-1 rounded border border-primary/10">
                            🏢 Shop: {o.shopName} ({o.shopPhone})
                          </div>
                        )}
                        <div className="flex flex-wrap gap-1 mt-1.5">
                          {o.isB2B && (
                            <span className="bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400 text-[9px] font-black px-1.5 py-0.5 rounded uppercase tracking-wider">
                              🏢 B2B Bulk
                            </span>
                          )}
                          {o.deliveryMethod === 'PICKUP' && (
                            <span className="bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-400 text-[9px] font-black px-1.5 py-0.5 rounded uppercase tracking-wider">
                              🏪 Pickup
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="py-3 px-4 max-w-[200px] truncate text-text-secondary font-medium">
                        {o.address.houseNo}, {o.address.street}, {o.address.area}
                      </td>
                      <td className="py-3 px-4 font-bold text-text-primary">{formatPrice(o.total)}</td>
                      <td className="py-3 px-4">
                        <select
                          value={o.status}
                          onChange={(e) => handleOrderStatusChange(o.id, e.target.value)}
                          disabled={updatingOrderId === o.id}
                          className="bg-muted px-2.5 py-1 rounded-lg border text-xs font-bold text-text-primary focus:outline-none cursor-pointer"
                        >
                          <option value="PENDING">Placed</option>
                          <option value="CONFIRMED">Confirmed</option>
                          <option value="PACKED">Packed</option>
                          <option value="SHIPPED">On the Way</option>
                          <option value="DELIVERED">Delivered</option>
                          <option value="CANCELLED">Cancelled</option>
                        </select>
                      </td>
                      <td className="py-3 px-4">
                        {updatingOrderId === o.id ? (
                          <Loader2 className="h-4 w-4 animate-spin text-primary" />
                        ) : (
                          <Link
                            href={`/order/${o.id}/track`}
                            className="text-primary hover:underline text-[11px] font-bold"
                          >
                            Live Track
                          </Link>
                        )}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )
    })()}

      {/* ---------------------------------------------------- */}
      {/* PRODUCTS & INVENTORY TAB */}
      {/* ---------------------------------------------------- */}
      {activeTab === 'products' && (
        <div className="space-y-6 animate-fade-in">
          
          {/* Controls row */}
          <div className="flex flex-col md:flex-row gap-4 items-center justify-between bg-card p-4 rounded-2xl border border-border shadow-sm">
            <div className="flex flex-1 w-full gap-3">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
                <input
                  type="text"
                  placeholder="Search products by name..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-9 pr-4 py-2 w-full text-xs rounded-xl border border-border bg-muted/30 focus:outline-none focus:border-primary font-semibold"
                />
              </div>
              <select
                value={selectedCategoryFilter}
                onChange={(e) => setSelectedCategoryFilter(e.target.value)}
                className="px-3 py-2 text-xs rounded-xl border border-border bg-card font-bold text-text-secondary focus:outline-none"
              >
                <option value="">All Categories</option>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>
            
            <button
              onClick={() => setShowAddProduct(!showAddProduct)}
              className="flex items-center gap-1.5 px-4 py-2 bg-primary text-primary-foreground text-xs font-bold rounded-xl hover:bg-primary/95 transition-all w-full md:w-auto justify-center"
            >
              <PlusCircle className="h-4 w-4" />
              Add New Product
            </button>
          </div>

          {/* Add Product Inline Form */}
          {showAddProduct && (
            <form 
              onSubmit={handleCreateProduct}
              className="bg-card p-6 border border-border rounded-2xl shadow-sm space-y-4 animate-slide-up"
            >
              <div className="border-b border-border/60 pb-2">
                <h4 className="font-extrabold text-text-primary text-sm">Add New Product Details</h4>
                <p className="text-[10px] text-text-secondary mt-0.5">Define your inventory item specs, MRP and FastKirana pricing.</p>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Product Name *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Fresh Red Apple"
                    value={newProduct.name}
                    onChange={(e) => setNewProduct({ ...newProduct, name: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Category *</label>
                  <select
                    required
                    value={newProduct.categoryId}
                    onChange={(e) => setNewProduct({ ...newProduct, categoryId: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  >
                    {categories.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Unit Specification *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. 1 kg, 12 pcs, 500 ml"
                    value={newProduct.unit}
                    onChange={(e) => setNewProduct({ ...newProduct, unit: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">MRP Price (INR) *</label>
                  <input
                    type="number"
                    step="0.01"
                    required
                    placeholder="e.g. 100"
                    value={newProduct.mrp}
                    onChange={(e) => setNewProduct({ ...newProduct, mrp: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">FastKirana Discounted Price (INR) *</label>
                  <input
                    type="number"
                    step="0.01"
                    required
                    placeholder="e.g. 80"
                    value={newProduct.price}
                    onChange={(e) => setNewProduct({ ...newProduct, price: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Initial Stock Qty *</label>
                  <input
                    type="number"
                    required
                    placeholder="e.g. 50"
                    value={newProduct.stock}
                    onChange={(e) => setNewProduct({ ...newProduct, stock: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>

                <div className="md:col-span-2">
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Description</label>
                  <input
                    type="text"
                    placeholder="Product details, origin, health benefits..."
                    value={newProduct.description}
                    onChange={(e) => setNewProduct({ ...newProduct, description: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Emoji Icon / Image URL (Cloudinary)</label>
                  <div className="flex gap-2">
                    <input
                      type="text"
                      placeholder="e.g. 🍎 or image absolute link"
                      value={newProduct.imageUrl}
                      onChange={(e) => setNewProduct({ ...newProduct, imageUrl: e.target.value })}
                      className="flex-1 px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    />
                    <label className="cursor-pointer px-3 py-2 bg-primary/10 hover:bg-primary/20 text-primary text-[10px] font-black rounded-xl border border-primary/20 transition-all flex items-center gap-1.5 whitespace-nowrap">
                      {isUploading ? <Loader2 className="h-3 w-3 animate-spin" /> : 'Upload'}
                      <input
                        type="file"
                        accept="image/*"
                        onChange={(e) => {
                          const file = e.target.files?.[0]
                          if (file) {
                            handleCloudinaryUpload(file, (url) => {
                              setNewProduct({ ...newProduct, imageUrl: url })
                            })
                          }
                        }}
                        className="hidden"
                        disabled={isUploading}
                      />
                    </label>
                  </div>
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Tags (comma-separated)</label>
                  <input
                    type="text"
                    placeholder="e.g. fresh, sweet, healthy"
                    value={newProduct.tags}
                    onChange={(e) => setNewProduct({ ...newProduct, tags: e.target.value })}
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
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Cost Price (INR)</label>
                  <input
                    type="number"
                    step="0.01"
                    placeholder="e.g. 60"
                    value={newProduct.costPrice}
                    onChange={(e) => setNewProduct({ ...newProduct, costPrice: e.target.value })}
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

                <div className="md:col-span-3 flex flex-wrap gap-x-6 gap-y-2 pt-2 border-t border-border/40">
                  <span className="text-[10px] font-extrabold text-text-secondary block w-full">Quick Rows / Smart Features</span>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={newProduct.tags.split(',').map(t => t.trim().toLowerCase()).includes('popular')}
                      onChange={(e) => toggleTag('new', 'popular', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>Mark as Trending (Popular)</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={newProduct.tags.split(',').map(t => t.trim().toLowerCase()).includes('late-night')}
                      onChange={(e) => toggleTag('new', 'late-night', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>Mark as Late Night Craving</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={newProduct.tags.split(',').map(t => t.trim().toLowerCase()).includes('breakfast')}
                      onChange={(e) => toggleTag('new', 'breakfast', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>Mark as Breakfast Essential</span>
                  </label>
                </div>      
              </div>

              <div className="flex items-center gap-2 pt-5">
                  <input
                    type="checkbox"
                    id="isAvailable"
                    checked={newProduct.isAvailable}
                    onChange={(e) => setNewProduct({ ...newProduct, isAvailable: e.target.checked })}
                    className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                  />
                  <label htmlFor="isAvailable" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                    Immediately Available for Sale
                  </label>
              </div>

              <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
                <button
                  type="button"
                  onClick={() => setShowAddProduct(false)}
                  className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isCreatingProduct}
                  className="flex items-center gap-1 px-5 py-2 bg-accent text-white text-xs font-bold rounded-xl hover:bg-accent/90 transition-all shadow-sm"
                >
                  {isCreatingProduct ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      Creating...
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
                    <th className="py-3 px-4 w-[100px] text-center">Status</th>
                    <th className="py-3 px-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/40 font-semibold">
                  {filteredProducts.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="text-center py-10 text-text-secondary">
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
                                <div className="text-[10px] text-text-muted font-normal">{p.unit}</div>
                              </div>
                            </div>
                          </td>

                          {/* Category */}
                          <td className="py-3 px-4">
                            <span className="bg-muted px-2 py-0.5 border border-border/80 text-[10px] text-text-secondary rounded font-bold uppercase tracking-wider">
                              {p.category.name}
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
                          </td>

                          {/* Status */}
                          <td className="py-3 px-4 text-center">
                            <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold ${
                              p.isAvailable 
                                ? 'bg-accent/15 text-accent border border-accent/20' 
                                : 'bg-muted text-text-muted border border-border'
                            }`}>
                              {p.isAvailable ? 'Active' : 'Disabled'}
                            </span>
                          </td>

                          {/* Actions */}
                          <td className="py-3 px-4 text-right">
                            <div className="flex items-center justify-end gap-1.5">
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
          </div>

        </div>
      )}

      {/* ---------------------------------------------------- */}
      {/* CATEGORIES TAB */}
      {/* ---------------------------------------------------- */}
      {activeTab === 'categories' && (
        <div className="space-y-6 animate-fade-in">
          
          {/* Controls header */}
          <div className="flex justify-between items-center bg-card p-4 rounded-2xl border border-border shadow-sm">
            <div>
              <h3 className="font-extrabold text-text-primary text-base">Store Categories</h3>
              <p className="text-[10px] text-text-secondary mt-0.5">Control category grouping and listing sort orders.</p>
            </div>
            
            <button
              onClick={() => setShowAddCategory(!showAddCategory)}
              className="flex items-center gap-1.5 px-4 py-2 bg-primary text-primary-foreground text-xs font-bold rounded-xl hover:bg-primary/95 transition-all"
            >
              <PlusCircle className="h-4 w-4" />
              Add New Category
            </button>
          </div>

          {/* Add Category Form */}
          {showAddCategory && (
            <form 
              onSubmit={handleCreateCategory}
              className="bg-card p-6 border border-border rounded-2xl shadow-sm space-y-4 max-w-md animate-slide-up"
            >
              <div className="border-b border-border/60 pb-2">
                <h4 className="font-extrabold text-text-primary text-sm">Add Category Details</h4>
              </div>

              <div className="space-y-3">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Category Name *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Gourmet Sweets"
                    value={newCategory.name}
                    onChange={(e) => setNewCategory({ ...newCategory, name: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Category Image / Icon</label>
                  <div className="flex items-center gap-3 bg-muted/10 p-3 rounded-xl border border-dashed border-border/80">
                    <div className="relative h-12 w-12 bg-muted/50 border flex items-center justify-center rounded-xl overflow-hidden shrink-0">
                      {newCategory.imageUrl && (newCategory.imageUrl.startsWith('data:image/') || newCategory.imageUrl.startsWith('/') || newCategory.imageUrl.startsWith('http')) ? (
                        <img src={newCategory.imageUrl} alt="Preview" className="h-full w-full object-cover" />
                      ) : newCategory.imageUrl && newCategory.imageUrl.length < 5 ? (
                        <span className="text-xl">{newCategory.imageUrl}</span>
                      ) : (
                        <span className="text-lg text-text-secondary">📁</span>
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
                    
                    <div className="flex-1 space-y-1.5">
                      <div className="flex items-center gap-2">
                        <label className="cursor-pointer px-3 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary text-[10px] font-bold rounded-lg border border-primary/20 transition-all">
                          Upload Photo
                          <input
                            type="file"
                            accept="image/*"
                            onChange={(e) => handleImageFileChange('new', e)}
                            className="hidden"
                          />
                        </label>
                        <span className="text-[9px] text-text-secondary">Max size 2MB</span>
                      </div>
                      
                      <div className="relative">
                        <input
                          type="text"
                          placeholder="Or type Emoji (e.g. 🍫)"
                          value={newCategory.imageUrl.startsWith('data:image/') ? '' : newCategory.imageUrl}
                          onChange={(e) => setNewCategory({ ...newCategory, imageUrl: e.target.value })}
                          className="w-full px-2.5 py-1 text-[11px] rounded-lg border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                        />
                      </div>
                    </div>
                  </div>
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Sort Order Weight</label>
                  <input
                    type="number"
                    placeholder="e.g. 9"
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
                  className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isCreatingCategory}
                  className="flex items-center gap-1 px-5 py-2 bg-accent text-white text-xs font-bold rounded-xl hover:bg-accent/90 transition-all"
                >
                  {isCreatingCategory ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      Creating...
                    </>
                  ) : (
                    'Create Category'
                  )}
                </button>
              </div>
            </form>
          )}

          {/* Categories list table */}
          <div className="bg-card border border-border rounded-2xl p-6 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse text-xs">
                <thead>
                  <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-bold">
                    <th className="py-3 px-4">Icon</th>
                    <th className="py-3 px-4">Category Name</th>
                    <th className="py-3 px-4">Slug Identifier</th>
                    <th className="py-3 px-4 text-center">Sort Order</th>
                    <th className="py-3 px-4 text-center">Items Stocked</th>
                    <th className="py-3 px-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/40 font-semibold text-text-primary">
                  {categories.map((c) => (
                    <tr key={c.id} className="hover:bg-muted/30">
                      <td className="py-3 px-4">
                        <span className="h-8 w-8 bg-muted/50 border flex items-center justify-center rounded-lg overflow-hidden">
                          {c.imageUrl && (c.imageUrl.startsWith('data:image/') || c.imageUrl.startsWith('/') || c.imageUrl.startsWith('http')) ? (
                            <img src={c.imageUrl} alt={c.name} className="h-full w-full object-cover" />
                          ) : c.imageUrl && c.imageUrl.length < 5 ? (
                            <span className="text-base">{c.imageUrl}</span>
                          ) : (
                            <span className="text-base">📦</span>
                          )}
                        </span>
                      </td>
                      <td className="py-3 px-4 font-bold text-sm text-text-primary">{c.name}</td>
                      <td className="py-3 px-4 font-mono text-[10px] text-text-muted">{c.slug}</td>
                      <td className="py-3 px-4 text-center font-bold">{c.sortOrder}</td>
                      <td className="py-3 px-4 text-center">
                        <span className="bg-primary/10 text-primary px-2.5 py-0.5 rounded-full text-[10px] font-bold">
                          {c._count?.products || 0} Products
                        </span>
                      </td>
                      <td className="py-3 px-4 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          <button
                            onClick={() => startEditingCategory(c)}
                            className="px-2.5 py-1 border border-border hover:bg-muted text-[10px] font-bold rounded-lg text-text-secondary transition-all"
                          >
                            Edit
                          </button>
                          <button
                            onClick={() => handleDeleteCategory(c.id)}
                            disabled={deletingCategoryId === c.id}
                            className="p-1.5 border border-border text-discount hover:bg-discount/10 hover:border-discount/20 rounded-lg transition-colors inline-flex items-center justify-center"
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
                  ))}
                </tbody>
              </table>
            </div>
          </div>

        </div>
      )}

      {/* ---------------------------------------------------- */}
      {/* CUSTOMERS / USERS TAB */}
      {/* ---------------------------------------------------- */}
      {activeTab === 'users' && (
        <div className="bg-card border border-border rounded-2xl p-6 shadow-sm overflow-hidden animate-fade-in">
          <div className="flex justify-between items-center mb-4">
            <div>
              <h3 className="font-extrabold text-text-primary text-base">Customer Accounts</h3>
              <p className="text-[10px] text-text-secondary mt-0.5">Access user profiles and check transaction frequencies.</p>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-bold">
                  <th className="py-3 px-4">Name</th>
                  <th className="py-3 px-4">Email</th>
                  <th className="py-3 px-4">Phone</th>
                  <th className="py-3 px-4 text-center">Role</th>
                  <th className="py-3 px-4 text-center">Password</th>
                  <th className="py-3 px-4 text-center">Orders Placed</th>
                  <th className="py-3 px-4 text-right">Joined Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/40 font-semibold text-text-primary">
                {users.map((u) => (
                  <tr key={u.id} className="hover:bg-muted/30">
                    <td className="py-3 px-4">
                      <div className="flex items-center gap-2">
                        <div className="h-7 w-7 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-[10px]">
                          {u.name?.charAt(0) || 'U'}
                        </div>
                        <span className="font-bold">{u.name || 'Anonymous User'}</span>
                      </div>
                    </td>
                    <td className="py-3 px-4 font-medium text-text-secondary">{u.email}</td>
                    <td className="py-3 px-4 text-text-muted font-mono">{u.phone || 'N/A'}</td>
                    <td className="py-3 px-4 text-center">
                      <select
                        value={u.role}
                        onChange={(e) => handleUserRoleChange(u.id, e.target.value)}
                        disabled={updatingUserRoleId === u.id}
                        className="bg-muted px-2 py-1 rounded-lg border text-[11px] font-bold text-text-primary focus:outline-none cursor-pointer"
                      >
                        <option value="USER">Customer (USER)</option>
                        <option value="PICKER">Grocery Picker</option>
                        <option value="CHEF">Cafe Chef</option>
                        <option value="DELIVERY">Delivery Rider</option>
                        <option value="ADMIN">Admin</option>
                      </select>
                    </td>
                    <td className="py-3 px-4 text-center">
                      {u.role !== 'USER' ? (
                        settingPasswordUserId === u.id ? (
                          <div className="flex items-center gap-1.5 justify-center">
                            <input
                              type="password"
                              placeholder="Min 6 chars"
                              value={passwordInput}
                              onChange={(e) => setPasswordInput(e.target.value)}
                              className="w-24 px-2 py-1 text-[11px] border border-border rounded-lg bg-muted/30 focus:outline-none focus:border-primary font-medium"
                              autoFocus
                            />
                            <button
                              onClick={() => handleSetPassword(u.id)}
                              disabled={savingPasswordId === u.id}
                              className="p-1 bg-accent text-white rounded-md hover:bg-accent/90 transition-colors"
                            >
                              {savingPasswordId === u.id ? (
                                <Loader2 className="h-3 w-3 animate-spin" />
                              ) : (
                                <Check className="h-3 w-3" />
                              )}
                            </button>
                            <button
                              onClick={() => { setSettingPasswordUserId(null); setPasswordInput('') }}
                              className="p-1 bg-muted text-text-secondary rounded-md hover:bg-muted/80 transition-colors"
                            >
                              <X className="h-3 w-3" />
                            </button>
                          </div>
                        ) : (
                          <button
                            onClick={() => { setSettingPasswordUserId(u.id); setPasswordInput('') }}
                            className="px-2.5 py-1 text-[10px] font-bold bg-primary/10 text-primary border border-primary/20 rounded-lg hover:bg-primary/20 transition-colors cursor-pointer"
                          >
                            Set Password
                          </button>
                        )
                      ) : (
                        <span className="text-[10px] text-text-muted">OTP only</span>
                      )}
                    </td>
                    <td className="py-3 px-4 text-center">
                      <span className="font-bold bg-muted px-2 py-0.5 rounded border text-[10px]">
                        {u._count?.orders || 0} orders
                      </span>
                    </td>
                    <td className="py-3 px-4 text-right text-text-muted font-medium">
                      {new Date(u.createdAt).toLocaleDateString('en-IN', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                      })}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ---------------------------------------------------- */}
      {/* REVIEWS TAB */}
      {/* ---------------------------------------------------- */}
      {activeTab === 'reviews' && (
        <div className="space-y-6 animate-fade-in">
          
          {/* Reviews header with stats */}
          <div className="flex flex-col md:flex-row gap-4 items-center justify-between bg-card p-4 rounded-2xl border border-border shadow-sm">
            <div className="flex items-center gap-4">
              <div>
                <h3 className="font-extrabold text-text-primary text-base">Customer Reviews</h3>
                <p className="text-[10px] text-text-secondary mt-0.5">
                  Monitor, moderate & manage all product feedback
                </p>
              </div>
              <div className="flex items-center gap-2 bg-yellow-500/10 border border-yellow-500/20 px-3 py-1.5 rounded-xl">
                <Star className="h-4 w-4 text-yellow-500 fill-yellow-500" />
                <span className="text-sm font-black text-yellow-600 dark:text-yellow-400">{avgRating}</span>
                <span className="text-[10px] font-bold text-text-secondary">avg ({reviews.length} reviews)</span>
              </div>
            </div>
            <div className="relative w-full md:w-72">
              <Search className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
              <input
                type="text"
                placeholder="Search by customer, product, comment..."
                value={reviewSearch}
                onChange={(e) => setReviewSearch(e.target.value)}
                className="pl-9 pr-4 py-2 w-full text-xs rounded-xl border border-border bg-muted/30 focus:outline-none focus:border-primary font-semibold"
              />
            </div>
          </div>

          {/* Rating distribution bar */}
          <div className="bg-card border border-border rounded-2xl p-5 shadow-sm">
            <h4 className="text-xs font-extrabold text-text-primary mb-3">Rating Distribution</h4>
            <div className="space-y-2">
              {[5, 4, 3, 2, 1].map((star) => {
                const count = reviews.filter((r: any) => r.rating === star).length
                const pct = reviews.length > 0 ? (count / reviews.length) * 100 : 0
                return (
                  <div key={star} className="flex items-center gap-3">
                    <div className="flex items-center gap-0.5 w-16 justify-end">
                      <span className="text-[11px] font-bold text-text-primary">{star}</span>
                      <Star className="h-3 w-3 text-yellow-500 fill-yellow-500" />
                    </div>
                    <div className="flex-1 h-2.5 bg-muted/50 rounded-full overflow-hidden border border-border/40">
                      <div
                        className="h-full rounded-full transition-all duration-500"
                        style={{
                          width: `${pct}%`,
                          background: star >= 4
                            ? 'linear-gradient(90deg, #22c55e, #4ade80)'
                            : star === 3
                              ? 'linear-gradient(90deg, #eab308, #facc15)'
                              : 'linear-gradient(90deg, #ef4444, #f87171)',
                        }}
                      />
                    </div>
                    <span className="text-[10px] font-bold text-text-muted w-12 text-right">{count} ({pct.toFixed(0)}%)</span>
                  </div>
                )
              })}
            </div>
          </div>

          {/* Reviews List */}
          <div className="bg-card border border-border rounded-2xl p-6 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse text-xs">
                <thead>
                  <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-bold">
                    <th className="py-3 px-4">Customer</th>
                    <th className="py-3 px-4">Product</th>
                    <th className="py-3 px-4">Rating</th>
                    <th className="py-3 px-4">Comment</th>
                    <th className="py-3 px-4">Date</th>
                    <th className="py-3 px-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/40 font-semibold">
                  {filteredReviews.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="text-center py-10 text-text-secondary">
                        <MessageSquare className="h-8 w-8 mx-auto mb-2 text-text-muted" />
                        No reviews found.
                      </td>
                    </tr>
                  ) : (
                    filteredReviews.map((r: any) => (
                      <tr key={r.id} className="hover:bg-muted/30">
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-2">
                            <div className="h-7 w-7 rounded-full bg-yellow-500/10 flex items-center justify-center text-yellow-600 font-bold text-[10px]">
                              {r.user.name?.charAt(0) || 'U'}
                            </div>
                            <div>
                              <div className="font-bold text-text-primary text-[11px]">{r.user.name || 'Anonymous'}</div>
                              <div className="text-[9px] text-text-muted font-normal">{r.user.email}</div>
                            </div>
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-2">
                            <span className="text-lg h-7 w-7 bg-muted/60 flex items-center justify-center rounded-lg border text-[11px]">
                              {r.product.imageUrl && r.product.imageUrl.length < 5 ? r.product.imageUrl : '📦'}
                            </span>
                            <span className="font-bold text-text-primary text-[11px] max-w-[140px] truncate">{r.product.name}</span>
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-0.5">
                            {renderStars(r.rating)}
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          <p className="text-text-secondary font-medium text-[11px] max-w-[250px] truncate">
                            {r.comment || <span className="italic text-text-muted">No comment</span>}
                          </p>
                        </td>
                        <td className="py-3 px-4 text-text-muted font-medium text-[10px]">
                          {new Date(r.createdAt).toLocaleDateString('en-IN', {
                            day: 'numeric',
                            month: 'short',
                            year: 'numeric',
                          })}
                        </td>
                        <td className="py-3 px-4 text-right">
                          <div className="flex items-center justify-end gap-1.5">
                            <button
                              onClick={() => startEditingReview(r)}
                              className="px-2.5 py-1 border border-border hover:bg-muted text-[10px] font-bold rounded-lg text-text-secondary transition-all"
                            >
                              Edit
                            </button>
                            <button
                              onClick={() => handleDeleteReview(r.id)}
                              disabled={deletingReviewId === r.id}
                              className="p-1.5 border border-border text-discount hover:bg-discount/10 hover:border-discount/20 rounded-lg transition-colors inline-flex items-center justify-center"
                            >
                              {deletingReviewId === r.id ? (
                                <Loader2 className="h-3.5 w-3.5 animate-spin" />
                              ) : (
                                <Trash className="h-3.5 w-3.5" />
                              )}
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>

        </div>
      )}

      {/* ---------------------------------------------------- */}
      {/* COUPONS / OFFERS TAB */}
      {/* ---------------------------------------------------- */}
      {activeTab === 'coupons' && (
        <div className="space-y-6 animate-fade-in">
          
          {/* Coupons header */}
          <div className="flex flex-col md:flex-row gap-4 items-center justify-between bg-card p-4 rounded-2xl border border-border shadow-sm">
            <div>
              <h3 className="font-extrabold text-text-primary text-base">Offers & Coupons</h3>
              <p className="text-[10px] text-text-secondary mt-0.5">
                Create, edit and manage promotional discount codes for customers
              </p>
            </div>
            <div className="flex items-center gap-3">
              <div className="flex items-center gap-2 bg-purple-500/10 border border-purple-500/20 px-3 py-1.5 rounded-xl">
                <Ticket className="h-4 w-4 text-purple-500" />
                <span className="text-[11px] font-bold text-purple-600 dark:text-purple-400">
                  {coupons.filter((c: any) => c.isActive).length} active / {coupons.length} total
                </span>
              </div>
              <button
                onClick={() => setShowAddCoupon(!showAddCoupon)}
                className="flex items-center gap-1.5 px-4 py-2 bg-primary text-primary-foreground text-xs font-bold rounded-xl hover:bg-primary/95 transition-all"
              >
                <PlusCircle className="h-4 w-4" />
                New Coupon
              </button>
            </div>
          </div>

          {/* Add Coupon Form */}
          {showAddCoupon && (
            <form
              onSubmit={handleCreateCoupon}
              className="bg-card p-6 border border-border rounded-2xl shadow-sm space-y-4 animate-slide-up"
            >
              <div className="border-b border-border/60 pb-2">
                <h4 className="font-extrabold text-text-primary text-sm">Create New Coupon</h4>
                <p className="text-[10px] text-text-secondary mt-0.5">Configure discount code, type, and usage limits</p>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Coupon Code *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. SAVE20, WELCOME50"
                    value={newCoupon.code}
                    onChange={(e) => setNewCoupon({ ...newCoupon, code: e.target.value.toUpperCase() })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-bold uppercase tracking-wider"
                  />
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Discount Type *</label>
                  <select
                    value={newCoupon.discountType}
                    onChange={(e) => setNewCoupon({ ...newCoupon, discountType: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  >
                    <option value="PERCENT">Percentage (%)</option>
                    <option value="FLAT">Flat Amount (₹)</option>
                  </select>
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">
                    Discount Value * {newCoupon.discountType === 'PERCENT' ? '(%)' : '(₹)'}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    required
                    placeholder={newCoupon.discountType === 'PERCENT' ? 'e.g. 20' : 'e.g. 50'}
                    value={newCoupon.value}
                    onChange={(e) => setNewCoupon({ ...newCoupon, value: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Min Order Value (₹)</label>
                  <input
                    type="number"
                    step="0.01"
                    placeholder="e.g. 200"
                    value={newCoupon.minOrder}
                    onChange={(e) => setNewCoupon({ ...newCoupon, minOrder: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Max Discount Cap (₹)</label>
                  <input
                    type="number"
                    step="0.01"
                    placeholder="e.g. 100"
                    value={newCoupon.maxDiscount}
                    onChange={(e) => setNewCoupon({ ...newCoupon, maxDiscount: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Max Total Uses</label>
                  <input
                    type="number"
                    placeholder="e.g. 100 (leave blank for unlimited)"
                    value={newCoupon.maxUses}
                    onChange={(e) => setNewCoupon({ ...newCoupon, maxUses: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Expiry Date</label>
                  <input
                    type="date"
                    value={newCoupon.expiresAt}
                    onChange={(e) => setNewCoupon({ ...newCoupon, expiresAt: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>

                <div className="flex items-center gap-2 pt-5">
                  <input
                    type="checkbox"
                    id="couponActive"
                    checked={newCoupon.isActive}
                    onChange={(e) => setNewCoupon({ ...newCoupon, isActive: e.target.checked })}
                    className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                  />
                  <label htmlFor="couponActive" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                    Activate Immediately
                  </label>
                </div>
              </div>

              <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
                <button
                  type="button"
                  onClick={() => setShowAddCoupon(false)}
                  className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isCreatingCoupon}
                  className="flex items-center gap-1 px-5 py-2 bg-accent text-white text-xs font-bold rounded-xl hover:bg-accent/90 transition-all shadow-sm"
                >
                  {isCreatingCoupon ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      Creating...
                    </>
                  ) : (
                    'Create Coupon'
                  )}
                </button>
              </div>
            </form>
          )}

          {/* Coupons List */}
          <div className="bg-card border border-border rounded-2xl p-6 shadow-sm overflow-hidden">
            <h3 className="font-extrabold text-text-primary text-base mb-4">All Coupons</h3>
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse text-xs">
                <thead>
                  <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-bold">
                    <th className="py-3 px-4">Code</th>
                    <th className="py-3 px-4">Type</th>
                    <th className="py-3 px-4">Value</th>
                    <th className="py-3 px-4">Min Order</th>
                    <th className="py-3 px-4">Max Discount</th>
                    <th className="py-3 px-4 text-center">Usage</th>
                    <th className="py-3 px-4 text-center">Status</th>
                    <th className="py-3 px-4">Expires</th>
                    <th className="py-3 px-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/40 font-semibold">
                  {coupons.length === 0 ? (
                    <tr>
                      <td colSpan={9} className="text-center py-10 text-text-secondary">
                        <Ticket className="h-8 w-8 mx-auto mb-2 text-text-muted" />
                        No coupons created yet.
                      </td>
                    </tr>
                  ) : (
                    coupons.map((c: any) => {
                      const isExpired = c.expiresAt && new Date(c.expiresAt) < new Date()
                      
                      return (
                        <tr key={c.id} className={`hover:bg-muted/30 ${isExpired ? 'opacity-60' : ''}`}>
                          {/* Code */}
                          <td className="py-3 px-4">
                            <span className="font-mono font-black text-[11px] bg-purple-500/10 text-purple-600 dark:text-purple-400 px-2 py-0.5 rounded-lg border border-purple-500/20">
                              {c.code}
                            </span>
                          </td>

                          {/* Type */}
                          <td className="py-3 px-4">
                            <span className="flex items-center gap-1 text-[11px]">
                              {c.discountType === 'PERCENT' ? (
                                <><Percent className="h-3 w-3 text-blue-500" /> Percent</>
                              ) : (
                                <><IndianRupee className="h-3 w-3 text-accent" /> Flat</>
                              )}
                            </span>
                          </td>

                          {/* Value */}
                          <td className="py-3 px-4">
                            <span className="font-extrabold text-accent">
                              {c.discountType === 'PERCENT' ? `${c.value}%` : `₹${c.value}`}
                            </span>
                          </td>

                          {/* Min Order */}
                          <td className="py-3 px-4">
                            <span className="text-text-secondary">₹{c.minOrder}</span>
                          </td>

                          {/* Max Discount */}
                          <td className="py-3 px-4">
                            <span className="text-text-secondary">
                              {c.maxDiscount ? `₹${c.maxDiscount}` : '—'}
                            </span>
                          </td>

                          {/* Usage */}
                          <td className="py-3 px-4 text-center">
                            <span className="bg-muted px-2 py-0.5 rounded border text-[10px] font-bold">
                              {c.usedCount}{c.maxUses ? ` / ${c.maxUses}` : ' / ∞'}
                            </span>
                          </td>

                          {/* Status */}
                          <td className="py-3 px-4 text-center">
                            <button
                              onClick={() => handleToggleCoupon(c.id, c.isActive)}
                              disabled={savingCouponId === c.id}
                              className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[9px] font-bold cursor-pointer transition-all ${
                                c.isActive
                                  ? 'bg-accent/15 text-accent border border-accent/20 hover:bg-accent/25'
                                  : 'bg-muted text-text-muted border border-border hover:bg-muted/80'
                              }`}
                            >
                              {savingCouponId === c.id ? (
                                <Loader2 className="h-3 w-3 animate-spin" />
                              ) : c.isActive ? (
                                <ToggleRight className="h-3 w-3" />
                              ) : (
                                <ToggleLeft className="h-3 w-3" />
                              )}
                              {c.isActive ? 'Active' : 'Disabled'}
                            </button>
                          </td>

                          {/* Expires */}
                          <td className="py-3 px-4">
                            <span className={`text-[10px] font-medium ${isExpired ? 'text-discount font-bold' : 'text-text-muted'}`}>
                              {c.expiresAt
                                ? new Date(c.expiresAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
                                : 'Never'}
                              {isExpired && ' (Expired)'}
                            </span>
                          </td>

                          {/* Actions */}
                          <td className="py-3 px-4 text-right">
                            <div className="flex items-center justify-end gap-1.5">
                              <button
                                onClick={() => startEditingCoupon(c)}
                                className="p-1.5 border border-border hover:bg-muted text-text-secondary rounded-lg transition-colors"
                                title="Edit coupon"
                              >
                                <Pencil className="h-3.5 w-3.5" />
                              </button>
                              <button
                                onClick={() => handleDeleteCoupon(c.id)}
                                disabled={deletingCouponId === c.id}
                                className="p-1.5 border border-border text-discount hover:bg-discount/10 hover:border-discount/20 rounded-lg transition-colors"
                                title="Delete coupon"
                              >
                                {deletingCouponId === c.id ? (
                                  <Loader2 className="h-3.5 w-3.5 animate-spin" />
                                ) : (
                                  <Trash className="h-3.5 w-3.5" />
                                )}
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
          </div>

        </div>
      )}

      {activeTab === 'analytics' && (
        <div className="animate-fade-in">
          <AdminAnalytics
            products={products}
            orders={orders}
            categories={categories}
            stats={{
              revenue: stats.revenue,
              orderCount: stats.orderCount,
              lowStockCount: stats.lowStockCount
            }}
          />
        </div>
      )}

      {activeTab === 'alerts' && (
        <div className="animate-fade-in">
          <AdminAlerts
            onProductUpdated={async () => {
              try {
                const res = await fetch('/api/products?limit=1000')
                if (res.ok) {
                  const data = await res.json()
                  if (data.products) setProducts(data.products)
                }
              } catch (err) {
                console.error(err)
              }
            }}
          />
        </div>
      )}

      {activeTab === 'inward' && (
        <div className="animate-fade-in">
          <AdminInward
            onInwardCompleted={async () => {
              try {
                const res = await fetch('/api/products?limit=1000')
                if (res.ok) {
                  const data = await res.json()
                  if (data.products) setProducts(data.products)
                }
              } catch (err) {
                console.error(err)
              }
            }}
          />
        </div>
      )}

      {activeTab === 'bulk-update' && (
        <div className="animate-fade-in">
          <AdminBulkUpdate
            categories={categories}
            onUpdateCompleted={async () => {
              try {
                const res = await fetch('/api/products?limit=1000')
                if (res.ok) {
                  const data = await res.json()
                  if (data.products) setProducts(data.products)
                }
              } catch (err) {
                console.error(err)
              }
            }}
          />
        </div>
      )}

      {activeTab === 'reports' && (
        <div className="animate-fade-in">
          <AdminReports />
        </div>
      )}

      {activeTab === 'banners' && (
        <div className="animate-fade-in">
          <AdminBanners />
        </div>
      )}

      {activeTab === 'settings' && (
        <div className="animate-fade-in">
          <AdminSettings />
        </div>
      )}
        </motion.div>
      </AnimatePresence>

      {/* Product Edit Modal */}
      {editingProduct && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in p-4">
          <div className="bg-card border border-border rounded-2xl shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto p-6 animate-scale-up space-y-4">
            <div className="flex justify-between items-center border-b border-border/60 pb-3">
              <h4 className="font-extrabold text-text-primary text-base">Edit Product: {editingProduct.name}</h4>
              <button onClick={() => setEditingProduct(null)} className="text-text-secondary hover:text-text-primary">
                <X className="h-5 w-5" />
              </button>
            </div>
            <form onSubmit={saveProductChanges} className="space-y-4">
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
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Category *</label>
                  <select
                    required
                    value={productEditForm.categoryId}
                    onChange={(e) => setProductEditForm({ ...productEditForm, categoryId: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  >
                    {categories.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Unit Specification *</label>
                  <input
                    type="text"
                    required
                    value={productEditForm.unit}
                    onChange={(e) => setProductEditForm({ ...productEditForm, unit: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Stock Qty *</label>
                  <input
                    type="number"
                    required
                    value={productEditForm.stock}
                    onChange={(e) => setProductEditForm({ ...productEditForm, stock: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">MRP Price (INR) *</label>
                  <input
                    type="number"
                    step="0.01"
                    required
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
                    required
                    value={productEditForm.price}
                    onChange={(e) => setProductEditForm({ ...productEditForm, price: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Emoji Icon / Image URL (Cloudinary)</label>
                  <div className="flex gap-2">
                    <input
                      type="text"
                      value={productEditForm.imageUrl}
                      onChange={(e) => setProductEditForm({ ...productEditForm, imageUrl: e.target.value })}
                      className="flex-1 px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    />
                    <label className="cursor-pointer px-3 py-2 bg-primary/10 hover:bg-primary/20 text-primary text-[10px] font-black rounded-xl border border-primary/20 transition-all flex items-center gap-1.5 whitespace-nowrap">
                      {isUploading ? <Loader2 className="h-3 w-3 animate-spin" /> : 'Upload'}
                      <input
                        type="file"
                        accept="image/*"
                        onChange={(e) => {
                          const file = e.target.files?.[0]
                          if (file) {
                            handleCloudinaryUpload(file, (url) => {
                              setProductEditForm({ ...productEditForm, imageUrl: url })
                            })
                          }
                        }}
                        className="hidden"
                        disabled={isUploading}
                      />
                    </label>
                  </div>
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
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Expiry Date</label>
                  <input
                    type="date"
                    value={productEditForm.expiryDate ? productEditForm.expiryDate.split('T')[0] : ''}
                    onChange={(e) => setProductEditForm({ ...productEditForm, expiryDate: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>

                <div className="md:col-span-2 flex flex-wrap gap-x-6 gap-y-2 pt-2 border-t border-border/40">
                  <span className="text-[10px] font-extrabold text-text-secondary block w-full">Quick Rows / Smart Features</span>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('popular')}
                      onChange={(e) => toggleTag('edit', 'popular', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>Mark as Trending (Popular)</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('late-night')}
                      onChange={(e) => toggleTag('edit', 'late-night', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>Mark as Late Night Craving</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('breakfast')}
                      onChange={(e) => toggleTag('edit', 'breakfast', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>Mark as Breakfast Essential</span>
                  </label>
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
              <div className="flex items-center gap-2 pt-2">
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
                  disabled={savingProductId === editingProduct.id}
                  className="flex items-center gap-1 px-5 py-2 bg-accent text-white text-xs font-bold rounded-xl hover:bg-accent/90 transition-all shadow-sm font-semibold"
                >
                  {savingProductId === editingProduct.id ? (
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
      )}

      {/* Category Edit Modal */}
      {editingCategory && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in p-4">
          <div className="bg-card border border-border rounded-2xl shadow-xl w-full max-w-md p-6 animate-scale-up space-y-4">
            <div className="flex justify-between items-center border-b border-border/60 pb-3">
              <h4 className="font-extrabold text-text-primary text-base">Edit Category</h4>
              <button onClick={() => setEditingCategory(null)} className="text-text-secondary hover:text-text-primary">
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
                        <label className="cursor-pointer px-3 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary text-[10px] font-bold rounded-lg border border-primary/20 transition-all">
                          Upload Photo
                          <input
                            type="file"
                            accept="image/*"
                            onChange={(e) => handleImageFileChange('edit', e)}
                            className="hidden"
                          />
                        </label>
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
                  disabled={savingCategoryId === editingCategory.id}
                  className="flex items-center gap-1 px-5 py-2 bg-accent text-white text-xs font-bold rounded-xl hover:bg-accent/90 transition-all shadow-sm font-semibold"
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
        </div>
      )}

      {/* Review Edit Modal */}
      {editingReview && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in p-4">
          <div className="bg-card border border-border rounded-2xl shadow-xl w-full max-w-md p-6 animate-scale-up space-y-4">
            <div className="flex justify-between items-center border-b border-border/60 pb-3">
              <h4 className="font-extrabold text-text-primary text-base">Edit Review</h4>
              <button onClick={() => setEditingReview(null)} className="text-text-secondary hover:text-text-primary">
                <X className="h-5 w-5" />
              </button>
            </div>
            <form onSubmit={saveReviewChanges} className="space-y-4">
              <div className="space-y-3">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Rating (1-5 Stars)</label>
                  <select
                    value={reviewEditForm.rating}
                    onChange={(e) => setReviewEditForm({ ...reviewEditForm, rating: parseInt(e.target.value) || 5 })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-bold"
                  >
                    <option value="5">5 Stars ⭐⭐⭐⭐⭐</option>
                    <option value="4">4 Stars ⭐⭐⭐⭐</option>
                    <option value="3">3 Stars ⭐⭐⭐</option>
                    <option value="2">2 Stars ⭐⭐</option>
                    <option value="1">1 Star ⭐</option>
                  </select>
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Review Comment</label>
                  <textarea
                    rows={4}
                    value={reviewEditForm.comment}
                    onChange={(e) => setReviewEditForm({ ...reviewEditForm, comment: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
              </div>
              <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
                <button
                  type="button"
                  onClick={() => setEditingReview(null)}
                  className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={savingReviewId === editingReview.id}
                  className="flex items-center gap-1 px-5 py-2 bg-accent text-white text-xs font-bold rounded-xl hover:bg-accent/90 transition-all shadow-sm font-semibold"
                >
                  {savingReviewId === editingReview.id ? (
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
      )}

      {/* Coupon Edit Modal */}
      {editingCoupon && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in p-4">
          <div className="bg-card border border-border rounded-2xl shadow-xl w-full max-w-lg p-6 animate-scale-up space-y-4">
            <div className="flex justify-between items-center border-b border-border/60 pb-3">
              <h4 className="font-extrabold text-text-primary text-base">Edit Coupon</h4>
              <button onClick={() => setEditingCoupon(null)} className="text-text-secondary hover:text-text-primary">
                <X className="h-5 w-5" />
              </button>
            </div>
            <form onSubmit={saveCouponChanges} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Coupon Code *</label>
                  <input
                    type="text"
                    required
                    value={couponEditForm.code}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, code: e.target.value.toUpperCase() })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-bold uppercase tracking-wider"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Discount Type *</label>
                  <select
                    value={couponEditForm.discountType}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, discountType: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  >
                    <option value="PERCENT">Percentage (%)</option>
                    <option value="FLAT">Flat Amount (₹)</option>
                  </select>
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">
                    Discount Value * {couponEditForm.discountType === 'PERCENT' ? '(%)' : '(₹)'}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    required
                    value={couponEditForm.value}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, value: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Min Order Value (₹)</label>
                  <input
                    type="number"
                    step="0.01"
                    value={couponEditForm.minOrder}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, minOrder: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Max Discount Cap (₹)</label>
                  <input
                    type="number"
                    step="0.01"
                    value={couponEditForm.maxDiscount}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, maxDiscount: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    placeholder="Unlimited"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Max Total Uses</label>
                  <input
                    type="number"
                    value={couponEditForm.maxUses}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, maxUses: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    placeholder="Unlimited"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Expiry Date</label>
                  <input
                    type="date"
                    value={couponEditForm.expiresAt}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, expiresAt: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div className="flex items-center gap-2 pt-5">
                  <input
                    type="checkbox"
                    id="editCouponActive"
                    checked={couponEditForm.isActive}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, isActive: e.target.checked })}
                    className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                  />
                  <label htmlFor="editCouponActive" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                    Coupon is Active
                  </label>
                </div>
              </div>
              <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
                <button
                  type="button"
                  onClick={() => setEditingCoupon(null)}
                  className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={savingCouponId === editingCoupon.id}
                  className="flex items-center gap-1 px-5 py-2 bg-accent text-white text-xs font-bold rounded-xl hover:bg-accent/90 transition-all shadow-sm font-semibold"
                >
                  {savingCouponId === editingCoupon.id ? (
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
      )}

    </div>
  )
}
