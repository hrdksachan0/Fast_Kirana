'use client'

import { useState, useEffect, useRef, useCallback, useMemo } from 'react'

import { useSession } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { formatPrice } from '@/lib/utils'
import { toast } from 'sonner'
import { 
  Loader2, 
  ShoppingBag, 
  RefreshCw, 
  CheckCircle,
  Coffee,
  User,
  Barcode,
  Check,
  Search,
  ChevronRight,
  Flame,
  ChefHat,
  Clock,
  UtensilsCrossed,
  ClipboardList,
  PackageCheck,
  Timer,
  RotateCcw
} from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { ProductImage } from '@/components/product/product-image'
import { playNotificationChime, playSuccessChime } from '@/lib/audio'
import { triggerHaptic } from '@/lib/haptic'

interface OrderItem {
  id: string
  productId: string
  name: string
  price: number
  quantity: number
  imageUrl?: string
  product?: {
    slug: string
  }
}

interface CompanionOrder {
  id: string
  status: string
  shopName: string | null
  items: {
    id: string
    name: string
    quantity: number
  }[]
}

interface Order {
  id: string
  status: string
  total: number
  createdAt: string | Date
  paymentMethod: string
  deliveryMethod: string
  user: {
    name: string
    phone: string | null
  }
  address: {
    houseNo: string
    street: string
    area: string
    city: string
    pincode: string
  }
  items: OrderItem[]
  companionOrder?: CompanionOrder | null
  assignedPickerId?: string | null
  assignedChefId?: string | null
  assignedPicker?: { name: string } | null
  assignedChef?: { name: string } | null
}

// --- UI-only helpers ---
const foodEmojis = ['🍕', '🍔', '🌮', '🥪', '🍜', '🍛', '🧁', '☕', '🍩', '🥐', '🍳', '🥗']
function getItemEmoji(index: number) {
  return foodEmojis[index % foodEmojis.length]
}

function formatElapsed(createdAt: string | Date): string {
  const created = new Date(createdAt)
  const now = new Date()
  const diffMs = now.getTime() - created.getTime()
  const mins = Math.floor(diffMs / 60000)
  if (mins < 1) return 'Just now'
  if (mins < 60) return `${mins}m ago`
  const hrs = Math.floor(mins / 60)
  return `${hrs}h ${mins % 60}m ago`
}

function getSlaClass(createdAt: string | Date, status: string): string {
  if (status !== 'PENDING') return 'text-gray-400 font-semibold'
  const created = new Date(createdAt)
  const now = new Date()
  const diffMs = now.getTime() - created.getTime()
  const mins = Math.floor(diffMs / 60000)
  if (mins >= 10) return 'text-rose-500 font-black animate-pulse'
  if (mins >= 5) return 'text-amber-500 font-black animate-pulse'
  return 'text-gray-400 font-semibold'
}

// Stagger animation variants
const containerVariants = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.08 }
  }
} as const

const itemVariants = {
  hidden: { opacity: 0, y: 20, scale: 0.97 },
  show: { 
    opacity: 1, y: 0, scale: 1,
    transition: { type: 'spring' as const, damping: 20, stiffness: 200 }
  }
} as const

const statCardVariants = {
  hidden: { opacity: 0, y: 15, scale: 0.95 },
  show: { 
    opacity: 1, y: 0, scale: 1,
    transition: { type: 'spring' as const, damping: 18, stiffness: 220 }
  }
} as const

