'use client'

import { useState, useEffect, useMemo } from 'react'
import { useSession } from 'next-auth/react'
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
  const { data: session } = useSession()
  const authHeaders = useMemo(() => ({
    'Content-Type': 'application/json',
    ...(session?.user?.id ? { 'x-user-id': session.user.id } : {}),
    ...((session?.user as any)?.role ? { 'x-user-role': (session?.user as any).role } : { 'x-user-role': 'ADMIN' }),
    ...(session?.user?.email ? { 'x-user-email': session.user.email } : {}),
    ...((session?.user as any)?.phone ? { 'x-user-phone': (session?.user as any).phone } : {}),
  }), [session])

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
    bogoType: 'BUY_LARGE_GET_SMALL',
    triggerVariant: 'Large',
    rewardVariant: 'Small',
    bogoDishId: '',
    defaultFreeDishId: '',
    restaurantId: '',
    badgeText: '',
    menuSection: '',
    autoApply: false,
    syncRestaurantBadge: true,
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
    bogoType: 'BUY_LARGE_GET_SMALL',
    triggerVariant: 'Large',
    rewardVariant: 'Small',
    bogoDishId: '',
    defaultFreeDishId: '',
    restaurantId: '',
    badgeText: '',
    menuSection: '',
    autoApply: false,
    syncRestaurantBadge: true,
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
          const res = await fetch(`/api/admin/reviews?t=${Date.now()}`, { headers: authHeaders })
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
  }, [activeTab, reviews.length, authHeaders])

  // Lazy load coupons
  useEffect(() => {
    if (activeTab === 'coupons' && coupons.length === 0) {
      const loadCoupons = async () => {
        setIsLoadingCoupons(true)
        try {
          const res = await fetch(`/api/admin/coupons?t=${Date.now()}`, { headers: authHeaders })
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
  }, [activeTab, coupons.length, authHeaders])

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
        headers: authHeaders,
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
        headers: authHeaders,
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
    if (!newCoupon.code) {
      toast.error('Coupon code is required')
      return
    }

    const isBogoOrFreeDelivery = newCoupon.discountType === 'BOGO' || newCoupon.discountType === 'FREE_DELIVERY'
    if (!isBogoOrFreeDelivery && !newCoupon.value) {
      toast.error('Discount value is required')
      return
    }

    setIsCreatingCoupon(true)
    try {
      const payload = {
        ...newCoupon,
        value: isBogoOrFreeDelivery ? (newCoupon.discountType === 'FREE_DELIVERY' ? 0 : 100) : (parseFloat(newCoupon.value) || 0),
        minOrder: parseFloat(newCoupon.minOrder) || 0,
        maxDiscount: newCoupon.maxDiscount ? parseFloat(newCoupon.maxDiscount) : null,
        maxUses: newCoupon.maxUses ? parseInt(newCoupon.maxUses) : null,
      }

      const res = await fetch('/api/admin/coupons', {
        method: 'POST',
        headers: authHeaders,
        body: JSON.stringify(payload),
      })

      if (res.ok) {
        const created = await res.json()
        setCoupons([created, ...coupons])
        toast.success(`Coupon "${created.code}" created!`)
        setShowAddCoupon(false)
        setNewCoupon({
          code: '',
          discountType: 'PERCENT',
          bogoType: 'BUY_LARGE_GET_SMALL',
          triggerVariant: 'Large',
          rewardVariant: 'Small',
          bogoDishId: '',
          defaultFreeDishId: '',
          restaurantId: '',
          badgeText: '',
          menuSection: '',
          autoApply: false,
          syncRestaurantBadge: true,
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
      bogoType: c.bogoType || 'BUY_LARGE_GET_SMALL',
      triggerVariant: c.triggerVariant || 'Large',
      rewardVariant: c.rewardVariant || 'Small',
      bogoDishId: c.bogoDishId || '',
      defaultFreeDishId: c.defaultFreeDishId || '',
      restaurantId: c.restaurantId || '',
      badgeText: c.badgeText || '',
      menuSection: c.menuSection || '',
      autoApply: c.autoApply === true,
      syncRestaurantBadge: true,
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
      const isBogoOrFreeDelivery = couponEditForm.discountType === 'BOGO' || couponEditForm.discountType === 'FREE_DELIVERY'
      const res = await fetch('/api/admin/coupons', {
        method: 'PATCH',
        headers: authHeaders,
        body: JSON.stringify({
          couponId: editingCoupon.id,
          code: couponEditForm.code,
          discountType: couponEditForm.discountType,
          bogoType: couponEditForm.bogoType,
          triggerVariant: couponEditForm.triggerVariant,
          rewardVariant: couponEditForm.rewardVariant,
          bogoDishId: couponEditForm.bogoDishId || null,
          defaultFreeDishId: couponEditForm.defaultFreeDishId || null,
          restaurantId: couponEditForm.restaurantId || null,
          badgeText: couponEditForm.badgeText || null,
          menuSection: couponEditForm.menuSection || null,
          autoApply: couponEditForm.autoApply,
          syncRestaurantBadge: couponEditForm.syncRestaurantBadge,
          value: isBogoOrFreeDelivery ? (couponEditForm.discountType === 'FREE_DELIVERY' ? 0 : 100) : (parseFloat(couponEditForm.value) || 0),
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
        headers: authHeaders,
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
        headers: authHeaders,
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
