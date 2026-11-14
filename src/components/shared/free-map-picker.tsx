'use client'

import { useEffect, useRef, useState, useCallback } from 'react'
import { Navigation, Search, X, Loader2, MapPin, Check } from 'lucide-react'
import { toast } from 'sonner'
import { getDistanceKm } from '@/lib/distance'
import { cn } from '@/lib/utils'

interface LocationData {
  lat: number
  lng: number
  address: string
  street: string
  city: string
  pincode: string
  houseNo?: string
  label?: string
}

interface FreeMapPickerProps {
  initialLat?: number | null
  initialLng?: number | null
  initialHouseNo?: string
  initialLabel?: string
  storeLat?: number
  storeLng?: number
  originName?: string
  deliveryRadiusKm?: number
  onLocationSelect: (data: LocationData) => void
  onClose?: () => void
}

let leafletScriptPromise: Promise<any> | null = null

function loadLeaflet(): Promise<any> {
  if (typeof window === 'undefined') return Promise.resolve()
  if ((window as any).L) return Promise.resolve((window as any).L)
  if (leafletScriptPromise) return leafletScriptPromise

  // Inject CSS
  if (!document.getElementById('leaflet-css-cdn')) {
    const link = document.createElement('link')
    link.id = 'leaflet-css-cdn'
    link.rel = 'stylesheet'
    link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css'
    document.head.appendChild(link)
  }

  // Inject JS
  leafletScriptPromise = new Promise((resolve, reject) => {
    const script = document.createElement('script')
    script.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js'
    script.async = true
    script.onload = () => resolve((window as any).L)
    script.onerror = (err) => {
      leafletScriptPromise = null
      reject(err)
    }
    document.head.appendChild(script)
  })

  return leafletScriptPromise
}

