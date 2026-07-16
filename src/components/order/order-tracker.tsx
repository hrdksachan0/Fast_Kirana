'use client'

import { useState, useEffect, useRef, useMemo } from 'react'
import { LockscreenAlertMockup } from '@/components/order/lockscreen-alert-mockup'
import { useRouter } from 'next/navigation'
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
import { cn, formatPhone, formatAddress } from '@/lib/utils'
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
  createdAt: string
  items: OrderItem[]
  address: OrderAddress
  deliveryUser?: {
    name: string | null
    phone: string | null
  } | null
  isCombined?: boolean
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
  const [supportPhone, setSupportPhone] = useState('+91 70544 70303')
  const [isCafeOpen, setIsCafeOpen] = useState(initialIsCafeOpen)
  
  // Customer Edit Order Modal States & Handlers
  const [isEditing, setIsEditing] = useState(false)
  const [editItems, setEditItems] = useState<any[]>([])
  const [isSaving, setIsSaving] = useState(false)
  const [allProducts, setAllProducts] = useState<any[]>([])

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
    setIsEditing(true)

    try {
      const [resRest, resCafe] = await Promise.all([
        fetch('/api/products?category=restaurant&limit=100').catch(() => null),
        fetch('/api/products?category=cafe&limit=100').catch(() => null)
      ])
      let prods: any[] = []
      if (resRest?.ok) {
        const d = await resRest.json()
        prods = [...prods, ...(d.products || [])]
      }
      if (resCafe?.ok) {
        const d = await resCafe.json()
        prods = [...prods, ...(d.products || [])]
      }
      setAllProducts(prods)
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
        window.location.reload()
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
    const idx = statusSteps.findIndex((s) => s.status === order.status)
    if (idx !== -1) {
      setActiveStep(idx)
    }
  }, [order.status])

  const [leafletLoaded, setLeafletLoaded] = useState(false)
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<any>(null)
  const riderMarkerRef = useRef<any>(null)


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
    }, 5000)

    return () => clearInterval(pollInterval)
  }, [order.id, order.status, compOrder?.id])

  // SSE connection to listen for updates (status changes, edits)
  useEffect(() => {
    const eventSource = new EventSource('/api/sse/orders')
    
    eventSource.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data)
        if (data.orderId === order.id && (data.type === 'order-edited' || data.type === 'status-change')) {
          fetch(`/api/orders/${order.id}`)
            .then(res => res.json())
            .then(updatedOrder => {
              if (updatedOrder && updatedOrder.status) {
                setOrder(updatedOrder)
                if (data.type === 'order-edited') {
                  toast.info('⚠️ Your order has been modified by the store. Bill details updated.', {
                    icon: '📝'
                  })
                }
              }
            })
        }

        if (compOrder && data.orderId === compOrder.id && (data.type === 'order-edited' || data.type === 'status-change')) {
          fetch(`/api/orders/${compOrder.id}`)
            .then(res => res.json())
            .then(updatedOrder => {
              if (updatedOrder && updatedOrder.status) {
                setCompOrder(updatedOrder)
                if (data.type === 'order-edited') {
                  toast.info('⚠️ Your order has been modified by the store. Bill details updated.', {
                    icon: '📝'
                  })
                }
              }
            })
        }
      } catch (err) {
        console.error('SSE message parsing error in tracker:', err)
      }
    }

    return () => {
      eventSource.close()
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

    const routeLine = L.polyline([[pickupLat, pickupLng], [destLat, destLng]], {
      color: '#e20a22',
      weight: 3,
      dashArray: '5, 8',
      opacity: 0.7,
    }).addTo(map)

    map.fitBounds(routeLine.getBounds(), { padding: [40, 40] })

    const riderLat = order.deliveryLat || storeLat
    const riderLng = order.deliveryLng || storeLng
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
      if (order.status === 'SHIPPED' && !order.deliveryLat) {
        const elapsed = (Date.now() - startTime) % 20000
        const t = elapsed / 20000
        const currentLat = storeLat + (destLat - storeLat) * t
        const currentLng = storeLng + (destLng - storeLng) * t
        riderMarkerRef.current.setLatLng([currentLat, currentLng])
      } else if (order.deliveryLat && order.deliveryLng) {
        riderMarkerRef.current.setLatLng([order.deliveryLat, order.deliveryLng])
      } else {
        riderMarkerRef.current.setLatLng([storeLat, storeLng])
      }
      animationFrame = requestAnimationFrame(animateRider)
    }

    animateRider()

    return () => cancelAnimationFrame(animationFrame)
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
  const combinedSubtotal = order.subtotal + (compOrder?.subtotal || 0)
  const combinedDiscount = order.discount + (compOrder?.discount || 0)
  const combinedDeliveryFee = order.deliveryFee + (compOrder?.deliveryFee || 0)
  const combinedTaxes = order.taxes + (compOrder?.taxes || 0)
  const combinedMiscFee = order.miscFee + (compOrder?.miscFee || 0)
  const combinedTotal = order.total + (compOrder?.total || 0)

  const isCafeOrder = order.shopName === 'FastKirana Cafe Kitchen'
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
            <h2 className="text-sm font-bold text-amber-800 dark:text-amber-400">Cafe is currently Closed</h2>
            <p className="text-xs text-amber-700 dark:text-amber-500 mt-0.5 leading-relaxed">
              FastKirana Cafe Kitchen is closed. Active orders placed before closing are still processed and delivered. If you have any concerns or want to cancel/refund, please call support.
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
      
      {/* Visual Delivery Status Card */}
      <div className="bg-card border border-border p-4 min-[375px]:p-5 md:p-6 rounded-2xl shadow-sm space-y-5 md:space-y-6">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 border-b border-border/40 pb-4">
          <div>
            <span className={cn(
              "text-[10px] uppercase font-bold px-2 py-0.5 rounded-full",
              combinedStatus === 'CANCELLED'
                ? "text-red-600 bg-red-100 dark:text-red-400 dark:bg-red-950/40"
                : "text-accent bg-accent/10"
            )}>
              {combinedStatus === 'CANCELLED' ? 'Order Cancelled' : 'Live Tracking Active'}
            </span>
            <h1 className="text-xl font-black text-text-primary tracking-tight mt-1">
              {combinedStatus === 'CANCELLED'
                ? 'Order Cancelled'
                : combinedStatus === 'DELIVERED' 
                ? 'Order Delivered!' 
                : order.deliveryMethod === 'PICKUP' 
                ? 'Order Ready for Pickup!' 
                : isScheduled 
                ? 'Arriving at Scheduled Time' 
                : 'Arriving Soon'}
            </h1>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <div className="flex items-center gap-2 text-xs font-semibold text-text-secondary bg-muted px-3 py-1.5 rounded-xl border">
              <Clock className="h-4 w-4 text-primary" />
              <span>Placed at: {new Date(order.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
            </div>
            {combinedStatus === 'PENDING' && (
              <button
                onClick={handleOpenCustomerEdit}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary font-black rounded-xl text-xs transition-all shadow-xs cursor-pointer border border-primary/20 active:scale-95"
              >
                <Edit className="h-3.5 w-3.5" /> Modify Items
              </button>
            )}
          </div>
        </div>

        {/* Fulfillment & Order Details Badge Row */}
        <div className="flex flex-wrap gap-2">

          {order.deliveryMethod === 'PICKUP' ? (
            <span className="text-[10px] font-black text-purple-800 bg-purple-100 dark:bg-purple-900/30 dark:text-purple-400 px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1.5">
              <Store className="h-3.5 w-3.5 shrink-0" /> Self-Pickup (Take Away)
            </span>
          ) : (
            <span className="text-[10px] font-black text-emerald-800 bg-emerald-100 dark:bg-emerald-900/30 dark:text-emerald-400 px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1.5">
              <Truck className="h-3.5 w-3.5 shrink-0" /> Doorstep Delivery
            </span>
          )}
          {isScheduled && order.estimatedDelivery && (
            <span className="text-[10px] font-black text-amber-800 bg-amber-100 dark:bg-amber-900/30 dark:text-amber-400 px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1.5">
              <Clock className="h-3.5 w-3.5 shrink-0" /> Scheduled: {new Date(order.estimatedDelivery).toLocaleDateString()} {new Date(order.estimatedDelivery).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
            </span>
          )}
          {!isScheduled && order.estimatedDelivery && combinedStatus !== 'DELIVERED' && combinedStatus !== 'CANCELLED' && (
            combinedStatus === 'CONFIRMED' && new Date(order.estimatedDelivery).getTime() > Date.now() ? (
              <PrepCountdown clockTarget={order.estimatedDelivery} />
            ) : (
              <span className="text-[10px] font-black text-primary bg-primary/10 px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1.5">
                <Clock className="h-3.5 w-3.5 shrink-0" /> Estimated Delivery: {new Date(order.estimatedDelivery).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
              </span>
            )
          )}

        </div>

        {compOrder ? (
          <div className="rounded-xl border border-primary/10 bg-primary/5 p-4 space-y-3 text-xs font-semibold text-text-secondary">
            <h3 className="text-text-primary font-bold text-xs uppercase tracking-wider flex items-center gap-1.5">
              <Store className="h-4 w-4 text-primary shrink-0" /> Consolidated Fulfillment Status
            </h3>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {/* Primary Order Status */}
              <div className="bg-card p-3 rounded-lg border border-border/60 flex items-center justify-between shadow-sm">
                <div className="flex items-center gap-2">
                  <span className="text-lg leading-none">
                    {order.shopName?.includes('Cafe') ? '☕' : '🛒'}
                  </span>
                  <div>
                    <div className="text-text-primary font-extrabold text-[11px] truncate max-w-[150px]">{order.shopName || 'FastKirana Store'}</div>
                    <div className="text-[10px] text-text-muted mt-0.5">#{order.id.slice(-6).toUpperCase()} • {order.items.length} items</div>
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

              {/* Companion Order Status */}
              <div className="bg-card p-3 rounded-lg border border-border/60 flex items-center justify-between shadow-sm">
                <div className="flex items-center gap-2">
                  <span className="text-lg leading-none">
                    {compOrder.shopName?.includes('Cafe') ? '☕' : '🛒'}
                  </span>
                  <div>
                    <div className="text-text-primary font-extrabold text-[11px] truncate max-w-[150px]">{compOrder.shopName || 'FastKirana Cafe'}</div>
                    <div className="text-[10px] text-text-muted mt-0.5">#{compOrder.id.slice(-6).toUpperCase()} • {compOrder.items.length} items</div>
                  </div>
                </div>
                <span className={cn(
                  "text-[9px] font-black px-2 py-0.5 rounded-full uppercase tracking-wider",
                  compOrder.status === 'DELIVERED' ? 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400' :
                  compOrder.status === 'CANCELLED' ? 'bg-red-500/10 text-red-600 dark:text-red-400' :
                  compOrder.status === 'SHIPPED' ? 'bg-blue-500/10 text-blue-600 dark:text-blue-400' :
                  'bg-amber-500/10 text-amber-600 dark:text-amber-400'
                )}>
                  {compOrder.status}
                </span>
              </div>
            </div>
          </div>
        ) : (
          !order.isB2B && order.shopName && (
            <div className="rounded-xl border border-primary/10 bg-primary/5 p-3 flex items-center justify-between text-xs font-semibold text-text-secondary">
              <div className="flex items-center gap-2">
                <Store className="h-4 w-4 text-primary shrink-0" />
                <div>
                  <span className="text-text-primary font-bold">Fulfillment:</span> {order.shopName}
                </div>
              </div>
              {order.shopPhone && (
                <a href={`tel:${formatPhone(order.shopPhone).replace(/\s+/g, '')}`} className="text-primary hover:underline font-black flex items-center gap-1.5 shrink-0">
                  <Phone className="h-3.5 w-3.5" /> Support Hotline
                </a>
              )}
            </div>
          )
        )}

        {/* Support Call Buttons */}
        <div className="flex flex-col sm:flex-row gap-3 pt-1">
          <a
            href={`tel:${formatPhone(supportPhone).replace(/\s+/g, '')}`}
            className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2.5 border-2 border-primary/20 bg-primary/5 hover:bg-primary/10 text-primary font-black text-xs rounded-xl transition-all"
          >
            <Phone className="h-4 w-4" />
            Call Store Support ({formatPhone(supportPhone)})
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



        {/* Step Progression Map UI */}
        <div className="relative pl-8 space-y-6 before:absolute before:left-[11px] before:top-2 before:bottom-2 before:w-[2px] before:bg-border before:content-['']">
          {statusSteps.map((step, idx) => {
            const isCompleted = idx < activeStep
            const isActive = idx === activeStep
            const isCancelledStep = step.status === 'CANCELLED'
            const StepIcon = step.icon

            return (
              <div key={step.status} className="relative flex items-start gap-4">
                {/* Step Circle Pin */}
                <div
                  className={cn(
                    "absolute -left-[35px] flex h-6 w-6 items-center justify-center rounded-full border-2 transition-all duration-300",
                    isCancelledStep
                      ? "bg-red-500 border-red-500 text-white scale-110 shadow ring-4 ring-red-500/20"
                      : isCompleted || isActive
                      ? "bg-green-500 border-green-500 text-white"
                      : "bg-card border-border text-text-muted",
                    isActive && !isCancelledStep && "scale-110 shadow-md ring-4 ring-green-500/20"
                  )}
                >
                  {isCancelledStep ? (
                    <X className="h-3 w-3 stroke-[3]" />
                  ) : isCompleted || isActive ? (
                    <Check className="h-3 w-3 stroke-[3]" />
                  ) : (
                    <span className="text-[10px] font-bold">{idx + 1}</span>
                  )}
                </div>

                {/* Step Text Info */}
                <div className="flex-grow">
                  <h3
                    className={cn(
                      "text-sm font-extrabold",
                      isCancelledStep
                        ? "text-red-500"
                        : isActive
                        ? "text-green-600 dark:text-green-500"
                        : isCompleted
                        ? "text-text-primary"
                        : "text-text-muted"
                    )}
                  >
                    {step.label}
                  </h3>
                  <p className="text-xs text-text-secondary mt-0.5 leading-relaxed">
                    {step.desc}
                  </p>

                  {/* Micro-checklist for PACKED state */}
                  {isActive && step.status === 'PACKED' && (
                    <div className="mt-3 bg-muted/40 border border-border/60 rounded-xl p-3 space-y-2.5 max-w-xs animate-fade-in">
                      <span className="text-[9px] uppercase font-black text-accent tracking-wider block">
                        🛡️ DarkStore Fresh Checks
                      </span>
                      <div className="space-y-2">
                        {[
                          "Sanitizing grocery items",
                          "Quality checking freshness seals",
                          "Sealing hygiene-safe bags"
                        ].map((mStep, mIdx) => {
                          const isDone = mIdx < packingStep
                          const isPacking = mIdx === packingStep
                          
                          return (
                            <div key={mIdx} className="flex items-center gap-2 text-[11px] font-semibold">
                              {isDone ? (
                                <span className="text-accent font-black text-xs">✓</span>
                              ) : isPacking ? (
                                <span className="relative flex h-2 w-2">
                                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75"></span>
                                  <span className="relative inline-flex rounded-full h-2 w-2 bg-primary"></span>
                                </span>
                              ) : (
                                <span className="h-1.5 w-1.5 rounded-full bg-border" />
                              )}
                              <span className={cn(
                                "transition-colors duration-300",
                                isDone ? "text-text-muted line-through" : isPacking ? "text-primary font-bold animate-pulse-gentle" : "text-text-secondary"
                              )}>
                                {mStep}
                              </span>
                            </div>
                          )
                        })}
                      </div>
                    </div>
                  )}
                </div>

                {/* Live Loader for active step */}
                {isActive && order.status !== 'DELIVERED' && (
                  <Loader2 className="h-4 w-4 animate-spin text-primary shrink-0 mt-0.5" />
                )}
              </div>
            )
          })}
        </div>
      </div>

      <LockscreenAlertMockup orderId={order.id} />

      {/* Simulated Tracking Map Panel */}
      {order.status !== 'DELIVERED' && order.status !== 'PENDING' && order.status !== 'CANCELLED' && (
        <div className="bg-card border border-border p-4 min-[375px]:p-5 rounded-2xl shadow-sm space-y-4">
          <h2 className="text-sm font-bold text-text-primary flex items-center gap-2">
            <Navigation className="h-4 w-4 text-primary" />
            Live Rider Position
          </h2>

          {/* Map Simulation Graphics Area */}
          <div className="relative h-44 rounded-xl bg-muted/30 overflow-hidden border border-border/40 flex items-center justify-center bg-[radial-gradient(#e5e7eb_1px,transparent_1px)] [background-size:16px_16px]">
            {/* Route Line */}
            <div className="absolute h-1 w-[80%] bg-border rounded-full" />
            
            {/* Animated rider scooter */}
            <div
              className="absolute flex items-center justify-center h-10 w-10 bg-primary text-white rounded-full shadow-lg border-2 border-white transition-all duration-[15000ms] ease-linear"
              style={{
                left: `${
                  order.status === 'CONFIRMED' ? '15%' :
                  order.status === 'PACKED' ? '40%' :
                  order.status === 'SHIPPED' ? '65%' : '90%'
                }`
              }}
            >
              <Truck className="h-5 w-5 animate-pulse-gentle" />
            </div>

            {/* Destination House Marker */}
            <div className="absolute right-[10%] flex flex-col items-center gap-1">
              <Home className="h-6 w-6 text-accent fill-accent animate-bounce-subtle" />
              <span className="text-[9px] font-bold text-text-secondary bg-card px-1.5 py-0.5 rounded border shadow-sm">Home</span>
            </div>

            {/* Starting Store Marker */}
            <div className="absolute left-[10%] flex flex-col items-center gap-1">
              <Store className="h-6 w-6 text-primary fill-primary/10" />
              <span className="text-[9px] font-bold text-text-secondary bg-card px-1.5 py-0.5 rounded border shadow-sm max-w-[100px] truncate" title={order.shopName || 'Store'}>
                {order.shopName || 'Store'}
              </span>
            </div>
          </div>

          {/* Delivery Rider partner info block */}
          <div className="flex items-center justify-between border-t border-border/40 pt-4">
            <div className="flex items-center gap-3">
              <div className="flex h-11 w-11 items-center justify-center rounded-full bg-muted text-text-secondary border">
                <User className="h-5 w-5" />
              </div>
              <div className="text-xs">
                <h4 className="font-bold text-text-primary">{order.deliveryUser?.name || 'Sonu Kumar'}</h4>
                <p className="text-[10px] text-accent font-semibold">FastKirana Delivery Executive</p>
              </div>
            </div>
            <a
              href={`tel:${formatPhone(order.deliveryUser?.phone || '+919876543210').replace(/\s+/g, '')}`}
              className="flex items-center justify-center h-9 w-9 bg-accent/10 text-accent rounded-full hover:bg-accent/20 transition-colors"
              aria-label="Call Rider"
            >
              <Phone className="h-4 w-4" />
            </a>
          </div>
        </div>
      )}

      {/* Delivery Proof Card */}
      {order.status === 'DELIVERED' && (
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
      <div className="bg-card border border-border p-4 min-[375px]:p-5 rounded-2xl shadow-sm space-y-4">
        <h3 className="text-sm font-bold text-text-primary border-b border-border/40 pb-2">
          Receipt details
        </h3>
        <div className="space-y-3 text-xs font-semibold text-text-secondary">
          {mergedItems.map((item: any) => (
            <div key={item.id} className="flex justify-between items-start gap-4">
              <div>
                <span>{item.name} {item.selectedVariant ? `(${item.selectedVariant})` : ''} (×{item.quantity})</span>
                {item.shopName && (
                  <span className="block text-[9px] text-text-muted mt-0.5 font-bold">
                    📍 {item.shopName}
                  </span>
                )}
              </div>
              <span className="shrink-0">₹{item.price * item.quantity}</span>
            </div>
          ))}
          
          <div className="border-t border-border/40 pt-3 space-y-1.5">
            <div className="flex justify-between">
              <span>Subtotal</span>
              <span>₹{combinedSubtotal}</span>
            </div>
            {combinedDiscount > 0 && (
              <div className="flex justify-between text-emerald-600 dark:text-emerald-400">
                <span>Discount</span>
                <span>-₹{combinedDiscount}</span>
              </div>
            )}
            <div className="flex justify-between">
              <span>Delivery Fee</span>
              <span>{combinedDeliveryFee > 0 ? `₹${combinedDeliveryFee}` : 'FREE'}</span>
            </div>
            {combinedTaxes > 0 && (
              <div className="flex justify-between">
                <span>Taxes & GST</span>
                <span>₹{combinedTaxes.toFixed(1)}</span>
              </div>
            )}
            {combinedMiscFee > 0 && (
              <div className="flex justify-between">
                <span>Handling / Miscellaneous Fee</span>
                <span>₹{combinedMiscFee}</span>
              </div>
            )}
          </div>

          <div className="flex justify-between text-text-primary font-black border-t border-border/80 pt-3 mt-3 text-sm">
            <span>Grand Total</span>
            <span className="text-primary text-base font-extrabold">₹{combinedTotal.toFixed(0)}</span>
          </div>
        </div>
      </div>

      {/* Customer Edit Modal */}
      {isEditing && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-fade-in">
          <div className="bg-card border border-border w-full max-w-lg rounded-3xl shadow-2xl flex flex-col max-h-[90vh] animate-scale-in overflow-hidden">
            
            {/* Header */}
            <div className="px-5 py-4 border-b border-border/60 flex items-center justify-between bg-muted/20">
              <div>
                <h2 className="text-base font-black text-text-primary">Modify Order Items</h2>
                <p className="text-[10px] text-text-muted mt-0.5 font-semibold">Change quantities or swap variants before store confirmation</p>
              </div>
              <button
                onClick={() => setIsEditing(false)}
                className="h-8 w-8 rounded-full hover:bg-muted flex items-center justify-center text-text-secondary transition-colors"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            {/* Content List */}
            <div className="flex-1 overflow-y-auto p-5 space-y-4">
              {editItems.length === 0 ? (
                <div className="text-center py-8 text-text-secondary flex flex-col items-center gap-2">
                  <AlertCircle className="h-8 w-8 text-primary" />
                  <p className="text-xs font-bold">Your order is empty. You can cancel it from the tracking screen.</p>
                </div>
              ) : (
                editItems.map((item) => {
                  const productVariants = getVariantsForProduct(item.productId)
                  return (
                    <div key={item.id} className="p-3.5 bg-muted/20 rounded-2xl border border-border/40 flex flex-col gap-3">
                      <div className="flex justify-between items-start">
                        <div>
                          <h4 className="text-xs font-black text-text-primary leading-tight">{item.name}</h4>
                          {item.shopName && (
                            <span className="inline-block text-[9px] text-text-muted mt-1 font-bold">
                              📍 {item.shopName}
                            </span>
                          )}
                        </div>
                        <span className="text-xs font-black text-primary">₹{(item.price * item.quantity).toFixed(0)}</span>
                      </div>

                      {/* Variant Selector */}
                      {productVariants && productVariants.length > 0 && (
                        <div className="flex flex-col gap-1">
                          <label className="text-[9px] font-bold text-text-muted uppercase">Select Size / Option</label>
                          <select
                            value={item.selectedVariant || ''}
                            onChange={(e) => {
                              const selectedOpt = productVariants.find((v: any) => v.name === e.target.value)
                              if (selectedOpt) {
                                updateItemVariant(item.productId, item.selectedVariant, selectedOpt.name, selectedOpt.price)
                              }
                            }}
                            className="w-full text-xs font-black bg-card border border-border/80 px-2.5 py-1.5 rounded-xl text-text-primary focus:outline-none focus:border-primary"
                          >
                            {productVariants.map((v: any) => (
                              <option key={v.name} value={v.name}>
                                {v.name} (₹{v.price})
                              </option>
                            ))}
                          </select>
                        </div>
                      )}

                      {/* Quantity Controls */}
                      <div className="flex justify-between items-center pt-1 border-t border-border/30 mt-1">
                        <span className="text-[10px] text-text-secondary font-bold">Quantity</span>
                        <div className="flex items-center gap-3">
                          <button
                            type="button"
                            onClick={() => updateItemQty(item.productId, item.selectedVariant, -1)}
                            className="h-7 w-7 rounded-xl bg-card border border-border hover:bg-muted/30 flex items-center justify-center text-text-primary active:scale-90 transition-all cursor-pointer"
                          >
                            <Minus className="h-3.5 w-3.5" />
                          </button>
                          <span className="text-xs font-black w-6 text-center text-text-primary">{item.quantity}</span>
                          <button
                            type="button"
                            onClick={() => updateItemQty(item.productId, item.selectedVariant, 1)}
                            className="h-7 w-7 rounded-xl bg-card border border-border hover:bg-muted/30 flex items-center justify-center text-text-primary active:scale-90 transition-all cursor-pointer"
                          >
                            <Plus className="h-3.5 w-3.5" />
                          </button>
                        </div>
                      </div>
                    </div>
                  )
                })
              )}
            </div>

            {/* Footer Actions */}
            <div className="px-5 py-4 border-t border-border/60 bg-muted/20 flex gap-3">
              <button
                type="button"
                onClick={() => setIsEditing(false)}
                disabled={isSaving}
                className="flex-1 py-2.5 border border-border hover:bg-muted/30 font-bold rounded-xl text-xs transition-colors text-text-primary disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleSaveEdits}
                disabled={isSaving}
                className="flex-1 py-2.5 bg-primary hover:bg-primary/95 text-white font-black rounded-xl text-xs transition-all shadow-md flex items-center justify-center gap-1.5 disabled:opacity-80 active:scale-98 cursor-pointer"
              >
                {isSaving ? (
                  <>
                    <Loader2 className="h-3.5 w-3.5 animate-spin" /> Saving...
                  </>
                ) : (
                  'Save Changes'
                )}
              </button>
            </div>

          </div>
        </div>
      )}
    </div>
  )
}
