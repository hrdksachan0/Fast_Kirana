'use client'

import { useState, useEffect, useMemo, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { supabase } from '@/lib/supabase-client'
import { getDistanceKm } from '@/lib/distance'
import { toast } from 'sonner'
import {
  ShoppingBag,
  Package,
  Truck,
  CheckCircle2,
  Check,
  Store,
  X
} from 'lucide-react'

export interface OrderItem {
  id: string
  name: string
  price: number
  quantity: number
  selectedVariant?: string | null
  notes?: string | null
  refundAmount?: number
  isRefunded?: boolean
  productId?: string
  imageUrl?: string
  shopName?: string | null
}

export interface OrderAddress {
  label: string
  houseNo: string
  street: string
  area: string
  city: string
  pincode: string
  lat?: number | null
  lng?: number | null
  phone?: string | null
}

export interface Order {
  id: string
  readableId?: number | string
  baseReadableId?: string
  status: string
  subtotal: number
  discount: number
  deliveryFee: number
  taxes: number
  miscFee: number
  total: number
  refundAmount?: number
  notes?: string | null
  paymentMethod: string
  paymentStatus: string
  estimatedDelivery: string | null
  deliveryPhoto: string | null
  deliveryLat: number | null
  deliveryLng: number | null
  deliveryMethod?: string
  isB2B?: boolean
  shopName?: string | null
  shopPhone?: string | null
  restaurantId?: string | null
  createdAt: string
  items: OrderItem[]
  address: OrderAddress
  deliveryUser?: {
    name: string | null
    phone: string | null
  } | null
  isCombined?: boolean
  groceryStatus?: string | null
  groceryItems?: OrderItem[]
  restaurantStatus?: string | null
  restaurantName?: string | null
  restaurantItems?: OrderItem[]
  subOrders?: any[]
  customerPhone?: string
  customerName?: string
  userName?: string
}

interface UseOrderTrackerOptions {
  initialOrder: Order
  companionOrder?: Order | null
  isCafeOpen?: boolean
}

export function useOrderTracker({
  initialOrder,
  companionOrder,
  isCafeOpen: initialIsCafeOpen = true,
}: UseOrderTrackerOptions) {
  const router = useRouter()
  const [order, setOrder] = useState<Order>(initialOrder)
  const [compOrder, setCompOrder] = useState<Order | null>(companionOrder || null)
  const [activeStep, setActiveStep] = useState(0)
  const [packingStep, setPackingStep] = useState(0)
  const [storeLat, setStoreLat] = useState(26.1534185)
  const [storeLng, setStoreLng] = useState(80.1714024)
  const [supportPhone, setSupportPhone] = useState('+91 8112849854')
  const [isCafeOpen, setIsCafeOpen] = useState(initialIsCafeOpen)

  // Customer Edit Order Modal States & Handlers
  const [isEditing, setIsEditing] = useState(false)
  const [editItems, setEditItems] = useState<any[]>([])
  const [isSaving, setIsSaving] = useState(false)
  const [allProducts, setAllProducts] = useState<any[]>([])
  const [modifySearchQuery, setModifySearchQuery] = useState('')

  // Customer Pre-Confirmation Order Cancellation
  const [isCancelModalOpen, setIsCancelModalOpen] = useState(false)
  const [isCancelling, setIsCancelling] = useState(false)

  const handleCancelOrder = async () => {
    setIsCancelling(true)
    try {
      const res = await fetch(`/api/orders/${order.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'CANCELLED' }),
      })
      const data = await res.json()
      if (!res.ok) {
        throw new Error(data.error || 'Failed to cancel order')
      }
      toast.success('Order cancelled successfully')
      setIsCancelModalOpen(false)
      setOrder((prev: any) => ({ ...prev, status: 'CANCELLED' }))
      router.refresh()
    } catch (err: any) {
      toast.error(err.message || 'Could not cancel order')
    } finally {
      setIsCancelling(false)
    }
  }

  const isModifyCafeOrder = useMemo(() => {
    const shop = order.shopName || ''
    return shop.includes('Cafe') || order.items.some((i: any) => i.product?.tags?.includes('cafe'))
  }, [order])

  const isModifyRestaurantOrder = useMemo(() => {
    const shop = order.shopName || ''
    return shop.includes('Restaurant') || !!order.restaurantId || order.items.some((i: any) => i.product?.restaurantId || i.product?.tags?.includes('restaurant'))
  }, [order])

  const availableProdsToAdd = useMemo(() => {
    if (!modifySearchQuery.trim()) return []
    const query = modifySearchQuery.toLowerCase().trim()
    return allProducts.filter(p => {
      if (isModifyCafeOrder) {
        const isCafe = (p.category?.slug === 'cafe' || (Array.isArray(p.tags) && p.tags.includes('cafe'))) && !p.restaurantId
        if (!isCafe) return false
      } else if (isModifyRestaurantOrder) {
        if (order.restaurantId && p.restaurantId && p.restaurantId !== order.restaurantId) {
          return false
        }
        const isRest = p.restaurantId != null || p.category?.slug === 'restaurant' || p.category?.slug === 'wedson-restaurant' || (Array.isArray(p.tags) && (p.tags.includes('restaurant') || p.tags.includes('wedson-restaurant')))
        if (!isRest) return false
      } else {
        const isKitchen = p.restaurantId != null || p.category?.slug === 'cafe' || p.category?.slug === 'restaurant' || p.category?.slug === 'wedson-restaurant' || (Array.isArray(p.tags) && (p.tags.includes('cafe') || p.tags.includes('restaurant') || p.tags.includes('wedson-restaurant')))
        if (isKitchen) return false
      }
      
      const tagMatch = Array.isArray(p.tags)
        ? p.tags.some((t: string) => typeof t === 'string' && t.toLowerCase().includes(query))
        : (typeof p.tags === 'string' ? (p.tags as string).toLowerCase().includes(query) : false)

      return (p.name && p.name.toLowerCase().includes(query)) || tagMatch
    }).slice(0, 10)
  }, [allProducts, modifySearchQuery, isModifyCafeOrder, isModifyRestaurantOrder, order.restaurantId])

  const handleAddProductToOrder = (prod: any) => {
    const existingIndex = editItems.findIndex(i => i.productId === prod.id)
    if (existingIndex !== -1) {
      setEditItems(prev => prev.map((item, idx) => idx === existingIndex ? { ...item, quantity: item.quantity + 1 } : item))
    } else {
      const hasVariants = prod.variants && Array.isArray(prod.variants) && prod.variants.length > 0
      const defaultVariant = hasVariants ? prod.variants[0].name : null
      const defaultPrice = hasVariants ? prod.variants[0].price : prod.price
      setEditItems(prev => [
        ...prev,
        {
          id: `new-${prod.id}-${Date.now()}`,
          orderId: order.id,
          productId: prod.id,
          name: prod.name,
          price: defaultPrice,
          quantity: 1,
          selectedVariant: defaultVariant,
          imageUrl: prod.imageUrl,
          shopName: order.shopName
        }
      ])
    }
    toast.success(`Added ${prod.name} to order`)
  }

  const handleOpenCustomerEdit = async () => {
    const items = order.items.map(i => ({ ...i, orderId: order.id }))
    if (compOrder) {
      const compItems = compOrder.items.map(i => ({ ...i, orderId: compOrder.id }))
      setEditItems([...items, ...compItems])
    } else {
      setEditItems(items)
    }
    setModifySearchQuery('')
    setIsEditing(true)

    try {
      const url = order.restaurantId
        ? `/api/products?restaurantId=${order.restaurantId}&includeUnavailable=true&limit=250`
        : (isModifyRestaurantOrder
            ? '/api/products?category=restaurant,wedson-restaurant&includeUnavailable=true&limit=250'
            : (isModifyCafeOrder
                ? '/api/products?category=cafe,ice-cream,beverages&includeUnavailable=true&limit=250'
                : '/api/products?includeUnavailable=true&limit=250'))
      const res = await fetch(url).catch(() => null)
      if (res?.ok) {
        const d = await res.json()
        setAllProducts(d.products || [])
      }
    } catch (err) {
      console.error('Failed to load products for editing:', err)
    }
  }

  const updateItemQty = (productId: string, variant: string | null, delta: number) => {
    setEditItems(prev => prev.map(item => {
      if (item.productId === productId && item.selectedVariant === variant) {
        return { ...item, quantity: Math.max(0, item.quantity + delta) }
      }
      return item
    }).filter(i => i.quantity > 0))
  }

  const updateItemVariant = (productId: string, oldVariant: string | null, newVariant: string, newPrice: number) => {
    setEditItems(prev => prev.map(item => {
      if (item.productId === productId && item.selectedVariant === oldVariant) {
        return {
          ...item,
          selectedVariant: newVariant,
          price: newPrice
        }
      }
      return item
    }))
  }

  const handleSaveEdits = async () => {
    setIsSaving(true)
    try {
      const primaryUpdates = editItems.filter(i => i.orderId === order.id)
      const companionUpdates = compOrder ? editItems.filter(i => i.orderId === compOrder.id) : []

      const promises = [
        fetch(`/api/orders/${order.id}/edit`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ updatedItems: primaryUpdates })
        })
      ]

      if (compOrder) {
        promises.push(
          fetch(`/api/orders/${compOrder.id}/edit`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ updatedItems: companionUpdates })
          })
        )
      }

      const results = await Promise.all(promises)
      const failed = results.find(r => !r.ok)
      if (failed) {
        const data = await failed.json()
        toast.error(data.error || 'Failed to modify order')
      } else {
        toast.success('Order items updated successfully!')
        setIsEditing(false)
        router.refresh()
      }
    } catch (err) {
      toast.error('Error modifying order')
    } finally {
      setIsSaving(false)
    }
  }

  const combinedStatus = useMemo(() => {
    if (!compOrder) return order.status
    const statuses = [order.status, compOrder.status]
    if (statuses.includes('CANCELLED') && statuses.every(s => s === 'CANCELLED')) return 'CANCELLED'
    if (statuses.every(s => s === 'DELIVERED')) return 'DELIVERED'
    if (statuses.includes('SHIPPED')) return 'SHIPPED'
    if (statuses.every(s => s === 'PACKED' || s === 'SHIPPED' || s === 'DELIVERED')) return 'PACKED'
    if (statuses.includes('CONFIRMED')) return 'CONFIRMED'
    if (statuses.includes('PENDING')) return 'PENDING'
    if (statuses.includes('ADMIN_PENDING')) return 'ADMIN_PENDING'
    return 'PENDING'
  }, [order.status, compOrder?.status])

  const statusSteps = useMemo(() => {
    if (combinedStatus === 'CANCELLED') {
      return [
        { status: 'PENDING', label: 'Order Placed', desc: 'We have received your order.', icon: ShoppingBag },
        { status: 'CANCELLED', label: 'Order Cancelled', desc: 'This order has been cancelled.', icon: X },
      ]
    }
    if (order.deliveryMethod === 'PICKUP') {
      return [
        { status: 'PENDING', label: 'Order Placed', desc: 'We have received your order.', icon: ShoppingBag },
        { status: 'CONFIRMED', label: 'Confirmed', desc: 'Store has accepted your order.', icon: CheckCircle2 },
        { status: 'PACKED', label: 'Packing Items', desc: 'Packing fresh items at our store.', icon: Package },
        { status: 'SHIPPED', label: 'Ready for Pickup', desc: 'Your order is ready to be picked up!', icon: Store },
        { status: 'DELIVERED', label: 'Picked Up', desc: 'Order has been successfully picked up!', icon: Check },
      ]
    }
    return [
      { status: 'PENDING', label: 'Order Placed', desc: 'We have received your order.', icon: ShoppingBag },
      { status: 'CONFIRMED', label: 'Confirmed', desc: 'Store has accepted your order.', icon: CheckCircle2 },
      { status: 'PACKED', label: 'Packing Items', desc: 'Packing fresh items at our dark store.', icon: Package },
      { status: 'SHIPPED', label: 'Out for Delivery', desc: 'Rider is carrying your order.', icon: Truck },
      { status: 'DELIVERED', label: 'Delivered', desc: 'Order delivered to your door!', icon: Check },
    ]
  }, [combinedStatus, order.deliveryMethod])

  // Fetch store coordinates and support phone on mount
  useEffect(() => {
    fetch('/api/settings', { cache: 'no-store' })
      .then(res => res.json())
      .then(data => {
        if (data.store_lat) setStoreLat(parseFloat(data.store_lat))
        if (data.store_lng) setStoreLng(parseFloat(data.store_lng))
        if (data.contact_phone) setSupportPhone(data.contact_phone)
        if (data.cafe_open !== undefined) {
          setIsCafeOpen(data.cafe_open === 'true')
        }
      })
      .catch(err => console.error('Error fetching settings in order-tracker:', err))
  }, [])

  // Cycle through packaging micro-steps when order is in PACKED state
  useEffect(() => {
    if (order.status !== 'PACKED') return
    const interval = setInterval(() => {
      setPackingStep((prev) => (prev + 1) % 3)
    }, 3000)
    return () => clearInterval(interval)
  }, [order.status])

  // Determine active step index based on order status
  useEffect(() => {
    const currentStatus = order.status
    const mappedStatus = ['READY_FOR_PICKUP', 'READY', 'PREPARED'].includes(currentStatus)
      ? 'SHIPPED'
      : (currentStatus === 'ADMIN_PENDING' ? 'PENDING' : currentStatus)
    const idx = statusSteps.findIndex((s) => s.status === mappedStatus)
    if (idx !== -1) {
      setActiveStep(idx)
    }
  }, [order.status, statusSteps])

  // Fallback polling for order status
  useEffect(() => {
    const isMainTerminal = order.status === 'DELIVERED' || order.status === 'CANCELLED'
    const isCompTerminal = !compOrder || compOrder.status === 'DELIVERED' || compOrder.status === 'CANCELLED'
    if (isMainTerminal && isCompTerminal) return

    const pollInterval = setInterval(async () => {
      if (typeof document !== 'undefined' && document.visibilityState !== 'visible') return
      try {
        if (!isMainTerminal) {
          const res = await fetch(`/api/orders/${order.id}`)
          if (res.ok) {
            const data = await res.json()
            if (data && data.status) {
              setOrder((prev) => {
                if (JSON.stringify(data) !== JSON.stringify(prev)) {
                  if (data.status !== prev.status) {
                    toast.success(`Order Update: ${data.status} ✅`)
                  }
                  return data
                }
                return prev
              })
            }
          }
        }

        if (compOrder && !isCompTerminal) {
          const compRes = await fetch(`/api/orders/${compOrder.id}`)
          if (compRes.ok) {
            const compData = await compRes.json()
            if (compData && compData.status) {
              setCompOrder((prev) => {
                if (JSON.stringify(compData) !== JSON.stringify(prev)) {
                  return compData
                }
                return prev
              })
            }
          }
        }
      } catch (err) {
        console.error('Error during fallback order polling:', err)
      }
    }, 4000)

    return () => clearInterval(pollInterval)
  }, [order.id, order.status, compOrder?.id, compOrder?.status])

  // Real-time Supabase subscription
  useEffect(() => {
    const channel = supabase
      .channel(`order-${order.id}-tracking`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'Order' },
        (payload: any) => {
          const updated = payload.new
          if (!updated) return
          const orderId = updated.id

          if (orderId === order.id) {
            fetch(`/api/orders/${order.id}`)
              .then(res => res.json())
              .then(data => {
                if (data && data.status) {
                  const wasEdited = data.status === order.status && data.total !== order.total
                  setOrder(data)
                  if (wasEdited) {
                    toast.info('⚠️ Your order has been modified by the store. Bill details updated.', {
                      icon: '📝'
                    })
                  }
                }
              })
          }

          if (compOrder && orderId === compOrder.id) {
            fetch(`/api/orders/${compOrder.id}`)
              .then(res => res.json())
              .then(data => {
                if (data && data.status) {
                  const wasEdited = data.status === compOrder.status && data.total !== compOrder.total
                  setCompOrder(data)
                  if (wasEdited) {
                    toast.info('⚠️ Your order has been modified by the store. Bill details updated.', {
                      icon: '📝'
                    })
                  }
                }
              })
          }
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [order.id, compOrder?.id])

  // Merged items from both orders
  const mergedItems = useMemo(() => {
    const items = order.items.map(i => ({ ...i, shopName: order.shopName }))
    if (compOrder) {
      const compItems = compOrder.items.map(item => ({
        ...item,
        shopName: compOrder.shopName
      }))
      return [...items, ...compItems]
    }
    return items
  }, [order.items, order.shopName, compOrder])

  // Combined Billing Totals
  const combinedSubtotal = (order.subtotal || 0) + (compOrder?.subtotal || 0)
  const combinedDiscount = (order.discount || 0) + (compOrder?.discount || 0)
  const combinedDeliveryFee = (order.deliveryFee || 0) + (compOrder?.deliveryFee || 0)
  const combinedTaxes = (order.taxes || 0) + (compOrder?.taxes || 0)
  const rawMiscFee = (order.miscFee || 0) + (compOrder?.miscFee || 0)
  const combinedTotal = (order.total || 0) + (compOrder?.total || 0)
  const feeDiff = Math.max(0, combinedTotal - (combinedSubtotal - combinedDiscount + combinedDeliveryFee + combinedTaxes))
  const combinedMiscFee = rawMiscFee > 0 ? rawMiscFee : feeDiff
  const combinedRefundAmount = (order.refundAmount || 0) + (compOrder?.refundAmount || 0)

  // Live rider distance and ETA
  const trackingMetrics = useMemo(() => {
    if (order.deliveryMethod === 'PICKUP') return null
    if (order.status !== 'SHIPPED') return null

    const destLat = order.address?.lat || storeLat + 0.004
    const destLng = order.address?.lng || storeLng + 0.005
    
    let riderLat = order.deliveryLat || storeLat
    let riderLng = order.deliveryLng || storeLng
    
    const distanceKm = getDistanceKm(riderLat, riderLng, destLat, destLng)
    const etaMins = Math.max(2, Math.round(distanceKm * 3.5))
    const isArrived = distanceKm <= 0.25
    
    return {
      distance: distanceKm.toFixed(1),
      distanceNum: distanceKm,
      eta: etaMins,
      isArrived
    }
  }, [order.status, order.deliveryLat, order.deliveryLng, order.address?.lat, order.address?.lng, storeLat, storeLng, order.deliveryMethod])

  const isCafeOrder = !!(order as any).restaurantId || (order as any).orderType === 'RESTAURANT' || order.shopName?.toLowerCase().includes('cafe')
  const isScheduled = !!(order.estimatedDelivery && order.createdAt && 
    (new Date(order.estimatedDelivery).getTime() - new Date(order.createdAt).getTime() > 45 * 60 * 1000))

  return {
    order,
    setOrder,
    compOrder,
    setCompOrder,
    activeStep,
    packingStep,
    storeLat,
    storeLng,
    supportPhone,
    isCafeOpen,
    combinedStatus,
    statusSteps,
    mergedItems,
    combinedSubtotal,
    combinedDiscount,
    combinedDeliveryFee,
    combinedTaxes,
    combinedMiscFee,
    combinedTotal,
    combinedRefundAmount,
    trackingMetrics,
    isCafeOrder,
    isScheduled,
    isEditing,
    setIsEditing,
    editItems,
    setEditItems,
    isSaving,
    allProducts,
    modifySearchQuery,
    setModifySearchQuery,
    availableProdsToAdd,
    handleAddProductToOrder,
    handleOpenCustomerEdit,
    updateItemQty,
    updateItemVariant,
    handleSaveEdits,
    isCancelModalOpen,
    setIsCancelModalOpen,
    isCancelling,
    handleCancelOrder,
  }
}
