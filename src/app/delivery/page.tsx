'use client';
import { apiUrl } from '@/lib/api-url';

import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { useSession } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { isToday } from 'date-fns'
import { toast } from 'sonner'
import { playNotificationChime, playSuccessChime } from '@/lib/audio'
import { triggerHaptic } from '@/lib/haptic'
import { Loader2, Truck, ShoppingBag, ChevronDown } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { supabase } from '@/lib/supabase-client'

// Shared Utilities & Hooks
import { triggerConfetti } from '@/lib/confetti'
import { optimizeRoute } from '@/lib/delivery-routing'
import { useDeliveryOfflineSync } from '@/hooks/delivery/use-delivery-offline-sync'
import { useRiderLocationTracking } from '@/hooks/delivery/use-rider-location-tracking'
import { detectOrderRoute, DELIVERY_ROUTES, DeliveryRouteKey } from '@/lib/route-detector'
import { groupCombinedDeliveryOrders } from '@/lib/order-combiner'

// Sub-components
import DeliveryHeader from './components/delivery-header'
import CodPaymentModal from './components/cod-payment-modal'
import UpiQrModal from './components/upi-qr-modal'
import ActiveDeliveryCard from './components/active-delivery-card'
import PendingPickupCard from './components/pending-pickup-card'
import RiderWalletView from './components/rider-wallet-view'
import DeliveryHistoryView from './components/delivery-history-view'
import { HandoverConfirmModal } from './components/handover-confirm-modal'

