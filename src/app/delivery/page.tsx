'use client'

import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { useSession } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { isToday } from 'date-fns'
import { toast } from 'sonner'
import { playNotificationChime, playSuccessChime } from '@/lib/audio'
import { triggerHaptic } from '@/lib/haptic'
import { Loader2, Truck, ShoppingBag } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { supabase } from '@/lib/supabase-client'

// Shared Utilities & Hooks
import { triggerConfetti } from '@/lib/confetti'
import { optimizeRoute } from '@/lib/delivery-routing'
import { useDeliveryOfflineSync } from '@/hooks/delivery/use-delivery-offline-sync'
import { useRiderLocationTracking } from '@/hooks/delivery/use-rider-location-tracking'

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
      const res = await fetch('/api/delivery/wallet')
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
  }, [status, fetchWallet, orders])

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
      const res = await fetch('/api/delivery/orders')
      if (res.ok) {
        const data = await res.json()
        setOrders(data)

        if (typeof window !== 'undefined') {
          const sanitizedCache = data.map((o: any) => ({
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
          setOrders(JSON.parse(cached))
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
        const savedQueue = JSON.parse(localStorage.getItem('offline_delivery_updates') || '[]')
        savedQueue.push({ orderId, newStatus, extraData, timestamp: new Date().getTime() })
        localStorage.setItem('offline_delivery_updates', JSON.stringify(savedQueue))
        setOfflineQueue(savedQueue)

        const updatedOrders = orders.map((o) => {
          if (o.id === orderId) {
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

      const res = await fetch(`/api/orders/${orderId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: newStatus, ...extraData }),
      })

      if (companionId) {
        await fetch(`/api/orders/${companionId}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: newStatus, ...extraData }),
        }).catch(() => null)
      }

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

  const rawOutForDelivery = useMemo(
    () => orders.filter((o) => o.status === 'SHIPPED'),
    [orders]
  )
  const outForDeliveryOrders = useMemo(() => {
    const optimized = optimizeRoute(rawOutForDelivery)
    const dedupped: any[] = []
    const seen = new Set<string>()
    for (const o of optimized) {
      if (seen.has(o.id)) continue
      dedupped.push(o)
      seen.add(o.id)
      if (o.companionOrder) seen.add(o.companionOrder.id)
    }
    return dedupped
  }, [rawOutForDelivery])

  const pendingOrders = useMemo(() => {
    const raw = orders.filter(
      (o) => o.status === 'PACKED' || o.status === 'PREPARING' || o.status === 'CONFIRMED'
    )
    const dedupped: any[] = []
    const seen = new Set<string>()
    for (const o of raw) {
      if (seen.has(o.id)) continue
      dedupped.push(o)
      seen.add(o.id)
      if (o.companionOrder) seen.add(o.companionOrder.id)
    }
    return dedupped
  }, [orders])

  const deliveredOrders = orders.filter(
    (o) =>
      o.status === 'DELIVERED' &&
      isToday(new Date(o.deliveredAt || o.updatedAt || o.createdAt))
  )

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
            await fetch('/api/delivery/location', {
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
    .reduce((sum: number, o: any) => sum + (o.total || 0), 0)

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
              <div className="space-y-6">
                {/* Out for Delivery Section */}
                <div className="space-y-3">
                  <div className="flex items-center justify-between">
                    <h2 className="text-xs font-black uppercase tracking-wider text-text-muted flex items-center gap-1.5">
                      <Truck className="h-3.5 w-3.5 text-primary" />
                      <span>Out For Delivery ({outForDeliveryOrders.length})</span>
                    </h2>
                    {outForDeliveryOrders.length > 1 && (
                      <span className="text-[10px] font-bold text-emerald-600 bg-emerald-50 dark:bg-emerald-950/40 px-2 py-0.5 rounded-md border border-emerald-500/20">
                        ⚡ Route Optimized
                      </span>
                    )}
                  </div>

                  {outForDeliveryOrders.length === 0 ? (
                    <div className="text-center py-8 border-2 border-dashed border-border rounded-2xl p-6 bg-card/30">
                      <p className="text-xs text-text-muted font-medium">
                        No active deliveries assigned to you right now.
                      </p>
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

                {/* Pending Pickups Section */}
                <div className="space-y-3 pt-2">
                  <h2 className="text-xs font-black uppercase tracking-wider text-text-muted flex items-center gap-1.5">
                    <ShoppingBag className="h-3.5 w-3.5 text-amber-500" />
                    <span>Ready for Pickup ({pendingOrders.length})</span>
                  </h2>

                  {pendingOrders.length === 0 ? (
                    <div className="text-center py-6 border border-border/60 rounded-2xl p-4 bg-card/20">
                      <p className="text-xs text-text-muted">No packed orders waiting for pickup.</p>
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
