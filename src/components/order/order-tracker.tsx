'use client'

import { useState, useEffect, useRef, useMemo } from 'react'
import { LockscreenAlertMockup } from '@/components/order/lockscreen-alert-mockup'
import { PayOnlineButton } from '@/components/order/pay-online-button'
import { useRouter } from 'next/navigation'
import { formatOrderTime, formatDate } from '@/lib/date-helpers'
import { supabase } from '@/lib/supabase-client'
import {
  Check,
  ShoppingBag,
  Package,
  Truck,
  CheckCircle2,
  Phone,
  User,
  Loader2,
  Clock,
  Navigation,
  MapPin,

  Store,
  Camera,
  Home,
  X,
  Edit,
  AlertCircle,
  Plus,
  Minus
} from 'lucide-react'
import { cn, formatPhone, formatAddress, getDeliveryPin } from '@/lib/utils'
import { getDistanceKm } from '@/lib/distance'
import { toast } from 'sonner'

function PrepCountdown({ clockTarget }: { clockTarget: string | Date }) {
  const [timeLeft, setTimeLeft] = useState<string>('')

  useEffect(() => {
    const target = new Date(clockTarget).getTime()
    
    const updateTimer = () => {
      const now = Date.now()
      const diff = target - now
      if (diff <= 0) {
        setTimeLeft('Food is ready! Packing...')
        return
      }

      const mins = Math.floor(diff / 60000)
      const secs = Math.floor((diff % 60000) / 1000)
      setTimeLeft(`Preparing: ${mins}m ${secs.toString().padStart(2, '0')}s left`)
    }

    updateTimer()
    const interval = setInterval(updateTimer, 1000)
    return () => clearInterval(interval)
  }, [clockTarget])

  return (
    <span className="text-[10px] font-black text-primary bg-primary/10 px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1.5 animate-pulse shadow-sm">
      <Clock className="h-3.5 w-3.5 shrink-0" /> {timeLeft}
    </span>
  )
}

interface OrderItem {
  id: string
  name: string
  price: number
  quantity: number
  selectedVariant?: string | null
}

interface OrderAddress {
  label: string
  houseNo: string
  street: string
  area: string
  city: string
  pincode: string
  lat?: number | null
  lng?: number | null
}

interface Order {
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
}

interface OrderTrackerProps {
  initialOrder: Order
  companionOrder?: Order | null
  isCafeOpen?: boolean
}

