'use client'

import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { useSession } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import { playNotificationChime, playSuccessChime } from '@/lib/audio'
import { triggerHaptic } from '@/lib/haptic'
import { Loader2, Truck, ShoppingBag } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { supabase } from '@/lib/supabase-client'

import DeliveryHeader from './components/delivery-header'
import CodPaymentModal from './components/cod-payment-modal'
import UpiQrModal from './components/upi-qr-modal'
import ActiveDeliveryCard from './components/active-delivery-card'
import PendingPickupCard from './components/pending-pickup-card'
import RiderWalletView from './components/rider-wallet-view'
import DeliveryHistoryView from './components/delivery-history-view'

function triggerConfetti() {
  if (typeof window === 'undefined') return
  const canvas = document.createElement('canvas')
  canvas.style.position = 'fixed'
  canvas.style.top = '0'
  canvas.style.left = '0'
  canvas.style.width = '100%'
  canvas.style.height = '100%'
  canvas.style.pointerEvents = 'none'
  canvas.style.zIndex = '9999'
  document.body.appendChild(canvas)

  const ctx = canvas.getContext('2d')
  if (!ctx) return

  const resizeCanvas = () => {
    canvas.width = window.innerWidth
    canvas.height = window.innerHeight
  }
  window.addEventListener('resize', resizeCanvas)
  resizeCanvas()

  const colors = ['#f43f5e', '#10b981', '#3b82f6', '#f59e0b', '#8b5cf6', '#ec4899', '#14b8a6']
  const particles: any[] = []

  for (let i = 0; i < 120; i++) {
    particles.push({
      x: Math.random() * canvas.width,
      y: Math.random() * -canvas.height - 20,
      size: Math.random() * 6 + 4,
      color: colors[Math.floor(Math.random() * colors.length)],
      speed: Math.random() * 4 + 3,
      angle: Math.random() * 360,
      rotationSpeed: Math.random() * 4 - 2
    })
  }

  let animationFrameId: number
  const startTime = Date.now()

  function update() {
    if (!ctx) return
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    
    if (Date.now() - startTime > 3000) {
      if (document.body.contains(canvas)) {
        document.body.removeChild(canvas)
      }
      window.removeEventListener('resize', resizeCanvas)
      cancelAnimationFrame(animationFrameId)
      return
    }

    let active = false
    particles.forEach(p => {
      p.y += p.speed
      p.angle += p.rotationSpeed
      p.x += Math.sin(p.angle * Math.PI / 180) * 0.8

      if (p.y < canvas.height + 20) {
        active = true
      }

      ctx.save()
      ctx.translate(p.x, p.y)
      ctx.rotate(p.angle * Math.PI / 180)
      ctx.fillStyle = p.color
      ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size)
      ctx.restore()
    })

    if (active) {
      animationFrameId = requestAnimationFrame(update)
    } else {
      if (document.body.contains(canvas)) {
        document.body.removeChild(canvas)
      }
      window.removeEventListener('resize', resizeCanvas)
    }
  }

  update()
}