export default function CafeKitchenDashboard() {
  const { data: session, status } = useSession()
  const router = useRouter()
  
  const [orders, setOrders] = useState<Order[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isRefreshing, setIsRefreshing] = useState(false)
  const [updatingId, setUpdatingId] = useState<string | null>(null)
  
  // Active Preparing Order State
  const [activeOrder, setActiveOrder] = useState<Order | null>(null)
  const [pickedItemIds, setPickedItemIds] = useState<Record<string, number>>({}) // itemId -> pickedQty
  const [scanInput, setScanInput] = useState('')
  const scanInputRef = useRef<HTMLInputElement>(null)

  // UI-only state
  const [currentTime, setCurrentTime] = useState(new Date())
  const [preparedToday, setPreparedToday] = useState(0)
  const [scanFocused, setScanFocused] = useState(false)

  const activeOrderRef = useRef<Order | null>(null)
  const updatingIdRef = useRef<string | null>(null)

  const aggregatedPrepItems = useMemo(() => {
    const counts: Record<string, { name: string; quantity: number; image?: string }> = {}
    
    orders.forEach(order => {
      const isClaimedByOther = !!(order.status === 'CONFIRMED' && order.assignedChefId && order.assignedChefId !== session?.user?.id)
      if (isClaimedByOther) return

      order.items.forEach((item: any) => {
        if (!counts[item.name]) {
          counts[item.name] = {
            name: item.name,
            quantity: 0,
            image: item.imageUrl || null
          }
        }
        counts[item.name].quantity += item.quantity
      })
    })

    return Object.values(counts).sort((a, b) => b.quantity - a.quantity)
  }, [orders, session?.user?.id])


  useEffect(() => {
    activeOrderRef.current = activeOrder
  }, [activeOrder])

  useEffect(() => {
    updatingIdRef.current = updatingId
  }, [updatingId])

  // Real-time clock
  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000)
    return () => clearInterval(timer)
  }, [])

  useEffect(() => {
    if (status === 'unauthenticated') {
      router.push('/login?callbackUrl=/cafe-kitchen')
    } else if (status === 'authenticated' && session?.user?.role !== 'CHEF' && session?.user?.role !== 'ADMIN') {
      router.push('/')
    }
  }, [status, session, router])

  const fetchOrders = useCallback(async (silent = false) => {
    if (!silent) setIsLoading(true)
    else setIsRefreshing(true)
    
    try {
      const res = await fetch('/api/picker/orders?type=cafe')
      if (res.ok) {
        const data = await res.json()
        setOrders(data)
        
        // If we have an active order, update its details from the list
        const currentActive = activeOrderRef.current
        if (currentActive) {
          const freshActive = data.find((o: Order) => o.id === currentActive.id)
          if (freshActive) {
            setActiveOrder(freshActive)
          } else {
            if (updatingIdRef.current !== currentActive.id) {
              toast.error('Active order is no longer in the queue (it may have been cancelled or claimed by another chef).')
              setActiveOrder(null)
              setPickedItemIds({})
            }
          }
        }
      } else {
        toast.error('Failed to fetch cafe kitchen orders')
      }
    } catch (err) {
      toast.error('Error fetching cafe kitchen queue')
    } finally {
      setIsLoading(false)
      setIsRefreshing(false)
    }
  }, [])

  // Connect to SSE for real-time order notifications
  useEffect(() => {
    if (status !== 'authenticated') return
    
    let eventSource: EventSource | null = null
    
    const connectSSE = () => {
      eventSource = new EventSource('/api/sse/orders')
      
      eventSource.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data)
          
          if (data.type === 'status-change') {
            const { orderId, status: newStatus } = data
            
            // Check if active order cancelled
            const currentActive = activeOrderRef.current
            if (currentActive && currentActive.id === orderId) {
              if (newStatus === 'CANCELLED') {
                toast.error('⚠️ The order you were preparing has been CANCELLED by the customer!')
                setActiveOrder(null)
                setPickedItemIds({})
              } else if (newStatus === 'PACKED' && updatingIdRef.current !== orderId) {
                toast.info('⚠️ The active order has been packed by another chef.')
                setActiveOrder(null)
                setPickedItemIds({})
              }
            }
            
            // Check if companion grocery order is packed (ready)
            if (currentActive && currentActive.companionOrder && currentActive.companionOrder.id === orderId) {
              if (newStatus === 'PACKED') {
                playSuccessChime()
                triggerHaptic('success')
                toast.success(`📦 Companion Grocery items are PACKED for ${currentActive.user.name}!`, {
                  duration: 5000,
                  icon: '📦'
                })
              }
            }
          }

          if (data.type === 'new-order' || data.type === 'status-change') {
            // Instant refresh of orders list
            fetchOrders(true)
            
            // Urgent sound if new cafe order
            if (data.type === 'new-order' && data.shopName === 'FastKirana Cafe Kitchen') {
              playNotificationChime()
              triggerHaptic()
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

  useEffect(() => {
    if (status === 'authenticated') {
      const silent = !!activeOrder
      fetchOrders(silent)
    }
  }, [status, fetchOrders, activeOrder])

  // Auto-refresh every 30 seconds
  useEffect(() => {
    if (status !== 'authenticated') return
    const interval = setInterval(() => fetchOrders(true), 30000)
    return () => clearInterval(interval)
  }, [status])

  // Audio alert and repeating chime when pending orders are in the queue
  useEffect(() => {
    if (status !== 'authenticated') return

    const pendingOrders = orders.filter(o => o.status === 'PENDING')
    if (pendingOrders.length === 0) return

    // Play chime immediately on new pending orders
    playNotificationChime()
    triggerHaptic('success')
    toast.info('New pending order(s) in queue!', {
      id: 'new-order-alert',
      icon: '🛎️',
    })

    // Repeat alarm chime every 5 seconds until they are accepted (status becomes CONFIRMED)
    const intervalId = setInterval(() => {
      const currentPending = orders.filter(o => o.status === 'PENDING')
      if (currentPending.length > 0) {
        playNotificationChime()
      } else {
        clearInterval(intervalId)
      }
    }, 5000)

    return () => clearInterval(intervalId)
  }, [orders, status])

  useEffect(() => {
    if (activeOrder && scanInputRef.current) {
      scanInputRef.current.focus()
    }
  }, [activeOrder])

  const handleStartPreparing = async (order: Order) => {
    setUpdatingId(order.id)
    try {
      const res = await fetch(`/api/orders/${order.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'CONFIRMED' }),
      })

      if (res.ok) {
        toast.success('Started preparing cafe order!')
        setActiveOrder(order)
        const initialPicked: Record<string, number> = {}
        order.items.forEach(item => {
          initialPicked[item.id] = 0
        })
        setPickedItemIds(initialPicked)
        fetchOrders(true)
      } else {
        toast.error('Failed to accept cafe order')
      }
    } catch (err) {
      toast.error('Error accepting cafe order')
    } finally {
      setUpdatingId(null)
    }
  }

  const checkIfAllPrepared = (newPicked: Record<string, number>, order: Order) => {
    return order.items.every(item => newPicked[item.id] === item.quantity)
  }

  const autoPackOrder = async (orderId: string) => {
    setUpdatingId(orderId)
    const toastId = toast.loading('🔥 All items prepared! Packing hot order...')
    try {
      const res = await fetch(`/api/orders/${orderId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'PACKED' }),
      })

      if (res.ok) {
        toast.dismiss(toastId)
        toast.success('🔥 Order prepared and packed! Transferred to Rider queue.', {
          duration: 4000
        })
        setPreparedToday(prev => prev + 1)
        setActiveOrder(null)
        setPickedItemIds({})
        fetchOrders(true)
      } else {
        toast.dismiss(toastId)
        toast.error('Failed to pack order')
      }
    } catch (err) {
      toast.dismiss(toastId)
      toast.error('Error packing order')
    } finally {
      setUpdatingId(null)
    }
  }

  const handleScanSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!activeOrder || !scanInput.trim()) return

    const query = scanInput.trim().toLowerCase()
    const matchingItem = activeOrder.items.find(item => {
      const slug = item.name.toLowerCase().replace(/[^a-z0-9]+/g, '-')
      return slug.includes(query) || item.name.toLowerCase().includes(query)
    })

    if (matchingItem) {
      const currentPicked = pickedItemIds[matchingItem.id] || 0
      if (currentPicked < matchingItem.quantity) {
        const newPicked = {
          ...pickedItemIds,
          [matchingItem.id]: currentPicked + 1
        }
        setPickedItemIds(newPicked)
        toast.success(`Prepared: ${matchingItem.name} (${currentPicked + 1}/${matchingItem.quantity})`, {
          icon: '🔥',
          duration: 1500
        })

        if (checkIfAllPrepared(newPicked, activeOrder)) {
          autoPackOrder(activeOrder.id)
        }
      } else {
        toast.info(`Already prepared all ${matchingItem.quantity} of ${matchingItem.name}`)
      }
    } else {
      toast.error(`No matching product found: "${scanInput}"`, {
        duration: 2000
      })
    }
    setScanInput('')
    if (scanInputRef.current) {
      scanInputRef.current.focus()
    }
  }

  const handleManualPrepareOne = (itemId: string, maxQty: number) => {
    if (!activeOrder) return
    const current = pickedItemIds[itemId] || 0
    if (current < maxQty) {
      const newPicked = {
        ...pickedItemIds,
        [itemId]: current + 1
      }
      setPickedItemIds(newPicked)
      if (checkIfAllPrepared(newPicked, activeOrder)) {
        autoPackOrder(activeOrder.id)
      }
    }
  }

  const handleManualPrepareAll = (itemId: string, maxQty: number) => {
    if (!activeOrder) return
    const newPicked = {
      ...pickedItemIds,
      [itemId]: maxQty
    }
    setPickedItemIds(newPicked)
    toast.success('Item checked off manually', { duration: 1000 })
    if (checkIfAllPrepared(newPicked, activeOrder)) {
      autoPackOrder(activeOrder.id)
    }
  }

  const handleResetItem = (itemId: string) => {
    setPickedItemIds({
      ...pickedItemIds,
      [itemId]: 0
    })
  }

  const handlePackOrder = async () => {
    if (!activeOrder) return
    autoPackOrder(activeOrder.id)
  }

  // --- Computed UI values ---
  const totalItemsToPrepare = orders.reduce((sum, o) => sum + o.items.reduce((s, i) => s + i.quantity, 0), 0)

  if (status === 'loading' || (isLoading && !activeOrder)) {
    return (
      <div className="flex min-h-[70vh] items-center justify-center bg-background">
        <motion.div 
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.4 }}
          className="text-center space-y-4"
        >
          <div className="relative mx-auto w-16 h-16">
            <div className="absolute inset-0 rounded-full bg-gradient-to-r from-rose-500 to-orange-500 opacity-20 animate-ping-slow" />
            <div className="relative h-16 w-16 rounded-full bg-gradient-to-r from-rose-500 to-orange-500 flex items-center justify-center">
              <Loader2 className="h-7 w-7 animate-spin text-white" />
            </div>
          </div>
          <div>
            <p className="text-sm font-bold text-text-primary">Loading Kitchen</p>
            <p className="text-xs text-text-muted mt-1">Preparing your console…</p>
          </div>
        </motion.div>
      </div>
    )
  }

  // =========================================================
  // ACTIVE PREPARATION SCREEN
  // =========================================================
  if (activeOrder) {
    const toPickItems = activeOrder.items.filter(item => (pickedItemIds[item.id] || 0) < item.quantity)
    const pickedItems = activeOrder.items.filter(item => (pickedItemIds[item.id] || 0) === item.quantity)
    const allCompleted = toPickItems.length === 0

    // Circular progress
    const totalQty = activeOrder.items.reduce((s, i) => s + i.quantity, 0)
    const preparedQty = activeOrder.items.reduce((s, i) => s + (pickedItemIds[i.id] || 0), 0)
    const progressPercent = totalQty > 0 ? Math.round((preparedQty / totalQty) * 100) : 0
    const circumference = 2 * Math.PI * 42
    const strokeDashoffset = circumference - (progressPercent / 100) * circumference

    return (
      <motion.div 
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.3 }}
        className="container mx-auto px-4 py-4 sm:py-6 max-w-lg space-y-5 bg-background pb-24"
      >
        {/* Header bar with back + order ID */}
        <motion.div 
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="relative overflow-hidden bg-gradient-to-r from-rose-500 via-pink-500 to-orange-500 p-4 sm:p-5 rounded-2xl shadow-lg text-white"
        >
          {/* Subtle pattern overlay */}
          <div className="absolute inset-0 opacity-10" style={{
            backgroundImage: 'radial-gradient(circle at 20% 50%, white 1px, transparent 1px), radial-gradient(circle at 80% 20%, white 1px, transparent 1px)',
            backgroundSize: '30px 30px, 40px 40px'
          }} />
          <div className="relative flex items-center justify-between">
            <button
              onClick={() => {
                setActiveOrder(null)
                setPickedItemIds({})
              }}
              className="flex items-center gap-1.5 text-xs font-bold text-white/90 hover:text-white bg-white/10 hover:bg-white/20 px-3 py-2 rounded-xl transition-all cursor-pointer min-h-[44px]"
            >
              ← Back
            </button>
            <div className="text-right">
              <p className="text-[10px] text-white/70 font-semibold">Preparing Order</p>
              <p className="text-xs font-mono font-bold">{activeOrder.id.slice(0, 12)}…</p>
            </div>
          </div>
        </motion.div>

        {/* Circular Progress + Customer Info */}
        <motion.div
          initial={{ opacity: 0, y: 15 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="bg-card border border-border rounded-2xl shadow-sm p-5 flex items-center gap-5"
        >
          {/* Circular progress ring */}
          <div className="relative flex-shrink-0">
            <svg width="96" height="96" viewBox="0 0 96 96" className="-rotate-90">
              <circle cx="48" cy="48" r="42" fill="none" stroke="#f1f5f9" strokeWidth="6" />
              <motion.circle
                cx="48" cy="48" r="42" fill="none"
                stroke="url(#progressGradient)"
                strokeWidth="6"
                strokeLinecap="round"
                strokeDasharray={circumference}
                initial={{ strokeDashoffset: circumference }}
                animate={{ strokeDashoffset }}
                transition={{ duration: 0.6, ease: 'easeOut' }}
              />
              <defs>
                <linearGradient id="progressGradient" x1="0%" y1="0%" x2="100%" y2="0%">
                  <stop offset="0%" stopColor="#f43f5e" />
                  <stop offset="100%" stopColor="#f97316" />
                </linearGradient>
              </defs>
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center">
              <motion.span
                key={progressPercent}
                initial={{ scale: 1.3, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                className="text-lg font-black text-text-primary"
              >
                {progressPercent}%
              </motion.span>
              <span className="text-[9px] font-semibold text-text-muted">prepared</span>
            </div>
          </div>

          {/* Customer + timer info */}
          <div className="flex-1 min-w-0 space-y-2">
            <div>
              <p className="text-[10px] text-text-muted font-semibold uppercase tracking-wider">Customer</p>
              <p className="text-sm font-black text-text-primary truncate">{activeOrder.user.name}</p>
            </div>
            <div className="flex items-center gap-3">
              <div>
                <p className="text-[10px] text-text-muted font-semibold">Elapsed</p>
                <p className="text-xs font-bold text-rose-500 flex items-center gap-1">
                  <Timer className="h-3 w-3" />
                  {formatElapsed(activeOrder.createdAt)}
                </p>
              </div>
              <div>
                <p className="text-[10px] text-text-muted font-semibold">Items</p>
                <p className="text-xs font-bold text-text-primary">{preparedQty}/{totalQty}</p>
              </div>
            </div>
          </div>
        </motion.div>

        {/* Companion Grocery Order Info */}
        {activeOrder.companionOrder && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.15 }}
            className="bg-gradient-to-r from-green-50 to-emerald-50 border border-emerald-200/60 p-4 rounded-2xl shadow-sm space-y-2.5"
          >
            <div className="flex items-center justify-between">
              <span className="text-xs font-black text-emerald-600 flex items-center gap-1">
                <span>📦</span> Companion Grocery Order
              </span>
              <span className={`text-[10px] font-black px-2 py-0.5 rounded uppercase ${
                activeOrder.companionOrder.status === 'PACKED' || activeOrder.companionOrder.status === 'SHIPPED' || activeOrder.companionOrder.status === 'DELIVERED'
                  ? 'bg-green-100 text-green-700'
                  : 'bg-emerald-100 text-emerald-700 animate-pulse-gentle'
              }`}>
                {activeOrder.companionOrder.status === 'CONFIRMED' ? 'PICKING' : activeOrder.companionOrder.status}
              </span>
            </div>
            <p className="text-[10px] text-text-secondary leading-normal font-semibold">
              Placed in the same checkout. Store picker is picking these items:
            </p>
            <div className="bg-white/80 border border-emerald-100/50 rounded-xl p-2.5 divide-y divide-emerald-100/30">
              {activeOrder.companionOrder.items.map((item) => (
                <div key={item.id} className="flex justify-between items-center text-[10px] font-bold py-1 first:pt-0 last:pb-0 text-text-primary">
                  <span>{item.name}</span>
                  <span className="bg-emerald-50 px-1.5 py-0.5 rounded text-emerald-600">Qty: {item.quantity}</span>
                </div>
              ))}
            </div>
          </motion.div>
        )}

        {/* Scan Barcode Form — Kitchen Timer Aesthetic */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className={`bg-card border-2 transition-all duration-300 p-5 rounded-2xl shadow-sm space-y-3 ${
            scanFocused 
              ? 'border-transparent shadow-lg' 
              : 'border-border'
          }`}
          style={scanFocused ? {
            borderImage: 'linear-gradient(135deg, #f43f5e, #f97316) 1',
            borderImageSlice: 1,
          } : undefined}
        >
          <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1.5">
            <div className="h-5 w-5 rounded-md bg-gradient-to-br from-rose-500 to-orange-500 flex items-center justify-center">
              <Barcode className="h-3 w-3 text-white" />
            </div>
            Kitchen Item Scanner
          </label>
          <form onSubmit={handleScanSubmit} className="flex gap-2">
            <input
              ref={scanInputRef}
              type="text"
              placeholder="Search or type product keyword (e.g. tea)"
              value={scanInput}
              onChange={(e) => setScanInput(e.target.value)}
              onFocus={() => setScanFocused(true)}
              onBlur={() => setScanFocused(false)}
              className="flex-1 bg-muted/40 border border-border px-4 py-3 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-rose-500/30 focus:border-rose-400 font-semibold transition-all min-h-[44px]"
            />
            <button
              type="submit"
              className="bg-gradient-to-r from-rose-500 to-orange-500 hover:from-rose-600 hover:to-orange-600 text-white text-xs font-bold px-5 py-3 rounded-xl transition-all flex items-center gap-1.5 cursor-pointer active:scale-95 min-h-[44px] min-w-[44px] shadow-md"
            >
              <Search className="h-4 w-4" />
              <span className="hidden sm:inline">Prepare</span>
            </button>
          </form>
          <p className="text-[9px] text-text-muted font-semibold leading-relaxed">
            💡 Type keywords (e.g., &quot;Chai&quot;, &quot;Samosa&quot;, &quot;Sandwich&quot;) and press Enter to scan and prepare.
          </p>
        </motion.div>

        {/* Items to Prepare */}
        <div className="space-y-3">
          <h3 className="text-xs font-black text-text-primary uppercase tracking-wider flex items-center gap-1.5">
            <UtensilsCrossed className="h-4 w-4 text-rose-500" />
            Items to Prepare ({toPickItems.length})
          </h3>
          
          <AnimatePresence mode="popLayout">
            {toPickItems.length === 0 ? (
              <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                className="bg-gradient-to-r from-green-50 to-emerald-50 border border-green-200/60 text-green-700 text-xs font-bold p-6 rounded-2xl text-center space-y-2"
              >
                <CheckCircle className="h-8 w-8 text-green-600 mx-auto animate-bounce" />
                <p>All cafe items prepared! Ready to dispatch.</p>
              </motion.div>
            ) : (
              toPickItems.map((item, idx) => {
                const picked = pickedItemIds[item.id] || 0
                const itemProgress = item.quantity > 0 ? (picked / item.quantity) * 100 : 0
                return (
                  <motion.div
                    key={item.id}
                    layoutId={item.id}
                    exit={{ opacity: 0, x: -30, scale: 0.95 }}
                    transition={{ type: 'spring', damping: 20, stiffness: 200 }}
                    className="bg-card border border-border rounded-2xl shadow-sm overflow-hidden hover:shadow-md transition-shadow"
                  >
                    {/* Item progress bar at top */}
                    <div className="h-1 bg-muted/40">
                      <motion.div
                        className="h-full bg-gradient-to-r from-rose-500 to-orange-500 rounded-full"
                        initial={{ width: 0 }}
                        animate={{ width: `${itemProgress}%` }}
                        transition={{ duration: 0.4 }}
                      />
                    </div>
                    <div className="p-4 flex items-center justify-between gap-3">
                      <div className="flex items-center gap-3 min-w-0">
                        <div className="h-11 w-11 bg-muted/40 rounded-xl flex-shrink-0 flex items-center justify-center overflow-hidden border">
                          <ProductImage
                            src={item.imageUrl}
                            alt={item.name}
                            className="h-full w-full object-contain"
                          />
                        </div>
                        <div className="min-w-0">
                          <h4 className="text-xs font-extrabold text-text-primary truncate flex items-center gap-1">
                            <span>{getItemEmoji(idx)}</span> {item.name}
                          </h4>
                          <span className="text-[10px] text-text-secondary font-bold block mt-0.5">
                            Target: {item.quantity} | Prepared: <span className="text-rose-500 font-black">{picked}</span>
                          </span>
                        </div>
                      </div>

                      {/* Actions */}
                      <div className="flex gap-1.5 shrink-0">
                        <button
                          onClick={() => handleManualPrepareOne(item.id, item.quantity)}
                          className="bg-muted hover:bg-muted-hover text-text-secondary text-xs font-bold py-2 px-3 rounded-xl border cursor-pointer active:scale-95 transition-all min-h-[44px] min-w-[44px] flex items-center justify-center"
                        >
                          +1
                        </button>
                        <button
                          onClick={() => handleManualPrepareAll(item.id, item.quantity)}
                          className="bg-gradient-to-r from-rose-500/10 to-orange-500/10 text-rose-500 hover:from-rose-500/20 hover:to-orange-500/20 text-xs font-black py-2 px-3 rounded-xl border border-rose-500/20 cursor-pointer active:scale-95 transition-all flex items-center gap-1 min-h-[44px]"
                        >
                          <Check className="h-3.5 w-3.5 stroke-[3]" />
                          Ready
                        </button>
                      </div>
                    </div>
                  </motion.div>
                )
              })
            )}
          </AnimatePresence>
        </div>

        {/* Prepared Items */}
        {pickedItems.length > 0 && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="space-y-3 pt-2"
          >
            <h3 className="text-xs font-black text-text-muted uppercase tracking-wider flex items-center gap-1.5">
              <CheckCircle className="h-4 w-4 text-green-500" />
              Prepared Items ({pickedItems.length})
            </h3>
            
            <div className="space-y-2">
              {pickedItems.map(item => (
                <motion.div
                  key={item.id}
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 0.7, x: 0 }}
                  className="bg-gradient-to-r from-green-50/50 to-emerald-50/30 border border-green-200/30 p-3 rounded-xl flex items-center justify-between gap-3"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <div className="h-8 w-8 bg-green-100 rounded-lg flex-shrink-0 flex items-center justify-center border border-green-200/50 text-green-600">
                      <Check className="h-4 w-4 stroke-[3]" />
                    </div>
                    <div className="min-w-0 line-through text-text-muted">
                      <h4 className="text-[11px] font-bold truncate">{item.name}</h4>
                      <span className="text-[9px] font-medium block mt-0.5">
                        Qty: {item.quantity} of {item.quantity} ready
                      </span>
                    </div>
                  </div>

                  <button
                    onClick={() => handleResetItem(item.id)}
                    className="text-[10px] font-bold text-danger hover:underline cursor-pointer flex items-center gap-1 min-h-[44px] min-w-[44px] justify-center"
                  >
                    <RotateCcw className="h-3 w-3" />
                    Reset
                  </button>
                </motion.div>
              ))}
            </div>
          </motion.div>
        )}

        {/* Dispatch button */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="pt-4 border-t border-border/40"
        >
          <button
            onClick={handlePackOrder}
            disabled={!allCompleted || updatingId === activeOrder.id}
            className={`h-14 w-full rounded-2xl font-black text-sm transition-all flex items-center justify-center gap-2 cursor-pointer active:scale-[0.98] ${
              allCompleted 
                ? 'bg-gradient-to-r from-rose-500 to-orange-500 text-white shadow-lg shadow-rose-300/40 animate-pulse-gentle' 
                : 'bg-muted text-text-muted border border-border cursor-not-allowed opacity-60'
            }`}
          >
            {updatingId === activeOrder.id ? (
              <>
                <Loader2 className="h-5 w-5 animate-spin" />
                Packing Order...
              </>
            ) : (
              <>
                <Flame className="h-5 w-5 text-orange-200 fill-orange-200" />
                Confirm &amp; Dispatch Hot Order
              </>
            )}
          </button>
        </motion.div>
      </motion.div>
    )
  }

  // =========================================================
  // MAIN QUEUE VIEW
  // =========================================================
  return (
    <motion.div
      initial="hidden"
      animate="show"
      variants={containerVariants}
      className="container mx-auto px-4 py-4 sm:py-6 max-w-lg space-y-5 bg-background pb-24"
    >
      
      {/* ===== Premium Cafe Header ===== */}
      <motion.div 
        variants={itemVariants}
        className="relative overflow-hidden bg-gradient-to-r from-rose-500 via-pink-500 to-orange-500 p-5 sm:p-6 rounded-3xl shadow-xl text-white"
      >
        {/* Animated background pattern */}
        <div className="absolute inset-0 opacity-[0.08]">
          <motion.div
            animate={{ rotate: 360 }}
            transition={{ duration: 60, repeat: Infinity, ease: 'linear' }}
            className="absolute -top-1/2 -right-1/2 w-full h-full"
            style={{
              backgroundImage: 'radial-gradient(circle, white 1.5px, transparent 1.5px)',
              backgroundSize: '24px 24px'
            }}
          />
        </div>
        {/* Glassmorphism inner glow */}
        <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
        
        <div className="relative flex items-center justify-between">
          <div className="flex items-center gap-3">
            <motion.div 
              animate={{ 
                rotateY: [0, 10, -10, 0],
                scale: [1, 1.05, 1]
              }}
              transition={{ 
                duration: 3, 
                repeat: Infinity, 
                ease: 'easeInOut' 
              }}
              className="h-12 w-12 rounded-2xl bg-white/20 flex items-center justify-center backdrop-blur-md border border-white/20"
            >
              <ChefHat className="h-6 w-6 text-white" />
            </motion.div>
            <div>
              <h1 className="text-base sm:text-lg font-black tracking-tight">Cafe Chef Console</h1>
              <p className="text-[11px] text-white/80 mt-0.5 font-medium">Logged in as {session?.user?.name || 'Chef'}</p>
            </div>
          </div>
          
          <div className="flex flex-col items-end gap-1.5">
            {/* Real-time clock */}
            <div className="flex items-center gap-1.5 bg-white/10 backdrop-blur-md px-2.5 py-1 rounded-lg border border-white/10">
              <Clock className="h-3 w-3 text-white/80" />
              <span className="text-[11px] font-mono font-bold text-white/90">
                {currentTime.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: true })}
              </span>
            </div>
            <button
              onClick={() => fetchOrders(true)}
              disabled={isRefreshing}
              className="p-2.5 bg-white/10 hover:bg-white/25 border border-white/20 rounded-xl transition-all disabled:opacity-50 cursor-pointer min-h-[44px] min-w-[44px] flex items-center justify-center"
            >
              <RefreshCw className={`h-4 w-4 ${isRefreshing ? 'animate-spin' : ''}`} />
            </button>
          </div>
        </div>
      </motion.div>

      {/* ===== Stats Row ===== */}
      <motion.div variants={itemVariants} className="grid grid-cols-3 gap-2.5 sm:gap-3">
        {/* Orders in Queue */}
        <motion.div
          variants={statCardVariants}
          className="relative overflow-hidden bg-gradient-to-br from-rose-50 to-pink-50 border border-rose-200/40 rounded-2xl p-3 sm:p-4 text-center"
        >
          <div className="absolute top-1.5 right-1.5 opacity-10">
            <ClipboardList className="h-8 w-8 text-rose-500" />
          </div>
          <div className="relative">
            <div className="h-8 w-8 mx-auto rounded-xl bg-gradient-to-br from-rose-500 to-pink-500 flex items-center justify-center mb-1.5 shadow-sm">
              <ClipboardList className="h-4 w-4 text-white" />
            </div>
            <motion.p
              key={orders.length}
              initial={{ scale: 1.4, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              className="text-xl sm:text-2xl font-black text-rose-600"
            >
              {orders.length}
            </motion.p>
            <p className="text-[9px] sm:text-[10px] font-bold text-rose-500/70 mt-0.5">In Queue</p>
          </div>
        </motion.div>

        {/* Items to Prepare */}
        <motion.div
          variants={statCardVariants}
          className="relative overflow-hidden bg-gradient-to-br from-orange-50 to-amber-50 border border-orange-200/40 rounded-2xl p-3 sm:p-4 text-center"
        >
          <div className="absolute top-1.5 right-1.5 opacity-10">
            <UtensilsCrossed className="h-8 w-8 text-orange-500" />
          </div>
          <div className="relative">
            <div className="h-8 w-8 mx-auto rounded-xl bg-gradient-to-br from-orange-500 to-amber-500 flex items-center justify-center mb-1.5 shadow-sm">
              <UtensilsCrossed className="h-4 w-4 text-white" />
            </div>
            <motion.p
              key={totalItemsToPrepare}
              initial={{ scale: 1.4, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              className="text-xl sm:text-2xl font-black text-orange-600"
            >
              {totalItemsToPrepare}
            </motion.p>
            <p className="text-[9px] sm:text-[10px] font-bold text-orange-500/70 mt-0.5">Items Total</p>
          </div>
        </motion.div>

        {/* Prepared Today */}
        <motion.div
          variants={statCardVariants}
          className="relative overflow-hidden bg-gradient-to-br from-green-50 to-emerald-50 border border-green-200/40 rounded-2xl p-3 sm:p-4 text-center"
        >
          <div className="absolute top-1.5 right-1.5 opacity-10">
            <PackageCheck className="h-8 w-8 text-green-500" />
          </div>
          <div className="relative">
            <div className="h-8 w-8 mx-auto rounded-xl bg-gradient-to-br from-green-500 to-emerald-500 flex items-center justify-center mb-1.5 shadow-sm">
              <PackageCheck className="h-4 w-4 text-white" />
            </div>
            <motion.p
              key={preparedToday}
              initial={{ scale: 1.4, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              className="text-xl sm:text-2xl font-black text-green-600"
            >
              {preparedToday}
            </motion.p>
            <p className="text-[9px] sm:text-[10px] font-bold text-green-500/70 mt-0.5">Packed Today</p>
          </div>
        </motion.div>
      </motion.div>

      {/* ===== Orders Queue Section ===== */}
      <motion.div variants={itemVariants} className="space-y-3">
        <h2 className="text-xs font-black text-text-primary uppercase tracking-wider flex items-center gap-1.5">
          <Coffee className="h-4 w-4 text-rose-500" />
          Hot Orders to Prepare ({orders.length})
        </h2>

        {/* Aggregated Preparation Summary */}
        {orders.length > 0 && aggregatedPrepItems.length > 0 && (
          <div className="bg-gradient-to-br from-amber-50 to-orange-50 dark:from-amber-950/20 dark:to-orange-950/20 border border-amber-200/50 dark:border-amber-900/40 rounded-2xl p-4 shadow-sm space-y-2.5">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-black text-amber-700 dark:text-amber-400 uppercase tracking-widest flex items-center gap-1.5">
                <ChefHat className="h-4 w-4" />
                Aggregated Prep Summary (Bulk Cooking)
              </span>
              <span className="text-[10px] text-amber-600/80 dark:text-amber-500/80 font-bold">
                {aggregatedPrepItems.reduce((acc, x) => acc + x.quantity, 0)} total items
              </span>
            </div>
            <div className="flex flex-wrap gap-2">
              {aggregatedPrepItems.map((item, idx) => (
                <div 
                  key={idx} 
                  className="flex items-center gap-2 bg-white dark:bg-zinc-900 border border-amber-100 dark:border-zinc-800 px-3 py-1.5 rounded-xl shadow-xs animate-slide-up"
                >
                  {item.image ? (
                    <img src={item.image} alt={item.name} className="h-6 w-6 object-contain rounded-md bg-muted/40 p-0.5" />
                  ) : (
                    <span className="text-sm">🍔</span>
                  )}
                  <span className="text-xs font-black text-gray-800 dark:text-gray-200">{item.name}</span>
                  <span className="text-xs font-black text-rose-600 bg-rose-50 px-2 py-0.5 rounded-md">
                    x{item.quantity}
                  </span>
                </div>
              ))}
            </div>
          </div>
        )}


        {orders.length === 0 ? (
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="bg-gradient-to-br from-rose-50/40 to-orange-50/40 border border-dashed border-rose-200/50 p-10 rounded-2xl text-center space-y-3"
          >
            <motion.div
              animate={{ y: [0, -6, 0] }}
              transition={{ duration: 2.5, repeat: Infinity, ease: 'easeInOut' }}
              className="text-4xl"
            >
              ☕
            </motion.div>
            <p className="text-xs text-text-muted font-semibold">No cafe orders pending!</p>
            <p className="text-[10px] text-text-muted">Time to clean the coffee machine.</p>
          </motion.div>
        ) : (
          <motion.div 
            variants={containerVariants}
            initial="hidden"
            animate="show"
            className="space-y-3"
          >
            {orders.map((order, orderIdx) => {
              const isClaimedByOther = !!(order.status === 'CONFIRMED' && order.assignedChefId && order.assignedChefId !== session?.user?.id)
              return (
                <motion.div
                  key={order.id}
                  variants={itemVariants}
                  whileHover={!isClaimedByOther ? { scale: 1.005 } : {}}
                  className="relative bg-card border border-border rounded-2xl shadow-sm overflow-hidden hover:shadow-md transition-shadow"
                >
                  {/* Warm gradient left accent */}
                  <div className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-rose-500 via-pink-500 to-orange-500 rounded-l-2xl" />

                  <div className="pl-4 pr-4 pt-4 pb-4 space-y-3">
                    {/* Customer name + Status label */}
                    <div className="flex justify-between items-start">
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-2 mb-1">
                          <div className="h-7 w-7 rounded-full bg-gradient-to-br from-rose-500/10 to-orange-500/10 flex items-center justify-center flex-shrink-0">
                            <User className="h-3.5 w-3.5 text-rose-500" />
                          </div>
                          <span className="text-sm font-black text-text-primary truncate">{order.user.name}</span>
                        </div>
                        <div className="flex items-center gap-2 ml-9">
                          <span className="text-[9px] font-mono font-bold text-text-muted truncate">{order.id.slice(0, 16)}…</span>
                          {order.companionOrder && (
                            <span className="bg-emerald-100 text-emerald-700 text-[8px] px-1.5 py-0.5 rounded font-black uppercase tracking-wider flex-shrink-0">
                              📦 grocery
                            </span>
                          )}
                        </div>
                      </div>
                      <div className="flex flex-col items-end gap-1.5 flex-shrink-0">
                        {isClaimedByOther ? (
                          <span className="px-2.5 py-1 rounded-lg text-[9px] font-black uppercase flex items-center gap-1 bg-red-500/10 text-red-600 border border-red-500/20">
                            👤 Claimed by {order.assignedChef?.name || 'Another Chef'}
                          </span>
                        ) : order.status === 'CONFIRMED' ? (
                          <span className="px-2.5 py-1 rounded-lg text-[9px] font-black uppercase flex items-center gap-1 bg-rose-500/10 text-rose-600 border border-rose-500/20">
                            <span className="h-1.5 w-1.5 rounded-full bg-rose-500 animate-pulse" />
                            Cooking by Me
                          </span>
                        ) : (
                          <span className="px-2.5 py-1 rounded-lg text-[9px] font-black uppercase flex items-center gap-1 bg-orange-500/10 text-orange-600 border border-orange-500/20">
                            <span className="h-1.5 w-1.5 rounded-full bg-orange-500 animate-pulse" />
                            New
                          </span>
                        )}
                        <span className={`text-[9px] flex items-center gap-1 ${getSlaClass(order.createdAt, order.status)}`}>
                          <Clock className="h-2.5 w-2.5" />
                          {formatElapsed(order.createdAt)}
                        </span>
                      </div>
                    </div>

                    {/* Items summary */}
                    <div className="space-y-1.5">
                      <span className="text-[10px] text-text-muted font-bold block flex items-center gap-1">
                        <Flame className="h-3 w-3 text-orange-400" />
                        Hot Items List
                      </span>
                      <div className="rounded-xl border border-rose-100/60 overflow-hidden">
                        {order.items.map((item, idx) => (
                          <div
                            key={item.id}
                            className={`flex justify-between items-center text-[11px] font-extrabold text-text-primary px-3 py-2 ${
                              idx % 2 === 0 ? 'bg-rose-500/[0.02]' : 'bg-orange-500/[0.02]'
                            } ${idx !== order.items.length - 1 ? 'border-b border-rose-100/30' : ''}`}
                          >
                            <span className="flex items-center gap-1.5">
                              <span className="text-sm">{getItemEmoji(idx)}</span>
                              {item.name}
                            </span>
                            <span className="text-rose-600 bg-rose-50 px-2 py-0.5 rounded-md text-[10px] font-black">×{item.quantity}</span>
                          </div>
                        ))}
                      </div>
                    </div>

                    {/* Payment and action row */}
                    <div className="flex justify-between items-center pt-2.5 border-t border-border/40">
                      <div>
                        <span className="text-[9px] font-bold text-text-secondary block">Payment</span>
                        <span className="text-xs font-extrabold text-text-primary">
                          {order.paymentMethod === 'COD' ? 'COD (Cash)' : 'Prepaid (Paid)'}
                        </span>
                      </div>

                      <button
                        onClick={() => {
                          if (isClaimedByOther) return
                          if (order.status === 'CONFIRMED') {
                            setActiveOrder(order)
                            const initialPicked: Record<string, number> = {}
                            order.items.forEach(item => {
                              initialPicked[item.id] = 0
                            })
                            setPickedItemIds(initialPicked)
                          } else {
                            handleStartPreparing(order)
                          }
                        }}
                        disabled={updatingId === order.id || isClaimedByOther}
                        className={`flex items-center gap-1.5 px-5 py-3 text-xs font-black rounded-xl transition-all shadow-md cursor-pointer active:scale-95 min-h-[44px] ${
                          isClaimedByOther
                            ? 'bg-muted text-text-muted border cursor-not-allowed shadow-none'
                            : 'bg-gradient-to-r from-rose-500 to-orange-500 text-white hover:shadow-lg hover:shadow-rose-300/30'
                        }`}
                      >
                        {updatingId === order.id ? (
                          <Loader2 className="h-4 w-4 animate-spin" />
                        ) : (
                          <>
                            <span>{isClaimedByOther ? 'Claimed' : order.status === 'CONFIRMED' ? 'Resume Cooking' : 'Accept & Cook'}</span>
                            <ChevronRight className="h-4 w-4 stroke-[2.5]" />
                          </>
                        )}
                      </button>
                    </div>
                  </div>
                </motion.div>
              )
            })}
          </motion.div>
        )}
      </motion.div>

      {/* Auto-refresh indicator */}
      <motion.div
        variants={itemVariants}
        className="flex items-center justify-center gap-1.5 py-2"
      >
        <div className="h-1.5 w-1.5 rounded-full bg-green-500 animate-pulse" />
        <span className="text-[9px] text-text-muted font-semibold">Auto-refreshing every 30s</span>
      </motion.div>

    </motion.div>
  )
}
