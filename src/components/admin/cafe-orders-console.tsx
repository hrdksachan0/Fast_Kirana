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
  notes?: string | null
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
  if (mins >= 30) return 'text-rose-500 font-black animate-pulse'
  if (mins >= 15) return 'text-amber-500 font-black animate-pulse'
  return 'text-gray-400 font-semibold'
}

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

export function CafeOrdersConsole() {
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
              toast.error('Active order is no longer in the queue.')
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
                toast.error('⚠️ The cafe order you were preparing has been CANCELLED!')
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
            fetchOrders(true)
            
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

  // Audio alert and repeating chime when pending orders are in queue
  useEffect(() => {
    if (status !== 'authenticated') return

    const pendingOrders = orders.filter(o => o.status === 'PENDING')
    if (pendingOrders.length === 0) return

    playNotificationChime()
    triggerHaptic('success')
    toast.info('New pending Cafe order(s) in queue!', {
      id: 'new-cafe-order-alert',
      icon: '🛎️',
    })

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
      return item.name.toLowerCase().includes(query)
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
      toast.error(`No matching product found: "${scanInput}"`)
    }
    setScanInput('')
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

  const totalItemsToPrepare = orders.reduce((sum, o) => sum + o.items.reduce((s, i) => s + i.quantity, 0), 0)

  if (isLoading && !activeOrder) {
    return (
      <div className="flex justify-center items-center py-24">
        <Loader2 className="h-8 w-8 text-orange-500 animate-spin" />
      </div>
    )
  }

  if (activeOrder) {
    const toPickItems = activeOrder.items.filter(item => (pickedItemIds[item.id] || 0) < item.quantity)
    const pickedItems = activeOrder.items.filter(item => (pickedItemIds[item.id] || 0) === item.quantity)
    const allCompleted = toPickItems.length === 0

    const totalQty = activeOrder.items.reduce((s, i) => s + i.quantity, 0)
    const preparedQty = activeOrder.items.reduce((s, i) => s + (pickedItemIds[i.id] || 0), 0)
    const progressPercent = totalQty > 0 ? Math.round((preparedQty / totalQty) * 100) : 0
    const circumference = 2 * Math.PI * 42
    const strokeDashoffset = circumference - (progressPercent / 100) * circumference

    return (
      <motion.div 
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        className="max-w-xl mx-auto space-y-6 pb-20"
      >
        <div className="relative overflow-hidden bg-gradient-to-r from-rose-500 to-orange-500 p-5 rounded-3xl shadow-lg text-white">
          <div className="flex items-center justify-between">
            <button
              onClick={() => {
                setActiveOrder(null)
                setPickedItemIds({})
              }}
              className="flex items-center gap-1.5 text-xs font-black text-white/95 hover:text-white bg-white/10 hover:bg-white/20 px-3.5 py-2 rounded-xl transition-all cursor-pointer"
            >
              ← Back to Queue
            </button>
            <div className="text-right">
              <p className="text-[10px] text-white/70 font-semibold uppercase tracking-wider">PREPARING CAFE TICKET</p>
              <p className="text-xs font-mono font-bold">{activeOrder.id.slice(0, 12)}</p>
            </div>
          </div>
        </div>

        <div className="bg-card border border-border/55 rounded-3xl p-5 flex items-center gap-6 shadow-sm">
          <div className="relative flex-shrink-0">
            <svg width="90" height="90" viewBox="0 0 96 96" className="-rotate-90">
              <circle cx="48" cy="48" r="42" fill="none" stroke="currentColor" className="text-border/40" strokeWidth="6" />
              <motion.circle
                cx="48" cy="48" r="42" fill="none"
                stroke="#f97316"
                strokeWidth="6"
                strokeLinecap="round"
                strokeDasharray={circumference}
                initial={{ strokeDashoffset: circumference }}
                animate={{ strokeDashoffset }}
                transition={{ duration: 0.6, ease: 'easeOut' }}
              />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center">
              <span className="text-lg font-black text-text-primary">{progressPercent}%</span>
              <span className="text-[9px] font-semibold text-text-muted">ready</span>
            </div>
          </div>

          <div className="flex-1 space-y-2">
            <div>
              <p className="text-[10px] text-text-muted font-semibold uppercase">Customer</p>
              <p className="text-sm font-black text-text-primary truncate">{activeOrder.user.name}</p>
            </div>
            <div className="flex items-center gap-4">
              <div>
                <p className="text-[10px] text-text-muted font-semibold">Elapsed</p>
                <p className="text-xs font-bold text-orange-500 flex items-center gap-1">
                  <Clock className="h-3.5 w-3.5" />
                  {formatElapsed(activeOrder.createdAt)}
                </p>
              </div>
              <div>
                <p className="text-[10px] text-text-muted font-semibold">Items prepared</p>
                <p className="text-xs font-bold text-text-primary">{preparedQty}/{totalQty}</p>
              </div>
            </div>
          </div>
        </div>

        {activeOrder.companionOrder && (
          <div className="bg-gradient-to-r from-green-50 to-emerald-50 border border-emerald-200/60 p-4 rounded-3xl shadow-sm space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-black text-emerald-600">📦 Companion Grocery Order</span>
              <span className="text-[9px] font-black bg-emerald-100 text-emerald-700 px-2 py-0.5 rounded uppercase">
                {activeOrder.companionOrder.status}
              </span>
            </div>
            <div className="bg-white border rounded-2xl p-2.5 space-y-1">
              {activeOrder.companionOrder.items.map((item) => (
                <div key={item.id} className="flex justify-between items-center text-[10px] font-bold text-text-primary">
                  <span>{item.name}</span>
                  <span className="text-emerald-600">Qty: {item.quantity}</span>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="bg-card border border-border/55 p-5 rounded-3xl shadow-sm space-y-3">
          <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1.5">
            <Barcode className="h-4 w-4 text-orange-500" />
            Kitchen Item Scanner
          </label>
          <form onSubmit={handleScanSubmit} className="flex gap-2">
            <input
              ref={scanInputRef}
              type="text"
              placeholder="Type cafe product name"
              value={scanInput}
              onChange={(e) => setScanInput(e.target.value)}
              className="flex-1 bg-muted/40 border border-border px-4 py-2.5 rounded-xl text-xs focus:outline-none focus:border-orange-400 font-semibold"
            />
            <button
              type="submit"
              className="bg-orange-500 hover:bg-orange-600 text-white text-xs font-bold px-4 py-2 rounded-xl transition-all cursor-pointer shadow-md"
            >
              Prepare
            </button>
          </form>
        </div>

        <div className="space-y-3">
          <h3 className="text-xs font-black text-text-primary uppercase tracking-wider flex items-center gap-1.5">
            <UtensilsCrossed className="h-4 w-4 text-orange-500" />
            Snacks to Prepare ({toPickItems.length})
          </h3>
          
          <div className="space-y-3">
            {toPickItems.map((item, idx) => {
              const picked = pickedItemIds[item.id] || 0
              return (
                <div key={item.id} className="bg-card border border-border/50 rounded-2xl p-4 flex items-center justify-between gap-4">
                  <div className="flex items-center gap-3">
                    <span className="text-xl shrink-0">{getItemEmoji(idx)}</span>
                    <div>
                      <h4 className="text-xs font-extrabold text-text-primary">{item.name}</h4>
                      {item.notes && (
                        <p className="text-[10px] text-amber-500 font-black mt-0.5">📝 Notes: {item.notes}</p>
                      )}
                      <p className="text-[10px] text-text-secondary font-bold mt-0.5">
                        Target: {item.quantity} | Prepared: <span className="text-orange-500 font-black">{picked}</span>
                      </p>
                    </div>
                  </div>

                  <div className="flex gap-2">
                    <button
                      onClick={() => handleManualPrepareOne(item.id, item.quantity)}
                      className="bg-muted hover:bg-muted-hover text-text-secondary text-xs font-bold py-2 px-3.5 rounded-xl border cursor-pointer transition-all active:scale-95"
                    >
                      +1
                    </button>
                    <button
                      onClick={() => handleManualPrepareAll(item.id, item.quantity)}
                      className="bg-orange-500/10 text-orange-600 hover:bg-orange-500/20 text-xs font-black py-2 px-4 rounded-xl border border-orange-500/20 cursor-pointer transition-all active:scale-95 flex items-center gap-1"
                    >
                      <Check className="h-3.5 w-3.5 stroke-[3]" />
                      Ready
                    </button>
                  </div>
                </div>
              )
            })}
          </div>
        </div>

        {pickedItems.length > 0 && (
          <div className="space-y-3 opacity-60">
            <h3 className="text-xs font-black text-text-secondary uppercase tracking-wider">Completed Items ({pickedItems.length})</h3>
            <div className="space-y-2">
              {pickedItems.map((item) => (
                <div key={item.id} className="bg-muted/30 border border-border/40 rounded-2xl p-3 flex justify-between items-center">
                  <div className="flex items-center gap-2">
                    <CheckCircle className="h-4 w-4 text-emerald-500" />
                    <span className="text-xs font-bold text-text-secondary line-through">{item.name}</span>
                  </div>
                  <button
                    onClick={() => handleResetItem(item.id)}
                    className="p-1 text-text-muted hover:text-text-primary rounded"
                  >
                    <RotateCcw className="h-3.5 w-3.5" />
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="pt-4 border-t border-border/45">
          <button
            onClick={handlePackOrder}
            disabled={!allCompleted || updatingId === activeOrder.id}
            className={`h-12 w-full rounded-2xl font-black text-xs transition-all flex items-center justify-center gap-2 cursor-pointer active:scale-98 ${
              allCompleted 
                ? 'bg-gradient-to-r from-rose-500 to-orange-550 text-white shadow-lg shadow-rose-600/10' 
                : 'bg-muted text-text-muted border cursor-not-allowed opacity-60'
            }`}
          >
            Confirm &amp; Dispatch Order
          </button>
        </div>
      </motion.div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-3 gap-4">
        <div className="bg-card border border-border/50 p-4 rounded-3xl text-center space-y-1 shadow-sm">
          <p className="text-[9px] font-extrabold uppercase tracking-wider text-text-secondary">Orders in Queue</p>
          <h4 className="text-2xl font-black text-text-primary">{orders.length}</h4>
        </div>
        <div className="bg-card border border-border/50 p-4 rounded-3xl text-center space-y-1 shadow-sm">
          <p className="text-[9px] font-extrabold uppercase tracking-wider text-text-secondary">Items to Prepare</p>
          <h4 className="text-2xl font-black text-text-primary">{totalItemsToPrepare}</h4>
        </div>
        <div className="bg-card border border-border/50 p-4 rounded-3xl text-center space-y-1 shadow-sm">
          <p className="text-[9px] font-extrabold uppercase tracking-wider text-text-secondary">Prepared Today</p>
          <h4 className="text-2xl font-black text-emerald-600">+{preparedToday}</h4>
        </div>
      </div>

      {orders.length === 0 ? (
        <div className="bg-card border border-border/55 p-12 rounded-3xl text-center space-y-3">
          <p className="text-xs text-text-secondary font-bold">No active cafe orders in queue right now.</p>
          <p className="text-[10px] text-text-muted">New orders will sound an alarm alert automatically.</p>
        </div>
      ) : (
        <div className="space-y-4">
          <h3 className="text-xs font-black text-text-primary uppercase tracking-wider flex items-center gap-1.5">
            <ShoppingBag className="h-4 w-4 text-orange-500" />
            Live Orders List ({orders.length})
          </h3>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {orders.map((order) => {
              const isClaimedByMe = order.assignedChefId === session?.user?.id
              const isClaimedByOther = !!(order.status === 'CONFIRMED' && order.assignedChefId && !isClaimedByMe)
              const claimLabel = isClaimedByOther ? `Preparing by ${order.assignedChef?.name || 'Chef'}` : isClaimedByMe ? 'Preparing' : 'Claim Order'

              return (
                <div key={order.id} className="bg-card border border-border/55 rounded-3xl p-5 shadow-sm flex flex-col justify-between space-y-4">
                  <div className="flex justify-between items-start">
                    <div>
                      <p className="text-xs font-mono font-bold text-text-primary">{order.id.slice(0, 8)}</p>
                      <p className="text-[9px] text-text-muted mt-0.5">{order.user.name} • {order.deliveryMethod}</p>
                    </div>
                    <span className={`text-[9px] font-black uppercase px-2 py-0.5 rounded ${
                      order.status === 'PENDING' ? 'bg-amber-100 text-amber-700 animate-pulse' : 'bg-orange-100 text-orange-700'
                    }`}>
                      {order.status === 'PENDING' ? 'RECEIVED' : 'PREPARING'}
                    </span>
                  </div>

                  <div className="divide-y divide-border/30 bg-muted/20 p-3 rounded-2xl border border-border/30">
                    {order.items.map((item, idx) => (
                      <div key={idx} className="flex justify-between items-center text-[11px] py-1.5 first:pt-0 last:pb-0 text-text-primary font-bold">
                        <span className="truncate pr-4">{item.name}</span>
                        <span className="bg-card px-1.5 py-0.5 rounded text-text-secondary border">x{item.quantity}</span>
                      </div>
                    ))}
                  </div>

                  <div className="flex justify-between items-center pt-2">
                    <p className={`text-[10px] ${getSlaClass(order.createdAt, order.status)}`}>
                      ⏳ {formatElapsed(order.createdAt)}
                    </p>
                    <button
                      onClick={() => !isClaimedByOther && handleStartPreparing(order)}
                      disabled={isClaimedByOther || updatingId === order.id}
                      className={`text-xs font-black px-4 py-2 rounded-xl transition-all cursor-pointer active:scale-95 ${
                        isClaimedByOther 
                          ? 'bg-zinc-800 text-zinc-600 border border-zinc-900 cursor-not-allowed' 
                          : 'bg-orange-600 text-white hover:bg-orange-700 shadow-md'
                      }`}
                    >
                      {claimLabel}
                    </button>
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      )}
    </div>
  )
}