function optimizeRoute(ordersList: any[]) {
  if (ordersList.length <= 1) return ordersList

  const storeLat = 26.1534185
  const storeLng = 80.1714024

  const getDistance = (lat1: number, lon1: number, lat2: number, lon2: number) => {
    const R = 6371
    const dLat = (lat2 - lat1) * Math.PI / 180
    const dLon = (lon2 - lon1) * Math.PI / 180
    const a = 
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
      Math.sin(dLon/2) * Math.sin(dLon/2)
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
    return R * c
  }

  const unvisited = [...ordersList]
  const optimized: any[] = []
  let currentLat = storeLat
  let currentLng = storeLng

  while (unvisited.length > 0) {
    let bestIndex = 0
    let minDistance = Infinity

    for (let i = 0; i < unvisited.length; i++) {
      const addr = unvisited[i].address
      const addrLat = addr?.lat ?? storeLat
      const addrLng = addr?.lng ?? storeLng
      const dist = getDistance(currentLat, currentLng, addrLat, addrLng)
      
      let score = dist
      if (unvisited[i].paymentMethod === 'COD') score -= 0.5
      const elapsedMins = (new Date().getTime() - new Date(unvisited[i].createdAt).getTime()) / (60 * 1000)
      score -= elapsedMins * 0.05

      if (score < minDistance) {
        minDistance = score
        bestIndex = i
      }
    }

    const nextOrder = unvisited.splice(bestIndex, 1)[0]
    optimized.push(nextOrder)
    currentLat = nextOrder.address?.lat ?? currentLat
    currentLng = nextOrder.address?.lng ?? currentLng
  }

  return optimized
}

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

  const [autoRefreshCountdown, setAutoRefreshCountdown] = useState(30)
  const [isOffline, setIsOffline] = useState(false)
  const [offlineQueue, setOfflineQueue] = useState<any[]>([])

  const ordersRef = useRef<any[]>([])

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

  useEffect(() => {
    if (typeof window === 'undefined') return
    setIsOffline(!navigator.onLine)
    
    const goOnline = () => {
      setIsOffline(false)
      toast.success('You are back online! Syncing local delivery updates...')
    }
    const goOffline = () => {
      setIsOffline(true)
      toast.warning('You are offline. Deliveries will be saved locally.')
    }
    
    window.addEventListener('online', goOnline)
    window.addEventListener('offline', goOffline)
    return () => {
      window.removeEventListener('online', goOnline)
      window.removeEventListener('offline', goOffline)
    }
  }, [])

  useEffect(() => {
    if (isOffline) return

    const syncOfflineUpdates = async () => {
      const savedQueue = JSON.parse(localStorage.getItem('offline_delivery_updates') || '[]')
      if (savedQueue.length === 0) return

      toast.loading(`Syncing ${savedQueue.length} offline updates to server...`, { id: 'offline-sync' })
      let successCount = 0

      for (const item of savedQueue) {
        try {
          const res = await fetch(`/api/orders/${item.orderId}`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status: item.newStatus, ...item.extraData }),
          })
          if (res.ok) {
            successCount++
          }
        } catch (err) {
          console.error('Failed to sync offline order update:', item.orderId, err)
        }
      }

      localStorage.setItem('offline_delivery_updates', '[]')
      setOfflineQueue([])
      
      toast.dismiss('offline-sync')
      if (successCount === savedQueue.length) {
        toast.success('Successfully synced all offline delivery status updates!')
      } else if (successCount > 0) {
        toast.warning(`Synced ${successCount} of ${savedQueue.length} updates. Some failed.`)
      }
      fetchOrders(true)
    }

    syncOfflineUpdates()
  }, [isOffline, fetchOrders])

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
            const oldOrder = payload.old as any
            const newOrder = payload.new as any
            const orderId = newOrder.id
            const newStatus = newOrder.status
            
            const activeShipped = ordersRef.current.filter(o => o.status === 'SHIPPED')
            const wasActive = activeShipped.find(o => o.id === orderId)
            if (wasActive && newStatus === 'CANCELLED') {
              playNotificationChime()
              triggerHaptic('warning')
              const orderNum = wasActive.readableId || orderId.slice(0, 8)
              toast.error(`⚠️ Active delivery #${orderNum} to ${wasActive.user?.name || 'customer'} was CANCELLED by the customer! Please do not deliver.`, {
                duration: 10000,
                icon: '🛑'
              })
            }

            const activePacked = ordersRef.current.filter(o => o.status === 'PACKED')
            const wasPending = activePacked.find(o => o.id === orderId)
            if (wasPending && newStatus === 'CANCELLED') {
              const orderNum = wasPending.readableId || orderId.slice(0, 8)
              toast.info(`📦 Order #${orderNum} in pickup queue has been CANCELLED.`, {
                icon: 'ℹ️'
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
    if (prevPendingCountRef.current !== null && currentPending.length > prevPendingCountRef.current) {
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
      const targetOrder = orders.find(o => o.id === orderId)
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

  const getCurrentCoords = (): Promise<{ lat: number; lng: number } | null> => {
    return new Promise((resolve) => {
      if (!navigator.geolocation) {
        resolve(null)
        return
      }

      const safetyTimeout = setTimeout(() => {
        console.warn('[Geolocation] Safety timeout fired, resolving coordinates to null')
        resolve(null)
      }, 3500)

      navigator.geolocation.getCurrentPosition(
        (position) => {
          clearTimeout(safetyTimeout)
          resolve({
            lat: position.coords.latitude,
            lng: position.coords.longitude,
          })
        },
        () => {
          clearTimeout(safetyTimeout)
          resolve(null)
        },
        { enableHighAccuracy: true, timeout: 3000 }
      )
    })
  }

  const rawOutForDelivery = useMemo(() => orders.filter((o) => o.status === 'SHIPPED'), [orders])
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
    const raw = orders.filter((o) => o.status === 'PACKED' || o.status === 'PREPARING' || o.status === 'CONFIRMED')
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

  const isToday = (dateStr: string | null | undefined) => {
    if (!dateStr) return false
    const d = new Date(dateStr)
    const today = new Date()
    return (
      d.getDate() === today.getDate() &&
      d.getMonth() === today.getMonth() &&
      d.getFullYear() === today.getFullYear()
    )
  }

  const deliveredOrders = orders.filter(
    (o) => o.status === 'DELIVERED' && isToday(o.deliveredAt || o.updatedAt || o.createdAt)
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
      const success = await handleUpdateStatus(orderId, 'DELIVERED', {
        deliveryLat: coords?.lat || null,
        deliveryLng: coords?.lng || null,
        isRiderCash,
        paymentCollectedBy,
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
    setPaymentChoiceOrderId(null)
    executeDeliveryCompletion(orderId, false, 'ONLINE')
  }

  const handleSelectCustomCash = (orderId: string, cashAmount: number) => {
    setPaymentChoiceOrderId(null)
    executeDeliveryCompletionWithCash(orderId, cashAmount)
  }

  const executeDeliveryCompletionWithCash = async (
    orderId: string,
    cashAmount: number
  ) => {
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
      {/* Rider Delivery Confirmation Dialog (Prevents accidental clicks) */}
      {confirmDeliveryOrder && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4">
          <motion.div 
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            className="bg-card border border-border w-full max-w-sm rounded-3xl p-5 space-y-4 text-center shadow-2xl"
          >
            <div className="w-12 h-12 rounded-2xl bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 mx-auto flex items-center justify-center text-2xl">
              📦
            </div>
            <div>
              <h3 className="text-base font-black text-text-primary">Confirm Parcel Handover</h3>
              <p className="text-xs text-text-muted mt-1">
                Order #{confirmDeliveryOrder.readableId || confirmDeliveryOrder.id.slice(0, 8)} • ₹{confirmDeliveryOrder.total}
              </p>
              <p className="text-xs font-medium text-text-secondary mt-2 bg-secondary/50 p-2.5 rounded-xl border border-border/50">
                Kya aapne customer ko parcel safely handover kar diya hai?
              </p>
            </div>
            <div className="grid grid-cols-2 gap-2.5 pt-1">
              <button
                type="button"
                onClick={() => setConfirmDeliveryOrder(null)}
                className="w-full py-3 px-3 rounded-2xl border border-border text-xs font-bold text-text-secondary hover:bg-secondary transition-colors"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => {
                  const target = confirmDeliveryOrder
                  setConfirmDeliveryOrder(null)
                  if (target.paymentMethod === 'COD') {
                    setPaymentChoiceOrderId(target.id)
                  } else {
                    executeDeliveryCompletion(target.id, false, 'ONLINE')
                  }
                }}
                className="w-full py-3 px-3 rounded-2xl bg-emerald-600 text-white text-xs font-black shadow-lg shadow-emerald-600/30 hover:bg-emerald-700 transition-colors"
              >
                Yes, Delivered ✅
              </button>
            </div>
          </motion.div>
        </div>
      )}

      {/* COD Payment Choice Modal (Cash vs Online vs Split) */}
      {paymentChoiceOrderId && (
        <CodPaymentModal
          order={orders.find((o) => o.id === paymentChoiceOrderId)}
          onClose={() => setPaymentChoiceOrderId(null)}
          onSelectCash={handleSelectCash}
          onSelectOnline={handleSelectOnline}
          onSelectCustomCash={handleSelectCustomCash}
        />
      )}

      {/* Doorstep Razorpay Dynamic UPI QR Modal */}
      {qrModalOrder && (
        <UpiQrModal
          order={qrModalOrder}
          onBack={() => setQrModalOrder(null)}
          onConfirmPaid={(orderId) => {
            setQrModalOrder(null)
            executeDeliveryCompletion(orderId, false, 'ONLINE')
          }}
        />
      )}

      {/* Header */}
      <DeliveryHeader
        userName={session?.user?.name}
        isOffline={isOffline}
        isRefreshing={isRefreshing}
        offlineQueueCount={offlineQueue.length}
        autoRefreshCountdown={autoRefreshCountdown}
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        onRefresh={() => {
          fetchOrders(true)
          setAutoRefreshCountdown(30)
        }}
      />

      <div className="px-4 py-5 space-y-5">
        {activeTab === 'deliveries' && (
          <>
            {/* Out for Delivery Section */}
            <div className="space-y-3">
              <div className="flex items-center gap-2.5">
                <div className="flex items-center gap-1.5 shrink-0">
                  <div className="h-6 w-6 rounded-lg bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center shadow-sm shadow-emerald-500/20">
                    <Truck className="h-3 w-3 text-white" />
                  </div>
                  <h2 className="text-xs font-black text-text-primary uppercase tracking-wider">
                    Out for Delivery
                  </h2>
                </div>
                {outForDeliveryOrders.length > 0 && (
                  <span className="text-[10px] font-black text-emerald-600 bg-emerald-50 dark:bg-emerald-500/10 px-2 py-0.5 rounded-full">
                    {outForDeliveryOrders.length}
                  </span>
                )}
                <div className="flex-1 h-px bg-gradient-to-r from-border to-transparent" />
              </div>

              <AnimatePresence mode="popLayout">
                {outForDeliveryOrders.length === 0 ? (
                  <motion.div
                    key="empty-active"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="bg-card/50 border border-dashed border-border/80 p-6 rounded-2xl text-center text-xs text-text-muted"
                  >
                    No orders currently out for delivery. Accept new orders below.
                  </motion.div>
                ) : (
                  outForDeliveryOrders.map((order, idx) => (
                    <ActiveDeliveryCard
                      key={order.id}
                      order={order}
                      idx={idx}
                      updatingId={updatingId}
                      onMarkDelivered={handleMarkDelivered}
                    />
                  ))
                )}
              </AnimatePresence>
            </div>

            <div className="h-px bg-gradient-to-r from-transparent via-border to-transparent" />

            {/* Pending Pickups Section */}
            <div className="space-y-3">
              <div className="flex items-center gap-2.5">
                <div className="flex items-center gap-1.5 shrink-0">
                  <div className="h-6 w-6 rounded-lg bg-gradient-to-br from-violet-500 to-purple-600 flex items-center justify-center shadow-sm shadow-violet-500/20">
                    <ShoppingBag className="h-3 w-3 text-white" />
                  </div>
                  <h2 className="text-xs font-black text-text-primary uppercase tracking-wider">
                    Pending Pickups
                  </h2>
                </div>
                {pendingOrders.length > 0 && (
                  <span className="text-[10px] font-black text-violet-600 bg-violet-50 dark:bg-violet-500/10 dark:text-violet-400 px-2 py-0.5 rounded-full">
                    {pendingOrders.length}
                  </span>
                )}
                <div className="flex-1 h-px bg-gradient-to-r from-border to-transparent" />
              </div>

              <AnimatePresence mode="popLayout">
                {pendingOrders.length === 0 ? (
                  <motion.div
                    key="empty-pending"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="bg-card/50 border border-dashed border-border/80 p-8 rounded-2xl text-center text-xs text-text-muted"
                  >
                    All caught up! No orders pending pickup in the local store.
                  </motion.div>
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
              </AnimatePresence>
            </div>
          </>
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
      </div>
    </div>
  )
}