export function OrderTracker({ initialOrder, companionOrder, isCafeOpen: initialIsCafeOpen = true }: OrderTrackerProps) {
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
        // If order has restaurantId, product MUST match order.restaurantId
        if (order.restaurantId && p.restaurantId && p.restaurantId !== order.restaurantId) {
          return false
        }
        // Exclude grocery/wedson mart items: product must have restaurantId or category/tag as restaurant/wedson-restaurant
        const isRest = p.restaurantId != null || p.category?.slug === 'restaurant' || p.category?.slug === 'wedson-restaurant' || (Array.isArray(p.tags) && (p.tags.includes('restaurant') || p.tags.includes('wedson-restaurant')))
        if (!isRest) return false
      } else {
        // Grocery order (Wedson Mart): Exclude any restaurant or cafe products
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

  const getVariantsForProduct = (productId: string) => {
    const prod = allProducts.find(p => p.id === productId)
    if (!prod || !prod.variants) return []
    try {
      return typeof prod.variants === 'string' ? JSON.parse(prod.variants) : prod.variants
    } catch {
      return []
    }
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

  const getCombinedStatus = () => {
    if (!compOrder) return order.status
    const statuses = [order.status, compOrder.status]
    if (statuses.includes('CANCELLED') && statuses.every(s => s === 'CANCELLED')) return 'CANCELLED'
    if (statuses.every(s => s === 'DELIVERED')) return 'DELIVERED'
    if (statuses.includes('SHIPPED')) return 'SHIPPED'
    if (statuses.every(s => s === 'PACKED' || s === 'SHIPPED' || s === 'DELIVERED')) return 'PACKED'
    if (statuses.includes('CONFIRMED')) return 'CONFIRMED'
    return 'PENDING'
  }
  const combinedStatus = getCombinedStatus()

  const statusSteps = combinedStatus === 'CANCELLED' ? [
    { status: 'PENDING', label: 'Order Placed', desc: 'We have received your order.', icon: ShoppingBag },
    { status: 'CANCELLED', label: 'Order Cancelled', desc: 'This order has been cancelled.', icon: X },
  ] : order.deliveryMethod === 'PICKUP' ? [
    { status: 'PENDING', label: 'Order Placed', desc: 'We have received your order.', icon: ShoppingBag },
    { status: 'CONFIRMED', label: 'Confirmed', desc: 'Store has accepted your order.', icon: CheckCircle2 },
    { status: 'PACKED', label: 'Packing Items', desc: 'Packing fresh items at our store.', icon: Package },
    { status: 'SHIPPED', label: 'Ready for Pickup', desc: 'Your order is ready to be picked up!', icon: Store },
    { status: 'DELIVERED', label: 'Picked Up', desc: 'Order has been successfully picked up!', icon: Check },
  ] : [
    { status: 'PENDING', label: 'Order Placed', desc: 'We have received your order.', icon: ShoppingBag },
    { status: 'CONFIRMED', label: 'Confirmed', desc: 'Store has accepted your order.', icon: CheckCircle2 },
    { status: 'PACKED', label: 'Packing Items', desc: 'Packing fresh items at our dark store.', icon: Package },
    { status: 'SHIPPED', label: 'Out for Delivery', desc: 'Rider is carrying your order.', icon: Truck },
    { status: 'DELIVERED', label: 'Delivered', desc: 'Order delivered to your door!', icon: Check },
  ]

  // Fetch store coordinates and support phone from settings on mount
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
    const mappedStatus = ['READY_FOR_PICKUP', 'READY', 'PREPARED'].includes(currentStatus) ? 'SHIPPED' : currentStatus
    const idx = statusSteps.findIndex((s) => s.status === mappedStatus)
    if (idx !== -1) {
      setActiveStep(idx)
    }
  }, [order.status, statusSteps])

  const [leafletLoaded, setLeafletLoaded] = useState(false)
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<any>(null)
  const riderMarkerRef = useRef<any>(null)
  const routeLineRef = useRef<any>(null)


  // 2. Poll order status from API every 5 seconds
  useEffect(() => {
    if (order.status === 'DELIVERED' || order.status === 'CANCELLED') return

    const pollInterval = setInterval(async () => {
      if (document.visibilityState !== 'visible') return
      try {
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

        if (compOrder) {
          const compRes = await fetch(`/api/orders/${compOrder.id}`)
          if (compRes.ok) {
            const compData = await compRes.json()
            if (compData && compData.status) {
              setCompOrder((prev) => {
                if (prev && JSON.stringify(compData) !== JSON.stringify(prev)) {
                  if (compData.status !== prev.status) {
                    toast.success(`Fulfillment Update: ${compData.status} ✅`)
                  }
                  return compData
                }
                return prev
              })
            }
          }
        }
      } catch {
        // silently ignore polling errors
      }
    }, 15000)

    return () => clearInterval(pollInterval)
  }, [order.id, order.status, compOrder?.id])

  // Supabase Realtime connection to listen for updates (status changes, edits)
  useEffect(() => {
    const channel = supabase
      .channel(`order-tracker-${order.id}`)
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'orders',
        },
        (payload) => {
          const updatedOrder = payload.new as any
          const orderId = updatedOrder.id

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

  // 3. Dynamically load Leaflet assets on client
  useEffect(() => {
    if (typeof window === 'undefined') return

    if ((window as any).L) {
      setLeafletLoaded(true)
      return
    }

    const cssLink = document.createElement('link')
    cssLink.rel = 'stylesheet'
    cssLink.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'
    document.head.appendChild(cssLink)

    const jsScript = document.createElement('script')
    jsScript.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'
    jsScript.onload = () => {
      setLeafletLoaded(true)
    }
    document.head.appendChild(jsScript)

    return () => {
      if (document.head.contains(cssLink)) {
        document.head.removeChild(cssLink)
      }
      if (document.head.contains(jsScript)) {
        document.head.removeChild(jsScript)
      }
    }
  }, [])

  // 4. Initialize map ONCE when Leaflet loads
  useEffect(() => {
    if (!leafletLoaded || !mapContainerRef.current) return
    const L = (window as any).L
    if (!L) return

    if (mapRef.current) return

    const destLat = order.address?.lat || storeLat + 0.004
    const destLng = order.address?.lng || storeLng + 0.005

    const pickupLat = order.deliveryMethod === 'PICKUP' ? (order.address?.lat || storeLat) : storeLat
    const pickupLng = order.deliveryMethod === 'PICKUP' ? (order.address?.lng || storeLng) : storeLng

    const map = L.map(mapContainerRef.current).setView([pickupLat, pickupLng], 14)
    mapRef.current = map

    L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
      attribution: '&copy; OpenStreetMap contributors'
    }).addTo(map)

    const storeIcon = L.divIcon({
      html: `<div class="flex items-center justify-center h-8 w-8 bg-primary text-white rounded-full border border-white shadow text-xs">🏪</div>`,
      className: '',
      iconSize: [28, 28],
      iconAnchor: [14, 14],
    })

    const destIcon = L.divIcon({
      html: `<div class="flex items-center justify-center h-8 w-8 bg-accent text-white rounded-full border border-white shadow text-xs">📍</div>`,
      className: '',
      iconSize: [28, 28],
      iconAnchor: [14, 14],
    })

    const riderIcon = L.divIcon({
      html: `<div class="flex items-center justify-center h-8 w-8 bg-yellow-500 text-white rounded-full border border-white shadow text-xs animate-bounce">🚴</div>`,
      className: '',
      iconSize: [28, 28],
      iconAnchor: [14, 14],
    })

    L.marker([pickupLat, pickupLng], { icon: storeIcon })
      .addTo(map)
      .bindPopup(`<b>Fulfilling Shop: ${order.shopName || 'FastKirana Store'}</b>`)

    L.marker([destLat, destLng], { icon: destIcon })
      .addTo(map)
      .bindPopup('<b>Your Location</b>')

    const riderLat = order.deliveryLat || storeLat
    const riderLng = order.deliveryLng || storeLng

    const routeLine = L.polyline([[riderLat, riderLng], [destLat, destLng]], {
      color: '#e20a22',
      weight: 3,
      dashArray: '5, 8',
      opacity: 0.7,
    }).addTo(map)
    routeLineRef.current = routeLine

    map.fitBounds(routeLine.getBounds(), { padding: [40, 40] })

    const riderMarker = L.marker([riderLat, riderLng], { icon: riderIcon }).addTo(map)
    riderMarkerRef.current = riderMarker

    return () => {
      if (mapRef.current) {
        mapRef.current.remove()
        mapRef.current = null
      }
    }
  }, [leafletLoaded, storeLat, storeLng])

  // 5. Update rider marker position smoothly without re-rendering the whole map
  useEffect(() => {
    if (!mapRef.current || !riderMarkerRef.current) return
    const destLat = order.address?.lat || storeLat + 0.004
    const destLng = order.address?.lng || storeLng + 0.005

    let animationFrame: number
    let startTime = Date.now()
    
    const animateRider = () => {
      if (!riderMarkerRef.current) return
      
      // Update rider marker position ONLY when real deliveryLat/deliveryLng GPS data exists
      if (order.deliveryLat && order.deliveryLng) {
        riderMarkerRef.current.setLatLng([order.deliveryLat, order.deliveryLng])
        if (riderMarkerRef.current.getElement()) {
          riderMarkerRef.current.getElement().style.display = 'flex'
        }
        if (routeLineRef.current) {
          routeLineRef.current.setLatLngs([[order.deliveryLat, order.deliveryLng], [destLat, destLng]])
        }
      } else {
        // Hide rider marker if no real GPS location is available yet (No fake location animation)
        if (riderMarkerRef.current.getElement()) {
          riderMarkerRef.current.getElement().style.display = 'none'
        }
        if (routeLineRef.current) {
          routeLineRef.current.setLatLngs([[storeLat, storeLng], [destLat, destLng]])
        }
      }
    }

    animateRider()
  }, [order.status, order.deliveryLat, order.deliveryLng, storeLat, storeLng, order.address?.lat, order.address?.lng])

  // Merge items from both orders
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

  // Live rider distance and ETA
  const trackingMetrics = useMemo(() => {
    if (order.deliveryMethod === 'PICKUP') return null
    if (order.status !== 'SHIPPED') return null

    const destLat = order.address?.lat || storeLat + 0.004
    const destLng = order.address?.lng || storeLng + 0.005
    
    let riderLat = order.deliveryLat
    let riderLng = order.deliveryLng
    
    if (!riderLat || !riderLng) {
      riderLat = storeLat
      riderLng = storeLng
    }
    
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
  const isScheduled = order.estimatedDelivery && order.createdAt && 
    (new Date(order.estimatedDelivery).getTime() - new Date(order.createdAt).getTime() > 45 * 60 * 1000)

  return (
    <div className="space-y-8 animate-fade-in">
      {isCafeOrder && !isCafeOpen && (order.status === 'PENDING' || order.status === 'CONFIRMED') && (
        <div className="bg-amber-50 dark:bg-amber-950/20 border border-amber-200 dark:border-amber-900/50 p-4 rounded-2xl flex items-start gap-3">
          <div className="h-10 w-10 rounded-full bg-amber-100 dark:bg-amber-900/40 text-amber-600 dark:text-amber-400 flex items-center justify-center shrink-0 font-bold">
            ⚠️
          </div>
          <div>
            <h2 className="text-sm font-bold text-amber-800 dark:text-amber-400">Kitchen is currently Closed</h2>
            <p className="text-xs text-amber-700 dark:text-amber-500 mt-0.5 leading-relaxed">
              Kitchen is closed. Active orders placed before closing are still processed and delivered. If you have any concerns or want to cancel/refund, please call support.
            </p>
          </div>
        </div>
      )}

      {order.status === 'CANCELLED' && (

        <div className="bg-red-50 dark:bg-red-950/20 border border-red-200 dark:border-red-900/50 p-4 rounded-2xl flex items-start gap-3">
          <div className="h-10 w-10 rounded-full bg-red-100 dark:bg-red-900/40 text-red-600 dark:text-red-400 flex items-center justify-center shrink-0 font-bold">
            ❌
          </div>
          <div>
            <h2 className="text-sm font-bold text-red-800 dark:text-red-400">Order Cancelled</h2>
            <p className="text-xs text-red-700 dark:text-red-500 mt-0.5">
              This order has been cancelled and will not be processed further. If payment was made, it will be refunded shortly.
            </p>
          </div>
        </div>
      )}
      
      {/* Pay Online Option for COD Orders */}
      {order.paymentStatus !== 'PAID' && order.status !== 'CANCELLED' && (
        <PayOnlineButton
          orderId={order.id}
          amount={combinedTotal || order.total}
          readableId={String(order.baseReadableId || order.readableId || '').replace(/-[GR\d]+$/i, '') || order.id?.slice(0, 8)}
          onPaymentSuccess={async () => {
            try {
              const refetchRes = await fetch(`/api/orders/${order.id}`)
              if (refetchRes.ok) {
                const freshData = await refetchRes.json()
                setOrder((prev: any) => ({
                  ...prev,
                  ...freshData,
                  paymentStatus: 'PAID',
                  paymentMethod: 'UPI',
                  status: freshData.status || (prev.status === 'PENDING' ? 'CONFIRMED' : prev.status),
                }))
              } else {
                setOrder((prev: any) => ({ ...prev, paymentStatus: 'PAID', paymentMethod: 'UPI', status: prev.status === 'PENDING' ? 'CONFIRMED' : prev.status }))
              }
            } catch (e) {
              setOrder((prev: any) => ({ ...prev, paymentStatus: 'PAID', paymentMethod: 'UPI', status: prev.status === 'PENDING' ? 'CONFIRMED' : prev.status }))
            }
            router.refresh()
          }}
          variant="card"
        />
      )}

      {/* Premium Visual Delivery Status Card */}
      <div className="bg-card border border-border/80 p-5 sm:p-7 rounded-3xl shadow-xl space-y-6 overflow-hidden relative">
        {/* Background Decorative Gradient Glow */}
        <div className="absolute -top-20 -right-20 w-64 h-64 bg-gradient-to-br from-primary/15 via-emerald-500/10 to-transparent rounded-full blur-3xl pointer-events-none" />

        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 border-b border-border/50 pb-5 relative z-10">
          <div>
            <div className="flex flex-wrap items-center gap-2 mb-2">
              <span className="font-mono font-black text-xs px-2.5 py-1 rounded-lg bg-muted border border-border/60 text-text-primary tracking-tight">
                #{String(order.baseReadableId || order.readableId || '').replace(/-[GR\d]+$/i, '') || order.id?.slice(0, 8)}
              </span>
              <span className={cn(
                "text-[10px] uppercase font-black px-2.5 py-1 rounded-full tracking-wider shadow-2xs flex items-center gap-1.5",
                combinedStatus === 'CANCELLED'
                  ? "text-red-600 bg-red-100 dark:text-red-400 dark:bg-red-950/40 border border-red-500/20"
                  : combinedStatus === 'DELIVERED'
                  ? "text-emerald-700 bg-emerald-100 dark:text-emerald-400 dark:bg-emerald-950/40 border border-emerald-500/20"
                  : order.status === 'SHIPPED'
                  ? "text-blue-700 bg-blue-100 dark:text-blue-400 dark:bg-blue-950/40 border border-blue-500/20"
                  : "text-amber-700 bg-amber-100 dark:text-amber-400 dark:bg-amber-950/40 border border-amber-500/20"
              )}>
                <span className={cn(
                  "h-1.5 w-1.5 rounded-full",
                  combinedStatus === 'CANCELLED' ? "bg-red-500" :
                  combinedStatus === 'DELIVERED' ? "bg-emerald-500" :
                  order.status === 'SHIPPED' ? "bg-blue-500 animate-ping" :
                  "bg-amber-500 animate-pulse"
                )} />
                {combinedStatus === 'CANCELLED' ? 'Cancelled' : 
                 combinedStatus === 'DELIVERED' ? 'Delivered' : 
                 order.status === 'SHIPPED' ? 'Out for Delivery' : 
                 order.status === 'PACKED' ? 'Packed & Ready' : 
                 order.status === 'CONFIRMED' ? 'Confirmed & Preparing' : 'Order Placed'}
              </span>

              {order.isCombined ? (
                <span className="text-[10px] font-black px-2.5 py-1 rounded-full bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20 flex items-center gap-1">
                  🛍️ Grocery + 🍽️ Restaurant Combined
                </span>
              ) : ((order as any).restaurantName || order.shopName) ? (
                <span className="text-[10px] font-bold px-2.5 py-1 rounded-full bg-rose-500/10 text-rose-600 dark:text-rose-400 border border-rose-500/20 flex items-center gap-1">
                  🏪 {(order as any).restaurantName || order.shopName}
                </span>
              ) : (
                <span className="text-[10px] font-bold px-2.5 py-1 rounded-full bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20 flex items-center gap-1">
                  🛒 FastKirana DarkStore
                </span>
              )}
            </div>

            <h1 className="text-2xl sm:text-3xl font-black text-text-primary tracking-tight">
              {combinedStatus === 'CANCELLED'
                ? 'Order Cancelled'
                : combinedStatus === 'DELIVERED' 
                ? (order.deliveryMethod === 'PICKUP' ? 'Order Picked Up! 🎉' : 'Order Delivered! 🎉') 
                : order.deliveryMethod === 'PICKUP' 
                ? (
                    (order.status === 'PACKED' || order.status === 'SHIPPED' || ['READY_FOR_PICKUP', 'READY', 'PREPARED'].includes(order.status))
                      ? 'Ready for Counter Pickup!'
                      : 'Preparing for Pickup'
                  )
                : order.status === 'SHIPPED'
                ? 'Rider On The Way 🛵'
                : order.status === 'PACKED'
                ? 'Order Packed & Ready'
                : order.status === 'CONFIRMED'
                ? 'Order Confirmed & Preparing'
                : 'Order Placed'}
            </h1>

            <p className="text-xs font-semibold text-text-secondary mt-1">
              {combinedStatus === 'CANCELLED'
                ? 'This order has been cancelled.'
                : combinedStatus === 'DELIVERED'
                ? 'Thank you for ordering with FastKirana!'
                : order.deliveryMethod === 'PICKUP'
                ? (
                    (order.status === 'PACKED' || order.status === 'SHIPPED' || ['READY_FOR_PICKUP', 'READY', 'PREPARED'].includes(order.status))
                      ? 'Your order is ready at the store counter. Please collect it at your convenience.'
                      : 'Your order is being freshly prepared by the store.'
                  )
                : order.status === 'SHIPPED'
                ? 'Your delivery partner has picked up the order and is on the way.'
                : order.status === 'PACKED'
                ? 'Items packed safely. Waiting for rider pickup.'
                : 'Your order is being freshly prepared with hygiene checks.'}
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2 shrink-0">
            <div className="flex items-center gap-1.5 text-xs font-semibold text-text-secondary bg-muted/50 px-3 py-1.5 rounded-xl border border-border/50">
              <Clock className="h-3.5 w-3.5 text-primary" />
              <span>Placed at: {formatOrderTime(order.createdAt)}</span>
            </div>
          </div>
        </div>

        {/* ── Modern 4-Step Timeline Stepper ── */}
        <div className="py-2 relative z-10">
          <div className="grid grid-cols-4 gap-2 relative">
            {[
              {
                label: 'Placed',
                icon: ShoppingBag,
                stepIdx: 0,
                activeWhen: ['PENDING', 'CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED'],
                isCurrent: order.status === 'PENDING'
              },
              {
                label: 'Preparing',
                icon: Package,
                stepIdx: 1,
                activeWhen: ['CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED'],
                isCurrent: order.deliveryMethod === 'PICKUP'
                  ? order.status === 'CONFIRMED'
                  : (order.status === 'CONFIRMED' || order.status === 'PACKED')
              },
              {
                label: order.deliveryMethod === 'PICKUP' ? 'Ready' : 'On The Way',
                icon: order.deliveryMethod === 'PICKUP' ? Store : Truck,
                stepIdx: 2,
                activeWhen: order.deliveryMethod === 'PICKUP'
                  ? ['PACKED', 'SHIPPED', 'DELIVERED']
                  : ['SHIPPED', 'DELIVERED'],
                isCurrent: order.deliveryMethod === 'PICKUP'
                  ? (order.status === 'PACKED' || order.status === 'SHIPPED')
                  : order.status === 'SHIPPED'
              },
              {
                label: order.deliveryMethod === 'PICKUP' ? 'Picked Up' : 'Delivered',
                icon: CheckCircle2,
                stepIdx: 3,
                activeWhen: ['DELIVERED'],
                isCurrent: order.status === 'DELIVERED'
              },
            ].map((step, idx) => {
              const isReached = step.activeWhen.includes(order.status)
              const isCurrent = step.isCurrent
              const StepIcon = step.icon

              return (
                <div key={idx} className="flex flex-col items-center text-center group">
                  <div className="w-full flex items-center mb-2">
                    <div className={cn(
                      "h-1 w-full rounded-full transition-colors",
                      idx === 0 ? "invisible" : isReached ? "bg-emerald-500" : "bg-muted"
                    )} />
                    <div className={cn(
                      "h-9 w-9 rounded-2xl flex items-center justify-center shrink-0 transition-all duration-300 shadow-sm",
                      isCurrent
                        ? "bg-primary text-white scale-110 shadow-md ring-4 ring-primary/20"
                        : isReached
                        ? "bg-emerald-500 text-white"
                        : "bg-muted/70 text-text-muted border border-border/60"
                    )}>
                      <StepIcon className="h-4 w-4" strokeWidth={2.2} />
                    </div>
                    <div className={cn(
                      "h-1 w-full rounded-full transition-colors",
                      idx === 3 ? "invisible" : isReached && idx < (activeStep || 1) ? "bg-emerald-500" : "bg-muted"
                    )} />
                  </div>
                  <span className={cn(
                    "text-[10px] sm:text-xs font-black leading-tight",
                    isCurrent ? "text-primary" : isReached ? "text-text-primary" : "text-text-muted"
                  )}>
                    {step.label}
                  </span>
                </div>
              )
            })}
          </div>
        </div>

        {/* Fulfillment & Order Details Badge Row */}
        <div className="flex flex-wrap items-center gap-2 pt-1">
          {order.deliveryMethod === 'PICKUP' ? (
            <span className="text-[10px] font-black text-purple-800 bg-purple-100 dark:bg-purple-900/30 dark:text-purple-400 px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1.5">
              <Store className="h-3.5 w-3.5 shrink-0" /> Self-Pickup (Take Away)
            </span>
          ) : (
            <span className="text-[10px] font-black text-sky-800 bg-sky-100 dark:bg-sky-900/30 dark:text-sky-400 px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1.5">
              <Truck className="h-3.5 w-3.5 shrink-0" /> Doorstep Fast Delivery
            </span>
          )}
          {isScheduled && order.estimatedDelivery && (
            <span className="text-[10px] font-black text-amber-800 bg-amber-100 dark:bg-amber-900/30 dark:text-amber-400 px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1.5">
              <Clock className="h-3.5 w-3.5 shrink-0" /> Scheduled: {formatDate(order.estimatedDelivery, 'yyyy-MM-dd')} {formatOrderTime(order.estimatedDelivery)}
            </span>
          )}

        </div>

        {/* Dual-Store Combined Order Fulfillment Status */}
        {order.isCombined && order.subOrders && order.subOrders.length > 0 ? (
          <div className="rounded-2xl border border-primary/20 bg-gradient-to-br from-primary/5 via-accent/5 to-card p-4 space-y-3 shadow-xs">
            <div className="flex items-center justify-between">
              <h3 className="text-text-primary font-black text-xs uppercase tracking-wider flex items-center gap-1.5">
                <Store className="h-4 w-4 text-primary shrink-0" />
                <span>Multi-Store Preparation Progress</span>
              </h3>
              <span className="text-[9.5px] font-black uppercase px-2 py-0.5 rounded-md bg-purple-500/15 text-purple-700 dark:text-purple-400 border border-purple-500/30">
                🔗 1 Delivery · 2 Stops
              </span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {order.subOrders.map((sub: any, idx: number) => {
                const isRest = sub.type === 'RESTAURANT'
                return (
                  <div key={sub.id || idx} className="bg-card p-3 rounded-xl border border-border/70 flex items-center justify-between shadow-2xs">
                    <div className="flex items-center gap-2.5 min-w-0">
                      <div className="h-9 w-9 rounded-xl flex items-center justify-center text-base shrink-0 bg-muted/60">
                        {isRest ? '🍳' : '🛒'}
                      </div>
                      <div className="min-w-0">
                        <div className="text-text-primary font-black text-xs truncate">
                          {isRest ? (sub.shopName || 'Restaurant') : 'FastKirana Darkstore'}
                        </div>
                        <div className="text-[10px] text-text-muted font-medium mt-0.5">
                          {sub.itemsCount || sub.items?.length || 0} {isRest ? 'Dishes' : 'Grocery items'}
                        </div>
                      </div>
                    </div>

                    <span className={cn(
                      "text-[9px] font-black px-2.5 py-1 rounded-full uppercase tracking-wider shrink-0",
                      sub.status === 'DELIVERED' ? 'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 border border-emerald-500/30' :
                      sub.status === 'CANCELLED' ? 'bg-red-500/15 text-red-600 dark:text-red-400 border border-red-500/30' :
                      sub.status === 'SHIPPED' ? 'bg-blue-500/15 text-blue-600 dark:text-blue-400 border border-blue-500/30' :
                      sub.status === 'PACKED' ? 'bg-purple-500/15 text-purple-600 dark:text-purple-400 border border-purple-500/30' :
                      'bg-amber-500/15 text-amber-700 dark:text-amber-300 border border-amber-500/30'
                    )}>
                      {sub.status === 'PACKED' ? (isRest ? '🍳 Food Ready' : '📦 Packed') : sub.status}
                    </span>
                  </div>
                )
              })}
            </div>
          </div>
        ) : compOrder ? (
          <div className="rounded-xl border border-primary/10 bg-primary/5 p-4 space-y-3 text-xs font-semibold text-text-secondary">
            <h3 className="text-text-primary font-bold text-xs uppercase tracking-wider flex items-center gap-1.5">
              <Store className="h-4 w-4 text-primary shrink-0" /> Consolidated Fulfillment Status
            </h3>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className="bg-card p-3 rounded-lg border border-border/60 flex items-center justify-between shadow-sm">
                <div className="flex items-center gap-2">
                  <span className="text-lg leading-none">
                    {order.shopName?.includes('Cafe') ? '☕' : '🛒'}
                  </span>
                  <div>
                    <div className="text-text-primary font-extrabold text-[11px] truncate max-w-[150px]">{order.shopName || 'FastKirana Store'}</div>
                    <div className="text-[10px] text-text-muted mt-0.5">#{order.readableId || order.id.slice(-6).toUpperCase()} • {order.items.length} items</div>
                  </div>
                </div>
                <span className={cn(
                  "text-[9px] font-black px-2 py-0.5 rounded-full uppercase tracking-wider",
                  order.status === 'DELIVERED' ? 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400' :
                  order.status === 'CANCELLED' ? 'bg-red-500/10 text-red-600 dark:text-red-400' :
                  order.status === 'SHIPPED' ? 'bg-blue-500/10 text-blue-600 dark:text-blue-400' :
                  'bg-amber-500/10 text-amber-600 dark:text-amber-400'
                )}>
                  {order.status}
                </span>
              </div>
            </div>
          </div>
        ) : (
          !order.isB2B && order.shopName && order.status !== 'SHIPPED' && (
            <div className="rounded-xl border border-primary/10 bg-primary/5 p-3 flex items-center justify-between text-xs font-semibold text-text-secondary">
              <div className="flex items-center gap-2">
                <Store className="h-4 w-4 text-primary shrink-0" />
                <div>
                  <span className="text-text-primary font-bold">Fulfillment:</span> {order.shopName}
                </div>
              </div>
            </div>
          )
        )}

        {/* Out For Delivery Dedicated Contact Card */}
        {order.status === 'SHIPPED' && order.deliveryMethod !== 'PICKUP' && (
          <div className="bg-gradient-to-br from-emerald-500/10 via-teal-500/5 to-card border border-emerald-500/30 p-4 sm:p-5 rounded-2xl shadow-sm flex flex-col sm:flex-row items-center justify-between gap-4">
            <div className="flex items-center gap-3.5 w-full sm:w-auto">
              <div className="h-12 w-12 rounded-2xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center text-2xl shrink-0 shadow-2xs">
                🛵
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-black text-emerald-700 dark:text-emerald-400 uppercase tracking-wide">
                    Delivery Partner Assigned
                  </span>
                  <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                </div>
                <div className="text-sm font-black text-text-primary mt-0.5 truncate">
                  {order.deliveryUser?.name && order.deliveryUser.name !== 'Admin'
                    ? order.deliveryUser.name
                    : 'FastKirana Delivery Executive'}
                </div>
                <div className="text-[10px] text-text-muted font-medium">
                  Verified FastKirana Delivery Partner
                </div>
              </div>
            </div>

            <a
              href={`tel:${formatPhone(order.deliveryUser?.phone || '+919696503759').replace(/\s+/g, '')}`}
              className="flex items-center justify-center gap-2 w-full sm:w-auto px-5 py-3 bg-emerald-600 hover:bg-emerald-700 text-white font-black text-xs rounded-xl shadow-md transition-all active:scale-95 text-center shrink-0 cursor-pointer"
            >
              <Phone className="h-4 w-4" />
              <span>Call Rider</span>
            </a>
          </div>
        )}

        {/* Self-Pickup Counter Details Card */}
        {order.deliveryMethod === 'PICKUP' && order.status !== 'DELIVERED' && (
          <div className="bg-gradient-to-br from-amber-500/10 via-orange-500/5 to-card border border-amber-500/25 p-4 sm:p-5 rounded-2xl shadow-xs flex flex-col gap-4">
            <div className="flex items-start gap-3.5">
              <div className="h-11 w-11 rounded-xl bg-amber-500/15 border border-amber-500/30 flex items-center justify-center text-xl shrink-0">
                🏪
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <span className="text-[10px] font-black text-amber-700 dark:text-amber-400 uppercase tracking-widest">
                    Self-Pickup Order
                  </span>
                  <span className="h-1.5 w-1.5 rounded-full bg-amber-500 animate-pulse" />
                </div>
                <div className="text-sm font-black text-text-primary mt-0.5">
                  {order.shopName || 'FastKirana Outlet'}
                </div>
                <div className="text-xs text-text-secondary mt-1 font-semibold">
                  Pickup Address: <span className="text-text-primary font-bold">{order.address?.street || 'FastKirana Store counter'}</span>
                </div>
                <p className="text-[10.5px] text-text-muted mt-1.5">
                  Please show your Order ID <span className="font-extrabold text-primary">#{order.baseReadableId || order.readableId || order.id.slice(-6).toUpperCase()}</span> at the counter to collect your items.
                </p>
              </div>
            </div>

            <div className="flex gap-2.5 w-full border-t border-border/40 pt-3 mt-1">
              <a
                href={`tel:${supportPhone}`}
                className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-muted/60 hover:bg-muted text-text-primary font-bold text-xs rounded-xl transition-all cursor-pointer"
              >
                <Phone className="h-3.5 w-3.5" />
                <span>Call Store</span>
              </a>
              <a
                href={`https://www.google.com/maps/dir/?api=1&destination=${order.address?.lat || storeLat},${order.address?.lng || storeLng}`}
                target="_blank"
                rel="noopener noreferrer"
                className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-primary text-white font-black text-xs rounded-xl shadow-md transition-all active:scale-95 cursor-pointer"
              >
                <Navigation className="h-3.5 w-3.5" />
                <span>Get Directions</span>
              </a>
            </div>
          </div>
        )}

        {/* Support Call Buttons */}
        {order.status !== 'SHIPPED' && order.deliveryMethod !== 'PICKUP' && (
          <div className="flex flex-col sm:flex-row gap-3 pt-1">
            <a
              href="tel:8112849854"
              className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2.5 border-2 border-primary/20 bg-primary/5 hover:bg-primary/10 text-primary font-black text-xs rounded-xl transition-all"
            >
              <Phone className="h-4 w-4" />
              FastKirana Support (8112849854)
            </a>
            {order.deliveryMethod === 'PICKUP' && (
              <a
                href={`https://www.google.com/maps/dir/?api=1&destination=${order.address?.lat || storeLat},${order.address?.lng || storeLng}`}
                target="_blank"
                rel="noopener noreferrer"
                className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2.5 border-2 border-accent/20 bg-accent/5 hover:bg-accent/10 text-accent font-black text-xs rounded-xl transition-all"
              >
                <Navigation className="h-4 w-4" />
                Get Store Directions
              </a>
            )}
          </div>
        )}



      </div>

      {/* Delivery Proof Card */}
      {order.status === 'DELIVERED' && order.deliveryMethod !== 'PICKUP' && (
        <div className="bg-card border-2 border-accent p-4 min-[375px]:p-5 rounded-2xl shadow-md space-y-4 animate-fade-in">
          <h2 className="text-sm font-black text-text-primary flex items-center gap-2">
            <CheckCircle2 className="h-5 w-5 text-accent" />
            Proof of Delivery
          </h2>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            {order.deliveryPhoto ? (
              <div className="space-y-1.5">
                <span className="text-[10px] font-bold text-text-secondary block">Photo Confirmation</span>
                <div className="rounded-xl overflow-hidden border border-border">
                  <img
                    src={order.deliveryPhoto}
                    alt="Delivery confirmation proof"
                    className="w-full h-44 object-cover"
                    loading="lazy"
                  />
                </div>
              </div>
            ) : (
              <div className="space-y-2 flex flex-col justify-center items-center border border-dashed rounded-xl p-4 bg-muted/20">
                <Camera className="h-8 w-8 text-text-muted stroke-[1.2]" />
                <span className="text-xs text-text-muted">No photo proof uploaded</span>
              </div>
            )}
            
            <div className="space-y-3 flex flex-col justify-between">
              <div>
                <span className="text-[10px] font-bold text-text-secondary block">Delivery Location (GPS)</span>
                {order.deliveryLat && order.deliveryLng ? (
                  <div className="space-y-2 mt-1">
                    <p className="text-xs font-semibold text-text-primary leading-relaxed">
                      Delivered Executive Location: <br />
                      <span className="font-mono text-[11px] text-text-secondary">
                        {order.deliveryLat.toFixed(5)}° N, {order.deliveryLng.toFixed(5)}° E
                      </span>
                    </p>
                    <a
                      href={`https://www.google.com/maps/search/?api=1&query=${order.deliveryLat},${order.deliveryLng}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-1.5 px-3.5 py-2.5 bg-accent text-white text-xs font-black rounded-xl hover:bg-accent/95 transition-all shadow-sm"
                    >
                      <Navigation className="h-3.5 w-3.5" />
                      View Delivery Spot on Google Maps
                    </a>
                  </div>
                ) : (
                  <p className="text-xs text-text-muted italic mt-1">GPS coordinates not captured for this order.</p>
                )}
              </div>
              
              <div className="bg-muted/40 p-3 rounded-xl border text-[11px] font-medium text-text-secondary leading-relaxed">
                Delivery address: <br />
                <span className="text-text-primary font-bold">{formatAddress(order.address, false)}</span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Self-Pickup Confirmation Success Card */}
      {order.status === 'DELIVERED' && order.deliveryMethod === 'PICKUP' && (
        <div className="bg-gradient-to-br from-emerald-500/10 via-teal-500/5 to-card border border-emerald-500/30 p-4 sm:p-5 rounded-2xl shadow-sm flex flex-col gap-3">
          <h2 className="text-sm font-black text-emerald-600 dark:text-emerald-400 flex items-center gap-2">
            <CheckCircle2 className="h-5 w-5 text-emerald-500" />
            Picked Up Successfully
          </h2>
          <p className="text-xs text-text-secondary leading-relaxed font-semibold">
            Your order has been collected from the store counter. Thank you for shopping with FastKirana!
          </p>
        </div>
      )}

      {/* Delivery Destination Card */}
      <div className="bg-card border border-border p-4 min-[375px]:p-5 rounded-2xl shadow-sm space-y-3">
        <h3 className="text-sm font-bold text-text-primary border-b border-border/40 pb-2 flex items-center gap-2">
          <MapPin className="h-4 w-4 text-primary" />
          {order.deliveryMethod === 'PICKUP' ? 'Pickup Location' : 'Delivery Destination'}
        </h3>
        <div className="text-xs space-y-3">
          <p className="text-text-secondary leading-relaxed font-semibold">
            {formatAddress(order.address)}
            {order.deliveryMethod === 'PICKUP' && (
              <span className="block text-[10px] text-text-muted mt-1 font-bold">
                📍 Coordinates: {order.address?.lat || storeLat}, {order.address?.lng || storeLng}
              </span>
            )}
          </p>
          {order.deliveryMethod === 'PICKUP' ? (
            <a
              href={`https://www.google.com/maps/dir/?api=1&destination=${order.address?.lat || storeLat},${order.address?.lng || storeLng}`}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 px-3.5 py-2 bg-accent/10 hover:bg-accent/20 text-accent text-xs font-black rounded-xl transition-all shadow-sm w-fit"
            >
              <Navigation className="h-3.5 w-3.5" />
              Get Store Directions (Lat: {order.address?.lat || storeLat}, Lng: {order.address?.lng || storeLng})
            </a>
          ) : (
            <a
              href={
                order.address.lat && order.address.lng
                  ? `https://www.google.com/maps/search/?api=1&query=${order.address.lat},${order.address.lng}`
                  : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
                      formatAddress(order.address)
                    )}`
              }
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 px-3.5 py-2 bg-accent/10 hover:bg-accent/20 text-accent text-xs font-black rounded-xl transition-all shadow-sm w-fit"
            >
              <Navigation className="h-3.5 w-3.5" />
              Locate Delivery Address on Google Maps
            </a>
          )}
        </div>
      </div>

      {/* Receipt mini summary */}
      <div className="bg-white dark:bg-zinc-900 border border-border/60 p-5 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] space-y-4">
        <div className="flex items-center gap-2 border-b border-dashed border-border/60 pb-3">
          <span className="text-lg">🧾</span>
          <div>
            <h3 className="text-xs font-black uppercase tracking-wider text-text-primary">
              Order Receipt
            </h3>
            <p className="text-[9px] text-text-muted font-bold uppercase mt-0.5">
              Payment Mode: {order.paymentMethod === 'COD' ? 'Cash on Delivery' : order.paymentMethod}
            </p>
          </div>
        </div>

        <div className="space-y-3">
          {/* Items List */}
          <div className="space-y-3">
            {order.isCombined && order.subOrders && order.subOrders.length > 1 ? (
              order.subOrders.map((sub: any, subIdx: number) => {
                const isRest = sub.type === 'RESTAURANT'
                const subItems = sub.items || []
                if (subItems.length === 0) return null
                return (
                  <div key={sub.id || subIdx} className="rounded-xl border border-border/50 overflow-hidden bg-muted/10">
                    <div className="bg-muted/40 px-3 py-1.5 text-[10px] font-black uppercase tracking-wider flex items-center justify-between text-text-secondary border-b border-border/40">
                      <span>{isRest ? `🍽️ ${sub.shopName || 'Restaurant'}` : `🥘 ${sub.shopName || 'FastKirana Dark Store'}`}</span>
                      <span className="text-[9px] font-mono text-text-muted">{subItems.length} items</span>
                    </div>
                    <div className="p-3 space-y-2 divide-y divide-border/20">
                      {subItems.map((item: any) => (
                        <div key={item.id} className="flex justify-between items-center pt-2 first:pt-0">
                          <div className="flex items-center gap-2.5 min-w-0">
                            <span className="inline-flex items-center justify-center text-[10px] font-black text-accent bg-accent/5 dark:bg-accent/10 px-2 py-0.5 rounded-lg border border-accent/10 shrink-0">
                              {item.quantity}x
                            </span>
                            <div className="min-w-0">
                              <p className="text-xs font-bold text-text-primary truncate">
                                {item.name} {item.selectedVariant ? `(${item.selectedVariant})` : ''}
                              </p>
                              {item.notes && (
                                <p className="text-[9px] text-amber-600 dark:text-amber-400 font-medium">
                                  📝 {item.notes}
                                </p>
                              )}
                            </div>
                          </div>
                          <span className="text-xs font-extrabold text-text-primary shrink-0 ml-4">
                            ₹{item.price * item.quantity}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                )
              })
            ) : (
              mergedItems.map((item: any) => (
                <div key={item.id} className="flex justify-between items-center py-1">
                  <div className="flex items-center gap-2.5 min-w-0">
                    <span className="inline-flex items-center justify-center text-[10px] font-black text-accent bg-accent/5 dark:bg-accent/10 px-2 py-0.5 rounded-lg border border-accent/10 shrink-0">
                      {item.quantity}x
                    </span>
                    <div className="min-w-0">
                      <p className="text-xs font-bold text-text-primary truncate">
                        {item.name} {item.selectedVariant ? `(${item.selectedVariant})` : ''}
                      </p>
                      {item.shopName && (
                        <p className="text-[9px] text-text-muted font-semibold flex items-center gap-0.5 mt-0.5">
                          <span>🏢</span> {item.shopName}
                        </p>
                      )}
                    </div>
                  </div>
                  <span className="text-xs font-extrabold text-text-primary shrink-0 ml-4">
                    ₹{item.price * item.quantity}
                  </span>
                </div>
              ))
            )}
          </div>
          
          {/* Cost Breakdown */}
          <div className="border-t border-dashed border-border/60 pt-3.5 space-y-2.5 text-xs">
            <div className="flex justify-between text-text-secondary font-semibold">
              <span>Subtotal</span>
              <span className="font-bold text-text-primary">₹{combinedSubtotal}</span>
            </div>
            {combinedDiscount > 0 && (
              <div className="flex justify-between text-emerald-600 dark:text-emerald-400 font-bold">
                <span>Discount Applied</span>
                <span>-₹{combinedDiscount}</span>
              </div>
            )}
            <div className="flex justify-between text-text-secondary font-semibold">
              <span>Delivery Charge</span>
              <span className={cn(combinedDeliveryFee === 0 ? "text-emerald-600 dark:text-emerald-400 font-black" : "font-bold text-text-primary")}>
                {combinedDeliveryFee > 0 ? `₹${combinedDeliveryFee}` : 'FREE 🎉'}
              </span>
            </div>
            {combinedTaxes > 0 && (
              <div className="flex justify-between text-text-secondary font-semibold">
                <span>Taxes & GST</span>
                <span className="font-bold text-text-primary">₹{combinedTaxes.toFixed(1)}</span>
              </div>
            )}
            {combinedMiscFee > 0 && (
              <div className="flex justify-between text-text-secondary font-semibold">
                <span>Packaging &amp; Handling Fee</span>
                <span className="font-bold text-text-primary">₹{combinedMiscFee}</span>
              </div>
            )}
          </div>

          {/* Grand Total */}
          <div className="flex justify-between items-center text-text-primary font-black border-t-2 border-dashed border-border/80 pt-4 mt-1">
            <span className="text-xs uppercase tracking-wider text-text-secondary">Grand Total</span>
            <span className="text-primary text-lg font-black tracking-tight">₹{combinedTotal.toFixed(0)}</span>
          </div>
        </div>
      </div>

    </div>
  )
}