export default function DeliveryDashboard() {
  const { data: session, status } = useSession()
  const router = useRouter()
  const [orders, setOrders] = useState<any[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isRefreshing, setIsRefreshing] = useState(false)
  const [updatingId, setUpdatingId] = useState<string | null>(null)

  const [activeTab, setActiveTab] = useState<'deliveries' | 'wallet' | 'history'>('deliveries')
  const [deliverySubTab, setDeliverySubTab] = useState<'active' | 'assigned'>('active')
  const [selectedRouteFilter, setSelectedRouteFilter] = useState<DeliveryRouteKey>('ALL')
  const [selectedVendorFilter, setSelectedVendorFilter] = useState<string>('ALL')
  const [paymentChoiceOrderId, setPaymentChoiceOrderId] = useState<string | null>(null)
  const [qrModalOrder, setQrModalOrder] = useState<any | null>(null)
  const [confirmDeliveryOrder, setConfirmDeliveryOrder] = useState<any | null>(null)

  const [walletInfo, setWalletInfo] = useState<{
    cashInHand: number
    cashLimit: number
    totalCollected: number
    totalDeposited: number
    isLocked: boolean
    isWarning: boolean
    remainingLimit: number
  } | null>(null)

  const [autoRefreshCountdown, setAutoRefreshCountdown] = useState(30)
  const ordersRef = useRef<any[]>([])

  const { getCurrentCoords } = useRiderLocationTracking()

  const fetchWallet = useCallback(async () => {
    try {
      const res = await fetch(`${apiUrl()}/api/delivery/wallet`)
      if (res.ok) {
        const data = await res.json()
        setWalletInfo(data.wallet || null)
      }
    } catch (err) {
      console.error('Failed to fetch wallet info:', err)
    }
  }, [])

  useEffect(() => {
    ordersRef.current = orders
  }, [orders])

  useEffect(() => {
    if (status === 'authenticated') {
      fetchWallet()
    }
  }, [status, fetchWallet])

  useEffect(() => {
    if (status === 'unauthenticated') {
      router.push('/login?callbackUrl=/delivery')
    }
  }, [status, router])

  const fetchOrders = useCallback(async (silent = false) => {
    if (!silent) setIsLoading(true)
    else setIsRefreshing(true)

    if (typeof window !== 'undefined' && !navigator.onLine) {
      try {
        const cached = localStorage.getItem('delivery_orders_cache')
        if (cached) {
          setOrders(JSON.parse(cached))
          toast.info('Viewing cached offline data')
        }
      } catch (err) {
        console.error('Failed to load cached delivery orders:', err)
      } finally {
        setIsLoading(false)
        setIsRefreshing(false)
      }
      return
    }

    try {
      const res = await fetch(`${apiUrl()}/api/delivery/orders`)
      if (res.ok) {
        const data = await res.json()
        const unified = groupCombinedDeliveryOrders(data)
        setOrders(unified)

        if (typeof window !== 'undefined') {
          const sanitizedCache = unified.map((o: any) => ({
            id: o.id,
            orderNumber: o.orderNumber,
            status: o.status,
            total: o.total,
            createdAt: o.createdAt,
          }))
          localStorage.setItem('delivery_orders_cache', JSON.stringify(sanitizedCache))
        }
      } else {
        toast.error('Failed to fetch delivery orders')
      }
    } catch (err) {
      if (typeof window !== 'undefined') {
        const cached = localStorage.getItem('delivery_orders_cache')
        if (cached) {
          setOrders(groupCombinedDeliveryOrders(JSON.parse(cached)))
          toast.warning('Network error. Loaded cached offline data.')
        }
      }
    } finally {
      setIsLoading(false)
      setIsRefreshing(false)
    }
  }, [])

  // Offline Sync Hook
  const { isOffline, offlineQueue, setOfflineQueue } = useDeliveryOfflineSync(() => {
    fetchOrders(true)
  })

  useEffect(() => {
    if (status === 'authenticated') {
      fetchOrders()
    }
  }, [status, fetchOrders])

  // Connect to Supabase Realtime for order notifications
  useEffect(() => {
    if (status !== 'authenticated') return

    let updateTimeout: NodeJS.Timeout | null = null

    const channel = supabase
      .channel('delivery-orders-live')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'orders',
        },
        (payload) => {
          if (payload.eventType === 'UPDATE') {
            const newOrder = payload.new as any
            const orderId = newOrder.id
            const newStatus = newOrder.status

            const activeShipped = ordersRef.current.filter((o) => o.status === 'SHIPPED')
            const wasActive = activeShipped.find((o) => o.id === orderId)
            if (wasActive && newStatus === 'CANCELLED') {
              playNotificationChime()
              triggerHaptic('warning')
              const orderNum = wasActive.readableId || orderId.slice(0, 8)
              toast.error(
                `⚠️ Active delivery #${orderNum} to ${
                  wasActive.user?.name || 'customer'
                } was CANCELLED by the customer! Please do not deliver.`,
                {
                  duration: 10000,
                  icon: '🛑',
                }
              )
            }

            const activePacked = ordersRef.current.filter((o) => o.status === 'PACKED')
            const wasPending = activePacked.find((o) => o.id === orderId)
            if (wasPending && newStatus === 'CANCELLED') {
              const orderNum = wasPending.readableId || orderId.slice(0, 8)
              toast.info(`📦 Order #${orderNum} in pickup queue has been CANCELLED.`, {
                icon: 'ℹ️',
              })
            }

            if (updateTimeout) clearTimeout(updateTimeout)
            updateTimeout = setTimeout(() => {
              fetchOrders(true)
            }, 1000)

            if (newStatus === 'PACKED') {
              playNotificationChime()
              triggerHaptic('success')
            }
          } else if (payload.eventType === 'INSERT') {
            if (updateTimeout) clearTimeout(updateTimeout)
            updateTimeout = setTimeout(() => {
              fetchOrders(true)
            }, 1000)
          }
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
      if (updateTimeout) {
        clearTimeout(updateTimeout)
      }
    }
  }, [status, fetchOrders])

  // Auto-refresh countdown
  useEffect(() => {
    if (status !== 'authenticated') return
    let isCancelled = false
    const id = setInterval(() => {
      if (isCancelled) return
      if (document.visibilityState !== 'visible') return
      setAutoRefreshCountdown((prev) => {
        if (prev <= 1) {
          fetchOrders(true)
          return 30
        }
        return prev - 1
      })
    }, 1000)
    return () => {
      isCancelled = true
      clearInterval(id)
    }
  }, [status, fetchOrders])

  const prevPendingCountRef = useRef<number | null>(null)

  useEffect(() => {
    if (status !== 'authenticated') return
    const currentPending = orders.filter((o) => o.status === 'PACKED')
    if (
      prevPendingCountRef.current !== null &&
      currentPending.length > prevPendingCountRef.current
    ) {
      playNotificationChime()
      triggerHaptic('success')
      toast.info('New order ready for pickup!', {
        id: 'new-pickup-alert',
        icon: '📦',
      })
    }
    prevPendingCountRef.current = currentPending.length
  }, [orders, status])

  const handleUpdateStatus = async (orderId: string, newStatus: string, extraData: any = {}) => {
    setUpdatingId(orderId)

    if (typeof window !== 'undefined' && !navigator.onLine) {
      try {
        const targetOrder = orders.find((o) => o.id === orderId)
        const companionId = targetOrder?.companionOrder?.id
        const subOrderIds = targetOrder?.subOrders?.map((s: any) => s.id) || []
        const allRelatedIds = Array.from(new Set([orderId, companionId, ...subOrderIds].filter(Boolean)))

        const savedQueue = JSON.parse(localStorage.getItem('offline_delivery_updates') || '[]')
        allRelatedIds.forEach((id) => {
          savedQueue.push({ orderId: id, newStatus, extraData, timestamp: new Date().getTime() })
        })
        localStorage.setItem('offline_delivery_updates', JSON.stringify(savedQueue))
        setOfflineQueue(savedQueue)

        const relatedSet = new Set(allRelatedIds)
        const updatedOrders = orders.map((o) => {
          if (relatedSet.has(o.id)) {
            const up: any = { ...o, status: newStatus }
            if (newStatus === 'SHIPPED') {
              up.deliveryUserId = session?.user?.id
              up.shippedAt = new Date().toISOString()
            } else if (newStatus === 'DELIVERED') {
              up.deliveryPhoto = extraData.deliveryPhoto || null
              up.deliveryLat = extraData.deliveryLat || null
              up.deliveryLng = extraData.deliveryLng || null
              up.deliveredAt = new Date().toISOString()
            }
            return up
          }
          return o
        })
        const sanitizedUpdatedCache = updatedOrders.map((o: any) => ({
          id: o.id,
          orderNumber: o.orderNumber,
          status: o.status,
          total: o.total,
          createdAt: o.createdAt,
        }))
        localStorage.setItem('delivery_orders_cache', JSON.stringify(sanitizedUpdatedCache))

        if (newStatus === 'DELIVERED') {
          playSuccessChime()
          triggerHaptic('success')
          triggerConfetti()
        } else {
          triggerHaptic('medium')
        }
        toast.success(`Saved locally! Status will sync when online.`)
        return true
      } catch (err) {
        toast.error('Failed to save offline status update')
        return false
      } finally {
        setUpdatingId(null)
      }
    }

    try {
      const targetOrder = orders.find((o) => o.id === orderId)
      const companionId = targetOrder?.companionOrder?.id
      const subOrderIds = targetOrder?.subOrders?.map((s: any) => s.id) || []
      const allRelatedIds = Array.from(new Set([orderId, companionId, ...subOrderIds].filter(Boolean)))

      // Update all related sub-orders simultaneously
      const patchPromises = allRelatedIds.map((id) =>
        fetch(`${apiUrl()}/api/orders/${id}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: newStatus, ...extraData }),
        })
      )
      const responses = await Promise.all(patchPromises)
      const res = responses[0]

      if (res.ok) {
        if (newStatus === 'DELIVERED') {
          playSuccessChime()
          triggerHaptic('success')
          triggerConfetti()
        } else {
          triggerHaptic('medium')
        }
        toast.success(`Order updated successfully!`)
        fetchOrders(true)
        return true
      } else {
        const errData = await res.json().catch(() => ({}))
        toast.error(errData.error || 'Failed to update order')
        fetchOrders(true)
        return false
      }
    } catch (err) {
      toast.error('Error updating order state')
      return false
    } finally {
      setUpdatingId(null)
    }
  }

  // Multi-Hub & Strict Rider Assignment Guard:
  // 1. If assigned by Admin, strictly match session rider ID.
  // 2. Multi-hub: match rider's assignedStoreId if configured.
  const currentRiderId = session?.user?.id
  const currentRiderStoreId = (session?.user as any)?.assignedStoreId

  const isOrderAssignedToMe = useCallback(
    (o: any) => {
      // If order has an assigned rider, must match currently logged-in rider
      if (o.deliveryUserId) {
        return o.deliveryUserId === currentRiderId
      }
      if (o.companionOrder?.deliveryUserId) {
        return o.companionOrder.deliveryUserId === currentRiderId
      }
      if (o.subOrders?.some((s: any) => s.deliveryUserId === currentRiderId)) {
        return true
      }
      // If unassigned, only show if rider belongs to the same operational hub and order has no rider
      if (currentRiderStoreId && o.storeId && o.storeId !== currentRiderStoreId) {
        return false
      }
      // If unassigned orders are gated: only show if explicitly assigned to this rider
      return false
    },
    [currentRiderId, currentRiderStoreId]
  )

  const rawOutForDelivery = useMemo(
    () => orders.filter((o) => o.status === 'SHIPPED' && (o.deliveryUserId === currentRiderId || isOrderAssignedToMe(o))),
    [orders, currentRiderId, isOrderAssignedToMe]
  )
  const outForDeliveryOrders = useMemo(() => {
    const optimized = optimizeRoute(rawOutForDelivery)
    const dedupped: any[] = []
    const seen = new Set<string>()
    for (const o of optimized) {
      if (seen.has(o.id)) continue
      dedupped.push(o)
      seen.add(o.id)
      if (o.companionOrder?.id) seen.add(o.companionOrder.id)
      if (o.subOrders) o.subOrders.forEach((s: any) => seen.add(s.id))
      if (o.combinedId) seen.add(o.combinedId)
    }

    let filtered = dedupped
    if (selectedRouteFilter !== 'ALL') {
      filtered = filtered.filter((o) => detectOrderRoute(o).key === selectedRouteFilter)
    }
    if (selectedVendorFilter !== 'ALL') {
      filtered = filtered.filter((o) => {
        if (o.isCombined || o.companionOrder) return true
        const sName = (o.shopName || o.restaurantName || '').toLowerCase()
        if (selectedVendorFilter === 'GROCERY') {
          return !o.restaurantId && !sName.includes('restaurant') && !sName.includes('cafe')
        }
        if (selectedVendorFilter === 'RESTAURANT') {
          return !!o.restaurantId || sName.includes('restaurant') || sName.includes('cafe')
        }
        return sName.includes(selectedVendorFilter.toLowerCase())
      })
    }
    return filtered
  }, [rawOutForDelivery, selectedRouteFilter, selectedVendorFilter])

  const pendingOrders = useMemo(() => {
    // Only show orders that are assigned to this rider by admin!
    const raw = orders.filter(
      (o) =>
        ['PACKED', 'PREPARING', 'CONFIRMED'].includes(o.status) &&
        (o.deliveryUserId === currentRiderId || isOrderAssignedToMe(o) || (!o.deliveryUserId && !currentRiderStoreId))
    )
    const dedupped: any[] = []
    const seen = new Set<string>()
    for (const o of raw) {
      if (seen.has(o.id)) continue
      dedupped.push(o)
      seen.add(o.id)
      if (o.companionOrder?.id) seen.add(o.companionOrder.id)
      if (o.subOrders) o.subOrders.forEach((s: any) => seen.add(s.id))
      if (o.combinedId) seen.add(o.combinedId)
    }

    let filtered = dedupped
    if (selectedRouteFilter !== 'ALL') {
      filtered = filtered.filter((o) => detectOrderRoute(o).key === selectedRouteFilter)
    }
    if (selectedVendorFilter !== 'ALL') {
      filtered = filtered.filter((o) => {
        // Combined multi-outlet orders stay visible in both GROCERY & RESTAURANT views
        if (o.isCombined || o.companionOrder) return true

        const sName = (o.shopName || o.restaurantName || '').toLowerCase()
        if (selectedVendorFilter === 'GROCERY') {
          return !o.restaurantId && !sName.includes('restaurant') && !sName.includes('cafe')
        }
        if (selectedVendorFilter === 'RESTAURANT') {
          return !!o.restaurantId || sName.includes('restaurant') || sName.includes('cafe')
        }
        return sName.includes(selectedVendorFilter.toLowerCase())
      })
    }
    return filtered
  }, [orders, currentRiderId, currentRiderStoreId, isOrderAssignedToMe, selectedRouteFilter, selectedVendorFilter])

  // Extract unique available vendors/restaurants for the filter
  const availableVendors = useMemo(() => {
    const active = orders.filter((o) =>
      ['SHIPPED', 'PACKED', 'PREPARING', 'CONFIRMED'].includes(o.status) &&
      (o.deliveryUserId === currentRiderId || !o.deliveryUserId)
    )
    const vendors = new Set<string>()
    for (const o of active) {
      const name = (o.shopName || o.restaurantName || '').trim()
      if (name) vendors.add(name)
    }
    return Array.from(vendors)
  }, [orders, currentRiderId])

  // Count active orders across routes for pill badges
  const routeCounts = useMemo(() => {
    const activeOrders = orders.filter((o) =>
      ['SHIPPED', 'PACKED', 'PREPARING', 'CONFIRMED'].includes(o.status)
    )
    const counts: Record<DeliveryRouteKey, number> = {
      ALL: activeOrders.length,
      HAMIRPUR: 0,
      MOOSANAGAR: 0,
      KANPUR: 0,
      JAHANABAD: 0,
      TOWN_CENTER: 0,
    }
    for (const o of activeOrders) {
      const r = detectOrderRoute(o).key
      if (counts[r] !== undefined) counts[r]++
    }
    return counts
  }, [orders])

  const deliveredOrders = useMemo(() => {
    const raw = orders.filter(
      (o) =>
        o.status === 'DELIVERED' &&
        isToday(new Date(o.deliveredAt || o.updatedAt || o.createdAt))
    )
    const dedupped: any[] = []
    const seen = new Set<string>()
    for (const o of raw) {
      if (seen.has(o.id)) continue
      dedupped.push(o)
      seen.add(o.id)
      if (o.companionOrder?.id) seen.add(o.companionOrder.id)
      if (o.subOrders) o.subOrders.forEach((s: any) => seen.add(s.id))
      if (o.combinedId) seen.add(o.combinedId)
    }
    return dedupped
  }, [orders])

  const lastLocationPostRef = useRef<number>(0)

  useEffect(() => {
    if (rawOutForDelivery.length === 0) return

    let watchId: number | null = null

    if (navigator.geolocation) {
      watchId = navigator.geolocation.watchPosition(
        async (position) => {
          const now = Date.now()
          if (now - lastLocationPostRef.current < 15000) return
          lastLocationPostRef.current = now
          try {
            await fetch(`${apiUrl()}/api/delivery/location`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                lat: position.coords.latitude,
                lng: position.coords.longitude,
              }),
            })
          } catch (err) {
            console.error('Error posting live location:', err)
          }
        },
        (err) => console.warn('Geolocation watch error:', err),
        { enableHighAccuracy: true, timeout: 5000 }
      )
    }

    return () => {
      if (watchId !== null && navigator.geolocation) {
        navigator.geolocation.clearWatch(watchId)
      }
    }
  }, [rawOutForDelivery.length])

  const todayDeliveries = deliveredOrders.length
  const todayCodCollected = deliveredOrders
    .filter((o) => o.paymentMethod === 'COD')
    .reduce((sum: number, o: any) => sum + (o.combinedTotal || ((o.total || 0) + (o.companionOrder ? (o.companionOrder.total || 0) : 0))), 0)

  const executeDeliveryCompletion = async (
    orderId: string,
    isRiderCash: boolean,
    paymentCollectedBy: string
  ) => {
    setUpdatingId(orderId)
    try {
      const coords = await getCurrentCoords()
      const isOnline = paymentCollectedBy === 'ONLINE' || !isRiderCash
      const success = await handleUpdateStatus(orderId, 'DELIVERED', {
        deliveryLat: coords?.lat || null,
        deliveryLng: coords?.lng || null,
        isRiderCash,
        paymentCollectedBy,
        paymentMethod: isOnline ? 'UPI' : 'COD',
        paymentStatus: 'PAID',
      })

      if (success) {
        const matchingOrder = orders.find((o) => o.id === orderId)
        const displayId = matchingOrder?.readableId || orderId.slice(0, 8)
        toast.success(`🎉 Order #${displayId} Delivered Successfully!`, {
          description: coords
            ? `Delivered & verified at customer location.`
            : `Delivered successfully.`,
          duration: 4000,
        })
      }
    } catch (err) {
      toast.error('Failed to complete delivery')
    } finally {
      setUpdatingId(null)
      setPaymentChoiceOrderId(null)
    }
  }

  const handleMarkDelivered = (orderId: string) => {
    const order = orders.find((o) => o.id === orderId)
    if (order) {
      setConfirmDeliveryOrder(order)
    }
  }

  const handleSelectCash = (orderId: string) => {
    setPaymentChoiceOrderId(null)
    executeDeliveryCompletion(orderId, true, 'RIDER')
  }

  const handleSelectOnline = (orderId: string) => {
    const matchingOrder = orders.find((o) => o.id === orderId)
    setPaymentChoiceOrderId(null)
    if (matchingOrder) {
      setQrModalOrder(matchingOrder)
    } else {
      executeDeliveryCompletion(orderId, false, 'ONLINE')
    }
  }

  const handleSelectCustomCash = (orderId: string, cashAmount: number) => {
    setPaymentChoiceOrderId(null)
    executeDeliveryCompletionWithCash(orderId, cashAmount)
  }

  const executeDeliveryCompletionWithCash = async (orderId: string, cashAmount: number) => {
    setUpdatingId(orderId)
    try {
      const coords = await getCurrentCoords()
      const success = await handleUpdateStatus(orderId, 'DELIVERED', {
        deliveryLat: coords?.lat || null,
        deliveryLng: coords?.lng || null,
        isRiderCash: cashAmount > 0,
        cashAmount: cashAmount,
        paymentCollectedBy: cashAmount > 0 ? 'RIDER' : 'ONLINE',
      })

      if (success) {
        const matchingOrder = orders.find((o) => o.id === orderId)
        const displayId = matchingOrder?.readableId || orderId.slice(0, 8)
        toast.success(`🎉 Order #${displayId} Delivered Successfully!`, {
          description: `Delivered. Cash Collected: ₹${cashAmount}`,
          duration: 4000,
        })
      }
    } catch (err) {
      toast.error('Failed to complete delivery')
    } finally {
      setUpdatingId(null)
      setPaymentChoiceOrderId(null)
    }
  }

  return (
    <div className="container mx-auto max-w-lg pb-24 bg-background min-h-screen">
      {/* Handover Confirmation Modal */}
      <HandoverConfirmModal
        confirmDeliveryOrder={confirmDeliveryOrder}
        onClose={() => setConfirmDeliveryOrder(null)}
        onConfirm={(target) => {
          setConfirmDeliveryOrder(null)
          if (target.paymentMethod === 'COD') {
            setPaymentChoiceOrderId(target.id)
          } else {
            executeDeliveryCompletion(target.id, false, 'ONLINE')
          }
        }}
      />

      {/* Header */}
      <DeliveryHeader
        userName={session?.user?.name}
        isOffline={isOffline}
        isRefreshing={isRefreshing}
        offlineQueueCount={offlineQueue.length}
        autoRefreshCountdown={autoRefreshCountdown}
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        onRefresh={() => fetchOrders(true)}
      />

      {/* Main Content Area */}
      <div className="p-4 space-y-4">
        {isLoading ? (
          <div className="flex flex-col items-center justify-center py-20 text-text-muted space-y-3">
            <Loader2 className="h-8 w-8 animate-spin text-primary" />
            <p className="text-xs font-medium">Loading delivery orders…</p>
          </div>
        ) : (
          <>
            {activeTab === 'deliveries' && (
              <div className="space-y-4">
                {/* 1. Single-Row Dropdown Filters: Outlet & Route */}
                <div className="grid grid-cols-2 gap-2">
                  {/* Outlet Dropdown */}
                  <div className="relative">
                    <select
                      value={selectedVendorFilter}
                      onChange={(e) => setSelectedVendorFilter(e.target.value)}
                      className="w-full h-10 pl-3 pr-8 bg-card/90 border border-border/80 rounded-xl text-xs font-bold text-text-primary appearance-none cursor-pointer focus:outline-none focus:ring-2 focus:ring-primary/20 shadow-2xs truncate"
                    >
                      <option value="ALL">🍽️ All Outlets ({orders.filter(o => ['SHIPPED', 'PACKED', 'PREPARING', 'CONFIRMED'].includes(o.status)).length})</option>
                      <option value="GROCERY">🛒 Darkstore Only</option>
                      <option value="RESTAURANT">🍽️ Kitchens & Cafes</option>
                      {availableVendors.map((v) => (
                        <option key={v} value={v}>📍 {v}</option>
                      ))}
                    </select>
                    <ChevronDown className="absolute right-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-text-muted pointer-events-none" />
                  </div>

                  {/* Route Dropdown */}
                  <div className="relative">
                    <select
                      value={selectedRouteFilter}
                      onChange={(e) => setSelectedRouteFilter(e.target.value as DeliveryRouteKey)}
                      className="w-full h-10 pl-3 pr-8 bg-card/90 border border-border/80 rounded-xl text-xs font-bold text-text-primary appearance-none cursor-pointer focus:outline-none focus:ring-2 focus:ring-primary/20 shadow-2xs truncate"
                    >
                      <option value="ALL">📍 All Routes ({routeCounts.ALL})</option>
                      {(['HAMIRPUR', 'MOOSANAGAR', 'KANPUR', 'JAHANABAD'] as const).map((rKey) => {
                        const rInfo = DELIVERY_ROUTES[rKey]
                        const count = routeCounts[rKey] || 0
                        return (
                          <option key={rKey} value={rKey}>
                            {rInfo.emoji} {rInfo.shortLabel} {count > 0 ? `(${count})` : ''}
                          </option>
                        )
                      })}
                    </select>
                    <ChevronDown className="absolute right-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-text-muted pointer-events-none" />
                  </div>
                </div>

                {/* 2. Sub-Tab Switcher: On The Way vs Assigned Pickups */}
                <div className="grid grid-cols-2 p-1 bg-secondary/50 border border-border/60 rounded-2xl gap-1">
                  <button
                    type="button"
                    onClick={() => setDeliverySubTab('active')}
                    className={`flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-xl text-xs font-black transition-all cursor-pointer ${
                      deliverySubTab === 'active'
                        ? 'bg-card text-emerald-600 dark:text-emerald-400 shadow-sm border border-border/40'
                        : 'text-text-muted hover:text-text-primary'
                    }`}
                  >
                    <Truck className="h-3.5 w-3.5" />
                    <span>On The Way</span>
                    <span className={`px-2 py-0.5 rounded-full text-[10px] font-black ${
                      deliverySubTab === 'active'
                        ? 'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400'
                        : 'bg-muted text-text-muted'
                    }`}>
                      {outForDeliveryOrders.length}
                    </span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setDeliverySubTab('assigned')}
                    className={`flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-xl text-xs font-black transition-all cursor-pointer ${
                      deliverySubTab === 'assigned'
                        ? 'bg-card text-purple-600 dark:text-purple-400 shadow-sm border border-border/40'
                        : 'text-text-muted hover:text-text-primary'
                    }`}
                  >
                    <ShoppingBag className="h-3.5 w-3.5" />
                    <span>Assigned Pickups</span>
                    <span className={`px-2 py-0.5 rounded-full text-[10px] font-black ${
                      deliverySubTab === 'assigned'
                        ? 'bg-purple-500/15 text-purple-600 dark:text-purple-400'
                        : 'bg-muted text-text-muted'
                    }`}>
                      {pendingOrders.length}
                    </span>
                  </button>
                </div>

                {/* 3A. Active Deliveries View (On The Way) */}
                {deliverySubTab === 'active' && (
                  <div className="space-y-4">
                    {outForDeliveryOrders.length === 0 ? (
                      <div className="text-center py-12 px-6 border-2 border-dashed border-border/70 rounded-3xl bg-card/40 space-y-3">
                        <div className="text-4xl">🛵</div>
                        <div className="space-y-1">
                          <h3 className="text-sm font-black text-text-primary">No orders out for delivery</h3>
                          <p className="text-xs text-text-muted max-w-xs mx-auto">
                            Accept new pickup orders from the Assigned tab to start your trip.
                          </p>
                        </div>
                        {pendingOrders.length > 0 && (
                          <button
                            type="button"
                            onClick={() => setDeliverySubTab('assigned')}
                            className="mt-2 inline-flex items-center gap-1.5 px-4 py-2 bg-purple-500/15 hover:bg-purple-500/25 text-purple-700 dark:text-purple-300 border border-purple-500/30 rounded-xl text-xs font-black cursor-pointer transition-all active:scale-95"
                          >
                            <span>Go to Assigned Pickups ({pendingOrders.length})</span>
                            <span>➔</span>
                          </button>
                        )}
                      </div>
                    ) : (
                      outForDeliveryOrders.map((order, idx) => (
                        <ActiveDeliveryCard
                          key={order.id}
                          order={order}
                          idx={idx}
                          updatingId={updatingId}
                          onMarkDelivered={() => handleMarkDelivered(order.id)}
                          onOpenQr={() => setQrModalOrder(order)}
                        />
                      ))
                    )}
                  </div>
                )}

                {/* 3B. Assigned Pickups View (Option 2 Kitchen Switcher) */}
                {deliverySubTab === 'assigned' && (
                  <div className="space-y-4">
                    {pendingOrders.length === 0 ? (
                      <div className="text-center py-12 px-6 border-2 border-dashed border-border/70 rounded-3xl bg-card/40 space-y-3">
                        <div className="text-4xl">📦</div>
                        <div className="space-y-1">
                          <h3 className="text-sm font-black text-text-primary">No pickup orders waiting</h3>
                          <p className="text-xs text-text-muted max-w-xs mx-auto">
                            You have no pending assigned pickups right now.
                          </p>
                        </div>
                      </div>
                    ) : (
                      pendingOrders.map((order) => (
                        <PendingPickupCard
                          key={order.id}
                          order={order}
                          updatingId={updatingId}
                          onUpdateStatus={handleUpdateStatus}
                        />
                      ))
                    )}
                  </div>
                )}
              </div>
            )}
                      />
                    ))
                  )}
                </div>
              </div>
            )}

            {activeTab === 'wallet' && (
              <RiderWalletView
                walletInfo={walletInfo}
                todayCodCollected={todayCodCollected}
                todayDeliveries={todayDeliveries}
              />
            )}

            {activeTab === 'history' && (
              <DeliveryHistoryView
                todayDeliveries={todayDeliveries}
                deliveredOrders={deliveredOrders}
              />
            )}
          </>
        )}
      </div>

      {/* Payment Option Modal for COD Orders */}
      {paymentChoiceOrderId && (
        <CodPaymentModal
          order={orders.find((o) => o.id === paymentChoiceOrderId)}
          onClose={() => setPaymentChoiceOrderId(null)}
          onSelectCash={handleSelectCash}
          onSelectOnline={handleSelectOnline}
          onSelectCustomCash={handleSelectCustomCash}
          walletInfo={walletInfo}
        />
      )}

      {/* Live Doorstep UPI QR Modal */}
      {qrModalOrder && (
        <UpiQrModal
          order={qrModalOrder}
          onBack={() => setQrModalOrder(null)}
          onConfirmPaid={() => {
            executeDeliveryCompletion(qrModalOrder.id, false, 'ONLINE')
            setQrModalOrder(null)
          }}
        />
      )}
    </div>
  )
}