export function FreeMapPicker({
  initialLat = 26.1534185,
  initialLng = 80.1714024,
  initialHouseNo = '',
  initialLabel = 'Home',
  storeLat = 26.1534185,
  storeLng = 80.1714024,
  originName,
  deliveryRadiusKm = 2.0,
  onLocationSelect,
  onClose,
}: FreeMapPickerProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const mapInstanceRef = useRef<any>(null)
  
  const [currentLat, setCurrentLat] = useState<number>(initialLat || storeLat)
  const [currentLng, setCurrentLng] = useState<number>(initialLng || storeLng)
  const [houseNo, setHouseNo] = useState<string>(initialHouseNo)
  const [selectedTag, setSelectedTag] = useState<string>(initialLabel)
  const [searchQuery, setSearchQuery] = useState('')
  const [isSearching, setIsSearching] = useState(false)
  const [isDetecting, setIsDetecting] = useState(false)
  const [isLoadingMap, setIsLoadingMap] = useState(true)
  const [formattedAddress, setFormattedAddress] = useState('Detecting address...')
  const [city, setCity] = useState('')
  const [pincode, setPincode] = useState('')

  const distanceKm = getDistanceKm(storeLat, storeLng, currentLat, currentLng)
  const isServiceable = distanceKm <= deliveryRadiusKm

  // OpenStreetMap Reverse Geocoding (Free Nominatim API)
  const resolveAddressOSM = useCallback(async (lat: number, lng: number) => {
    try {
      const res = await fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&zoom=18&addressdetails=1`)
      if (!res.ok) return
      const data = await res.json()
      if (data && data.address) {
        const addrObj = data.address
        const detectedCity = addrObj.city || addrObj.town || addrObj.village || addrObj.subdistrict || 'Kanpur'
        const detectedPincode = addrObj.postcode || ''
        const road = addrObj.road || addrObj.suburb || addrObj.neighbourhood || ''
        const fullAddr = data.display_name || `${road}, ${detectedCity}`
        
        setFormattedAddress(fullAddr)
        setCity(detectedCity)
        setPincode(detectedPincode)
      }
    } catch {
      setFormattedAddress(`Location (${lat.toFixed(4)}, ${lng.toFixed(4)})`)
    }
  }, [])

  // Initialize Free OpenStreetMap Leaflet Map
  useEffect(() => {
    let active = true

    loadLeaflet()
      .then((L) => {
        if (!active || !mapContainerRef.current) return

        if (!mapInstanceRef.current) {
          const map = L.map(mapContainerRef.current, {
            center: [currentLat, currentLng],
            zoom: 16,
            zoomControl: false,
          })
          mapInstanceRef.current = map

          // OpenStreetMap Tile Layer (100% Free)
          L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '© OpenStreetMap',
          }).addTo(map)

          // Delivery Zone Circle
          L.circle([storeLat, storeLng], {
            color: '#EA4335',
            fillColor: '#EA4335',
            fillOpacity: 0.12,
            radius: deliveryRadiusKm * 1000,
          }).addTo(map)

          // Store Marker
          const storeIcon = L.divIcon({
            html: '<div style="font-size: 26px;">🏪</div>',
            className: 'custom-store-pin',
            iconSize: [30, 30],
            iconAnchor: [15, 15],
          })
          L.marker([storeLat, storeLng], { icon: storeIcon }).addTo(map).bindPopup('FastMinute Dark Store Hub')

          // Update location on map move
          map.on('move', () => {
            const center = map.getCenter()
            setCurrentLat(center.lat)
            setCurrentLng(center.lng)
          })

          map.on('moveend', () => {
            const center = map.getCenter()
            resolveAddressOSM(center.lat, center.lng)
          })

          // Initial reverse geocode
          resolveAddressOSM(currentLat, currentLng)
        }
        setIsLoadingMap(false)
      })
      .catch((err) => {
        console.error('Failed to load Leaflet:', err)
        setIsLoadingMap(false)
      })

    return () => {
      active = false
    }
  }, [storeLat, storeLng, deliveryRadiusKm, resolveAddressOSM])

  // Detect GPS Location
  const handleDetectGPS = () => {
    if (!navigator.geolocation) {
      toast.error('Geolocation is not supported by your browser')
      return
    }

    setIsDetecting(true)
    toast.info('Detecting your GPS coordinates...', { icon: '📡' })

    navigator.geolocation.getCurrentPosition(
      (position) => {
        const { latitude, longitude } = position.coords
        setCurrentLat(latitude)
        setCurrentLng(longitude)

        if (mapInstanceRef.current) {
          mapInstanceRef.current.setView([latitude, longitude], 17)
        }

        resolveAddressOSM(latitude, longitude)
        setIsDetecting(false)
        toast.success('GPS Location Detected!')
      },
      (error) => {
        setIsDetecting(false)
        if (error.code === 1) {
          toast.error('Location permission denied. Please allow location access in browser settings.')
        } else {
          toast.info('GPS signal unavailable. Trying IP location...')
          fetch('https://ipapi.co/json/')
            .then((res) => res.json())
            .then((data) => {
              if (data.latitude && data.longitude) {
                setCurrentLat(data.latitude)
                setCurrentLng(data.longitude)
                if (mapInstanceRef.current) {
                  mapInstanceRef.current.setView([data.latitude, data.longitude], 15)
                }
                resolveAddressOSM(data.latitude, data.longitude)
                toast.success(`Approximate location set to ${data.city || 'your area'}`)
              }
            })
            .catch(() => toast.error('Unable to detect location. Please search manually.'))
        }
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    )
  }

  // Free OpenStreetMap Search (Nominatim API)
  const handleSearchOSM = async () => {
    if (!searchQuery.trim()) return
    setIsSearching(true)

    try {
      const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(searchQuery.trim())}&countrycodes=in&limit=1`)
      const data = await res.json()
      if (data && data[0]) {
        const lat = parseFloat(data[0].lat)
        const lng = parseFloat(data[0].lon)
        setCurrentLat(lat)
        setCurrentLng(lng)

        if (mapInstanceRef.current) {
          mapInstanceRef.current.setView([lat, lng], 17)
        }
        resolveAddressOSM(lat, lng)
        toast.success('Location found!')
      } else {
        toast.error('No matching location found.')
      }
    } catch {
      toast.error('Search failed. Please try again.')
    } finally {
      setIsSearching(false)
    }
  }

  const handleConfirm = () => {
    if (!isServiceable) {
      toast.error(`Location is outside delivery zone (${distanceKm.toFixed(1)} km away). We deliver up to ${deliveryRadiusKm} km.`)
      return
    }

    onLocationSelect({
      lat: currentLat,
      lng: currentLng,
      address: formattedAddress,
      street: formattedAddress.split(',')[0] || 'Doorstep',
      city: city || 'Kanpur',
      pincode: pincode || '209206',
      houseNo: houseNo.trim() || '.',
      label: selectedTag || 'Home',
    })
  }

  return (
    <div className="bg-card border border-border rounded-3xl p-4 sm:p-5 shadow-2xl space-y-3.5 max-w-md w-full mx-auto animate-in fade-in zoom-in-95 duration-200">
      <div className="flex justify-between items-start border-b border-border/40 pb-3">
        <div>
          <h3 className="font-black text-text-primary text-base flex items-center gap-1.5">
            <span className="text-primary">📍</span>
            <span>Pin Exact Delivery Location</span>
          </h3>
          <p className="text-[11px] text-text-secondary font-medium mt-0.5">
            Move map to place pin at your door / gate
          </p>
        </div>
        {onClose && (
          <button
            onClick={onClose}
            className="p-1.5 rounded-xl hover:bg-muted text-text-secondary hover:text-text-primary transition-colors cursor-pointer"
            aria-label="Close"
          >
            <X size={18} />
          </button>
        )}
      </div>

      {/* Search Bar */}
      <div className="flex items-center gap-2">
        <div className="relative flex-1">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-text-muted" />
          <input
            type="text"
            placeholder="Search colony, area or street..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleSearchOSM()}
            className="w-full pl-9 pr-3 py-2 text-xs rounded-xl border border-border bg-muted/30 focus:outline-none focus:border-primary font-medium"
          />
        </div>
        <button
          onClick={handleSearchOSM}
          disabled={isSearching}
          className="px-3.5 py-2 bg-primary hover:bg-primary/90 text-white text-xs font-bold rounded-xl transition-all cursor-pointer disabled:opacity-50 shrink-0 shadow-2xs"
        >
          {isSearching ? <Loader2 size={14} className="animate-spin" /> : 'Search'}
        </button>
      </div>

      {/* GPS Button */}
      <button
        type="button"
        onClick={handleDetectGPS}
        disabled={isDetecting}
        className="w-full bg-primary/10 hover:bg-primary/15 text-primary border border-primary/20 rounded-xl p-2.5 flex items-center justify-center gap-2 transition-all text-xs font-bold cursor-pointer active:scale-98"
      >
        {isDetecting ? <Loader2 size={15} className="animate-spin" /> : <Navigation size={15} className="rotate-45" />}
        <span>Detect My Exact GPS Location</span>
      </button>

      {/* Map Container */}
      <div className="relative w-full h-56 rounded-2xl overflow-hidden border border-border bg-muted shadow-inner">
        <div ref={mapContainerRef} className="w-full h-full" />

        {isLoadingMap && (
          <div className="absolute inset-0 bg-background/80 backdrop-blur-xs flex items-center justify-center">
            <Loader2 size={24} className="animate-spin text-primary" />
          </div>
        )}

        {/* Center Target Pin with Zomato/Swiggy Bobbing effect */}
        <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-full pointer-events-none z-20 flex flex-col items-center">
          <MapPin size={34} className="text-primary fill-primary/20 drop-shadow-md transition-transform duration-200" />
          <div className="w-2.5 h-1 bg-black/35 rounded-full blur-[1px]" />
        </div>
      </div>

      {/* Zomato-Style Bottom Sheet: Address Details + Flat No + Tags */}
      <div className="p-3.5 bg-muted/30 dark:bg-zinc-900/60 rounded-2xl border border-border/80 space-y-2.5">
        {/* Address Mention Header */}
        <div className="flex items-start justify-between gap-2">
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-1.5 text-text-primary font-black text-xs">
              <span className="text-primary text-sm">📍</span>
              <span className="truncate">{formattedAddress.split(',').slice(0, 2).join(',') || formattedAddress}</span>
            </div>
            <p className="text-[10.5px] text-text-secondary truncate mt-0.5 font-medium">
              {formattedAddress}
            </p>
          </div>
          <span className={cn(
            'text-[9px] font-black px-2 py-0.5 rounded-full shrink-0 border',
            isServiceable
              ? 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/20'
              : 'bg-rose-500/10 text-rose-600 dark:text-rose-400 border-rose-500/20'
          )}>
            {isServiceable ? `${distanceKm.toFixed(1)} km • Deliverable` : `${distanceKm.toFixed(1)} km • Out of Zone`}
          </span>
        </div>

        {/* Address Details Input */}
        <div>
          <label className="text-[10.5px] font-bold text-text-secondary flex items-center justify-between mb-1">
            <span>Enter Your Address</span>
          </label>
          <input
            type="text"
            value={houseNo}
            onChange={(e) => setHouseNo(e.target.value)}
            placeholder="Enter Your Address"
            className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-white dark:bg-zinc-800 focus:outline-none focus:border-primary font-medium shadow-2xs"
          />
        </div>

        {/* Tag Selection Chips [Home] [Work] [Other] */}
        <div className="flex items-center gap-2">
          {[
            { id: 'Home', icon: '🏠', label: 'Home' },
            { id: 'Work', icon: '💼', label: 'Work' },
            { id: 'Other', icon: '📍', label: 'Other' },
          ].map((tag) => (
            <button
              key={tag.id}
              type="button"
              onClick={() => setSelectedTag(tag.id)}
              className={cn(
                'flex-1 py-1.5 px-2 rounded-xl text-xs font-bold border transition-all cursor-pointer flex items-center justify-center gap-1.5 shadow-2xs',
                selectedTag === tag.id
                  ? 'bg-primary text-white border-primary shadow-xs'
                  : 'bg-white dark:bg-zinc-800 text-text-secondary border-border/80 hover:bg-muted'
              )}
            >
              <span>{tag.icon}</span>
              <span>{tag.label}</span>
            </button>
          ))}
        </div>

        {/* Save & Deliver Here Button */}
        <button
          type="button"
          onClick={handleConfirm}
          disabled={!isServiceable}
          className="w-full py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white font-black text-xs rounded-xl transition-all shadow-md active:scale-98 cursor-pointer disabled:opacity-50 flex items-center justify-center gap-1.5 mt-1"
        >
          <Check size={16} /> Save Address & Deliver Here
        </button>
      </div>
    </div>
  )
}
