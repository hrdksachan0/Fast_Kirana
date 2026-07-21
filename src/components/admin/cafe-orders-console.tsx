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
  RotateCcw,
  Volume2,
  VolumeX,
  Printer,
  Edit,
  AlertCircle,
  Trash2,
  Plus,
  Minus,
  X
} from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { ProductImage } from '@/components/product/product-image'
import { playNotificationChime, playSuccessChime, playKitchenAlarmChime } from '@/lib/audio'
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
  selectedVariant?: string | null
  notes?: string | null
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
  deliveryFee: number
  taxes: number
  miscFee: number
  discount: number
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
  shopName?: string | null
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
  if (mins >= 5) return 'text-rose-500 font-black animate-pulse'
  if (mins >= 2) return 'text-amber-500 font-black animate-pulse'
  return 'text-gray-400 font-semibold'
}

function getOrderCardSlaBorder(createdAt: string | Date, status: string): string {
  if (status !== 'PENDING') return 'border-border/55'
  const created = new Date(createdAt)
  const now = new Date()
  const diffMs = now.getTime() - created.getTime()
  const mins = Math.floor(diffMs / 60000)
  if (mins >= 5) return 'border-rose-500 dark:border-rose-500/80 shadow-[0_0_12px_rgba(244,63,94,0.2)] animate-pulse'
  if (mins >= 2) return 'border-amber-450 dark:border-amber-450/80 shadow-[0_0_8px_rgba(245,158,11,0.15)]'
  return 'border-border/55'
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

  const [soundEnabled, setSoundEnabled] = useState(true)
  const [audioContextBlocked, setAudioContextBlocked] = useState(false)
  const [prepModalOrder, setPrepModalOrder] = useState<Order | null>(null)
  const [selectedPrepTime, setSelectedPrepTime] = useState<number>(15)
  const [editingOrder, setEditingOrder] = useState<Order | null>(null)
  const [editItems, setEditItems] = useState<any[]>([])
  const [outOfStockIds, setOutOfStockIds] = useState<string[]>([])
  const [searchQuery, setSearchQuery] = useState('')
  const [searchResults, setSearchResults] = useState<any[]>([])
  const [allProducts, setAllProducts] = useState<any[]>([])
  const [isSavingEdit, setIsSavingEdit] = useState(false)
  const [taxRate, setTaxRate] = useState(0.05) // Default 5%
  const [deliveryFeeSetting, setDeliveryFeeSetting] = useState(25)
  const [miscFeeSetting, setMiscFeeSetting] = useState(5)
  const [freeDeliveryThreshold, setFreeDeliveryThreshold] = useState(200)

  // Load settings on mount
  useEffect(() => {
    fetch('/api/settings')
      .then(res => res.json())
      .then(data => {
        if (data) {
          if (data.tax_rate !== undefined) {
            setTaxRate(parseFloat(data.tax_rate) / 100)
          }
          if (data.delivery_fee !== undefined) {
            setDeliveryFeeSetting(parseFloat(data.delivery_fee))
          }
          if (data.misc_fee !== undefined) {
            setMiscFeeSetting(parseFloat(data.misc_fee))
          }
          if (data.cafe_free_delivery_threshold !== undefined) {
            setFreeDeliveryThreshold(parseFloat(data.cafe_free_delivery_threshold))
          }
        }
      })
      .catch(() => {})
  }, [])

  // Load sound preference from localStorage
  useEffect(() => {
    const stored = localStorage.getItem('kitchen_sound_enabled')
    if (stored !== null) {
      setSoundEnabled(stored === 'true')
    }
    
    // Check if AudioContext is blocked by browser autoplay policy
    import('@/lib/audio').then(({ isAudioContextSuspended }) => {
      if (isAudioContextSuspended()) {
        setAudioContextBlocked(true)
      }
    })
  }, [])

  const toggleSound = () => {
    const next = !soundEnabled
    setSoundEnabled(next)
    localStorage.setItem('kitchen_sound_enabled', String(next))
    if (next) {
      playKitchenAlarmChime()
    }
  }

  const handleUnblockAudio = async () => {
    const { tryUnlockAudioContext } = await import('@/lib/audio')
    const unlocked = await tryUnlockAudioContext()
    if (unlocked) {
      setAudioContextBlocked(false)
      toast.success('Sound alerts enabled! 🔔')
      playKitchenAlarmChime()
    }
  }

  const activeOrderRef = useRef<Order | null>(null)
  const updatingIdRef = useRef<string | null>(null)

  const soundEnabledRef = useRef(true)
  const audioContextBlockedRef = useRef(false)

  useEffect(() => {
    soundEnabledRef.current = soundEnabled
  }, [soundEnabled])

  useEffect(() => {
    audioContextBlockedRef.current = audioContextBlocked
  }, [audioContextBlocked])

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

  const printedOrderIdsRef = useRef<Set<string>>(new Set())
  const isFirstFetchRef = useRef<boolean>(true)
  const printKOTReceiptRef = useRef<((order: Order) => void) | null>(null)

  // Real-time clock
  useEffect(() => {
    const timer = setInterval(() => setCurrentTime(new Date()), 1000)
    return () => clearInterval(timer)
  }, [])

  const fetchOrders = useCallback(async (silent = false) => {
    if (!silent) setIsLoading(true)
    else setIsRefreshing(true)
    
    try {
      const res = await fetch(`/api/picker/orders?type=cafe&t=${Date.now()}`, { cache: 'no-store' })
      if (res.ok) {
        const data = await res.json()
        setOrders(data)

        // Auto-print KOT for new incoming CONFIRMED orders
        if (isFirstFetchRef.current) {
          // On initial load, mark all current CONFIRMED orders as "already printed"
          const existingConfirmedIds = data.filter((o: Order) => o.status === 'CONFIRMED').map((o: Order) => o.id)
          printedOrderIdsRef.current = new Set(existingConfirmedIds)
          isFirstFetchRef.current = false
        } else {
          data.forEach((order: Order) => {
            if (order.status === 'CONFIRMED' && !printedOrderIdsRef.current.has(order.id)) {
              printedOrderIdsRef.current.add(order.id)
              // Trigger automatic print
              printKOTReceiptRef.current?.(order)
            }
          })
        }
        
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
    let updateTimeout: NodeJS.Timeout | null = null
    
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
            // Debounce fetchOrders to avoid event storm when multiple concurrent orders arrive
            if (updateTimeout) clearTimeout(updateTimeout)
            updateTimeout = setTimeout(() => {
              fetchOrders(true)
            }, 1000)
            
            if (data.type === 'new-order' && data.shopName === 'FastKirana Cafe Kitchen') {
              if (soundEnabledRef.current && !audioContextBlockedRef.current) {
                playKitchenAlarmChime()
              }
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
      if (updateTimeout) {
        clearTimeout(updateTimeout)
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

    if (soundEnabled && !audioContextBlocked) {
      playKitchenAlarmChime()
    }
    triggerHaptic('success')
    toast.info('New pending Cafe order(s) in queue!', {
      id: 'new-cafe-order-alert',
      icon: '🛎️',
    })

    const intervalId = setInterval(() => {
      const currentPending = orders.filter(o => o.status === 'PENDING')
      if (currentPending.length > 0) {
        if (soundEnabledRef.current && !audioContextBlockedRef.current) {
          playKitchenAlarmChime()
        }
      } else {
        clearInterval(intervalId)
      }
    }, 3000)

    return () => clearInterval(intervalId)
  }, [orders, status, soundEnabled, audioContextBlocked])

  useEffect(() => {
    if (activeOrder && scanInputRef.current) {
      scanInputRef.current.focus()
    }
  }, [activeOrder])

  const handleStartPreparing = (order: Order) => {
    setPrepModalOrder(order)
    setSelectedPrepTime(15) // Default 15 minutes
  }

  const confirmStartPreparing = async () => {
    if (!prepModalOrder) return
    const order = prepModalOrder
    setPrepModalOrder(null)
    setUpdatingId(order.id)
    try {
      const res = await fetch(`/api/orders/${order.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'CONFIRMED', prepTime: selectedPrepTime }),
      })

      if (res.ok) {
        toast.success(`Started preparing cafe order! Timer set to ${selectedPrepTime} mins.`)
        setActiveOrder(order)
        const initialPicked: Record<string, number> = {}
        order.items.forEach(item => {
          initialPicked[item.id] = 0
        })
        setPickedItemIds(initialPicked)
        fetchOrders(true)
        // Automatically print KOT receipt on acceptance
        printKOTReceipt(order)
      } else {
        toast.error('Failed to accept cafe order')
      }
    } catch (err) {
      toast.error('Error accepting cafe order')
    } finally {
      setUpdatingId(null)
    }
  }

  const handleQuickAccept = async (order: Order) => {
    setUpdatingId(order.id)
    try {
      const res = await fetch(`/api/orders/${order.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'CONFIRMED', prepTime: 15 }),
      })

      if (res.ok) {
        toast.success(`Accepted cafe order! Timer set to 15 mins.`)
        setActiveOrder(order)
        const initialPicked: Record<string, number> = {}
        order.items.forEach(item => {
          initialPicked[item.id] = 0
        })
        setPickedItemIds(initialPicked)
        fetchOrders(true)
        printKOTReceipt(order)
      } else {
        toast.error('Failed to accept cafe order')
      }
    } catch (err) {
      toast.error('Error accepting cafe order')
    } finally {
      setUpdatingId(null)
    }
  }

  const handleQuickAcceptAndPack = async (order: Order) => {
    setUpdatingId(order.id)
    const toastId = toast.loading('☕ Quick accepting & packing cafe order...')
    try {
      // 1. Confirm order
      const confirmRes = await fetch(`/api/orders/${order.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'CONFIRMED', prepTime: 15 }),
      })
      if (!confirmRes.ok) throw new Error('Failed to confirm cafe order')

      // 2. Pack order
      const packRes = await fetch(`/api/orders/${order.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'PACKED' }),
      })
      if (!packRes.ok) throw new Error('Failed to pack cafe order')

      toast.dismiss(toastId)
      toast.success('☕ Order accepted, prepared, and packed in one click!', { duration: 4000 })
      setPreparedToday(prev => prev + 1)
      fetchOrders(true)
      printKOTReceipt(order)
    } catch (err: any) {
      toast.dismiss(toastId)
      toast.error(err.message || 'Error quick packing cafe order')
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

  // Edit Order Handlers & Effects
  const handleEditOrder = async (order: Order) => {
    setEditingOrder(order)
    setEditItems(order.items.map(item => ({
      productId: item.productId,
      name: item.name,
      price: item.price,
      quantity: item.quantity,
      selectedVariant: item.selectedVariant || null,
      notes: item.notes || null
    })))
    setOutOfStockIds([])
    setSearchQuery('')
    
    try {
      const res = await fetch(`/api/products?category=cafe,ice-cream,beverages&limit=100`)
      if (res.ok) {
        const data = await res.json()
        setAllProducts(data.products || [])
      }
    } catch (err) {
      console.error('Failed to fetch catalog products:', err)
    }
  }

  useEffect(() => {
    if (!searchQuery.trim()) {
      setSearchResults([])
      return
    }
    const query = searchQuery.toLowerCase()
    const filtered = allProducts.filter(p => p.name.toLowerCase().includes(query))
    setSearchResults(filtered)
  }, [searchQuery, allProducts])

  const updateItemQty = (productId: string, variant: string | null, delta: number) => {
    setEditItems(prev => {
      return prev.map(item => {
        if (item.productId === productId && item.selectedVariant === variant) {
          const newQty = Math.max(0, item.quantity + delta)
          return { ...item, quantity: newQty }
        }
        return item
      }).filter(item => item.quantity > 0)
    })
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
    toast.success('Variant updated!')
  }

  const markItemOutOfStock = (productId: string) => {
    if (!outOfStockIds.includes(productId)) {
      setOutOfStockIds(prev => [...prev, productId])
    }
    setEditItems(prev => prev.filter(item => item.productId !== productId))
    toast.info('Item marked out of stock (saved changes will update availability)')
  }

  const addCatalogItem = (product: any) => {
    const exists = editItems.find(item => item.productId === product.id)
    if (exists) {
      updateItemQty(product.id, null, 1)
    } else {
      setEditItems(prev => [...prev, {
        productId: product.id,
        name: product.name,
        price: product.price,
        quantity: 1,
        selectedVariant: null,
        notes: null
      }])
    }
    setSearchQuery('')
    toast.success(`Added ${product.name} to list!`)
  }

  const saveEditedOrder = async () => {
    if (!editingOrder) return
    setIsSavingEdit(true)
    try {
      const res = await fetch(`/api/orders/${editingOrder.id}/edit`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          updatedItems: editItems,
          outOfStockProductIds: outOfStockIds
        })
      })
      if (res.ok) {
        toast.success('Order updated successfully!')
        setEditingOrder(null)
        fetchOrders(true)
      } else {
        const data = await res.json()
        toast.error(data.error || 'Failed to edit order')
      }
    } catch (err) {
      toast.error('Error saving order updates')
    } finally {
      setIsSavingEdit(false)
    }
  }

  const handlePackOrder = async () => {
    if (!activeOrder) return
    autoPackOrder(activeOrder.id)
  }

  const printKOTReceipt = (order: Order) => {
    const printWindow = window.open('', '_blank', 'width=600,height=800')
    if (!printWindow) {
      toast.error('Failed to open print window. Please allow popups!')
      return
    }

    const dateStr = new Date(order.createdAt).toLocaleString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: true
    })

    const orderTypeLabel = 'CAFE'

    const itemsHtml = order.items.map(item => `
      <tr style="border-bottom: 1px dashed #ddd;">
        <td style="padding: 6px 0; font-weight: bold; font-size: 14px; vertical-align: top; width: 35px;">[${item.quantity}x]</td>
        <td style="padding: 6px 0; font-size: 13px;">
          <div style="font-weight: bold;">
            ${item.name}
            ${item.selectedVariant ? `<span style="font-size: 11px; color: #ff0000; margin-left: 5px;">(${item.selectedVariant})</span>` : ''}
          </div>
          ${item.notes ? `<div style="font-size: 11px; color: #555; font-style: italic; margin-top: 2px;">📝 Notes: ${item.notes}</div>` : ''}
        </td>
      </tr>
    `).join('')

    printWindow.document.write(`
      <html>
        <head>
          <title>KOT - ${order.readableId || order.id.slice(0, 8)}</title>
          <style>
            @page {
              size: auto;
              margin: 0mm;
            }
            body {
              font-family: 'Courier New', Courier, monospace;
              width: 80mm;
              margin: 0 auto;
              padding: 10px;
              color: #000;
              background: #fff;
            }
            .logo-container {
              text-align: center;
              margin-bottom: 2px;
            }
            .logo-text {
              font-size: 18px;
              font-weight: 900;
              letter-spacing: 1.5px;
              border: 2px solid #000;
              padding: 3px 6px;
              display: inline-block;
            }
            .tagline {
              font-size: 8px;
              font-weight: bold;
              margin-top: 3px;
              letter-spacing: 0.5px;
            }
            .shop-name {
              text-align: center;
              font-size: 11px;
              font-weight: 800;
              margin-top: 6px;
              text-transform: uppercase;
            }
            .subtitle {
              text-align: center;
              font-size: 11px;
              font-weight: bold;
              margin-top: 3px;
              margin-bottom: 10px;
              border-bottom: 2px dashed #000;
              padding-bottom: 6px;
            }
            .info-table {
              width: 100%;
              font-size: 12px;
              margin-bottom: 8px;
              border-bottom: 2px dashed #000;
              padding-bottom: 8px;
            }
            .items-table {
              width: 100%;
              border-collapse: collapse;
              margin-bottom: 10px;
            }
            .footer {
              text-align: center;
              font-size: 10px;
              margin-top: 15px;
              border-top: 2px dashed #000;
              padding-top: 8px;
              font-weight: bold;
            }
            @media print {
              body {
                width: 100%;
                padding: 5px;
              }
            }
          </style>
        </head>
        <body>
          <div style="font-size: 18px; font-weight: 950; text-align: center; text-transform: uppercase; letter-spacing: 1px; margin-top: 5px; margin-bottom: 2px;">FASTKIRANA</div>
          <div class="subtitle">ORDER TICKET (KOT)</div>
          
          <table class="info-table">
            <tr>
              <td style="font-weight: bold; width: 45%;">KOT ID:</td>
              <td style="text-align: right; font-weight: bold; font-size: 14px; width: 55%;">#${order.readableId || order.id.slice(0, 8).toUpperCase()}</td>
            </tr>
            <tr>
              <td style="width: 45%;">Date:</td>
              <td style="text-align: right; width: 55%;">${dateStr}</td>
            </tr>
            <tr>
              <td style="width: 45%;">Type:</td>
              <td style="text-align: right; font-weight: bold; width: 55%;">${order.deliveryMethod}</td>
            </tr>
            <tr>
              <td style="width: 45%;">Customer:</td>
              <td style="text-align: right; font-weight: bold; width: 55%;">${order.user.name}</td>
            </tr>
          </table>

          <table class="items-table">
            ${itemsHtml}
          </table>

          <div class="footer">
            *** Happy Cooking ***<br>
            FastKirana Partner App
          </div>

          <script>
            window.onload = function() {
              window.print();
              setTimeout(function() { window.close(); }, 500);
            }
          </script>
        </body>
      </html>
    `)
    printWindow.document.close()
  }

  printKOTReceiptRef.current = printKOTReceipt

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
            <div className="flex items-center gap-2">
              <button
                onClick={() => {
                  setActiveOrder(null)
                  setPickedItemIds({})
                }}
                className="flex items-center gap-1.5 text-xs font-black text-white/95 hover:text-white bg-white/10 hover:bg-white/20 px-3.5 py-2 rounded-xl transition-all cursor-pointer"
              >
                ← Back
              </button>
              <button
                onClick={() => printKOTReceipt(activeOrder)}
                className="flex items-center gap-1.5 text-xs font-black bg-white text-orange-600 hover:bg-zinc-100 px-3.5 py-2 rounded-xl transition-all cursor-pointer shadow-sm"
              >
                <Printer className="h-3.5 w-3.5 text-orange-500" /> Print KOT
              </button>
              <button
                onClick={() => {
                  const updated: Record<string, number> = {}
                  activeOrder.items.forEach(item => {
                    updated[item.id] = item.quantity
                  })
                  setPickedItemIds(updated)
                  autoPackOrder(activeOrder.id)
                }}
                className="flex items-center gap-1.5 text-xs font-black bg-emerald-600 hover:bg-emerald-700 text-white px-3.5 py-2 rounded-xl transition-all cursor-pointer shadow-sm active:scale-95 border border-emerald-500/20"
              >
                <CheckCircle className="h-3.5 w-3.5" /> Mark Ready (Pack All)
              </button>
            </div>
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

  const computedSubtotal = editItems.reduce((sum, item) => sum + item.price * item.quantity, 0)
  const computedDeliveryFee = editingOrder?.deliveryMethod === 'PICKUP' 
    ? 0 
    : (computedSubtotal < freeDeliveryThreshold ? deliveryFeeSetting : 0)
  const computedMiscFee = editingOrder?.deliveryMethod === 'PICKUP' 
    ? 0 
    : (editingOrder?.miscFee === 0 ? 0 : miscFeeSetting)
  const computedTaxes = parseFloat((computedSubtotal * taxRate).toFixed(2))
  const computedTotal = computedSubtotal + computedDeliveryFee + computedTaxes + computedMiscFee - (editingOrder?.discount || 0)

  return (
    <div className="space-y-6">
      {/* Browser Autoplay Sound Unblock Notice Banner */}
      {audioContextBlocked && soundEnabled && (
        <button
          onClick={handleUnblockAudio}
          className="w-full text-center text-xs font-black text-rose-600 bg-rose-500/10 hover:bg-rose-500/15 border border-rose-500/20 py-3 rounded-2xl transition-all flex items-center justify-center gap-1.5 cursor-pointer animate-pulse shadow-inner"
        >
          <span>🔊</span> Click here to enable Live Order Sound Alerts
        </button>
      )}

      {/* Sound Alerts Controls Header Toggle Bar */}
      <div className="flex justify-between items-center bg-card border border-border/50 px-4 py-3 rounded-3xl shadow-xs">
        <span className="text-[10px] font-black uppercase tracking-wider text-text-secondary">
          Kitchen Sounds
        </span>
        <button
          onClick={toggleSound}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl border text-[10px] font-black tracking-wide uppercase transition-all cursor-pointer ${
            soundEnabled
              ? 'bg-[#00b140]/10 border-[#00b140]/25 text-[#00b140]'
              : 'bg-zinc-500/10 border-zinc-500/20 text-zinc-500'
          }`}
        >
          {soundEnabled ? (
            <>
              <Volume2 className="h-3.5 w-3.5" /> Sound Alerts: ON
            </>
          ) : (
            <>
              <VolumeX className="h-3.5 w-3.5" /> Sound Alerts: MUTED
            </>
          )}
        </button>
      </div>

      {/* Overview Stats */}
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

              const pendingOrders = orders.filter(o => o.status === 'PENDING')
              const pendingIdx = pendingOrders.findIndex(o => o.id === order.id)
              const fifoRank = pendingIdx !== -1 ? pendingIdx + 1 : null

              return (
                <div 
                  key={order.id} 
                  className={`bg-card border ${getOrderCardSlaBorder(order.createdAt, order.status)} rounded-3xl p-5 shadow-sm flex flex-col justify-between space-y-4 transition-all duration-300`}
                >
                  <div className="flex justify-between items-start">
                    <div>
                      <div className="flex items-center gap-1.5">
                        <p className="text-xs font-mono font-bold text-text-primary">#{order.readableId || order.id.slice(0, 8)}</p>
                        {fifoRank && (
                          <span className={`text-[9px] font-black px-1.5 py-0.5 rounded-full flex items-center gap-0.5 shrink-0 ${
                            fifoRank === 1 
                              ? 'bg-amber-500/15 text-amber-700 dark:text-amber-400 border border-amber-500/20' 
                              : 'bg-zinc-100 text-zinc-600 dark:bg-zinc-800/40 dark:text-zinc-400 border border-border/40'
                          }`}>
                            {fifoRank === 1 ? '👑 FIFO #1 (Oldest)' : `FIFO #${fifoRank}`}
                          </span>
                        )}
                      </div>
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
                    <div className="flex items-center gap-2">
                      {order.status === 'PENDING' && (
                        <button
                          onClick={() => handleEditOrder(order)}
                          className="flex items-center gap-1 px-3 py-2 bg-card hover:bg-muted text-text-secondary rounded-xl border border-border text-[11px] font-black transition-all cursor-pointer shadow-xs active:scale-95 shrink-0"
                          title="Edit Order Items & Quantities"
                        >
                          <Edit className="h-3.5 w-3.5" /> Edit
                        </button>
                      )}
                      {isClaimedByMe && (
                        <button
                          onClick={() => printKOTReceipt(order)}
                          className="p-2 bg-card hover:bg-muted text-text-secondary rounded-xl border border-border transition-all cursor-pointer shadow-xs flex items-center justify-center shrink-0"
                          title="Print Kitchen Order Ticket (KOT)"
                        >
                          <Printer className="h-4 w-4 text-orange-500" />
                        </button>
                      )}
                      
                      {!isClaimedByMe && !isClaimedByOther && (
                        <div className="flex gap-1.5">
                          <button
                            onClick={() => handleQuickAccept(order)}
                            disabled={updatingId === order.id}
                            className="text-[10px] font-black px-2.5 py-2 rounded-xl bg-indigo-650 hover:bg-indigo-700 text-white transition-all cursor-pointer active:scale-95 shadow-xs shrink-0"
                            title="Accept and set 15m timer instantly"
                          >
                            ⚡ Accept (15m)
                          </button>
                          <button
                            onClick={() => handleQuickAcceptAndPack(order)}
                            disabled={updatingId === order.id}
                            className="text-[10px] font-black px-2.5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white transition-all cursor-pointer active:scale-95 shadow-xs shrink-0"
                            title="Accept, prepare and pack immediately"
                          >
                            🍲 Accept & Pack
                          </button>
                        </div>
                      )}
                      
                      <button
                        onClick={() => !isClaimedByOther && handleStartPreparing(order)}
                        disabled={isClaimedByOther || updatingId === order.id}
                        className={`text-xs font-black px-4 py-2 rounded-xl transition-all cursor-pointer active:scale-95 shrink-0 ${
                          isClaimedByOther 
                            ? 'bg-zinc-800 text-zinc-600 border border-zinc-900 cursor-not-allowed' 
                            : 'bg-orange-600 text-white hover:bg-orange-700 shadow-md'
                        }`}
                      >
                        {claimLabel}
                      </button>
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Smart Prep Time Modal */}
      <AnimatePresence>
        {prepModalOrder && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setPrepModalOrder(null)}
              className="absolute inset-0 bg-black/60 backdrop-blur-xs"
            />
            
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 20 }}
              transition={{ type: 'spring', damping: 20, stiffness: 300 }}
              className="relative w-full max-w-sm overflow-hidden bg-card border border-border rounded-3xl shadow-2xl p-6 space-y-6 z-10"
            >
              <div className="text-center space-y-2">
                <div className="mx-auto w-12 h-12 rounded-full bg-orange-500/10 flex items-center justify-center text-orange-650">
                  <Timer className="h-6 w-6" />
                </div>
                <h3 className="text-sm font-black text-text-primary uppercase tracking-wider">
                  Set Preparation Time
                </h3>
                <p className="text-[10px] text-text-secondary font-bold leading-normal">
                  Select estimated time to cook this order. Customers will see this countdown on their tracking screen.
                </p>
              </div>

              {/* Grid of timings options */}
              <div className="grid grid-cols-3 gap-2">
                {[5, 10, 15, 20, 30, 45].map((mins) => (
                  <button
                    key={mins}
                    type="button"
                    onClick={() => setSelectedPrepTime(mins)}
                    className={`p-3 rounded-2xl border text-xs font-black tracking-wide transition-all cursor-pointer flex flex-col items-center justify-center gap-1 active:scale-95 ${
                      selectedPrepTime === mins
                        ? 'bg-orange-500/10 border-orange-500/30 text-orange-655'
                        : 'bg-muted/40 hover:bg-muted/75 border-border/40 text-text-secondary'
                    }`}
                  >
                    <span className="text-[11px] font-black">{mins} Min</span>
                    <span className="text-[9px] font-medium opacity-80">ETA</span>
                  </button>
                ))}
              </div>

              {/* Action buttons */}
              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setPrepModalOrder(null)}
                  className="flex-1 h-11 border border-border hover:bg-muted text-text-secondary text-xs font-black rounded-xl cursor-pointer active:scale-98 transition-all"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={confirmStartPreparing}
                  className="flex-1 h-11 bg-orange-600 hover:bg-orange-700 text-white text-xs font-black rounded-xl cursor-pointer shadow-md shadow-orange-500/15 active:scale-98 transition-all"
                >
                  Start Cooking
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* Edit Order Modal */}
      <AnimatePresence>
        {editingOrder && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setEditingOrder(null)}
              className="absolute inset-0 bg-black/60 backdrop-blur-xs"
            />

            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 20 }}
              className="relative w-full max-w-lg bg-card border border-border rounded-3xl shadow-2xl p-6 flex flex-col max-h-[90vh] z-10 space-y-4"
            >
              <div className="flex justify-between items-center pb-2 border-b border-border/40">
                <div>
                  <h3 className="text-sm font-black text-text-primary uppercase tracking-wider flex items-center gap-1.5">
                    <Edit className="h-4 w-4 text-orange-500" /> Edit Order #{editingOrder.id.slice(0, 8).toUpperCase()}
                  </h3>
                  <p className="text-[10px] text-text-secondary font-bold mt-0.5">
                    Modify items, adjust quantities, or add menu items before confirmation.
                  </p>
                </div>
                <button
                  onClick={() => setEditingOrder(null)}
                  className="p-1.5 hover:bg-muted text-text-secondary rounded-xl transition-all cursor-pointer"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>

              {/* Catalog Search Input */}
              <div className="relative">
                <Search className="absolute left-3 top-3 h-4 w-4 text-text-muted" />
                <input
                  type="text"
                  placeholder="Search catalog to add items..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full h-10 pl-9 pr-4 rounded-xl border border-border bg-muted/20 text-xs font-bold focus:outline-hidden focus:border-orange-500 transition-all text-text-primary"
                />

                {/* Search Results Dropdown List */}
                {searchResults.length > 0 && (
                  <div className="absolute top-11 left-0 right-0 max-h-48 overflow-y-auto bg-card border border-border rounded-2xl shadow-xl z-20 divide-y divide-border/30">
                    {searchResults.map((prod) => (
                      <button
                        key={prod.id}
                        onClick={() => addCatalogItem(prod)}
                        className="w-full px-4 py-2.5 text-left text-xs font-bold hover:bg-muted/50 flex justify-between items-center transition-all text-text-primary cursor-pointer"
                      >
                        <span>{prod.name}</span>
                        <span className="text-orange-600 font-extrabold">{formatPrice(prod.price)}</span>
                      </button>
                    ))}
                  </div>
                )}
              </div>

              {/* Items List in current edit */}
              <div className="flex-1 overflow-y-auto min-h-0 space-y-2 py-1 pr-1">
                {editItems.length === 0 ? (
                  <div className="text-center py-8 text-xs text-text-muted font-bold">
                    No items in this order. Add items from search above.
                  </div>
                ) : (
                  editItems.map((item, idx) => (
                    <div key={idx} className="flex items-center justify-between p-3 bg-muted/20 rounded-2xl border border-border/30 gap-4">
                      <div className="min-w-0 flex-1">
                        <p className="text-xs font-bold text-text-primary truncate">{item.name}</p>
                        <p className="text-[10px] text-text-secondary font-extrabold mt-0.5">{formatPrice(item.price)}</p>
                        {(() => {
                          const prodDetails = allProducts.find(p => p.id === item.productId)
                          const variants = prodDetails?.variants as any[] | undefined
                          if (variants && Array.isArray(variants) && variants.length > 0) {
                            return (
                              <div className="mt-1.5 flex items-center gap-1">
                                <span className="text-[9px] text-text-secondary font-extrabold uppercase">Variant:</span>
                                <select
                                  value={item.selectedVariant || ''}
                                  onChange={(e) => {
                                    const val = e.target.value
                                    const selectedVar = variants.find(v => v.name === val)
                                    if (selectedVar) {
                                      updateItemVariant(item.productId, item.selectedVariant, val, selectedVar.price)
                                    }
                                  }}
                                  className="text-[9px] font-black bg-card border border-border rounded-lg px-1.5 py-0.5 focus:outline-hidden text-text-primary"
                                >
                                  {variants.map((v) => (
                                    <option key={v.name} value={v.name}>
                                      {v.name} ({formatPrice(v.price)})
                                    </option>
                                  ))}
                                </select>
                              </div>
                            )
                          }
                          return null
                        })()}
                      </div>

                      <div className="flex items-center gap-3">
                        <div className="flex items-center border border-border bg-card rounded-xl overflow-hidden shrink-0">
                          <button
                            onClick={() => updateItemQty(item.productId, item.selectedVariant, -1)}
                            className="p-1.5 hover:bg-muted text-text-secondary cursor-pointer"
                          >
                            <Minus className="h-3.5 w-3.5" />
                          </button>
                          <span className="px-2.5 text-xs font-black text-text-primary min-w-[20px] text-center">
                            {item.quantity}
                          </span>
                          <button
                            onClick={() => updateItemQty(item.productId, item.selectedVariant, 1)}
                            className="p-1.5 hover:bg-muted text-text-secondary cursor-pointer"
                          >
                            <Plus className="h-3.5 w-3.5" />
                          </button>
                        </div>

                        <button
                          onClick={() => markItemOutOfStock(item.productId)}
                          className="p-2 hover:bg-orange-50 text-orange-600 rounded-xl border border-transparent hover:border-orange-100 transition-all cursor-pointer shrink-0"
                          title="Mark Out of Stock"
                        >
                          <AlertCircle className="h-4 w-4" />
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>

              {/* Recalculated Live Bill Preview */}
              <div className="bg-muted/40 p-4 rounded-2xl border border-border/40 space-y-1.5 text-xs font-bold text-text-secondary">
                <div className="flex justify-between">
                  <span>Subtotal</span>
                  <span className="text-text-primary">{formatPrice(computedSubtotal)}</span>
                </div>
                <div className="flex justify-between">
                  <span>Taxes (5%)</span>
                  <span className="text-text-primary">{formatPrice(computedTaxes)}</span>
                </div>
                <div className="flex justify-between">
                  <span>Delivery Fee</span>
                  <span className="text-text-primary">{formatPrice(computedDeliveryFee)}</span>
                </div>
                {computedMiscFee > 0 && (
                  <div className="flex justify-between">
                    <span>Handling / Packaging Fee</span>
                    <span className="text-text-primary">{formatPrice(computedMiscFee)}</span>
                  </div>
                )}
                <div className="flex justify-between">
                  <span>Discount</span>
                  <span className="text-text-primary">-{formatPrice(editingOrder.discount)}</span>
                </div>
                <div className="flex justify-between pt-1.5 border-t border-border/40 text-sm font-black text-text-primary">
                  <span>Estimated Total</span>
                  <span className="text-orange-600 font-black">{formatPrice(computedTotal)}</span>
                </div>

                {editingOrder.paymentMethod === 'ONLINE' && (
                  <div className="mt-2 text-[10px] text-amber-600 bg-amber-500/10 p-2 rounded-xl flex items-start gap-1.5 border border-amber-500/20 leading-normal">
                    <AlertCircle className="h-3.5 w-3.5 shrink-0 mt-0.5" />
                    <span>
                      <strong>Pre-paid Order:</strong> Price changes will require manual difference adjustment during dispatch/delivery.
                    </span>
                  </div>
                )}
              </div>

              {/* Action buttons */}
              <div className="flex gap-3 pt-2">
                <button
                  disabled={isSavingEdit}
                  onClick={() => setEditingOrder(null)}
                  className="flex-1 h-11 border border-border hover:bg-muted text-text-secondary text-xs font-black rounded-xl cursor-pointer active:scale-98 transition-all disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  disabled={isSavingEdit || editItems.length === 0}
                  onClick={saveEditedOrder}
                  className="flex-1 h-11 bg-orange-600 hover:bg-orange-700 text-white text-xs font-black rounded-xl cursor-pointer shadow-md shadow-orange-500/15 active:scale-98 transition-all flex items-center justify-center gap-1.5 disabled:opacity-50"
                >
                  {isSavingEdit ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" /> Saving...
                    </>
                  ) : (
                    'Save Changes'
                  )}
                </button>
              </div>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  )
}
