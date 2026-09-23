'use client'

import { useEffect, useRef, useState } from 'react'

interface TrackerMapViewProps {
  order: {
    shopName?: string | null
    deliveryMethod?: string
    status: string
    deliveryLat: number | null
    deliveryLng: number | null
    address?: {
      lat?: number | null
      lng?: number | null
    } | null
  }
  storeLat: number
  storeLng: number
}

export function TrackerMapView({ order, storeLat, storeLng }: TrackerMapViewProps) {
  const [leafletLoaded, setLeafletLoaded] = useState(false)
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<any>(null)
  const riderMarkerRef = useRef<any>(null)
  const routeLineRef = useRef<any>(null)

  // Dynamically load Leaflet assets on client
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

  // Initialize map ONCE when Leaflet loads
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
      html: `<div class="relative flex items-center justify-center h-8 w-8 bg-amber-500 text-white rounded-full border-2 border-white shadow-lg text-xs animate-pulse">🚴</div>`,
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
  }, [leafletLoaded, storeLat, storeLng, order.address?.lat, order.address?.lng, order.deliveryLat, order.deliveryLng, order.deliveryMethod, order.shopName])

  // Update rider marker position smoothly without re-rendering the whole map
  useEffect(() => {
    if (!mapRef.current || !riderMarkerRef.current) return
    const destLat = order.address?.lat || storeLat + 0.004
    const destLng = order.address?.lng || storeLng + 0.005

    if (order.deliveryLat && order.deliveryLng) {
      riderMarkerRef.current.setLatLng([order.deliveryLat, order.deliveryLng])
      if (riderMarkerRef.current.getElement()) {
        riderMarkerRef.current.getElement().style.display = 'flex'
      }
      if (routeLineRef.current) {
        routeLineRef.current.setLatLngs([[order.deliveryLat, order.deliveryLng], [destLat, destLng]])
      }
    } else {
      if (riderMarkerRef.current.getElement()) {
        riderMarkerRef.current.getElement().style.display = 'none'
      }
      if (routeLineRef.current) {
        routeLineRef.current.setLatLngs([[storeLat, storeLng], [destLat, destLng]])
      }
    }
  }, [order.status, order.deliveryLat, order.deliveryLng, storeLat, storeLng, order.address?.lat, order.address?.lng])

  return (
    <div className="rounded-2xl overflow-hidden border border-border/70 shadow-sm relative h-64 sm:h-72 w-full bg-muted/20">
      <div ref={mapContainerRef} className="h-full w-full z-0" />
      <div className="absolute bottom-2.5 left-2.5 z-10 bg-card/90 backdrop-blur-md px-3 py-1.5 rounded-xl border border-border/60 text-[10px] font-bold text-text-secondary shadow-xs flex items-center gap-2">
        <span className="flex items-center gap-1">🏪 Darkstore</span>
        <span className="text-text-muted">•</span>
        <span className="flex items-center gap-1">🚴 Live Rider</span>
        <span className="text-text-muted">•</span>
        <span className="flex items-center gap-1">📍 Destination</span>
      </div>
    </div>
  )
}
