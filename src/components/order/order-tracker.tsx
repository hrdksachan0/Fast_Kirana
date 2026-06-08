'use client'

import { useState, useEffect, useRef } from 'react'
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
  Building2,
  Store,
  Camera,
  Home,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { toast } from 'sonner'
import { PushNotificationConsent } from '@/components/shared/push-notification-consent'

interface OrderItem {
  id: string
  name: string
  price: number
  quantity: number
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
}

interface OrderTrackerProps {
  initialOrder: Order
}

const statusSteps = [
  { status: 'PENDING', label: 'Order Placed', desc: 'We have received your order.', icon: ShoppingBag },
  { status: 'CONFIRMED', label: 'Confirmed', desc: 'Store has accepted your order.', icon: CheckCircle2 },
  { status: 'PACKED', label: 'Packing Items', desc: 'Packing fresh items at our dark store.', icon: Package },
  { status: 'SHIPPED', label: 'Out for Delivery', desc: 'Rider is carrying your order.', icon: Truck },
  { status: 'DELIVERED', label: 'Delivered', desc: 'Groceries delivered to your door!', icon: Check },
]

export function OrderTracker({ initialOrder }: OrderTrackerProps) {
  const router = useRouter()
  const [order, setOrder] = useState<Order>(initialOrder)
  const [activeStep, setActiveStep] = useState(0)
  const [packingStep, setPackingStep] = useState(0)
  const [storeLat, setStoreLat] = useState(26.1534185)
  const [storeLng, setStoreLng] = useState(80.1714024)

  // Fetch store coordinates from settings on mount
  useEffect(() => {
    fetch('/api/settings')
      .then(res => res.json())
      .then(data => {
        if (data.store_lat) setStoreLat(parseFloat(data.store_lat))
        if (data.store_lng) setStoreLng(parseFloat(data.store_lng))
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

  // 1. Notification Permission request
  useEffect(() => {
    if (typeof window !== 'undefined' && 'Notification' in window) {
      if (Notification.permission === 'default') {
        Notification.requestPermission()
      }
    }
  }, [])

  // 2. Connect to Server-Sent Events (SSE) live stream
  useEffect(() => {
    if (order.status === 'DELIVERED' || order.status === 'CANCELLED') return

    const eventSource = new EventSource(`/api/orders/${order.id}/live`)

    eventSource.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data)
        
        if (data.status && data.status !== order.status) {
          setOrder((prev) => {
            const statusLabels: Record<string, string> = {
              CONFIRMED: 'Confirmed by Store',
              PACKED: 'Packed & Ready',
              SHIPPED: 'On the Way (Out for Delivery)',
              DELIVERED: 'Delivered Successfully',
              CANCELLED: 'Cancelled',
            }
            
            if (typeof window !== 'undefined' && 'Notification' in window && Notification.permission === 'granted') {
              new Notification(`Order Update: ${statusLabels[data.status] || data.status}`, {
                body: `Your FastKirana order status has changed to: ${statusLabels[data.status] || data.status}`,
                icon: '/manifest.json',
              })
            }
            
            return {
              ...prev,
              status: data.status,
              deliveryLat: data.deliveryLat ?? prev.deliveryLat,
              deliveryLng: data.deliveryLng ?? prev.deliveryLng,
            }
          })
        } else if (data.deliveryLat !== undefined || data.deliveryLng !== undefined) {
          setOrder((prev) => ({
            ...prev,
            deliveryLat: data.deliveryLat,
            deliveryLng: data.deliveryLng,
          }))
        }
      } catch (err) {
        console.error('Error parsing SSE event:', err)
      }
    }

    eventSource.onerror = (err) => {
      console.error('EventSource connection error:', err)
      eventSource.close()
    }

    return () => {
      eventSource.close()
    }
  }, [order.id, order.status])

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

  // 4. Initialize and control tracking map
  useEffect(() => {
    if (!leafletLoaded || !mapContainerRef.current) return
    const L = (window as any).L
    if (!L) return

    if (mapRef.current) {
      mapRef.current.remove()
      mapRef.current = null
    }

    const destLat = order.address?.lat || storeLat + 0.004
    const destLng = order.address?.lng || storeLng + 0.005

    const map = L.map(mapContainerRef.current).setView([storeLat, storeLng], 14)
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

    L.marker([storeLat, storeLng], { icon: storeIcon })
      .addTo(map)
      .bindPopup(`<b>Fulfilling Shop: ${order.shopName || 'FastKirana Store'}</b>`)

    L.marker([destLat, destLng], { icon: destIcon })
      .addTo(map)
      .bindPopup('<b>Your Location</b>')

    const routeLine = L.polyline([[storeLat, storeLng], [destLat, destLng]], {
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

    let animationFrame: number
    let startTime = Date.now()
    
    const animateRider = () => {
      if (order.status === 'SHIPPED' && !order.deliveryLat) {
        const elapsed = (Date.now() - startTime) % 20000
        const t = elapsed / 20000
        const currentLat = storeLat + (destLat - storeLat) * t
        const currentLng = storeLng + (destLng - storeLng) * t
        riderMarker.setLatLng([currentLat, currentLng])
      } else if (order.deliveryLat && order.deliveryLng) {
        riderMarker.setLatLng([order.deliveryLat, order.deliveryLng])
      } else {
        riderMarker.setLatLng([storeLat, storeLng])
      }
      animationFrame = requestAnimationFrame(animateRider)
    }

    animateRider()

    return () => {
      cancelAnimationFrame(animationFrame)
      if (mapRef.current) {
        mapRef.current.remove()
        mapRef.current = null
      }
    }
  }, [leafletLoaded, order.status, order.deliveryLat, order.deliveryLng, order.address, order.shopName])

  const isScheduled = order.estimatedDelivery && order.createdAt && 
    (new Date(order.estimatedDelivery).getTime() - new Date(order.createdAt).getTime() > 15 * 60 * 1000)

  return (
    <div className="space-y-8 animate-fade-in">
      <PushNotificationConsent />
      
      {/* Visual Delivery Status Card */}
      <div className="bg-card border border-border p-4 min-[375px]:p-5 md:p-6 rounded-2xl shadow-sm space-y-5 md:space-y-6">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 border-b border-border/40 pb-4">
          <div>
            <span className="text-[10px] uppercase font-bold text-accent bg-accent/10 px-2 py-0.5 rounded-full">
              Live Tracking Active
            </span>
            <h1 className="text-xl font-black text-text-primary tracking-tight mt-1">
              {order.status === 'DELIVERED' 
                ? 'Order Delivered!' 
                : order.deliveryMethod === 'PICKUP' 
                ? 'Order Ready for Pickup!' 
                : isScheduled 
                ? 'Arriving at Scheduled Time' 
                : 'Arriving Soon'}
            </h1>
          </div>
          <div className="flex items-center gap-2 text-xs font-semibold text-text-secondary bg-muted px-3 py-1.5 rounded-xl border">
            <Clock className="h-4 w-4 text-primary" />
            <span>Placed at: {new Date(order.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
          </div>
        </div>

        {/* Fulfillment & Order Details Badge Row */}
        <div className="flex flex-wrap gap-2">
          {order.isB2B && (
            <span className="text-[10px] font-black text-blue-800 bg-blue-100 dark:bg-blue-900/30 dark:text-blue-400 px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1.5">
              <Building2 className="h-3.5 w-3.5 shrink-0" /> B2B Wholesale Order
            </span>
          )}
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
        </div>

                {!order.isB2B && order.shopName && (
          <div className="rounded-xl border border-primary/10 bg-primary/5 p-3 flex items-center justify-between text-xs font-semibold text-text-secondary">
            <div className="flex items-center gap-2">
              <Store className="h-4 w-4 text-primary shrink-0" />
              <div>
                <span className="text-text-primary font-bold">Fulfillment:</span> {order.shopName}
              </div>
            </div>
            {order.shopPhone && (
              <a href={`tel:${order.shopPhone}`} className="text-primary hover:underline font-black flex items-center gap-1.5 shrink-0">
                <Phone className="h-3.5 w-3.5" /> Support Hotline
              </a>
            )}
          </div>
        )}

        {/* Support Call Buttons */}
        <div className="flex flex-col sm:flex-row gap-3 pt-1">
          <a
            href="tel:+917054470303"
            className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2.5 border-2 border-primary/20 bg-primary/5 hover:bg-primary/10 text-primary font-black text-xs rounded-xl transition-all"
          >
            <Phone className="h-4 w-4" />
            Call Store Support (+91 70544 70303)
          </a>
          {order.deliveryMethod === 'PICKUP' && (
            <a
              href="https://www.google.com/maps/search/?api=1&query=FastKirana+Central+Hub+Main+Market+Road+Sector+3+Town+Center"
              target="_blank"
              rel="noopener noreferrer"
              className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2.5 border-2 border-accent/20 bg-accent/5 hover:bg-accent/10 text-accent font-black text-xs rounded-xl transition-all"
            >
              <Navigation className="h-4 w-4" />
              Get Store Directions
            </a>
          )}
        </div>

        {/* Live Embedded Tracking Map */}
        {order.status !== 'DELIVERED' && order.status !== 'CANCELLED' && (
          <div className="relative border border-border/80 rounded-2xl overflow-hidden shadow-sm h-[240px] w-full bg-muted/20 z-20">
            <div ref={mapContainerRef} className="h-full w-full z-10" />
            {!leafletLoaded && (
              <div className="absolute inset-0 flex flex-col items-center justify-center bg-card z-20 gap-2 text-xs font-semibold text-text-secondary">
                <Loader2 className="h-5 w-5 text-primary animate-spin" />
                <span>Loading live tracking map...</span>
              </div>
            )}
          </div>
        )}

        {/* Step Progression Map UI */}
        <div className="relative pl-8 space-y-6 before:absolute before:left-[11px] before:top-2 before:bottom-2 before:w-[2px] before:bg-border before:content-['']">
          {statusSteps.map((step, idx) => {
            const isCompleted = idx < activeStep
            const isActive = idx === activeStep
            const StepIcon = step.icon

            return (
              <div key={step.status} className="relative flex items-start gap-4">
                {/* Step Circle Pin */}
                <div
                  className={cn(
                    "absolute -left-[35px] flex h-6 w-6 items-center justify-center rounded-full border-2 transition-all duration-300",
                    isCompleted
                      ? "bg-accent border-accent text-white"
                      : isActive
                      ? "bg-primary border-primary text-white scale-110 shadow"
                      : "bg-card border-border text-text-muted"
                  )}
                >
                  {isCompleted ? (
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
                      isActive ? "text-primary" : isCompleted ? "text-text-primary" : "text-text-muted"
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

      {/* Simulated Tracking Map Panel */}
      {order.status !== 'DELIVERED' && order.status !== 'PENDING' && (
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
                <h4 className="font-bold text-text-primary">Ramesh Kumar</h4>
                <p className="text-[10px] text-accent font-semibold">FastKirana Delivery Executive</p>
              </div>
            </div>
            <a
              href="tel:+917054470303"
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
                <span className="text-text-primary font-bold">{order.address.houseNo}, {order.address.street}, {order.address.area}</span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Delivery Destination Card */}
      <div className="bg-card border border-border p-4 min-[375px]:p-5 rounded-2xl shadow-sm space-y-3">
        <h3 className="text-sm font-bold text-text-primary border-b border-border/40 pb-2 flex items-center gap-2">
          <MapPin className="h-4 w-4 text-primary" />
          Delivery Destination
        </h3>
        <div className="text-xs space-y-3">
          <p className="text-text-secondary leading-relaxed font-semibold">
            House No {order.address.houseNo}, {order.address.street}, {order.address.area}, {order.address.city} - {order.address.pincode}
          </p>
          <a
            href={
              order.address.lat && order.address.lng
                ? `https://www.google.com/maps/search/?api=1&query=${order.address.lat},${order.address.lng}`
                : `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
                    `${order.address.houseNo} ${order.address.street} ${order.address.area} ${order.address.city} ${order.address.pincode}`
                  )}`
            }
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 px-3.5 py-2 bg-accent/10 hover:bg-accent/20 text-accent text-xs font-black rounded-xl transition-all shadow-sm w-fit"
          >
            <Navigation className="h-3.5 w-3.5" />
            Locate Delivery Address on Google Maps
          </a>
        </div>
      </div>

      {/* Reciept mini summary */}
      <div className="bg-card border border-border p-4 min-[375px]:p-5 rounded-2xl shadow-sm space-y-3">
        <h3 className="text-sm font-bold text-text-primary border-b border-border/40 pb-2">
          Receipt details
        </h3>
        <div className="space-y-1.5 text-xs font-semibold text-text-secondary">
          {order.items.map((item) => (
            <div key={item.id} className="flex justify-between">
              <span>{item.name} (×{item.quantity})</span>
              <span>₹{item.price * item.quantity}</span>
            </div>
          ))}
          <div className="flex justify-between text-text-primary font-extrabold border-t border-border-light pt-2 mt-2">
            <span>Grand Total</span>
            <span className="text-primary">₹{order.total.toFixed(0)}</span>
          </div>
        </div>
      </div>

    </div>
  )
}
