'use client'

import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { useSession } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { formatPrice } from '@/lib/utils'
import { toast } from 'sonner'
import { playNotificationChime, playSuccessChime } from '@/lib/audio'
import { triggerHaptic } from '@/lib/haptic'
import { 
  Loader2, 
  MapPin, 
  Phone, 
  ShoppingBag, 
  RefreshCw, 
  Navigation, 
  CheckCircle,
  Truck,
  IndianRupee,
  User,
  Camera,
  Package,
  Clock,
  Zap
} from 'lucide-react'
import PhotoCapture from '@/components/delivery/photo-capture'
import { motion, AnimatePresence } from 'framer-motion'

// ─── Animated counter hook ───────────────────────────────────────────────────
function useAnimatedNumber(target: number, duration = 600) {
  const [display, setDisplay] = useState(0)
  useEffect(() => {
    let start = 0
    const startTime = performance.now()
    const step = (now: number) => {
      const elapsed = now - startTime
      const progress = Math.min(elapsed / duration, 1)
      const eased = 1 - Math.pow(1 - progress, 3) // ease-out cubic
      setDisplay(Math.round(eased * target))
      if (progress < 1) requestAnimationFrame(step)
    }
    requestAnimationFrame(step)
  }, [target, duration])
  return display
}

// ─── Real-time clock component ──────────────────────────────────────────────
function LiveClock() {
  const [time, setTime] = useState<string>('')
  useEffect(() => {
    const tick = () =>
      setTime(
        new Date().toLocaleTimeString('en-IN', {
          hour: '2-digit',
          minute: '2-digit',
          second: '2-digit',
          hour12: true,
        })
      )
    tick()
    const id = setInterval(tick, 1000)
    return () => clearInterval(id)
  }, [])
  if (!time) return null
  return (
    <span className="text-[10px] font-mono text-white/80 tracking-wider flex items-center gap-1">
      <Clock className="h-3 w-3" />
      {time}
    </span>
  )
}

// ─── Stagger container / item variants ──────────────────────────────────────
const containerVariants = {
  hidden: {},
  show: { transition: { staggerChildren: 0.08 } },
} as const

const itemVariants = {
  hidden: { opacity: 0, y: 18, scale: 0.97 },
  show: { opacity: 1, y: 0, scale: 1, transition: { type: 'spring' as const, stiffness: 260, damping: 24 } },
  exit: { opacity: 0, y: -12, scale: 0.96, transition: { duration: 0.22 } },
} as const

