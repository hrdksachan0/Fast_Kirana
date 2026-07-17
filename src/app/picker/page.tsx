'use client'

import { useState, useEffect, useRef, useCallback, useMemo } from 'react'
import { useSession } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { formatPrice } from '@/lib/utils'
import { toast } from 'sonner'
import { playNotificationChime, playSuccessChime } from '@/lib/audio'
import { triggerHaptic } from '@/lib/haptic'
import { 
  Loader2, 
  ShoppingBag, 
  RefreshCw, 
  CheckCircle,
  Package,
  User,
  Barcode,
  Check,
  Search,
  ChevronRight,
  Sparkles,
  Smartphone,
  Clock,
  ListChecks,
  TrendingUp,
  ArrowLeft,
  Zap,
  CircleDot,
  RotateCcw,
  Camera,
  Layers,
  ArrowRight
} from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { ProductImage } from '@/components/product/product-image'

interface OrderItem {
  id: string
  productId: string
  name: string
  price: number
  quantity: number
  imageUrl?: string
  product?: {
    slug: string
    location?: string | null
    category?: {
      slug: string
    }
  }
}

interface CompanionOrder {
  id: string
  readableId?: number
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
  readableId?: number
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
    phone?: string
  }
  items: OrderItem[]
  companionOrder?: CompanionOrder | null
  assignedPickerId?: string | null
  assignedChefId?: string | null
  assignedPicker?: { name: string } | null
  assignedChef?: { name: string } | null
}

const BIN_CONFIGS = [
  { name: 'Blue Bin', bg: 'bg-blue-500/10 dark:bg-blue-500/20 text-blue-600 dark:text-blue-400 border-blue-200/50 dark:border-blue-800/30', fill: 'bg-blue-500' },
  { name: 'Red Bin', bg: 'bg-red-500/10 dark:bg-red-500/20 text-red-600 dark:text-red-400 border-red-200/50 dark:border-red-800/30', fill: 'bg-red-500' },
  { name: 'Green Bin', bg: 'bg-green-500/10 dark:bg-green-500/20 text-green-600 dark:text-green-400 border-green-200/50 dark:border-green-800/30', fill: 'bg-green-500' },
]

const CATEGORY_AISLES: Record<string, number> = {
  'fruits-vegetables': 1,
  'dairy-breakfast': 2,
  'bakery-biscuits': 3,
  'snacks-munchies': 4,
  'beverages': 5,
  'personal-care': 6,
  'household': 7,
  'atta-rice-dal': 8,
}

function getAisleNumber(categorySlug: string = ''): number {
  return CATEGORY_AISLES[categorySlug] || 9
}

function getAisleName(aisleNo: number): string {
  switch (aisleNo) {
    case 1: return 'Fresh Produce Rack'
    case 2: return 'Chilled Dairy Section'
    case 3: return 'Bread & Bakery Aisle'
    case 4: return 'Snacks & Biscuits Aisle'
    case 5: return 'Chilled Beverages'
    case 6: return 'Hygiene & Personal Care'
    case 7: return 'Household Cleaners'
    case 8: return 'Staples & Grains Rack'
    default: return 'General Inventory Shelves'
  }
}

// --- Helper: time ago ---
function timeAgo(date: string | Date): string {
  const now = new Date()
  const then = new Date(date)
  const diffMs = now.getTime() - then.getTime()
  const diffSec = Math.floor(diffMs / 1000)
  if (diffSec < 60) return `${diffSec}s ago`
  const diffMin = Math.floor(diffSec / 60)
  if (diffMin < 60) return `${diffMin}m ago`
  const diffHr = Math.floor(diffMin / 60)
  if (diffHr < 24) return `${diffHr}h ago`
  return `${Math.floor(diffHr / 24)}d ago`
}

function getSlaClass(date: string | Date, status: string): string {
  if (status !== 'PENDING') return 'text-gray-400 font-semibold'
  const now = new Date()
  const then = new Date(date)
  const diffMs = now.getTime() - then.getTime()
  const diffMin = Math.floor(diffMs / 60000)
  if (diffMin >= 10) return 'text-rose-500 font-black animate-pulse'
  if (diffMin >= 5) return 'text-amber-500 font-black animate-pulse'
  return 'text-gray-400 font-semibold'
}

// --- Circular progress component ---
function CircularProgress({ picked, total }: { picked: number; total: number }) {
  const pct = total === 0 ? 100 : Math.round((picked / total) * 100)
  const radius = 40
  const circumference = 2 * Math.PI * radius
  const strokeDashoffset = circumference - (pct / 100) * circumference

  return (
    <div className="relative flex items-center justify-center">
      <svg width="96" height="96" viewBox="0 0 96 96" className="-rotate-90">
        <circle
          cx="48" cy="48" r={radius}
          fill="none"
          stroke="currentColor"
          strokeWidth="6"
          className="text-gray-200"
        />
        <motion.circle
          cx="48" cy="48" r={radius}
          fill="none"
          stroke="url(#progressGradient)"
          strokeWidth="6"
          strokeLinecap="round"
          strokeDasharray={circumference}
          initial={{ strokeDashoffset: circumference }}
          animate={{ strokeDashoffset }}
          transition={{ duration: 0.7, ease: 'easeOut' }}
        />
        <defs>
          <linearGradient id="progressGradient" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stopColor="#2563eb" />
            <stop offset="100%" stopColor="#4f46e5" />
          </linearGradient>
        </defs>
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="text-lg font-black text-gray-800">{picked}/{total}</span>
        <span className="text-[9px] font-bold text-gray-400 uppercase tracking-wider">picked</span>
      </div>
    </div>
  )
}

