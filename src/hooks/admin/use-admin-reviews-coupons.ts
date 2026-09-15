'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'

interface UseAdminReviewsCouponsProps {
  initialReviews?: any[]
  initialCoupons?: any[]
  activeTab: string
}

export function useAdminReviewsCoupons({
  initialReviews,
  initialCoupons,
  activeTab,
}: UseAdminReviewsCouponsProps) {
  // Reviews state
  const [reviews, setReviews] = useState(initialReviews || [])
  const [isLoadingReviews, setIsLoadingReviews] = useState(false)
  const [deletingReviewId, setDeletingReviewId] = useState<string | null>(null)
  const [reviewSearch, setReviewSearch] = useState('')

  const [editingReview, setEditingReview] = useState<any | null>(null)
  const [savingReviewId, setSavingReviewId] = useState<string | null>(null)
  const [reviewEditForm, setReviewEditForm] = useState({
    rating: 5,
    comment: '',
  })

  // Coupons state
  const [coupons, setCoupons] = useState(initialCoupons || [])
  const [isLoadingCoupons, setIsLoadingCoupons] = useState(false)
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
    categoryId: '',
    oncePerCustomer: false,
  })

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
    categoryId: '',
    oncePerCustomer: false,
  })

  // Lazy load reviews
  useEffect(() => {
    if (activeTab === 'reviews' && reviews.length === 0) {
      const loadReviews = async () => {
        setIsLoadingReviews(true)
        try {
          const res = await fetch(`/api/admin/reviews?t=${Date.now()}`)
          if (res.ok) {
            const data = await res.json()
            setReviews(data)
          }
        } catch (err) {
          console.error('Failed to load reviews:', err)
        } finally {
          setIsLoadingReviews(false)
        }
      }
      loadReviews()
    }
  }, [activeTab, reviews.length])

  // Lazy load coupons
  useEffect(() => {
    if (activeTab === 'coupons' && coupons.length === 0) {
      const loadCoupons = async () => {
        setIsLoadingCoupons(true)
        try {
          const res = await fetch(`/api/admin/coupons?t=${Date.now()}`)
          if (res.ok) {
            const data = await res.json()
            setCoupons(data)
          }
        } catch (err) {
          console.error('Failed to load coupons:', err)
        } finally {
          setIsLoadingCoupons(false)
        }
      }
      loadCoupons()
    }
  }, [activeTab, coupons.length])

  // Reviews handlers
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
          type: editingReview.type,
        }),
      })

      if (res.ok) {
        const updated = await res.json()
        setReviews(
          reviews.map((r: any) =>
            r.id === editingReview.id
              ? { ...r, rating: updated.rating, comment: updated.comment }
              : r
          )
        )
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
    const reviewType = (reviews as any[]).find((r) => r.id === reviewId)?.type
    setDeletingReviewId(reviewId)
    try {
      const res = await fetch('/api/admin/reviews', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reviewId, type: reviewType }),
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

  // Coupons handlers
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
          categoryId: '',
          oncePerCustomer: false,
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
      categoryId: c.categoryId || '',
      oncePerCustomer: c.oncePerCustomer === true,
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
          categoryId: couponEditForm.categoryId || null,
          oncePerCustomer: couponEditForm.oncePerCustomer,
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

  return {
    reviews,
    setReviews,
    isLoadingReviews,
    deletingReviewId,
    reviewSearch,
    setReviewSearch,
    editingReview,
    setEditingReview,
    savingReviewId,
    reviewEditForm,
    setReviewEditForm,
    startEditingReview,
    saveReviewChanges,
    handleDeleteReview,
    coupons,
    setCoupons,
    isLoadingCoupons,
    showAddCoupon,
    setShowAddCoupon,
    isCreatingCoupon,
    deletingCouponId,
    newCoupon,
    setNewCoupon,
    editingCoupon,
    setEditingCoupon,
    savingCouponId,
    couponEditForm,
    setCouponEditForm,
    handleCreateCoupon,
    startEditingCoupon,
    saveCouponChanges,
    handleToggleCoupon,
    handleDeleteCoupon,
  }
}