function optimizeRoute(ordersList: any[]) {
  if (ordersList.length <= 1) return ordersList

  const storeLat = 26.155
  const storeLng = 80.175

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

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN COMPONENT — all business logic unchanged
// ═══════════════════════════════════════════════════════════════════════════════
export default function DeliveryDashboard() {
  const { data: session, status } = useSession()
  const router = useRouter()
  const [orders, setOrders] = useState<any[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isRefreshing, setIsRefreshing] = useState(false)
  const [updatingId, setUpdatingId] = useState<string | null>(null)
  const [capturingOrderId, setCapturingOrderId] = useState<string | null>(null)
  const [capturingPhotoSubmitting, setCapturingPhotoSubmitting] = useState(false)

  // Payment choice states for COD orders
  const [paymentChoiceOrderId, setPaymentChoiceOrderId] = useState<string | null>(null)
  const [upiQrOrderId, setUpiQrOrderId] = useState<string | null>(null)

  // UI-only state
  const [autoRefreshCountdown, setAutoRefreshCountdown] = useState(30)

  // Offline support states
  const [isOffline, setIsOffline] = useState(false)
  const [offlineQueue, setOfflineQueue] = useState<any[]>([])

  useEffect(() => {
    if (status === 'unauthenticated') {
      router.push('/login?callbackUrl=/delivery')
    }
  }, [status, router])

  const fetchOrders = useCallback(async (silent = false) => {
    if (!silent) setIsLoading(true)
    else setIsRefreshing(true)
    
    // Check local storage fallback first if offline
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
        
        // Cache to local storage
        if (typeof window !== 'undefined') {
          localStorage.setItem('delivery_orders_cache', JSON.stringify(data))
        }
      } else {
        toast.error('Failed to fetch delivery orders')
      }
    } catch (err) {
      // Fetch failed - try loading cached copy
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

  // Monitor connection status
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

  // Sync offline updates when back online
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

  // Connect to SSE for real-time order notifications
  useEffect(() => {
    if (status !== 'authenticated') return
    
    let eventSource: EventSource | null = null
    
    const connectSSE = () => {
      eventSource = new EventSource('/api/sse/orders')
      
      eventSource.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data)
          if (data.type === 'new-order' || data.type === 'status-change') {
            // Instant refresh of orders list
            fetchOrders(true)
            
            // Audio sound if order became PACKED (ready for rider pickup)
            if (data.type === 'status-change' && data.status === 'PACKED') {
              playNotificationChime()
              triggerHaptic('success')
            }
          }
        } catch (err) {
          console.error('SSE parse error:', err)
        }
      }
      
      eventSource.onerror = (err) => {
        eventSource?.close()
        setTimeout(connectSSE, 5000)
      }
    }
    
    connectSSE()
    
    return () => {
      if (eventSource) {
        eventSource.close()
      }
    }
  }, [status, fetchOrders])


  // Auto-refresh every 30 seconds
  useEffect(() => {
    if (status !== 'authenticated') return
    const id = setInterval(() => {
      setAutoRefreshCountdown((prev) => {
        if (prev <= 1) {
          fetchOrders(true)
          return 30
        }
        return prev - 1
      })
    }, 1000)
    return () => clearInterval(id)
  }, [status, fetchOrders])

  const prevPendingCountRef = useRef<number | null>(null)

  // Audio alert when new packed/ready orders arrive for pickup
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

    // Handle offline status updates
    if (typeof window !== 'undefined' && !navigator.onLine) {
      try {
        const savedQueue = JSON.parse(localStorage.getItem('offline_delivery_updates') || '[]')
        savedQueue.push({ orderId, newStatus, extraData, timestamp: new Date().getTime() })
        localStorage.setItem('offline_delivery_updates', JSON.stringify(savedQueue))
        setOfflineQueue(savedQueue)

        // Update local state immediately
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
        setOrders(updatedOrders)
        localStorage.setItem('delivery_orders_cache', JSON.stringify(updatedOrders))

        if (newStatus === 'DELIVERED') {
          playSuccessChime()
          triggerHaptic('success')
        } else {
          triggerHaptic('medium')
        }
        toast.success(`Saved locally! Status will sync when online.`)
      } catch (err) {
        toast.error('Failed to save offline status update')
      } finally {
        setUpdatingId(null)
      }
      return
    }

    try {
      const res = await fetch(`/api/orders/${orderId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: newStatus, ...extraData }),
      })

      if (res.ok) {
        if (newStatus === 'DELIVERED') {
          playSuccessChime()
          triggerHaptic('success')
        } else {
          triggerHaptic('medium')
        }
        toast.success(`Order updated successfully!`)
        fetchOrders(true)
      } else {
        toast.error('Failed to update order')
      }
    } catch (err) {
      toast.error('Error updating order state')
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
      navigator.geolocation.getCurrentPosition(
        (position) => {
          resolve({
            lat: position.coords.latitude,
            lng: position.coords.longitude,
          })
        },
        () => {
          resolve(null)
        },
        { enableHighAccuracy: true, timeout: 6000 }
      )
    })
  }

  // Group orders with route optimization for out-for-delivery orders
  const rawOutForDelivery = useMemo(() => orders.filter((o) => o.status === 'SHIPPED'), [orders])
  const outForDeliveryOrders = useMemo(() => optimizeRoute(rawOutForDelivery), [rawOutForDelivery])
  const pendingOrders = orders.filter((o) => o.status === 'PACKED')
  const deliveredOrders = orders.filter((o) => o.status === 'DELIVERED')

  // Stats
  const todayDeliveries = deliveredOrders.length
  const todayCodCollected = deliveredOrders
    .filter((o) => o.paymentMethod === 'COD')
    .reduce((sum: number, o: any) => sum + (o.total || 0), 0)
  const activeDeliveries = outForDeliveryOrders.length

  // Animated stats
  const animDeliveries = useAnimatedNumber(todayDeliveries)
  const animCod = useAnimatedNumber(todayCodCollected)
  const animActive = useAnimatedNumber(activeDeliveries)

  // Photo capture handlers
  const handleMarkDelivered = (orderId: string) => {
    const order = orders.find((o) => o.id === orderId)
    if (order && order.paymentMethod === 'COD') {
      setPaymentChoiceOrderId(orderId)
    } else {
      setCapturingOrderId(orderId)
    }
  }

  const handleSelectCash = (orderId: string) => {
    setPaymentChoiceOrderId(null)
    setCapturingOrderId(orderId)
  }

  const handleSelectUpi = (orderId: string) => {
    setPaymentChoiceOrderId(null)
    setUpiQrOrderId(orderId)
  }

  const handleConfirmUpiPaid = (orderId: string) => {
    setUpiQrOrderId(null)
    setCapturingOrderId(orderId)
  }

  const handlePhotoCaptured = async (photoBase64: string) => {
    if (!capturingOrderId) return
    setCapturingPhotoSubmitting(true)
    try {
      const coords = await getCurrentCoords()
      await handleUpdateStatus(capturingOrderId, 'DELIVERED', {
        deliveryPhoto: photoBase64,
        deliveryLat: coords?.lat || null,
        deliveryLng: coords?.lng || null,
      })
      toast.success('📸 Delivery confirmed with photo proof!', {
        description: coords 
          ? `Photo proof and GPS coordinates saved for order #${capturingOrderId.slice(0, 8)}…`
          : `Photo proof saved for order #${capturingOrderId.slice(0, 8)}… (GPS not available)`,
        duration: 4000,
      })
    } catch (err) {
      toast.error('Failed to save delivery proof')
    } finally {
      setCapturingPhotoSubmitting(false)
      setCapturingOrderId(null)
    }
  }

  const handlePhotoCancelled = () => {
    setCapturingOrderId(null)
  }

  // ─── Loading state ──────────────────────────────────────────────────────────
  if (status === 'loading' || isLoading) {
    return (
      <div className="flex min-h-[70vh] items-center justify-center bg-background">
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="text-center space-y-3"
        >
          <div className="relative mx-auto w-14 h-14">
            <div className="absolute inset-0 rounded-full bg-gradient-to-br from-emerald-400 to-teal-500 opacity-20 animate-ping" />
            <div className="relative h-14 w-14 rounded-full bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center shadow-lg">
              <Loader2 className="h-6 w-6 animate-spin text-white" />
            </div>
          </div>
          <p className="text-xs font-bold text-text-secondary">Loading Delivery Queue…</p>
        </motion.div>
      </div>
    )
  }

  // ─── Main render ────────────────────────────────────────────────────────────
  return (
    <div className="container mx-auto max-w-lg pb-24 bg-background min-h-screen">

      {/* Photo Capture Overlay */}
      {capturingOrderId && (
        <PhotoCapture
          orderId={capturingOrderId}
          onConfirm={handlePhotoCaptured}
          onCancel={handlePhotoCancelled}
          isSubmitting={capturingPhotoSubmitting}
        />
      )}

      {/* COD Payment Choice Modal */}
      <AnimatePresence>
        {paymentChoiceOrderId && (() => {
          const order = orders.find((o) => o.id === paymentChoiceOrderId)
          if (!order) return null
          return (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-[100] bg-black/60 backdrop-blur-sm flex items-center justify-center p-4"
            >
              <motion.div
                initial={{ scale: 0.95, y: 15 }}
                animate={{ scale: 1, y: 0 }}
                exit={{ scale: 0.95, y: 15 }}
                className="bg-card w-full max-w-sm rounded-3xl border border-border p-6 shadow-2xl space-y-5"
              >
                <div className="text-center space-y-2">
                  <div className="mx-auto h-12 w-12 rounded-full bg-amber-500/10 flex items-center justify-center text-amber-500">
                    <IndianRupee className="h-6 w-6" />
                  </div>
                  <h3 className="text-lg font-black text-text-primary">COD Payment Option</h3>
                  <p className="text-xs text-text-muted">
                    Collect payment of <span className="font-extrabold text-text-primary">{formatPrice(order.total)}</span> for Order #{order.id.slice(0, 8)}. How is the customer paying?
                  </p>
                </div>

                <div className="grid grid-cols-1 gap-3">
                  <button
                    onClick={() => handleSelectCash(order.id)}
                    className="flex items-center gap-3 w-full p-4 rounded-2xl border border-border bg-muted/40 hover:bg-muted/80 hover:border-primary/20 transition-all font-bold text-sm text-left cursor-pointer active:scale-98"
                  >
                    <span className="text-2xl">💵</span>
                    <div>
                      <p className="text-text-primary font-black">Cash Payment</p>
                      <p className="text-[10px] text-text-muted">Collect physical cash and check notes</p>
                    </div>
                  </button>

                  <button
                    onClick={() => handleSelectUpi(order.id)}
                    className="flex items-center gap-3 w-full p-4 rounded-2xl border border-emerald-500/20 bg-emerald-500/5 hover:bg-emerald-500/10 hover:border-emerald-500/40 transition-all font-bold text-sm text-left cursor-pointer active:scale-98"
                  >
                    <span className="text-2xl">📱</span>
                    <div>
                      <p className="text-emerald-600 font-black">UPI QR Code Scan</p>
                      <p className="text-[10px] text-emerald-600/80">Show dynamic scanner QR on your phone</p>
                    </div>
                  </button>
                </div>

                <button
                  onClick={() => setPaymentChoiceOrderId(null)}
                  className="w-full text-center text-xs font-bold text-text-muted hover:text-text-primary transition-colors py-2 cursor-pointer"
                >
                  Cancel
                </button>
              </motion.div>
            </motion.div>
          )
        })()}
      </AnimatePresence>

      {/* UPI QR Code Scanner Modal */}
      <AnimatePresence>
        {upiQrOrderId && (() => {
          const order = orders.find((o) => o.id === upiQrOrderId)
          if (!order) return null
          
          const upiUrl = `upi://pay?pa=fastkirana@upi&pn=FastKirana&am=${order.total}&cu=INR&tn=Order_${order.id.slice(0, 8)}`
          const qrSrc = `https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${encodeURIComponent(upiUrl)}`

          return (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 z-[100] bg-black/60 backdrop-blur-sm flex items-center justify-center p-4"
            >
              <motion.div
                initial={{ scale: 0.95, y: 15 }}
                animate={{ scale: 1, y: 0 }}
                exit={{ scale: 0.95, y: 15 }}
                className="bg-card w-full max-w-sm rounded-3xl border border-border p-6 shadow-2xl space-y-5 flex flex-col items-center"
              >
                <div className="text-center space-y-1.5 w-full">
                  <span className="text-xs font-black uppercase text-emerald-600 tracking-wider bg-emerald-50 px-2 py-0.5 rounded border border-emerald-100">
                    UPI SCANNER ACTIVE
                  </span>
                  <h3 className="text-base font-extrabold text-text-primary pt-1">Scan QR to Pay</h3>
                  <p className="text-xs text-text-muted">
                    Pay <span className="font-black text-text-primary">{formatPrice(order.total)}</span> directly to FastKirana store bank
                  </p>
                </div>

                {/* QR Code Wrapper */}
                <div className="relative h-48 w-48 bg-white border border-border rounded-2xl p-2.5 shadow-sm flex items-center justify-center overflow-hidden">
                  <img
                    src={qrSrc}
                    alt="UPI Payment QR Code"
                    className="w-full h-full object-contain"
                  />
                </div>

                <div className="text-center space-y-1">
                  <p className="text-[10px] font-bold text-text-muted">
                    Payee Handle: <span className="font-extrabold text-text-primary">fastkirana@upi</span>
                  </p>
                  <p className="text-[9px] text-text-muted/80">
                    Accepts GPay, PhonePe, Paytm, BHIM and all banking apps
                  </p>
                </div>

                <div className="w-full grid grid-cols-2 gap-3.5 pt-2">
                  <button
                    onClick={() => {
                      setUpiQrOrderId(null)
                      setPaymentChoiceOrderId(order.id) // back to choice
                    }}
                    className="h-11 border border-border rounded-xl text-xs font-bold hover:bg-muted text-text-secondary transition-colors cursor-pointer"
                  >
                    Go Back
                  </button>
                  <button
                    onClick={() => handleConfirmUpiPaid(order.id)}
                    className="h-11 bg-emerald-500 hover:bg-emerald-600 text-white rounded-xl text-xs font-extrabold transition-all shadow-md shadow-emerald-500/10 cursor-pointer active:scale-98"
                  >
                    Payment Received
                  </button>
                </div>
              </motion.div>
            </motion.div>
          )
        })()}
      </AnimatePresence>

      {/* ═══ Gradient Header ═══ */}
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ type: 'spring', stiffness: 200, damping: 22 }}
        className="relative overflow-hidden bg-gradient-to-br from-emerald-500 to-teal-600 px-5 py-5 sm:rounded-b-3xl shadow-xl"
      >
        {/* Glassmorphism decorative circles */}
        <div className="absolute -top-8 -right-8 h-32 w-32 rounded-full bg-white/10 blur-2xl" />
        <div className="absolute -bottom-6 -left-6 h-24 w-24 rounded-full bg-white/5 blur-xl" />

        <div className="relative flex justify-between items-center">
          <div className="flex items-center gap-3">
            {/* Glassmorphism avatar */}
            <div className="h-11 w-11 rounded-2xl bg-white/20 backdrop-blur-md border border-white/30 flex items-center justify-center shadow-inner">
              <motion.div
                animate={{ x: [0, 3, 0] }}
                transition={{ repeat: Infinity, duration: 2, ease: 'easeInOut' }}
              >
                <Truck className="h-5 w-5 text-white drop-shadow" />
              </motion.div>
            </div>
            <div>
              <h1 className="text-sm font-black text-white tracking-tight flex items-center gap-1.5">
                Rider Console
                {isOffline && (
                  <span className="px-1.5 py-0.5 rounded bg-rose-500 text-white text-[8px] font-black uppercase tracking-wider animate-pulse">
                    Offline
                  </span>
                )}
              </h1>
              <p className="text-[10px] text-white/70 mt-0.5">
                {session?.user?.name || 'Delivery Boy'}
              </p>
            </div>
          </div>

          <div className="flex flex-col items-end gap-1.5">
            <LiveClock />
            <button
              onClick={() => { fetchOrders(true); setAutoRefreshCountdown(30) }}
              disabled={isRefreshing}
              className="h-9 w-9 min-h-[44px] min-w-[44px] rounded-xl bg-white/15 backdrop-blur-md border border-white/20 flex items-center justify-center text-white hover:bg-white/25 transition-all disabled:opacity-50 active:scale-95"
            >
              <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
            </button>
          </div>
        </div>

        {offlineQueue.length > 0 && (
          <div className="mt-3 bg-amber-500/25 border border-amber-500/40 rounded-xl p-2.5 text-[9px] font-bold text-amber-100 flex items-center justify-between animate-fade-in">
            <span>⚠️ {offlineQueue.length} unsynced offline updates</span>
            <span className="animate-pulse">Waiting for network...</span>
          </div>
        )}

        {/* Auto-refresh progress bar */}
        <div className="mt-3 h-0.5 rounded-full bg-white/10 overflow-hidden">
          <motion.div
            className="h-full bg-white/40 rounded-full"
            animate={{ width: `${((30 - autoRefreshCountdown) / 30) * 100}%` }}
            transition={{ duration: 0.5, ease: 'linear' }}
          />
        </div>
        <p className="text-[8px] text-white/40 mt-1 text-right font-mono">
          auto-refresh in {autoRefreshCountdown}s
        </p>
      </motion.div>

      <div className="px-4 py-5 space-y-5">

        {/* ═══ Rider Achievements Milestone Widget ═══ */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.05 }}
          className="bg-gradient-to-br from-slate-900 to-slate-950 text-white border border-slate-800 rounded-3xl p-4 shadow-lg relative overflow-hidden"
        >
          {/* Decorative background circle */}
          <div className="absolute -bottom-8 -right-8 h-24 w-24 rounded-full bg-emerald-500/10 blur-xl pointer-events-none" />
          
          <div className="flex justify-between items-center pb-3 border-b border-slate-800/80">
            <div>
              <span className="text-[9px] font-black uppercase tracking-wider text-slate-400">Daily Milestone Goal</span>
              <div className="flex items-baseline gap-1 mt-0.5">
                <span className="text-xl font-black text-emerald-400">{todayDeliveries}</span>
                <span className="text-[10px] text-slate-400 font-bold">completed today</span>
              </div>
            </div>
            <div className="text-right">
              <span className="text-[9px] font-black uppercase tracking-wider text-slate-400">Active status</span>
              <p className="text-xs font-bold text-emerald-400 mt-0.5 flex items-center gap-1">
                <span className="relative flex h-1.5 w-1.5">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                  <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-emerald-500" />
                </span>
                On Duty
              </p>
            </div>
          </div>

          <div className="pt-3 space-y-2">
            <div className="flex justify-between items-center text-xs">
              <span className="font-bold text-slate-300">Milestone Target</span>
              <span className="font-black text-emerald-400">{todayDeliveries}/5 Deliveries</span>
            </div>
            
            <div className="h-2 rounded-full bg-slate-800 overflow-hidden">
              <div
                className="h-full rounded-full bg-gradient-to-r from-emerald-500 to-teal-400 transition-all duration-500"
                style={{ width: `${Math.min((todayDeliveries / 5) * 100, 100)}%` }}
              />
            </div>
            
            <p className="text-[9px] font-bold text-slate-400">
              {todayDeliveries >= 5 ? (
                <span className="text-emerald-400 flex items-center gap-1">🎉 Milestone bonus target achieved today!</span>
              ) : (
                `Complete ${5 - todayDeliveries} more deliveries to reach your daily milestone bonus!`
              )}
            </p>
          </div>
        </motion.div>

        {/* ═══ Stats Cards ═══ */}
        <motion.div
          initial="hidden"
          animate="show"
          variants={containerVariants}
          className="grid grid-cols-3 gap-2.5"
        >
          {/* Deliveries Done */}
          <motion.div variants={itemVariants} className="relative overflow-hidden bg-card border border-border p-3.5 rounded-2xl shadow-sm group">
            <div className="absolute inset-0 bg-gradient-to-br from-emerald-500/5 to-teal-500/10 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
            <div className="relative">
              <div className="h-8 w-8 rounded-xl bg-gradient-to-br from-emerald-400 to-teal-500 flex items-center justify-center mb-2 shadow-md shadow-emerald-500/20">
                <Package className="h-3.5 w-3.5 text-white" />
              </div>
              <span className="text-xl font-black text-text-primary leading-none block">{animDeliveries}</span>
              <span className="text-[9px] font-bold text-text-secondary block mt-1">Delivered</span>
            </div>
          </motion.div>

          {/* COD Collected */}
          <motion.div variants={itemVariants} className="relative overflow-hidden bg-card border border-border p-3.5 rounded-2xl shadow-sm group">
            <div className="absolute inset-0 bg-gradient-to-br from-amber-500/5 to-orange-500/10 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
            <div className="relative">
              <div className="h-8 w-8 rounded-xl bg-gradient-to-br from-amber-400 to-orange-500 flex items-center justify-center mb-2 shadow-md shadow-amber-500/20">
                <IndianRupee className="h-3.5 w-3.5 text-white" />
              </div>
              <span className="text-xl font-black text-text-primary leading-none block">{formatPrice(animCod)}</span>
              <span className="text-[9px] font-bold text-text-secondary block mt-1">COD Cash</span>
            </div>
          </motion.div>

          {/* Active Deliveries */}
          <motion.div variants={itemVariants} className="relative overflow-hidden bg-card border border-border p-3.5 rounded-2xl shadow-sm group">
            <div className="absolute inset-0 bg-gradient-to-br from-blue-500/5 to-indigo-500/10 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
            <div className="relative">
              <div className="h-8 w-8 rounded-xl bg-gradient-to-br from-blue-400 to-indigo-500 flex items-center justify-center mb-2 shadow-md shadow-blue-500/20">
                <Zap className="h-3.5 w-3.5 text-white" />
              </div>
              <span className="text-xl font-black text-text-primary leading-none block">{animActive}</span>
              <span className="text-[9px] font-bold text-text-secondary block mt-1">Active</span>
            </div>
          </motion.div>
        </motion.div>

        {/* ═══ SECTION 1: Active Deliveries ═══ */}
        <div className="space-y-3">
          {/* Section divider */}
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
                <motion.div
                  key={order.id}
                  variants={itemVariants}
                  initial="hidden"
                  animate="show"
                  exit="exit"
                  layout
                  className="relative bg-card border border-border rounded-2xl shadow-md overflow-hidden"
                >
                  {/* Green gradient left accent */}
                  <div className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-emerald-400 via-teal-500 to-emerald-600 rounded-l-2xl" />

                  <div className="pl-4 pr-4 pt-4 pb-4 space-y-3.5">
                    {/* Top row: ID & Payment + pulsing indicator */}
                    <div className="flex justify-between items-start border-b border-border/40 pb-3">
                      <div className="flex items-center gap-2">
                        {/* Pulsing live dot */}
                        <span className="relative flex h-2.5 w-2.5 shrink-0">
                          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                          <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500" />
                        </span>
                        <div>
                          <div className="flex items-center gap-1.5">
                            <span className="text-[10px] font-bold text-text-muted">Active Order</span>
                            <span className="px-1.5 py-0.5 rounded-md bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 text-[8px] font-black uppercase tracking-wider border border-emerald-500/20">
                              Stop #{idx + 1}
                            </span>
                          </div>
                          <span className="text-xs font-mono font-bold text-text-primary">{order.id}</span>
                        </div>
                      </div>
                      <div className={`px-2.5 py-1 rounded-lg text-[10px] font-bold ${
                        order.paymentMethod === 'COD' 
                          ? 'bg-gradient-to-r from-amber-50 to-orange-50 dark:from-amber-500/10 dark:to-orange-500/10 text-amber-700 dark:text-amber-400 border border-amber-200/60 dark:border-amber-500/20 animate-pulse-gentle' 
                          : 'bg-accent/10 text-accent border border-accent/20'
                      }`}>
                        {order.paymentMethod === 'COD' ? '💰 Collect Cash (COD)' : '✅ Paid Online'}
                      </div>
                    </div>

                    {/* Customer contact card */}
                    <div className="flex items-center justify-between bg-gradient-to-r from-muted/30 to-muted/10 p-3 rounded-xl border border-border/40">
                      <div className="flex items-center gap-2.5">
                        <div className="h-9 w-9 rounded-full bg-gradient-to-br from-emerald-400 to-teal-500 flex items-center justify-center text-white text-[10px] font-bold shadow-md shadow-emerald-500/15">
                          <User className="h-4 w-4" />
                        </div>
                        <div>
                          <div className="text-xs font-bold text-text-primary">{order.user.name || 'Customer'}</div>
                          <div className="text-[10px] text-text-secondary">{order.user.phone || 'No phone'}</div>
                        </div>
                      </div>
                      {order.user.phone && (
                        <a
                          href={`tel:${order.user.phone}`}
                          className="h-11 w-11 min-h-[44px] min-w-[44px] rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 text-white flex items-center justify-center hover:from-emerald-600 hover:to-teal-700 transition-all shadow-md shadow-emerald-500/20 active:scale-95"
                        >
                          <Phone className="h-4.5 w-4.5" />
                        </a>
                      )}
                    </div>

                    {/* Pickup & Delivery with step indicators */}
                    <div className="bg-gradient-to-b from-muted/15 to-muted/5 p-3.5 rounded-xl border border-border/40 space-y-0">
                      {/* Step 1 — Pickup */}
                      <div className="flex gap-3">
                        <div className="flex flex-col items-center shrink-0">
                          <div className="h-7 w-7 rounded-full bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center text-white text-[10px] font-black shadow-sm">
                            1
                          </div>
                          {/* Connecting line */}
                          <div className="w-0.5 flex-1 bg-gradient-to-b from-teal-400 to-emerald-300 my-1 rounded-full min-h-[20px]" />
                        </div>
                        <div className="pb-3">
                          <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider">Pickup</span>
                          <span className="text-[11px] leading-relaxed text-text-primary font-bold block mt-0.5">
                            {order.shopName === 'FastKirana Cafe Kitchen'
                              ? '☕ FastKirana Cafe Kitchen (Food counter)'
                              : '🏪 FastKirana Central Hub (Grocery Darkstore)'}
                          </span>
                        </div>
                      </div>

                      {/* Step 2 — Deliver */}
                      <a
                        href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
                          `${order.address.houseNo}, ${order.address.street}, ${order.address.area}, ${order.address.city} ${order.address.pincode}`
                        )}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="flex gap-3 group/map hover:bg-emerald-50/50 dark:hover:bg-emerald-500/5 -mx-1 px-1 py-1 rounded-lg transition-colors cursor-pointer"
                        title="Click to navigate with Google Maps"
                      >
                        <div className="flex flex-col items-center shrink-0">
                          <div className="h-7 w-7 rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white text-[10px] font-black shadow-sm">
                            2
                          </div>
                        </div>
                        <div>
                          <span className="text-[10px] font-bold text-text-muted uppercase tracking-wider flex items-center gap-1.5">
                            Deliver To
                            <span className="text-[8px] font-black text-emerald-600 bg-emerald-50 dark:bg-emerald-500/10 dark:text-emerald-400 px-1.5 py-0.5 rounded-md tracking-wider group-hover/map:bg-emerald-100 transition-colors">
                              NAVIGATE 🗺️
                            </span>
                          </span>
                          <span className="text-[11px] leading-relaxed text-text-primary font-bold block mt-0.5 group-hover/map:underline">
                            {order.address.houseNo}, {order.address.street}, {order.address.area}, {order.address.city} - {order.address.pincode}
                          </span>
                        </div>
                      </a>
                    </div>

                    {/* Items bag summary */}
                    <div className="border-t border-border/40 pt-3 space-y-1.5">
                      <div className="flex items-center gap-1.5">
                        <ShoppingBag className="h-3 w-3 text-text-muted" />
                        <span className="text-[10px] font-bold text-text-secondary">Items in bag ({order.items.length})</span>
                      </div>
                      <div className="bg-muted/10 p-2.5 rounded-xl border border-border/30 space-y-1 max-h-[110px] overflow-y-auto">
                        {order.items.map((item: any) => (
                          <div key={item.id} className="flex justify-between items-center text-[11px]">
                            <span className="text-text-primary font-bold">{item.name}</span>
                            <span className="text-text-secondary font-semibold bg-muted/20 px-1.5 py-0.5 rounded text-[10px]">×{item.quantity}</span>
                          </div>
                        ))}
                      </div>
                    </div>

                    {/* COD total + action */}
                    <div className="flex justify-between items-center border-t border-border/40 pt-3">
                      <div>
                        <span className="text-[10px] font-bold text-text-secondary block">Total to Collect</span>
                        <span className="text-lg font-black text-text-primary">{formatPrice(order.total)}</span>
                      </div>
                      
                      <button
                        onClick={() => handleMarkDelivered(order.id)}
                        disabled={updatingId === order.id}
                        className="flex items-center gap-1.5 px-5 py-3 min-h-[44px] bg-gradient-to-r from-emerald-500 to-teal-600 text-white text-xs font-black rounded-xl hover:from-emerald-600 hover:to-teal-700 transition-all shadow-md shadow-emerald-500/20 active:scale-95 disabled:opacity-60"
                      >
                        {updatingId === order.id ? (
                          <Loader2 className="h-4 w-4 animate-spin" />
                        ) : (
                          <>
                            <Camera className="h-4 w-4" />
                            Mark Delivered
                          </>
                        )}
                      </button>
                    </div>
                  </div>
                </motion.div>
              ))
            )}
          </AnimatePresence>
        </div>

        {/* ═══ Section divider ═══ */}
        <div className="h-px bg-gradient-to-r from-transparent via-border to-transparent" />

        {/* ═══ SECTION 2: Pending Pickups ═══ */}
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
              pendingOrders.map((order, idx) => {
                const isCafe = order.shopName === 'FastKirana Cafe Kitchen'
                return (
                  <motion.div
                    key={order.id}
                    variants={itemVariants}
                    initial="hidden"
                    animate="show"
                    exit="exit"
                    layout
                    className={`relative bg-card border rounded-2xl shadow-sm overflow-hidden transition-all ${
                      isCafe
                        ? 'border-rose-200/80 dark:border-rose-500/20'
                        : 'border-blue-200/60 dark:border-blue-500/15'
                    }`}
                  >
                    {/* Subtle left accent */}
                    <div className={`absolute left-0 top-0 bottom-0 w-0.5 rounded-l-2xl ${
                      isCafe
                        ? 'bg-gradient-to-b from-rose-400 to-pink-500'
                        : 'bg-gradient-to-b from-blue-400 to-indigo-500'
                    }`} />

                    <div className="pl-4 pr-4 pt-4 pb-4 space-y-3">
                      {/* ID & Status */}
                      <div className="flex justify-between items-center border-b border-border/40 pb-2.5">
                        <div>
                          <span className="text-[9px] font-bold text-text-muted flex items-center gap-1.5">
                            Order ID
                            {isCafe && (
                              <span className="bg-rose-100 dark:bg-rose-500/10 text-rose-700 dark:text-rose-400 text-[8px] px-1.5 py-0.5 rounded-md font-black uppercase tracking-wider">
                                ☕ cafe
                              </span>
                            )}
                          </span>
                          <span className="text-xs font-mono font-bold text-text-primary">{order.id}</span>
                        </div>
                        <span className={`px-2.5 py-1 rounded-lg text-[9px] font-bold uppercase ${
                          order.status === 'PACKED'
                            ? 'bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-500/10 dark:to-teal-500/10 text-emerald-700 dark:text-emerald-400 border border-emerald-200/60 dark:border-emerald-500/20'
                            : 'bg-amber-500/10 text-amber-600 border border-amber-500/20'
                        }`}>
                          {order.status === 'PACKED' ? '✅ Packed (Ready)' : '⏳ Preparing'}
                        </span>
                      </div>

                      {/* Pickup & Deliver info */}
                      <div className="space-y-2 text-[11px] text-text-secondary font-semibold bg-gradient-to-b from-muted/10 to-transparent p-3 rounded-xl border border-border/30">
                        <div className="flex items-start gap-2">
                          <div className={`h-5 w-5 rounded-md flex items-center justify-center shrink-0 mt-0.5 text-[9px] font-black text-white ${
                            isCafe ? 'bg-gradient-to-br from-rose-400 to-pink-500' : 'bg-gradient-to-br from-blue-400 to-indigo-500'
                          }`}>
                            P
                          </div>
                          <div>
                            <span className="text-[9px] font-bold text-text-muted uppercase tracking-wider block">Pickup</span>
                            <span className="text-text-primary font-bold">
                              {isCafe ? '☕ FastKirana Cafe Kitchen' : '🏪 FastKirana Central Hub'}
                            </span>
                          </div>
                        </div>
                        <div className="h-px bg-border/30 ml-7" />
                        <div className="flex items-start gap-2">
                          <div className="h-5 w-5 rounded-md bg-gradient-to-br from-emerald-400 to-teal-500 flex items-center justify-center shrink-0 mt-0.5">
                            <MapPin className="h-3 w-3 text-white" />
                          </div>
                          <div>
                            <span className="text-[9px] font-bold text-text-muted uppercase tracking-wider block">Deliver To</span>
                            <span className="text-text-primary font-bold">{order.address.area}, {order.address.city}</span>
                          </div>
                        </div>
                      </div>

                      {/* Amount + Action */}
                      <div className="flex justify-between items-center pt-1.5 border-t border-border/40">
                        <div>
                          <span className="text-[9px] font-bold text-text-secondary block">Amount</span>
                          <span className="text-sm font-black text-text-primary">{formatPrice(order.total)}</span>
                          <span className="text-[8px] text-text-muted font-bold block">
                            ({order.paymentMethod === 'COD' ? '💰 Collect Cash' : '✅ Paid Online'})
                          </span>
                        </div>

                        <button
                          onClick={() => handleUpdateStatus(order.id, 'SHIPPED')}
                          disabled={updatingId === order.id}
                          className={`flex items-center gap-1.5 px-4 py-3 min-h-[44px] text-white text-xs font-bold rounded-xl transition-all shadow-md active:scale-95 disabled:opacity-60 ${
                            isCafe
                              ? 'bg-gradient-to-r from-rose-500 to-pink-600 hover:from-rose-600 hover:to-pink-700 shadow-rose-500/15'
                              : 'bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700 shadow-blue-500/15'
                          }`}
                        >
                          {updatingId === order.id ? (
                            <Loader2 className="h-3.5 w-3.5 animate-spin" />
                          ) : (
                            <>
                              <Navigation className="h-3.5 w-3.5" />
                              Pick Up Order
                            </>
                          )}
                        </button>
                      </div>
                    </div>
                  </motion.div>
                )
              })
            )}
          </AnimatePresence>
        </div>
      </div>
    </div>
  )
}