export default function PickerDashboard() {
  const { data: session, status } = useSession()
  const router = useRouter()
  
  const [orders, setOrders] = useState<Order[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isRefreshing, setIsRefreshing] = useState(false)
  const [updatingId, setUpdatingId] = useState<string | null>(null)
  
  // Active Picking Order State
  const [activeOrder, setActiveOrder] = useState<Order | null>(null)
  const [pickedItemIds, setPickedItemIds] = useState<Record<string, number>>({}) // itemId -> pickedQty
  const [scanInput, setScanInput] = useState('')
  const scanInputRef = useRef<HTMLInputElement>(null)

  // Camera Barcode Scanning States
  const [isCameraScanning, setIsCameraScanning] = useState(false)
  const videoRef = useRef<HTMLVideoElement>(null)
  const videoStreamRef = useRef<MediaStream | null>(null)

  // Multi-Order Picking States
  const [selectedOrderIds, setSelectedOrderIds] = useState<string[]>([])
  const [isMultiPickingMode, setIsMultiPickingMode] = useState(false)
  const [multiActiveOrders, setMultiActiveOrders] = useState<Order[]>([])
  const [multiPickedItemIds, setMultiPickedItemIds] = useState<Record<string, Record<string, number>>>({}) // orderId -> { itemId -> qty }
  const [binColors, setBinColors] = useState<Record<string, typeof BIN_CONFIGS[0]>>({})
  const [justPickedItem, setJustPickedItem] = useState<{ name: string; binName: string; binColorClass: string } | null>(null)

  // --- UI-only state ---
  const [currentTime, setCurrentTime] = useState(new Date())
  const [pickedToday, setPickedToday] = useState(0)
  const [refreshProgress, setRefreshProgress] = useState(100) // 0-100, ticks down every second

  // State refs for stable callback dependencies
  const activeOrderRef = useRef<Order | null>(null)
  const isMultiPickingModeRef = useRef(false)
  const multiActiveOrdersRef = useRef<Order[]>([])
  const updatingIdRef = useRef<string | null>(null)

  useEffect(() => {
    activeOrderRef.current = activeOrder
  }, [activeOrder])

  useEffect(() => {
    isMultiPickingModeRef.current = isMultiPickingMode
  }, [isMultiPickingMode])

  useEffect(() => {
    multiActiveOrdersRef.current = multiActiveOrders
  }, [multiActiveOrders])

  useEffect(() => {
    updatingIdRef.current = updatingId
  }, [updatingId])

  // Real-time clock
  useEffect(() => {
    const t = setInterval(() => setCurrentTime(new Date()), 1000)
    return () => clearInterval(t)
  }, [])

  const prevOrdersCountRef = useRef<number | null>(null)

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

  // Auto-refresh every 30 seconds with progress indicator
  useEffect(() => {
    if (status !== 'authenticated') return
    const INTERVAL = 30
    let elapsed = 0
    const t = setInterval(() => {
      elapsed++
      setRefreshProgress(Math.max(0, 100 - (elapsed / INTERVAL) * 100))
      if (elapsed >= INTERVAL) {
        elapsed = 0
        setRefreshProgress(100)
        fetchOrders(true)
      }
    }, 1000)
    return () => clearInterval(t)
  }, [status])

  useEffect(() => {
    if (status === 'unauthenticated') {
      router.push('/login?callbackUrl=/picker')
    } else if (status === 'authenticated' && session?.user?.role !== 'PICKER' && session?.user?.role !== 'ADMIN') {
      router.push('/')
    }
  }, [status, session, router])

  const fetchOrders = useCallback(async (silent = false) => {
    if (!silent) setIsLoading(true)
    else setIsRefreshing(true)
    
    try {
      const res = await fetch('/api/picker/orders')
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
            // Active order is no longer in pending/confirmed queue (e.g. packed by someone else or cancelled)
            if (updatingIdRef.current !== currentActive.id) {
              toast.error('Active order is no longer in the queue (it may have been cancelled or claimed by another user).')
              setActiveOrder(null)
              setPickedItemIds({})
            }
          }
        }

        // If we have multi-active orders, update their details from the list
        if (isMultiPickingModeRef.current && multiActiveOrdersRef.current.length > 0) {
          const updatedMultiActive = multiActiveOrdersRef.current.map(mo => {
            const fresh = data.find((o: Order) => o.id === mo.id)
            return fresh || mo
          })
          setMultiActiveOrders(updatedMultiActive)
        }
      } else {
        toast.error('Failed to fetch picker orders')
      }
    } catch (err) {
      toast.error('Error fetching picker queue')
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
                toast.error('⚠️ The order you were picking has been CANCELLED by the customer!')
                setActiveOrder(null)
                setPickedItemIds({})
              } else if (newStatus === 'PACKED' && updatingIdRef.current !== orderId) {
                toast.info('⚠️ The active order has been packed by another picker.')
                setActiveOrder(null)
                setPickedItemIds({})
              }
            }
            
            // Check if any multi-active order cancelled
            if (isMultiPickingModeRef.current && multiActiveOrdersRef.current.length > 0) {
              const hasOrder = multiActiveOrdersRef.current.some(o => o.id === orderId)
              if (hasOrder) {
                if (newStatus === 'CANCELLED') {
                  const cancelledOrder = multiActiveOrdersRef.current.find(o => o.id === orderId)
                  toast.error(`⚠️ Order for ${cancelledOrder?.user?.name || 'customer'} has been CANCELLED!`)
                  setMultiActiveOrders(prev => prev.filter(o => o.id !== orderId))
                  setMultiPickedItemIds(prev => {
                    const copy = { ...prev }
                    delete copy[orderId]
                    return copy
                  })
                } else if (newStatus === 'PACKED' && updatingIdRef.current !== orderId) {
                  const packedOrder = multiActiveOrdersRef.current.find(o => o.id === orderId)
                  toast.info(`⚠️ Order for ${packedOrder?.user?.name || 'customer'} was packed by another picker.`)
                  setMultiActiveOrders(prev => prev.filter(o => o.id !== orderId))
                  setMultiPickedItemIds(prev => {
                    const copy = { ...prev }
                    delete copy[orderId]
                    return copy
                  })
                }
              }
            }

            // Check if companion cafe order is ready
            if (currentActive && currentActive.companionOrder && currentActive.companionOrder.id === orderId) {
              if (newStatus === 'PACKED') {
                playSuccessChime()
                triggerHaptic('success')
                toast.success(`☕ Cafe items are ready for ${currentActive.user.name}!`, {
                  duration: 5000,
                  icon: '☕'
                })
              }
            }

            // Check companion cafe order ready in multi-picking
            if (isMultiPickingModeRef.current && multiActiveOrdersRef.current.length > 0) {
              multiActiveOrdersRef.current.forEach(mo => {
                if (mo.companionOrder && mo.companionOrder.id === orderId) {
                  if (newStatus === 'PACKED') {
                    playSuccessChime()
                    triggerHaptic('success')
                    toast.success(`☕ Cafe items ready for ${mo.user.name}!`, {
                      duration: 5000,
                      icon: '☕'
                    })
                  }
                }
              })
            }
          }

          if (data.type === 'new-order' || data.type === 'status-change') {
            // Instant refresh of orders list
            fetchOrders(true)
            
            // Urgent sound if new grocery order
            if (data.type === 'new-order' && (data.shopName === null || data.shopName !== 'FastKirana Cafe Kitchen')) {
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
      const silent = !!activeOrder || isMultiPickingMode
      fetchOrders(silent)
    }
  }, [status, fetchOrders, activeOrder, isMultiPickingMode])

  // Automatically focus scan input on picking screen
  useEffect(() => {
    if (activeOrder && scanInputRef.current) {
      scanInputRef.current.focus()
    }
  }, [activeOrder])

  // Web Audio API Beep Sound generator
  const playBeep = () => {
    try {
      triggerHaptic('light')
      const ctx = new (window.AudioContext || (window as any).webkitAudioContext)()
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()
      osc.type = 'sine'
      osc.frequency.setValueAtTime(850, ctx.currentTime) // Crisp scanner beep
      gain.gain.setValueAtTime(0.08, ctx.currentTime)
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.12)
      osc.connect(gain)
      gain.connect(ctx.destination)
      osc.start()
      osc.stop(ctx.currentTime + 0.12)
    } catch (e) {
      console.warn('AudioContext failed:', e)
    }
  }

  // Camera Scanner stream controller
  const startCamera = async () => {
    setIsCameraScanning(true)
  }

  const stopCamera = () => {
    setIsCameraScanning(false)
    if (videoStreamRef.current) {
      videoStreamRef.current.getTracks().forEach(track => track.stop())
      videoStreamRef.current = null
    }
  }

  useEffect(() => {
    if (isCameraScanning) {
      navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment' }
      }).then(stream => {
        videoStreamRef.current = stream
        if (videoRef.current) {
          videoRef.current.srcObject = stream
        }
      }).catch(err => {
        console.warn('Camera access error:', err)
        toast.error('Camera block details: Simulating camera scanning feed overlays…')
      })
    } else {
      if (videoStreamRef.current) {
        videoStreamRef.current.getTracks().forEach(track => track.stop())
        videoStreamRef.current = null
      }
    }
    return () => {
      if (videoStreamRef.current) {
        videoStreamRef.current.getTracks().forEach(track => track.stop())
      }
    }
  }, [isCameraScanning])

  const handleStartPicking = async (order: Order) => {
    setUpdatingId(order.id)
    try {
      const res = await fetch(`/api/orders/${order.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'CONFIRMED' }),
      })

      if (res.ok) {
        toast.success('Order status updated to Preparing (Picking)!')
        setActiveOrder(order)
        // Initialize picked quantities to 0
        const initialPicked: Record<string, number> = {}
        order.items.forEach(item => {
          initialPicked[item.id] = 0
        })
        setPickedItemIds(initialPicked)
        fetchOrders(true)
      } else {
        toast.error('Failed to accept order')
      }
    } catch (err) {
      toast.error('Error accepting order')
    } finally {
      setUpdatingId(null)
    }
  }

  const checkIfAllPicked = (newPicked: Record<string, number>, order: Order) => {
    return order.items.every(item => newPicked[item.id] === item.quantity)
  }

  const autoPackOrder = async (orderId: string) => {
    setUpdatingId(orderId)
    const toastId = toast.loading('📦 All items picked! Automatically packing order...')
    try {
      const res = await fetch(`/api/orders/${orderId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'PACKED' }),
      })

      if (res.ok) {
        toast.dismiss(toastId)
        toast.success('📦 Order packed automatically! Transferred to Rider queue.', {
          duration: 4000
        })
        setPickedToday(prev => prev + 1)
        setActiveOrder(null)
        setPickedItemIds({})
        fetchOrders(true)
      } else {
        toast.dismiss(toastId)
        toast.error('Failed to automatically pack order')
      }
    } catch (err) {
      toast.dismiss(toastId)
      toast.error('Error during auto-packing')
    } finally {
      setUpdatingId(null)
    }
  }

  const handleScanSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!activeOrder || !scanInput.trim()) return

    const query = scanInput.trim().toLowerCase()
    
    // Find item that matches slug or name
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
        playBeep()
        toast.success(`Scanned: ${matchingItem.name} (${currentPicked + 1}/${matchingItem.quantity})`, {
          icon: '🏷️',
          duration: 1500
        })

        if (checkIfAllPicked(newPicked, activeOrder)) {
          autoPackOrder(activeOrder.id)
        }
      } else {
        toast.info(`Already picked all ${matchingItem.quantity} of ${matchingItem.name}`)
      }
    } else {
      toast.error(`No matching product found for scan: "${scanInput}"`, {
        duration: 2000
      })
    }
    setScanInput('')
    if (scanInputRef.current) {
      scanInputRef.current.focus()
    }
  }

  const handleManualPickOne = (itemId: string, maxQty: number) => {
    if (!activeOrder) return
    const current = pickedItemIds[itemId] || 0
    if (current < maxQty) {
      const newPicked = {
        ...pickedItemIds,
        [itemId]: current + 1
      }
      setPickedItemIds(newPicked)
      playBeep()
      if (checkIfAllPicked(newPicked, activeOrder)) {
        autoPackOrder(activeOrder.id)
      }
    }
  }

  const handleManualPickAll = (itemId: string, maxQty: number) => {
    if (!activeOrder) return
    const newPicked = {
      ...pickedItemIds,
      [itemId]: maxQty
    }
    setPickedItemIds(newPicked)
    playBeep()
    toast.success('Item checked off manually', { duration: 1000 })
    if (checkIfAllPicked(newPicked, activeOrder)) {
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

  // --- Multi-Order Picking Logic ---
  const handleStartMultiPicking = async () => {
    if (selectedOrderIds.length === 0) return
    setIsLoading(true)
    try {
      const activeOrdersToSet: Order[] = []
      const initialMultiPicked: Record<string, Record<string, number>> = {}
      const assignedBins: Record<string, typeof BIN_CONFIGS[0]> = {}

      for (let i = 0; i < selectedOrderIds.length; i++) {
        const orderId = selectedOrderIds[i]
        const order = orders.find(o => o.id === orderId)
        if (order) {
          // Accept/Confirm the order status
          await fetch(`/api/orders/${order.id}`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status: 'CONFIRMED' }),
          })

          activeOrdersToSet.push(order)
          assignedBins[order.id] = BIN_CONFIGS[i % BIN_CONFIGS.length]
          
          const orderPicked: Record<string, number> = {}
          order.items.forEach(item => {
            orderPicked[item.id] = 0
          })
          initialMultiPicked[order.id] = orderPicked
        }
      }

      setMultiActiveOrders(activeOrdersToSet)
      setBinColors(assignedBins)
      setMultiPickedItemIds(initialMultiPicked)
      setIsMultiPickingMode(true)
      setSelectedOrderIds([])
      toast.success(`Multi-Picking Console started for ${activeOrdersToSet.length} orders!`)
      fetchOrders(true)
    } catch (e) {
      toast.error('Failed to start multi-picking console')
    } finally {
      setIsLoading(false)
    }
  }

  // Consolidated checklist sorted by Location / Aisle number
  const consolidatedItems = useMemo(() => {
    if (!isMultiPickingMode || multiActiveOrders.length === 0) return []

    const itemsMap: Record<string, {
      productId: string
      name: string
      imageUrl?: string
      unit: string
      categorySlug: string
      location?: string | null
      totalNeeded: number
      totalPicked: number
      placements: Array<{
        orderId: string
        itemId: string
        quantityNeeded: number
        quantityPicked: number
        binInfo: typeof BIN_CONFIGS[0]
      }>
    }> = {}

    multiActiveOrders.forEach(order => {
      const bin = binColors[order.id] || BIN_CONFIGS[0]
      const orderPicked = multiPickedItemIds[order.id] || {}

      order.items.forEach(item => {
        const picked = orderPicked[item.id] || 0
        const catSlug = item.product?.category?.slug || ''

        if (!itemsMap[item.productId]) {
          itemsMap[item.productId] = {
            productId: item.productId,
            name: item.name,
            imageUrl: item.imageUrl,
            unit: item.name.toLowerCase().includes('gm') || item.name.toLowerCase().includes('kg') ? '' : 'pc',
            categorySlug: catSlug,
            location: item.product?.location || null,
            totalNeeded: 0,
            totalPicked: 0,
            placements: []
          }
        }

        const entry = itemsMap[item.productId]
        entry.totalNeeded += item.quantity
        entry.totalPicked += picked
        entry.placements.push({
          orderId: order.id,
          itemId: item.id,
          quantityNeeded: item.quantity,
          quantityPicked: picked,
          binInfo: bin
        })
      })
    })

    return Object.values(itemsMap).sort((a, b) => {
      if (a.location && b.location) {
        return a.location.localeCompare(b.location)
      }
      if (a.location) return -1
      if (b.location) return 1
      const aisleA = getAisleNumber(a.categorySlug)
      const aisleB = getAisleNumber(b.categorySlug)
      return aisleA - aisleB
    })
  }, [isMultiPickingMode, multiActiveOrders, binColors, multiPickedItemIds])


  const handleMultiPickOne = (productId: string) => {
    const itemEntry = consolidatedItems.find(item => item.productId === productId)
    if (!itemEntry) return

    const targetPlacement = itemEntry.placements.find(p => p.quantityPicked < p.quantityNeeded)
    if (!targetPlacement) return

    const orderId = targetPlacement.orderId
    const itemId = targetPlacement.itemId
    const bin = targetPlacement.binInfo

    const orderPicked = { ...(multiPickedItemIds[orderId] || {}) }
    const currentPicked = orderPicked[itemId] || 0
    orderPicked[itemId] = currentPicked + 1

    const updatedMultiPicked = {
      ...multiPickedItemIds,
      [orderId]: orderPicked
    }
    setMultiPickedItemIds(updatedMultiPicked)
    playBeep()

    setJustPickedItem({
      name: itemEntry.name,
      binName: bin.name,
      binColorClass: bin.bg
    })

    setTimeout(() => {
      setJustPickedItem(null)
    }, 1500)

    const order = multiActiveOrders.find(o => o.id === orderId)
    if (order) {
      const isOrderComplete = order.items.every(itm => (orderPicked[itm.id] || 0) === itm.quantity)
      if (isOrderComplete) {
        toast.success(`🎉 ${bin.name} fully picked! Ready to Pack.`, { duration: 3000 })
      }
    }
  }

  const handleMultiPickAll = (productId: string) => {
    const itemEntry = consolidatedItems.find(item => item.productId === productId)
    if (!itemEntry) return

    const updatedMultiPicked = { ...multiPickedItemIds }
    let lastBinName = ''
    let lastBinBg = ''

    itemEntry.placements.forEach(p => {
      if (p.quantityPicked < p.quantityNeeded) {
        if (!updatedMultiPicked[p.orderId]) {
          updatedMultiPicked[p.orderId] = {}
        }
        updatedMultiPicked[p.orderId][p.itemId] = p.quantityNeeded
        lastBinName = p.binInfo.name
        lastBinBg = p.binInfo.bg
      }
    })

    setMultiPickedItemIds(updatedMultiPicked)
    playBeep()
    
    if (lastBinName) {
      setJustPickedItem({
        name: itemEntry.name,
        binName: lastBinName,
        binColorClass: lastBinBg
      })
      setTimeout(() => setJustPickedItem(null), 1500)
    }
  }

  const handlePackMultiOrder = async (orderId: string) => {
    setUpdatingId(orderId)
    const toastId = toast.loading('📦 Packing order...')
    try {
      const res = await fetch(`/api/orders/${orderId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'PACKED' }),
      })

      if (res.ok) {
        toast.dismiss(toastId)
        toast.success(`📦 Order packed and assigned to Rider queue!`, { duration: 3000 })
        
        setMultiActiveOrders(prev => prev.filter(o => o.id !== orderId))
        
        const updatedPicked = { ...multiPickedItemIds }
        delete updatedPicked[orderId]
        setMultiPickedItemIds(updatedPicked)

        setPickedToday(prev => prev + 1)

        if (multiActiveOrders.length <= 1) {
          setIsMultiPickingMode(false)
        }
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

  // Auto-scan simulator loop effect
  useEffect(() => {
    if (!isCameraScanning) return

    const timer = setTimeout(() => {
      if (isMultiPickingMode) {
        const remainingItem = consolidatedItems.find(item => item.totalPicked < item.totalNeeded)
        if (remainingItem) {
          handleMultiPickOne(remainingItem.productId)
          toast.success(`📸 Barcode Scanned: ${remainingItem.name}`, { duration: 1500 })
        } else {
          toast.info('All items picked! Closing scanner.')
          stopCamera()
        }
      } else if (activeOrder) {
        const remainingItem = activeOrder.items.find(item => (pickedItemIds[item.id] || 0) < item.quantity)
        if (remainingItem) {
          handleManualPickOne(remainingItem.id, remainingItem.quantity)
          toast.success(`📸 Barcode Scanned: ${remainingItem.name}`, { duration: 1500 })
        } else {
          toast.info('All items picked! Closing scanner.')
          stopCamera()
        }
      }
    }, 2500)

    return () => clearTimeout(timer)
  }, [isCameraScanning, isMultiPickingMode, consolidatedItems, activeOrder, pickedItemIds])

  // Computed stats
  const totalItemsToPick = orders.reduce((acc, o) => acc + o.items.reduce((s, i) => s + i.quantity, 0), 0)

  if (status === 'loading' || (isLoading && !activeOrder && !isMultiPickingMode)) {
    return (
      <div className="flex min-h-[70vh] items-center justify-center bg-gradient-to-br from-blue-50 via-white to-indigo-50">
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="text-center space-y-3"
        >
          <div className="relative mx-auto w-14 h-14">
            <div className="absolute inset-0 rounded-full bg-gradient-to-tr from-blue-500 to-indigo-500 opacity-20 animate-ping" />
            <div className="relative flex items-center justify-center w-14 h-14 rounded-full bg-gradient-to-tr from-blue-600 to-indigo-600">
              <Loader2 className="h-6 w-6 animate-spin text-white" />
            </div>
          </div>
          <p className="text-xs font-bold text-gray-500">Loading Picking Queue...</p>
        </motion.div>
      </div>
    )
  }

  // active picking overlay panels
  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 via-white to-blue-50/30">
      
      {/* Dynamic Camera Scanner Panel Overlay */}
      <AnimatePresence>
        {isCameraScanning && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-[100] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4"
          >
            <motion.div
              initial={{ scale: 0.95, y: 20 }}
              animate={{ scale: 1, y: 0 }}
              exit={{ scale: 0.95, y: 20 }}
              className="bg-zinc-900 border border-zinc-800 text-white rounded-3xl p-5 w-full max-w-sm flex flex-col items-center space-y-4"
            >
              <div className="text-center w-full flex justify-between items-center pb-2 border-b border-zinc-800">
                <span className="text-xs font-extrabold tracking-wider text-blue-400 flex items-center gap-1.5">
                  <Camera className="h-4 w-4" /> BARCODE SCANNER
                </span>
                <button
                  onClick={stopCamera}
                  className="text-xs text-zinc-400 hover:text-white font-bold cursor-pointer"
                >
                  Close
                </button>
              </div>

              {/* Camera view screen */}
              <div className="relative w-full h-[240px] rounded-2xl overflow-hidden bg-black border border-zinc-800 flex items-center justify-center">
                <video
                  ref={videoRef}
                  autoPlay
                  playsInline
                  className="w-full h-full object-cover"
                />
                
                {/* Scanner targeting laser line */}
                <div className="absolute left-4 right-4 h-0.5 bg-red-500 shadow-[0_0_8px_rgba(239,68,68,0.8)] animate-pulse" style={{ top: '50%' }} />
                
                {/* Simulated frame */}
                <div className="absolute inset-8 border border-white/20 rounded-xl pointer-events-none flex items-center justify-center">
                  <span className="text-[10px] text-white/50 font-bold bg-black/40 px-2 py-0.5 rounded">Center Barcode</span>
                </div>
              </div>

              <div className="text-center w-full">
                <p className="text-[11px] font-bold text-zinc-400 animate-pulse">
                  Hold barcode up to camera...
                </p>
                <p className="text-[9px] text-zinc-500/80 mt-1 font-semibold">
                  (Automatically scanning remaining items every 2.5 seconds)
                </p>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Bin Assignment Overlay Alert */}
      <AnimatePresence>
        {justPickedItem && (
          <motion.div
            initial={{ opacity: 0, scale: 0.9, y: 30 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.9, y: -20 }}
            className="fixed top-12 left-4 right-4 z-[110] max-w-sm mx-auto shadow-2xl"
          >
            <div className={`rounded-2xl border p-4 backdrop-blur flex items-center gap-3.5 ${justPickedItem.binColorClass} border-current/25 shadow-lg`}>
              <div className="h-10 w-10 rounded-xl bg-white flex items-center justify-center text-lg shadow-sm shrink-0">
                📥
              </div>
              <div className="min-w-0">
                <span className="text-[9px] font-black uppercase tracking-wider opacity-60 block">Put item in bin:</span>
                <span className="text-lg font-black block leading-tight">{justPickedItem.binName}</span>
                <span className="text-[11px] font-bold block truncate mt-0.5 opacity-90">{justPickedItem.name}</span>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ─── SCENARIO A: MULTI-PICKING CONSOLE ─── */}
      {isMultiPickingMode ? (
        <div className="container mx-auto px-3 sm:px-4 py-4 sm:py-6 max-w-lg space-y-4 sm:space-y-5 pb-32">
          
          {/* Header */}
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            className="relative overflow-hidden rounded-2xl bg-slate-900 p-4 sm:p-5 text-white shadow-lg border border-slate-800"
          >
            <div className="flex justify-between items-center">
              <div className="flex items-center gap-2">
                <Layers className="h-5 w-5 text-blue-500" />
                <h1 className="text-sm sm:text-base font-black tracking-tight">Multi-Pick Console</h1>
              </div>
              <button
                onClick={() => {
                  if (confirm('Cancel multi-picking console? In-progress order states will be preserved.')) {
                    setIsMultiPickingMode(false)
                    setMultiActiveOrders([])
                  }
                }}
                className="text-[10px] font-extrabold text-red-400 hover:text-red-300 transition-colors cursor-pointer min-h-[44px] px-2"
              >
                Exit Console
              </button>
            </div>
            
            {/* Active Bins List */}
            <div className="mt-3.5 grid grid-cols-3 gap-2">
              {multiActiveOrders.map((ord, i) => {
                const bin = binColors[ord.id] || BIN_CONFIGS[0]
                const itemsCount = ord.items.reduce((s, itm) => s + itm.quantity, 0)
                const itemsPicked = ord.items.reduce((s, itm) => {
                  const oMap = multiPickedItemIds[ord.id] || {}
                  return s + (oMap[itm.id] || 0)
                }, 0)

                return (
                  <div key={ord.id} className={`rounded-xl border p-2 flex flex-col justify-between ${bin.bg}`}>
                    <div>
                      <span className="text-[9px] font-black uppercase tracking-wider block">{bin.name}</span>
                      <span className="text-[8px] font-bold block opacity-60 truncate mt-0.5">{ord.user.name}</span>
                    </div>
                    <div className="mt-2 flex items-baseline gap-0.5">
                      <span className="text-sm font-black">{itemsPicked}</span>
                      <span className="text-[9px] font-bold opacity-60">/{itemsCount}</span>
                    </div>
                  </div>
                )
              })}
            </div>
          </motion.div>

          {/* Camera Scan Simulation trigger */}
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className="bg-white border border-gray-200/80 p-4 rounded-2xl shadow-sm flex items-center justify-between"
          >
            <div className="space-y-0.5">
              <h3 className="text-xs font-black text-gray-700 flex items-center gap-1.5 uppercase tracking-wider">
                <Barcode className="h-4 w-4 text-blue-500" /> Camera Scanner
              </h3>
              <p className="text-[9px] text-gray-400 font-semibold leading-relaxed">
                Scan barcodes using your mobile camera to verify bins.
              </p>
            </div>
            <button
              onClick={startCamera}
              className="bg-gradient-to-r from-blue-600 to-indigo-600 text-white text-xs font-black px-4 py-2.5 rounded-xl flex items-center gap-1.5 cursor-pointer shadow-md shadow-blue-500/15 active:scale-95 transition-all"
            >
              <Camera className="h-3.5 w-3.5" /> Open Camera
            </button>
          </motion.div>

          {/* Consolidated Picking List grouped by Aisle */}
          <div className="space-y-4">
            <h2 className="text-xs font-black text-gray-400 uppercase tracking-wider px-1">
              Consolidated Picking Checklist
            </h2>

            {/* Render grouped by aisle */}
            {(() => {
              const aisles: Record<number, typeof consolidatedItems> = {}
              consolidatedItems.forEach(item => {
                const aisleNo = getAisleNumber(item.categorySlug)
                if (!aisles[aisleNo]) aisles[aisleNo] = []
                aisles[aisleNo].push(item)
              })

              return Object.keys(aisles).sort().map(aisleStr => {
                const aisleNo = parseInt(aisleStr, 10)
                const itemsList = aisles[aisleNo]
                const description = getAisleName(aisleNo)

                return (
                  <div key={aisleNo} className="space-y-2.5">
                    <div className="flex items-center gap-2 px-1">
                      <span className="text-xs font-black text-blue-600 bg-blue-50 px-2.5 py-1 rounded-lg">Aisle {aisleNo}</span>
                      <span className="text-[10px] text-gray-500 font-bold">{description}</span>
                    </div>

                    <div className="space-y-2">
                      {itemsList.map(item => {
                        const allCompleted = item.totalPicked === item.totalNeeded
                        return (
                          <div
                            key={item.productId}
                            className={`bg-white border border-gray-200/80 p-3 sm:p-4 rounded-xl shadow-sm relative overflow-hidden ${
                              allCompleted ? 'opacity-50' : ''
                            }`}
                          >
                            <div className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-blue-500 to-indigo-500 rounded-l-xl" />

                            <div className="flex items-center justify-between gap-3 pl-2">
                              <div className="flex items-center gap-3 min-w-0">
                                <div className="h-10 w-10 bg-gray-50 rounded-lg flex-shrink-0 flex items-center justify-center overflow-hidden border border-gray-100">
                                  <ProductImage
                                    src={item.imageUrl}
                                    alt={item.name}
                                    className="h-full w-full object-contain"
                                  />
                                </div>
                                <div className="min-w-0">
                                  <div className="flex items-center gap-2 flex-wrap">
                                    <h4 className="text-xs sm:text-sm font-extrabold text-gray-800 truncate leading-tight">{item.name}</h4>
                                    {item.location && (
                                      <span className="px-1.5 py-0.5 bg-amber-50 text-amber-600 border border-amber-200 rounded text-[9px] font-black uppercase shadow-sm">
                                        📍 {item.location}
                                      </span>
                                    )}
                                  </div>

                                  
                                  {/* Bin Placement list */}
                                  <div className="flex flex-wrap gap-1.5 mt-1.5">
                                    {item.placements.map((p, i) => (
                                      <span key={i} className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[8px] font-black uppercase ${p.binInfo.bg}`}>
                                        <span className={`h-1.5 w-1.5 rounded-full ${p.binInfo.fill}`} />
                                        {p.binInfo.name}: {p.quantityPicked}/{p.quantityNeeded}
                                      </span>
                                    ))}
                                  </div>
                                </div>
                              </div>

                              {/* Pick actions */}
                              {!allCompleted && (
                                <div className="flex gap-1.5 shrink-0">
                                  <button
                                    onClick={() => handleMultiPickOne(item.productId)}
                                    className="bg-gray-100 hover:bg-gray-200 text-gray-600 text-[10px] sm:text-xs font-bold min-h-[38px] px-2.5 flex items-center justify-center rounded-xl border border-gray-200 cursor-pointer transition-colors"
                                  >
                                    +1
                                  </button>
                                  <button
                                    onClick={() => handleMultiPickAll(item.productId)}
                                    className="bg-blue-50 text-blue-600 hover:bg-blue-100 text-[10px] sm:text-xs font-black min-h-[38px] px-2.5 rounded-xl border border-blue-200/60 cursor-pointer transition-colors flex items-center gap-1"
                                  >
                                    <Check className="h-3 w-3 stroke-[3]" />
                                    <span>All</span>
                                  </button>
                                </div>
                              )}
                            </div>
                          </div>
                        )
                      })}
                    </div>
                  </div>
                )
              })
            })()}
          </div>

          {/* Packing Actions Sticky Footer */}
          <div className="fixed bottom-0 left-0 right-0 z-50 bg-white/80 dark:bg-zinc-950/80 backdrop-blur-md border-t border-border p-4 shadow-lg flex flex-col gap-2">
            {multiActiveOrders.map(order => {
              const bin = binColors[order.id] || BIN_CONFIGS[0]
              const orderPicked = multiPickedItemIds[order.id] || {}
              const isOrderComplete = order.items.every(itm => (orderPicked[itm.id] || 0) === itm.quantity)

              return (
                <button
                  key={order.id}
                  onClick={() => handlePackMultiOrder(order.id)}
                  disabled={!isOrderComplete || updatingId === order.id}
                  className={`h-11 w-full rounded-xl font-black text-xs flex items-center justify-center gap-2 cursor-pointer transition-all border ${
                    isOrderComplete 
                      ? 'bg-slate-900 text-white border-slate-800 hover:bg-slate-800 shadow-md active:scale-98' 
                      : 'bg-gray-50 text-gray-300 border-gray-100 cursor-not-allowed opacity-60'
                  }`}
                >
                  <Package className="h-4 w-4" />
                  <span>Pack {bin.name} ({order.user.name})</span>
                  {isOrderComplete ? (
                    <span className="text-[10px] bg-green-500 text-white px-2 py-0.5 rounded-full font-black uppercase ml-1 animate-pulse">READY</span>
                  ) : (
                    <span className="text-[10px] font-bold text-gray-400 ml-1">IN-PROGRESS</span>
                  )}
                </button>
              )
            })}
          </div>

        </div>
      ) : activeOrder ? (
        /* ─── SCENARIO B: SINGLE ORDER ACTIVE PICKING SCREEN ─── */
        <div className="container mx-auto px-3 sm:px-4 py-4 sm:py-6 max-w-lg space-y-4 sm:space-y-5 pb-24">

          {/* Back and Header */}
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-blue-600 to-indigo-600 p-4 sm:p-5 text-white shadow-lg shadow-blue-500/20"
          >
            <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZyBmaWxsPSJub25lIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiPjxnIGZpbGw9IiNmZmZmZmYiIGZpbGwtb3BhY2l0eT0iMC4wNCI+PHBhdGggZD0iTTM2IDM0djZoNnYtNmgtNnptMC0xMHY2aDZ2LTZoLTZ6bTEwIDEwdjZoNnYtNmgtNnptLTIwIDB2Nmg2di02aC02em0xMC0xMHY2aDZ2LTZoLTZ6bS0xMCAwdjZoNnYtNmgtNnoiLz48L2c+PC9nPjwvc3ZnPg==')] opacity-50" />
            <div className="relative flex justify-between items-center">
              <div className="flex items-center gap-3">
                <button
                  onClick={() => {
                    setActiveOrder(null)
                    setPickedItemIds({})
                  }}
                  className="flex items-center gap-1 text-xs font-bold text-white/90 hover:text-white transition-colors min-h-[44px] min-w-[44px] cursor-pointer"
                >
                  <ArrowLeft className="h-4 w-4" />
                  <span className="hidden sm:inline">Back to Queue</span>
                </button>
              </div>
              <span className="text-[10px] font-bold text-white/70 font-mono uppercase tracking-wider">
                #{activeOrder.readableId || activeOrder.id.slice(0, 8)}
              </span>
            </div>
            <div className="relative mt-3 flex flex-col gap-1.5">
              <div className="flex items-center gap-3">
                <User className="h-4 w-4 text-white/70" />
                <span className="text-sm font-bold">{activeOrder.user.name}</span>
              </div>
              {(activeOrder.user.phone || activeOrder.address?.phone) && (
                <div className="flex items-center gap-3 text-xs text-white/80 pl-7">
                  <Smartphone className="h-3.5 w-3.5" />
                  <a href={`tel:${activeOrder.address?.phone || activeOrder.user.phone}`} className="hover:underline font-mono">
                    {activeOrder.address?.phone || activeOrder.user.phone}
                  </a>
                </div>
              )}
            </div>
          </motion.div>

          {/* Circular Progress */}
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: 0.1 }}
            className="flex flex-col items-center py-2"
          >
            <CircularProgress picked={Object.values(pickedItemIds).reduce((s, v) => s + v, 0)} total={activeOrder.items.reduce((s, i) => s + i.quantity, 0)} />
            <p className="mt-2 text-[10px] font-bold text-gray-400 uppercase tracking-wider">
              {activeOrder.items.every(item => pickedItemIds[item.id] === item.quantity) ? '✅ All items picked!' : `${activeOrder.items.filter(item => (pickedItemIds[item.id] || 0) < item.quantity).length} item(s) remaining`}
            </p>
          </motion.div>

          {/* Companion Cafe Order Info */}
          <AnimatePresence>
            {activeOrder.companionOrder && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                className="bg-gradient-to-r from-rose-50 to-orange-50 border border-orange-200/60 p-4 rounded-2xl shadow-sm space-y-2.5"
              >
                <div className="flex items-center justify-between">
                  <span className="text-xs font-black text-rose-600 flex items-center gap-1">
                    <span>☕</span> Companion Cafe Order
                  </span>
                  <span className={`text-[10px] font-black px-2 py-0.5 rounded uppercase ${
                    activeOrder.companionOrder.status === 'PACKED' || activeOrder.companionOrder.status === 'SHIPPED' || activeOrder.companionOrder.status === 'DELIVERED'
                      ? 'bg-green-100 text-green-700'
                      : 'bg-orange-100 text-orange-700'
                  }`}>
                    <span className="inline-flex items-center gap-1">
                      {!(activeOrder.companionOrder.status === 'PACKED' || activeOrder.companionOrder.status === 'SHIPPED' || activeOrder.companionOrder.status === 'DELIVERED') && (
                        <span className="relative flex h-1.5 w-1.5">
                          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-orange-400 opacity-75" />
                          <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-orange-500" />
                        </span>
                      )}
                      {activeOrder.companionOrder.status === 'CONFIRMED' ? 'PREPARING' : activeOrder.companionOrder.status}
                    </span>
                  </span>
                </div>
                <p className="text-[10px] text-gray-500 leading-normal font-semibold">
                  Placed in the same checkout. Kitchen is preparing these items:
                </p>
                <div className="bg-white/80 border border-orange-100/50 rounded-xl p-2.5 divide-y divide-orange-100/30">
                  {activeOrder.companionOrder.items.map((item) => (
                    <div key={item.id} className="flex justify-between items-center text-[10px] font-bold py-1 first:pt-0 last:pb-0 text-gray-700">
                      <span>{item.name}</span>
                      <span className="bg-orange-50 px-1.5 py-0.5 rounded text-rose-600">Qty: {item.quantity}</span>
                    </div>
                  ))}
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Scan Barcode Form */}
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.15 }}
            className="bg-white border border-gray-200/80 p-4 sm:p-5 rounded-2xl shadow-sm space-y-3"
          >
            <div className="flex justify-between items-center">
              <label className="text-[10px] font-extrabold uppercase tracking-wider text-gray-400 flex items-center gap-1.5">
                <Barcode className="h-4 w-4 text-blue-500" />
                Product Scan Simulator
              </label>
              <button
                onClick={startCamera}
                className="text-xs font-black text-blue-600 hover:text-blue-700 flex items-center gap-1 transition-colors cursor-pointer"
              >
                <Camera className="h-3.5 w-3.5" /> Use Camera Scanner
              </button>
            </div>
            
            <form onSubmit={handleScanSubmit} className="flex gap-2">
              <div className="relative flex-1 group">
                <input
                  ref={scanInputRef}
                  type="text"
                  placeholder="Scan barcode or type product name…"
                  value={scanInput}
                  onChange={(e) => setScanInput(e.target.value)}
                  className="w-full bg-gray-50 border-2 border-gray-200 px-3 sm:px-4 py-2.5 sm:py-3 rounded-xl text-xs sm:text-sm focus:outline-none focus:border-blue-500 focus:bg-white font-semibold transition-all placeholder:text-gray-300"
                />
              </div>
              <button
                type="submit"
                className="bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white text-xs font-bold px-4 sm:px-5 py-2.5 sm:py-3 rounded-xl transition-all flex items-center gap-1.5 cursor-pointer min-h-[44px] shadow-md shadow-blue-500/20 active:scale-95"
              >
                <Search className="h-4 w-4" />
                <span className="hidden sm:inline">Scan</span>
              </button>
            </form>
            <p className="text-[9px] text-gray-400 font-semibold leading-relaxed">
              💡 Type product name keywords (like &quot;Banana&quot;, &quot;Milk&quot;, or &quot;Dal&quot;) and press Enter to scan.
            </p>
          </motion.div>

          {/* Remaining to Pick Checklist */}
          <div className="space-y-3">
            <h3 className="text-xs font-black text-gray-700 uppercase tracking-wider flex items-center gap-1.5">
              <CircleDot className="h-3.5 w-3.5 text-blue-500" />
              Remaining Items ({activeOrder.items.filter(item => (pickedItemIds[item.id] || 0) < item.quantity).length})
            </h3>
            
            <AnimatePresence mode="popLayout">
              {activeOrder.items.filter(item => (pickedItemIds[item.id] || 0) < item.quantity).length === 0 ? (
                <motion.div
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  className="bg-gradient-to-br from-green-50 to-emerald-50 border border-green-200/60 text-green-700 text-xs font-bold p-6 rounded-2xl text-center space-y-2"
                >
                  <motion.div
                    animate={{ scale: [1, 1.15, 1] }}
                    transition={{ repeat: Infinity, duration: 2, ease: 'easeInOut' }}
                  >
                    <CheckCircle className="h-8 w-8 text-green-500 mx-auto" />
                  </motion.div>
                  <p>All items checked off successfully! Ready to Pack.</p>
                </motion.div>
              ) : (
                [...activeOrder.items].sort((a, b) => {
                        const locA = a.product?.location
                        const locB = b.product?.location
                        if (locA && locB) return locA.localeCompare(locB)
                        if (locA) return -1
                        if (locB) return 1
                        const slugA = a.product?.category?.slug || ''
                        const slugB = b.product?.category?.slug || ''
                        return getAisleNumber(slugA) - getAisleNumber(slugB)
                      }).filter(item => (pickedItemIds[item.id] || 0) < item.quantity)
                  .map((item, idx) => {
                    const picked = pickedItemIds[item.id] || 0
                    const progress = (picked / item.quantity) * 100
                    return (
                      <motion.div
                        key={item.id}
                        layoutId={item.id}
                        initial={{ opacity: 0, x: -20 }}
                        animate={{ opacity: 1, x: 0 }}
                        exit={{ opacity: 0, x: -30, scale: 0.95 }}
                        transition={{ type: 'spring', damping: 20, stiffness: 200, delay: idx * 0.04 }}
                        className="relative overflow-hidden bg-white border border-gray-200/80 p-3 sm:p-4 rounded-xl shadow-sm hover:shadow-md transition-shadow"
                      >
                        <div className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-blue-500 to-indigo-500 rounded-l-xl" />

                        <div className="flex items-center justify-between gap-3 pl-2">
                          <div className="flex items-center gap-3 min-w-0">
                            <div className="h-10 w-10 sm:h-11 sm:w-11 bg-gray-50 rounded-lg flex-shrink-0 flex items-center justify-center overflow-hidden border border-gray-100">
                              <ProductImage
                                src={item.imageUrl}
                                alt={item.name}
                                className="h-full w-full object-contain"
                              />
                            </div>
                            <div className="min-w-0">
                              <div className="flex items-center gap-2 flex-wrap">
                                <h4 className="text-xs sm:text-sm font-extrabold text-gray-800 truncate">{item.name}</h4>
                                {item.product?.location && (
                                  <span className="px-1.5 py-0.5 bg-amber-50 text-amber-600 border border-amber-200 rounded text-[9px] font-black uppercase shadow-sm">
                                    📍 {item.product.location}
                                  </span>
                                )}
                              </div>

                              <div className="flex items-center gap-2 mt-1">
                                <span className="text-[10px] text-gray-400 font-bold">
                                  {picked}/{item.quantity}
                                </span>
                                <div className="w-16 h-1.5 bg-gray-100 rounded-full overflow-hidden">
                                  <motion.div
                                    className="h-full bg-gradient-to-r from-blue-500 to-indigo-500 rounded-full"
                                    initial={{ width: 0 }}
                                    animate={{ width: `${progress}%` }}
                                    transition={{ duration: 0.3 }}
                                  />
                                </div>
                              </div>
                            </div>
                          </div>

                          <div className="flex gap-1.5 shrink-0">
                            <motion.button
                              whileTap={{ scale: 0.85 }}
                              onClick={() => handleManualPickOne(item.id, item.quantity)}
                              className="bg-gray-100 hover:bg-gray-200 text-gray-600 text-[10px] sm:text-xs font-bold min-h-[44px] min-w-[44px] flex items-center justify-center rounded-xl border border-gray-200 cursor-pointer transition-colors"
                            >
                              +1
                            </motion.button>
                            <motion.button
                              whileTap={{ scale: 0.85 }}
                              onClick={() => handleManualPickAll(item.id, item.quantity)}
                              className="bg-blue-50 text-blue-600 hover:bg-blue-100 text-[10px] sm:text-xs font-black min-h-[44px] px-3 rounded-xl border border-blue-200/60 cursor-pointer transition-colors flex items-center gap-1"
                            >
                              <Check className="h-3.5 w-3.5 stroke-[3]" />
                              <span className="hidden sm:inline">All</span>
                            </motion.button>
                          </div>
                        </div>
                      </motion.div>
                    )
                  })
              )}
            </AnimatePresence>
          </div>

          {/* Picked Checklist */}
          <AnimatePresence>
            {activeOrder.items.filter(item => (pickedItemIds[item.id] || 0) === item.quantity).length > 0 && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                className="space-y-3 pt-2"
              >
                <h3 className="text-xs font-black text-gray-400 uppercase tracking-wider flex items-center gap-1.5">
                  <CheckCircle className="h-3.5 w-3.5 text-green-500" />
                  Picked / Scanned ({activeOrder.items.filter(item => (pickedItemIds[item.id] || 0) === item.quantity).length})
                </h3>
                
                <div className="space-y-2">
                  {activeOrder.items
                    .filter(item => (pickedItemIds[item.id] || 0) === item.quantity)
                    .map((item, idx) => (
                      <motion.div
                        key={item.id}
                        initial={{ opacity: 0, x: 20 }}
                        animate={{ opacity: 0.7, x: 0 }}
                        transition={{ delay: idx * 0.05 }}
                        className="relative overflow-hidden bg-green-50/50 border border-green-200/40 p-3 rounded-xl"
                      >
                        <div className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-green-400 to-emerald-500 rounded-l-xl" />
                        <div className="flex items-center justify-between gap-3 pl-2">
                          <div className="flex items-center gap-3 min-w-0">
                            <div className="h-8 w-8 bg-green-100 rounded-lg flex-shrink-0 flex items-center justify-center text-green-600">
                              <Check className="h-4 w-4 stroke-[3]" />
                            </div>
                            <div className="min-w-0 line-through text-gray-400">
                              <h4 className="text-[11px] font-bold truncate">{item.name}</h4>
                              <span className="text-[9px] font-medium block mt-0.5">
                                {item.quantity}/{item.quantity} picked
                              </span>
                            </div>
                          </div>

                          <button
                            onClick={() => handleResetItem(item.id)}
                            className="flex items-center gap-1 text-[9px] font-bold text-red-400 hover:text-red-500 cursor-pointer min-h-[44px] min-w-[44px] justify-center transition-colors"
                          >
                            <RotateCcw className="h-3 w-3" />
                            Reset
                          </button>
                        </div>
                      </motion.div>
                    ))}
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Packing submit button */}
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
            className="pt-4 border-t border-gray-200/60"
          >
            <motion.button
              whileTap={activeOrder.items.every(item => pickedItemIds[item.id] === item.quantity) ? { scale: 0.97 } : {}}
              onClick={handlePackOrder}
              disabled={!activeOrder.items.every(item => pickedItemIds[item.id] === item.quantity) || updatingId === activeOrder.id}
              className={`h-12 sm:h-14 w-full rounded-2xl font-black text-xs sm:text-sm transition-all flex items-center justify-center gap-2 cursor-pointer ${
                activeOrder.items.every(item => pickedItemIds[item.id] === item.quantity)
                  ? 'bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700 text-white shadow-lg shadow-green-500/30' 
                  : 'bg-gray-100 text-gray-400 border border-gray-200 cursor-not-allowed opacity-60'
              }`}
            >
              {updatingId === activeOrder.id ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Packing Order...
                </>
              ) : (
                <>
                  <Package className="h-4 w-4" />
                  Confirm &amp; Pack Order
                </>
              )}
            </motion.button>
          </motion.div>
        </div>
      ) : (
        /* ─── SCENARIO C: MAIN QUEUE LIST ─── */
        <div className="container mx-auto px-3 sm:px-4 py-4 sm:py-6 max-w-lg space-y-4 sm:space-y-5 pb-24">
        
          {/* Picker Header */}
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-blue-600 to-indigo-600 p-4 sm:p-5 text-white shadow-lg shadow-blue-500/20"
          >
            <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZyBmaWxsPSJub25lIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiPjxnIGZpbGw9IiNmZmZmZmYiIGZpbGwtb3BhY2l0eT0iMC4wNCI+PHBhdGggZD0iTTM2IDM0djZoNnYtNmgtNnptMC0xMHY2aDZ2LTZoLTZ6bTEwIDEwdjZoNnYtNmgtNnptLTIwIDB2Nmg2di02aC02em0xMC0xMHY2aDZ2LTZoLTZ6bS0xMCAwdjZoNnYtNmgtNnoiLz48L2c+PC9nPjwvc3ZnPg==')] opacity-50" />
            
            <div className="relative flex justify-between items-start">
              <div className="flex items-center gap-3">
                <div className="h-11 w-11 rounded-full bg-white/20 backdrop-blur-sm border border-white/30 flex items-center justify-center animate-pulse-gentle">
                  <Smartphone className="h-5 w-5 text-white" />
                </div>
                <div>
                  <h1 className="text-sm sm:text-base font-black tracking-tight">Picker Console</h1>
                  <p className="text-[10px] sm:text-xs text-white/70 mt-0.5 font-medium">
                    {session?.user?.name || 'Picker'}
                  </p>
                </div>
              </div>
              
              <div className="flex items-center gap-2">
                <div className="hidden sm:flex items-center gap-1 bg-white/10 backdrop-blur-sm rounded-lg px-2.5 py-1.5 border border-white/10">
                  <Clock className="h-3 w-3 text-white/70" />
                  <span className="text-[10px] font-mono font-bold text-white/90">
                    {currentTime.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </span>
                </div>
                <button
                  onClick={() => fetchOrders(true)}
                  disabled={isRefreshing}
                  className="h-10 w-10 sm:h-9 sm:w-9 flex items-center justify-center rounded-xl bg-white/15 backdrop-blur-sm border border-white/20 hover:bg-white/25 transition-all disabled:opacity-50 cursor-pointer"
                >
                  <RefreshCw className={`h-4 w-4 text-white ${isRefreshing ? 'animate-spin' : ''}`} />
                </button>
              </div>
            </div>

            <div className="relative mt-3 h-0.5 bg-white/10 rounded-full overflow-hidden">
              <motion.div
                className="absolute inset-y-0 left-0 bg-white/40 rounded-full"
                animate={{ width: `${refreshProgress}%` }}
                transition={{ duration: 0.5, ease: 'linear' }}
              />
            </div>
          </motion.div>

          {/* Stats Row */}
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
            className="grid grid-cols-3 gap-2 sm:gap-3"
          >
            <div className="relative overflow-hidden bg-white border border-gray-200/80 rounded-xl p-3 sm:p-3.5 shadow-sm">
              <ShoppingBag className="h-4 w-4 text-blue-500 mb-1.5" />
              <p className="text-lg sm:text-xl font-black">{orders.length}</p>
              <p className="text-[8px] sm:text-[9px] font-bold text-gray-400 uppercase tracking-wider mt-0.5">In Queue</p>
            </div>

            <div className="relative overflow-hidden bg-white border border-gray-200/80 rounded-xl p-3 sm:p-3.5 shadow-sm">
              <ListChecks className="h-4 w-4 text-indigo-500 mb-1.5" />
              <p className="text-lg sm:text-xl font-black">{totalItemsToPick}</p>
              <p className="text-[8px] sm:text-[9px] font-bold text-gray-400 uppercase tracking-wider mt-0.5">Items</p>
            </div>

            <div className="relative overflow-hidden bg-white border border-gray-200/80 rounded-xl p-3 sm:p-3.5 shadow-sm">
              <TrendingUp className="h-4 w-4 text-green-500 mb-1.5" />
              <p className="text-lg sm:text-xl font-black">{pickedToday}</p>
              <p className="text-[8px] sm:text-[9px] font-bold text-gray-400 uppercase tracking-wider mt-0.5">Packed</p>
            </div>
          </motion.div>

          {/* Orders Queue Section */}
          <div className="space-y-3">
            <h2 className="text-xs font-black text-gray-700 uppercase tracking-wider flex items-center gap-1.5 px-1">
              <ShoppingBag className="h-4 w-4 text-blue-500" />
              Orders to Pick
            </h2>

            <AnimatePresence mode="popLayout">
              {orders.length === 0 ? (
                <motion.div
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0 }}
                  className="bg-white border-2 border-dashed border-gray-200 p-8 sm:p-10 rounded-2xl text-center"
                >
                  <Sparkles className="h-8 w-8 text-gray-300 mx-auto mb-3" />
                  <p className="text-xs font-bold text-gray-400">All caught up! No orders pending.</p>
                </motion.div>
              ) : (
                orders.map((order, idx) => {
                  const isClaimedByOther = !!(order.status === 'CONFIRMED' && order.assignedPickerId && order.assignedPickerId !== session?.user?.id)
                  return (
                    <motion.div
                      key={order.id}
                      initial={{ opacity: 0, y: 20 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, x: -50, scale: 0.95 }}
                      className="relative overflow-hidden bg-white border border-gray-200/80 rounded-2xl shadow-sm hover:shadow-md transition-shadow"
                    >
                      <div className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-blue-500 to-indigo-600" />

                      <div className="p-4 sm:p-5 space-y-3 pl-5">
                        <div className="flex justify-between items-start">
                          <div className="flex items-center gap-2.5 min-w-0">
                            <input
                              type="checkbox"
                              checked={selectedOrderIds.includes(order.id)}
                              disabled={isClaimedByOther}
                              onChange={(e) => {
                                if (e.target.checked) {
                                  if (selectedOrderIds.length >= 3) {
                                    toast.error('Maximum of 3 orders can be picked together')
                                    return
                                  }
                                  setSelectedOrderIds([...selectedOrderIds, order.id])
                                } else {
                                  setSelectedOrderIds(selectedOrderIds.filter(id => id !== order.id))
                                }
                              }}
                              className="h-4.5 w-4.5 text-blue-600 border-gray-300 rounded focus:ring-blue-500 cursor-pointer shrink-0 disabled:opacity-40 disabled:cursor-not-allowed"
                            />
                            <div className="min-w-0">
                              <div className="flex items-center gap-1.5">
                                <User className="h-3.5 w-3.5 text-gray-400 shrink-0" />
                                <h3 className="text-sm font-extrabold text-gray-800 truncate">{order.user.name}</h3>
                              </div>
                              {(order.user.phone || order.address?.phone) && (
                                <div className="flex items-center gap-1.5 mt-0.5 text-xs text-gray-500">
                                  <Smartphone className="h-3.5 w-3.5 text-gray-400 shrink-0" />
                                  <a href={`tel:${order.address?.phone || order.user.phone}`} className="hover:underline font-mono font-bold">
                                    {order.address?.phone || order.user.phone}
                                  </a>
                                </div>
                              )}
                              <div className="flex items-center gap-2 mt-1">
                                <span className="text-[9px] font-mono font-bold text-gray-400">#{order.readableId || order.id.slice(0, 8)}</span>
                                {order.companionOrder && (
                                  <span className="bg-rose-100 text-rose-600 text-[8px] px-1.5 py-0.5 rounded-full font-black uppercase">
                                    ☕ cafe
                                  </span>
                                )}
                              </div>
                            </div>
                          </div>

                          <div className="flex flex-col items-end gap-1">
                            {isClaimedByOther ? (
                              <span className="bg-rose-50 text-rose-600 border border-rose-200 text-[9px] px-2 py-0.5 rounded-full font-black uppercase">
                                👤 Claimed by {order.assignedPicker?.name || 'Another Picker'}
                              </span>
                            ) : order.status === 'CONFIRMED' ? (
                              <span className="bg-amber-50 text-amber-600 border border-amber-200 text-[9px] px-2 py-0.5 rounded-full font-black uppercase">
                                👤 Claimed by Me
                              </span>
                            ) : (
                              <span className="bg-blue-50 text-blue-600 border border-blue-200 text-[9px] px-2 py-0.5 rounded-full font-black uppercase">
                                Ready
                              </span>
                            )}
                            <span className={`text-[9px] flex items-center gap-0.5 ${getSlaClass(order.createdAt, order.status)}`}>
                              <Clock className="h-2.5 w-2.5" />
                              {timeAgo(order.createdAt)}
                            </span>
                          </div>
                        </div>

                        <div className="space-y-1.5">
                          <div className="bg-gray-50/80 rounded-xl border border-gray-100 overflow-hidden">
                            {order.items.map((item, i) => (
                              <div
                                key={item.id}
                                className={`flex justify-between items-center text-[11px] font-semibold text-gray-700 px-3 py-1.5 ${
                                  i % 2 === 1 ? 'bg-gray-100/50' : ''
                                } ${i !== order.items.length - 1 ? 'border-b border-gray-100/80' : ''}`}
                              >
                                <span className="truncate mr-2">{item.name}</span>
                                <span className="text-gray-400 font-bold shrink-0">×{item.quantity}</span>
                              </div>
                            ))}
                          </div>
                        </div>

                        <div className="flex justify-between items-center pt-2.5 border-t border-gray-100">
                          <div>
                            <span className="text-[9px] font-bold text-gray-400 block uppercase tracking-wider">Payment</span>
                            <span className="text-xs font-extrabold text-gray-700">
                              {order.paymentMethod === 'COD' ? 'COD (Cash)' : 'Prepaid ✓'}
                            </span>
                          </div>

                          <motion.button
                            whileTap={!isClaimedByOther ? { scale: 0.95 } : {}}
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
                                handleStartPicking(order)
                              }
                            }}
                            disabled={updatingId === order.id || isClaimedByOther}
                            className={`flex items-center gap-1.5 px-4 py-2.5 text-xs font-extrabold rounded-xl transition-all shadow-md min-h-[44px] cursor-pointer ${
                              isClaimedByOther
                                ? 'bg-slate-100 text-slate-400 border border-slate-200 cursor-not-allowed shadow-none'
                                : 'bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white shadow-blue-500/20'
                            }`}
                          >
                            <Zap className="h-3.5 w-3.5" />
                            <span>{isClaimedByOther ? 'Claimed' : order.status === 'CONFIRMED' ? 'Continue' : 'Start'}</span>
                            <ChevronRight className="h-3.5 w-3.5" />
                          </motion.button>
                        </div>
                      </div>
                    </motion.div>
                  )
                })
              )}
            </AnimatePresence>
          </div>

        </div>
      )}

      {/* Sticky Bottom Bar for Multi-picking trigger */}
      {selectedOrderIds.length > 0 && !activeOrder && !isMultiPickingMode && (
        <div className="fixed bottom-20 left-4 right-4 z-40 bg-slate-900 border border-slate-800 text-white rounded-2xl p-3 shadow-2xl flex items-center justify-between animate-slide-up">
          <div className="flex items-center gap-2 pl-2">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
            </span>
            <span className="text-xs font-bold">{selectedOrderIds.length} order{selectedOrderIds.length !== 1 ? 's' : ''} selected</span>
          </div>
          <button
            onClick={handleStartMultiPicking}
            className="bg-blue-600 hover:bg-blue-700 text-white text-xs font-black px-4 py-2.5 rounded-xl cursor-pointer transition-colors active:scale-95 shadow-md shadow-blue-500/10"
          >
            Start Multi-Picking
          </button>
        </div>
      )}

    </div>
  )
}
