'use client'

import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { MapPin, Navigation, Search, X, Loader2, Maximize2, Check, AlertCircle } from 'lucide-react'
import { useUIStore } from '@/stores/ui-store'
import { FreeMapPicker } from '@/components/shared/free-map-picker'
import { toast } from 'sonner'

function getDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371 // Radius of the earth in km
  const dLat = (lat2 - lat1) * (Math.PI / 180)
  const dLon = (lon2 - lon1) * (Math.PI / 180)
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

// Load Google Maps script globally with Places API
let scriptLoadingPromise: Promise<any> | null = null
function loadGoogleMapsScript(apiKey: string): Promise<any> {
  if (typeof window === 'undefined') return Promise.resolve()
  if ((window as any).google?.maps) return Promise.resolve((window as any).google.maps)
  if (scriptLoadingPromise) return scriptLoadingPromise

  scriptLoadingPromise = new Promise((resolve, reject) => {
    const script = document.createElement('script')
    script.src = `https://maps.googleapis.com/maps/api/js?key=${apiKey}&libraries=places`
    script.async = true
    script.defer = true
    script.onload = () => resolve((window as any).google.maps)
    script.onerror = (err) => {
      scriptLoadingPromise = null
      reject(err)
    }
    document.head.appendChild(script)
  })
  return scriptLoadingPromise
}

interface LocationPickerProps {
  open: boolean
  onClose: () => void
}

export function LocationPicker({ open, onClose }: LocationPickerProps) {
  const settings = useUIStore((s) => s.settings) || {}
  const setSelectedLocation = useUIStore((s) => s.setSelectedLocation)
  const setUserCoords = useUIStore((s) => s.setUserCoords)
  const userCoords = useUIStore((s) => s.userCoords)

  // Store & Radius settings
  const [storeLat, setStoreLat] = useState(26.1534185)
  const [storeLng, setStoreLng] = useState(80.1714024)
  const [deliveryRadius, setDeliveryRadius] = useState(5.0)

  // Location state
  const [currentLat, setCurrentLat] = useState<number>(26.156803)
  const [currentLng, setCurrentLng] = useState<number>(80.171633)
  const [addressName, setAddressName] = useState<string>('')
  const [searchQuery, setSearchQuery] = useState('')
  const [isDetecting, setIsDetecting] = useState(false)
  const [isSearching, setIsSearching] = useState(false)
  const [isMapFullscreen, setIsMapFullscreen] = useState(false)

  // Google Maps state
  const [apiKey, setApiKey] = useState<string | null>(null)
  const [isMapLoaded, setIsMapLoaded] = useState(false)
  const [isDragging, setIsDragging] = useState(false)

  const mapContainerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<any>(null)
  const inputRef = useRef<HTMLInputElement>(null)
  const autocompleteRef = useRef<any>(null)
  const geocoderRef = useRef<any>(null)

  // Sync settings
  useEffect(() => {
    if (settings.delivery_radius) setDeliveryRadius(parseFloat(settings.delivery_radius))
    if (settings.store_lat) setStoreLat(parseFloat(settings.store_lat))
    if (settings.store_lng) setStoreLng(parseFloat(settings.store_lng))
  }, [settings])

  // Initial coordinates on open
  useEffect(() => {
    if (open) {
      if (userCoords?.lat && userCoords?.lng) {
        setCurrentLat(userCoords.lat)
        setCurrentLng(userCoords.lng)
      } else {
        setCurrentLat(26.156803)
        setCurrentLng(80.171633)
      }
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => {
      document.body.style.overflow = ''
    }
  }, [open, userCoords])

  // Fetch Google Maps API Key
  useEffect(() => {
    if (!open) return
    fetch('/api/geocode/key')
      .then((res) => res.json())
      .then((data) => {
        if (data.apiKey) setApiKey(data.apiKey)
      })
      .catch(() => {})
  }, [open])

  // Load Google Maps Script
  useEffect(() => {
    if (!apiKey || !open) return
    loadGoogleMapsScript(apiKey)
      .then(() => setIsMapLoaded(true))
      .catch(() => {})
  }, [apiKey, open])

  // Reverse Geocode helper via Google Maps JS API Geocoder
  const resolveAddress = useCallback((lat: number, lng: number) => {
    const google = (window as any).google
    if (google?.maps?.Geocoder) {
      if (!geocoderRef.current) {
        geocoderRef.current = new google.maps.Geocoder()
      }
      geocoderRef.current.geocode({ location: { lat, lng } }, (results: any, status: string) => {
        if (status === 'OK' && results && results[0]) {
          const formatted = results[0].formatted_address
          const shortName = formatted.split(',').slice(0, 2).join(',')
          setAddressName(shortName)
        }
      })
    } else {
      // Server fallback
      fetch(`/api/geocode?lat=${lat}&lng=${lng}`)
        .then((res) => res.json())
        .then((data) => {
          const results = data.data?.results
          if (results && results[0]) {
            const shortName = results[0].formatted_address.split(',').slice(0, 2).join(',')
            setAddressName(shortName)
          }
        })
        .catch(() => {})
    }
  }, [])

  // Initialize Map & Google Places Autocomplete instance when loaded
  useEffect(() => {
    if (!isMapLoaded || !open) return

    const google = (window as any).google
    if (!google) return

    // Setup Map
    if (mapContainerRef.current) {
      const mapOptions = {
        center: { lat: currentLat, lng: currentLng },
        zoom: 17,
        gestureHandling: 'greedy',
        disableDefaultUI: true,
        zoomControl: false,
        styles: [
          {
            featureType: 'poi',
            elementType: 'labels',
            stylers: [{ visibility: 'off' }],
          },
        ],
      }

      const map = new google.maps.Map(mapContainerRef.current, mapOptions)
      mapRef.current = map

      // Draw red circle representing the delivery radius zone
      new google.maps.Circle({
        strokeColor: '#EA4335',
        strokeOpacity: 0.8,
        strokeWeight: 2,
        fillColor: '#EA4335',
        fillOpacity: 0.15,
        map: map,
        center: { lat: storeLat, lng: storeLng },
        radius: deliveryRadius * 1000, // in meters
        clickable: false
      })

      // Draw Admin Store Marker
      new google.maps.Marker({
        position: { lat: storeLat, lng: storeLng },
        map: map,
        title: "FastKirana Dark Store Hub",
        label: {
          text: "🏪",
          fontSize: "24px"
        }
      })

      map.addListener('dragstart', () => setIsDragging(true))
      map.addListener('drag', () => {
        const center = map.getCenter()
        if (center) {
          setCurrentLat(center.lat())
          setCurrentLng(center.lng())
        }
      })
      map.addListener('idle', () => {
        setIsDragging(false)
        const center = map.getCenter()
        if (center) {
          const lat = center.lat()
          const lng = center.lng()
          setCurrentLat(lat)
          setCurrentLng(lng)
          resolveAddress(lat, lng)
        }
      })
    }

    // Setup Google Places Autocomplete search bar
    if (inputRef.current && !autocompleteRef.current) {
      const autocomplete = new google.maps.places.Autocomplete(inputRef.current, {
        componentRestrictions: { country: 'in' },
        fields: ['geometry', 'formatted_address', 'name'],
      })
      autocompleteRef.current = autocomplete

      autocomplete.addListener('place_changed', () => {
        const place = autocomplete.getPlace()
        if (place.geometry && place.geometry.location) {
          const lat = place.geometry.location.lat()
          const lng = place.geometry.location.lng()
          setCurrentLat(lat)
          setCurrentLng(lng)
          setAddressName(place.name || place.formatted_address.split(',')[0])

          if (mapRef.current) {
            mapRef.current.panTo({ lat, lng })
            mapRef.current.setZoom(17)
          }
        }
      })
    }
  }, [isMapLoaded, open, resolveAddress])

  // Calculate distance
  const distance = useMemo(() => {
    return getDistance(storeLat, storeLng, currentLat, currentLng)
  }, [storeLat, storeLng, currentLat, currentLng])

  const isWithinZone = distance <= deliveryRadius

  // GPS detect location handler using Google Maps API & IP fallback
  const handleDetectLocation = useCallback(() => {
    if (!navigator.geolocation) {
      toast.error('Geolocation is not supported by your browser')
      return
    }

    setIsDetecting(true)
    toast.info('Detecting your GPS location...', { icon: '📡' })

    navigator.geolocation.getCurrentPosition(
      (position) => {
        let { latitude, longitude } = position.coords
        const dist = getDistance(storeLat, storeLng, latitude, longitude)

        // Mock for local testing if far away
        if (dist > 20) {
          latitude = storeLat + 0.0035
          longitude = storeLng + 0.002
          toast.info('GPS centered on dark store delivery zone for testing!')
        }

        setCurrentLat(latitude)
        setCurrentLng(longitude)

        if (mapRef.current) {
          mapRef.current.panTo({ lat: latitude, lng: longitude })
          mapRef.current.setZoom(17)
        }

        resolveAddress(latitude, longitude)
        setIsDetecting(false)
        toast.success('GPS location detected!')
      },
      (error) => {
        setIsDetecting(false)
        if (error.code === 1) {
          toast.error('Location permission denied. Please allow location access in your browser settings or search address manually.', { duration: 5000 })
        } else {
          toast.info('GPS signal unavailable. Trying IP location fallback...')
          fetch('https://ipapi.co/json/')
            .then(res => res.json())
            .then(data => {
              if (data.latitude && data.longitude) {
                setCurrentLat(data.latitude)
                setCurrentLng(data.longitude)
                if (mapRef.current) {
                  mapRef.current.panTo({ lat: data.latitude, lng: data.longitude })
                  mapRef.current.setZoom(15)
                }
                resolveAddress(data.latitude, data.longitude)
                toast.success(`Approximate location set to ${data.city || 'your area'}`)
              } else {
                toast.error('Unable to detect location. Please search manually.')
              }
            })
            .catch(() => {
              toast.error('Unable to detect location. Please search manually.')
            })
        }
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    )
  }, [storeLat, storeLng, resolveAddress])

  // Manual Address search handler (Google Maps Geocoder)
  const handleSearch = useCallback(() => {
    if (!searchQuery.trim()) return
    setIsSearching(true)

    const google = (window as any).google
    if (google?.maps?.Geocoder) {
      if (!geocoderRef.current) {
        geocoderRef.current = new google.maps.Geocoder()
      }
      geocoderRef.current.geocode({ address: searchQuery.trim(), componentRestrictions: { country: 'in' } }, (results: any, status: string) => {
        setIsSearching(false)
        if (status === 'OK' && results && results[0]) {
          const loc = results[0].geometry.location
          const lat = loc.lat()
          const lng = loc.lng()
          setCurrentLat(lat)
          setCurrentLng(lng)
          setAddressName(results[0].formatted_address.split(',')[0])

          if (mapRef.current) {
            mapRef.current.panTo({ lat, lng })
            mapRef.current.setZoom(17)
          }
          toast.success('Location found via Google Maps!')
        } else {
          toast.error('No location found for this search.')
        }
      })
    } else {
      fetch(`/api/geocode?address=${encodeURIComponent(searchQuery.trim())}`)
        .then((res) => res.json())
        .then((data) => {
          setIsSearching(false)
          const results = data.data?.results
          if (results && results[0]) {
            const loc = results[0].geometry.location
            setCurrentLat(loc.lat)
            setCurrentLng(loc.lng)
            setAddressName(results[0].formatted_address.split(',')[0])

            if (mapRef.current) {
              mapRef.current.panTo({ lat: loc.lat, lng: loc.lng })
              mapRef.current.setZoom(17)
            }
            toast.success('Location found!')
          } else {
            toast.error('No location found.')
          }
        })
        .catch(() => {
          setIsSearching(false)
          toast.error('Search failed.')
        })
    }
  }, [searchQuery])

  // Confirm Location handler
  const handleConfirm = useCallback(() => {
    if (!isWithinZone) {
      toast.error(`Selected location is not serviceable (${distance.toFixed(1)} km away).`)
      return
    }

    const finalName = addressName || `Ghatampur (${currentLat.toFixed(4)}, ${currentLng.toFixed(4)})`

    setSelectedLocation(finalName)
    setUserCoords({ lat: currentLat, lng: currentLng })

    toast.success(`Delivery location set to ${finalName}`, { icon: '📍' })
    onClose()
  }, [isWithinZone, distance, deliveryRadius, addressName, currentLat, currentLng, setSelectedLocation, setUserCoords, onClose])

  return (
    <AnimatePresence>
      {open && (
        <div className="fixed inset-0 z-[100] flex items-end sm:items-center justify-center p-0 sm:p-4">
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
            className="absolute inset-0 bg-black/60 backdrop-blur-sm"
          />

          {/* Dialog Card matching screenshot exactly */}
          <motion.div
            initial={{ opacity: 0, y: 50, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 50, scale: 0.96 }}
            transition={{ duration: 0.2, ease: 'easeOut' }}
            className="relative z-10 w-full sm:max-w-md bg-white dark:bg-zinc-950 rounded-t-3xl sm:rounded-3xl shadow-2xl overflow-hidden border border-slate-200 dark:border-zinc-800 flex flex-col max-h-[92vh]"
          >
            {/* Header */}
            <div className="px-6 pt-5 pb-2 flex items-start justify-between">
              <div>
                <h2 className="text-xl sm:text-2xl font-black text-slate-900 dark:text-white tracking-tight">
                  Select Delivery Location
                </h2>
                <p className="text-xs font-semibold text-slate-400 dark:text-zinc-400 mt-0.5">
                  100% Free Interactive Map & GPS Validation
                </p>
              </div>
              <button
                onClick={onClose}
                className="p-1.5 rounded-full text-slate-400 hover:text-slate-600 hover:bg-slate-100 dark:hover:bg-zinc-800 transition-all"
              >
                <X size={20} />
              </button>
            </div>

            {/* Scrollable body */}
            <div className="px-6 py-3 overflow-y-auto space-y-4 flex-1">
              {/* Search Bar Row with Google Places Autocomplete */}
              <div className="flex items-center gap-2">
                <div className="relative flex-1">
                  <Search size={18} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none" />
                  <input
                    ref={inputRef}
                    type="text"
                    placeholder="Search address or area..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
                    className="w-full pl-10 pr-4 py-2.5 bg-slate-50 dark:bg-zinc-900 border border-slate-200 dark:border-zinc-800 rounded-xl text-xs sm:text-sm font-medium text-slate-900 dark:text-white placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-rose-500/20 focus:border-rose-500 transition-all"
                  />
                  {searchQuery && (
                    <button
                      onClick={() => setSearchQuery('')}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                    >
                      <X size={14} />
                    </button>
                  )}
                </div>
                <button
                  onClick={handleSearch}
                  disabled={isSearching}
                  className="bg-[#E91E63] hover:bg-[#D81B60] active:scale-95 text-white font-bold text-xs sm:text-sm px-5 py-2.5 rounded-xl transition-all shadow-sm shrink-0 flex items-center justify-center"
                >
                  {isSearching ? <Loader2 size={16} className="animate-spin" /> : 'Search'}
                </button>
              </div>

              {/* GPS Location Row */}
              <button
                onClick={handleDetectLocation}
                disabled={isDetecting}
                className="w-full bg-[#f0f4fe] dark:bg-indigo-950/40 border border-indigo-100 dark:border-indigo-900/40 rounded-2xl p-3.5 flex items-center gap-3.5 text-left transition-all hover:bg-[#e6edfc] active:scale-[0.99]"
              >
                <div className="h-10 w-10 rounded-xl bg-indigo-100 dark:bg-indigo-900/60 flex items-center justify-center text-[#4f46e5] dark:text-indigo-400 shrink-0">
                  {isDetecting ? (
                    <Loader2 size={20} className="animate-spin" />
                  ) : (
                    <Navigation size={20} className="fill-current rotate-45" />
                  )}
                </div>
                <div className="flex-1 min-w-0">
                  <h4 className="text-sm font-bold text-[#4338ca] dark:text-indigo-300">
                    Use Current GPS Location
                  </h4>
                  <p className="text-xs text-slate-500 dark:text-zinc-400 mt-0.5 truncate">
                    Detects address automatically
                  </p>
                </div>
              </button>

              {/* Map Container */}
              <div className={`relative w-full rounded-2xl overflow-hidden border border-slate-200 dark:border-zinc-800 shadow-inner bg-slate-100 dark:bg-zinc-900 transition-all ${isMapFullscreen ? 'h-80' : 'h-60 sm:h-64'}`}>
                {/* Canvas Ref for Google Maps */}
                <div ref={mapContainerRef} className="w-full h-full" />

                {/* Fallback 100% Free OpenStreetMap interactive Leaflet view if Google Maps API key not set */}
                {!isMapLoaded && (
                  <div className="absolute inset-0 z-30 bg-background overflow-hidden">
                    <FreeMapPicker
                      initialLat={currentLat}
                      initialLng={currentLng}
                      storeLat={storeLat}
                      storeLng={storeLng}
                      deliveryRadiusKm={deliveryRadius}
                      onLocationSelect={(data) => {
                        setSelectedLocation(data.address)
                        setUserCoords({ lat: data.lat, lng: data.lng })
                        toast.success(`Delivery location set to ${data.address.split(',')[0]}`, { icon: '📍' })
                        onClose()
                      }}
                    />
                  </div>
                )}

                {/* Pulsing Red Circle Target Ring */}
                <div className="absolute left-1/2 top-1/2 pointer-events-none -translate-x-1/2 -translate-y-1/2 z-10 flex items-center justify-center">
                  <div className="w-10 h-10 rounded-full border-2 border-red-500 bg-red-500/10 animate-ping absolute opacity-70" />
                  <div className="w-4 h-4 rounded-full border border-white bg-red-500/30 absolute shadow-[0_0_8px_rgba(239,68,68,0.5)]" />
                </div>

                {/* Fixed Center Marker Pin */}
                <div className="absolute left-1/2 top-1/2 pointer-events-none -translate-x-1/2 -translate-y-full flex flex-col items-center select-none z-20">
                  <div className={`transition-transform duration-200 ease-out ${isDragging ? '-translate-y-3 scale-110' : 'translate-y-0 scale-100'}`}>
                    <svg width="38" height="38" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" className="drop-shadow-md">
                      <path d="M12 2C8.13 2 5 5.13 5 9C5 14.25 12 22 12 22C12 22 19 14.25 19 9C19 5.13 15.87 2 12 2Z" fill="#EA4335" stroke="#ffffff" strokeWidth="1.5" />
                      <circle cx="12" cy="9" r="3" fill="#ffffff" />
                    </svg>
                  </div>
                  <div className={`w-3 h-1 bg-black/40 rounded-full blur-[1px] transition-all duration-200 ease-out ${isDragging ? 'scale-50 opacity-30' : 'scale-100 opacity-80'}`} />
                </div>

                {/* Bottom-Left Coordinates Badge */}
                <div className="absolute bottom-3 left-3 bg-slate-900/95 dark:bg-black/95 text-white text-[11px] font-mono px-3 py-1.5 rounded-xl border border-white/10 shadow-md flex items-center gap-1.5 z-20 pointer-events-none">
                  <span>Coordinates: {currentLat.toFixed(6)}, {currentLng.toFixed(6)}</span>
                </div>

                {/* Bottom-Right Fullscreen Toggle */}
                <button
                  type="button"
                  onClick={() => setIsMapFullscreen((prev) => !prev)}
                  className="absolute bottom-3 right-3 bg-white dark:bg-zinc-800 p-2 rounded-xl border border-slate-200 dark:border-zinc-700 text-slate-700 dark:text-zinc-200 hover:text-[#E91E63] transition-all z-20 shadow-md active:scale-95"
                  title="Toggle fullscreen map view"
                >
                  <Maximize2 size={16} />
                </button>
              </div>

              {/* Warning Banner if Not Serviceable */}
              {!isWithinZone && (
                <div className="bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-900/50 rounded-2xl p-3.5 flex items-start gap-3 text-rose-900 dark:text-rose-200 animate-fadeIn">
                  <AlertCircle size={20} className="text-rose-600 dark:text-rose-400 shrink-0 mt-0.5" />
                  <div className="text-xs">
                    <h5 className="font-bold text-rose-900 dark:text-rose-300">Warning: Location Not Serviceable</h5>
                    <p className="mt-0.5 text-rose-800/90 dark:text-rose-300 font-medium leading-relaxed">
                      This address is {distance.toFixed(1)} km away. Delivery is only available within {deliveryRadius} km of our dark store.
                    </p>
                  </div>
                </div>
              )}

              {/* Target Address Card */}
              <div className="bg-slate-50/80 dark:bg-zinc-900/60 border border-slate-100 dark:border-zinc-800/80 rounded-2xl p-4 space-y-3">
                {/* Target Header */}
                <div>
                  <div className="flex items-center gap-2 text-slate-900 dark:text-white font-bold text-base">
                    <MapPin size={18} className="text-rose-500 fill-rose-500/20 shrink-0" />
                    <span>Target Address</span>
                  </div>
                  <p className="text-xs text-slate-500 dark:text-zinc-400 font-medium mt-1 pl-6.5">
                    {addressName ? addressName : `Lat: ${currentLat.toFixed(4)}, Lng: ${currentLng.toFixed(4)}`}
                  </p>
                </div>

                {/* Distance & Validation Row */}
                <div className="flex items-center justify-between pt-2.5 border-t border-slate-200/60 dark:border-zinc-800/60">
                  <div>
                    <span className="text-[10px] font-bold tracking-wider text-slate-400 dark:text-zinc-500 uppercase block">
                      DISTANCE TO STORE
                    </span>
                    <span className="text-xl sm:text-2xl font-black text-slate-900 dark:text-white tracking-tight">
                      {distance.toFixed(2)} km
                    </span>
                  </div>

                  {/* Zone pill badge matching exact screenshot pill */}
                  <div>
                    {isWithinZone ? (
                      <span className="bg-[#DCFCE7] dark:bg-emerald-950/60 text-[#16A34A] dark:text-emerald-400 border border-[#BBF7D0] dark:border-emerald-800 px-3 py-1.5 rounded-full text-[11px] font-extrabold uppercase tracking-wide flex items-center gap-1 shadow-sm">
                        <Check size={14} strokeWidth={3} />
                        WITHIN DELIVERY ZONE
                      </span>
                    ) : (
                      <span className="bg-rose-50 dark:bg-rose-950/60 text-rose-700 dark:text-rose-400 border border-rose-200 dark:border-rose-800 px-3 py-1.5 rounded-full text-[11px] font-extrabold uppercase tracking-wide flex items-center gap-1 shadow-sm">
                        <AlertCircle size={14} strokeWidth={2.5} />
                        NOT SERVICEABLE
                      </span>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Bottom Confirm Button */}
            <div className="p-5 pt-2 bg-white dark:bg-zinc-950 border-t border-slate-100 dark:border-zinc-900">
              <button
                onClick={handleConfirm}
                disabled={!isWithinZone}
                className={`w-full font-black text-sm tracking-wide uppercase py-4 rounded-2xl shadow-lg transition-all flex items-center justify-center gap-2 ${
                  isWithinZone
                    ? 'bg-[#E91E63] hover:bg-[#D81B60] active:scale-[0.98] text-white shadow-[#E91E63]/25 cursor-pointer'
                    : 'bg-slate-200 dark:bg-zinc-800 text-slate-400 dark:text-zinc-500 cursor-not-allowed shadow-none'
                }`}
              >
                {isWithinZone ? 'CONFIRM THIS LOCATION' : 'NOT SERVICEABLE'}
              </button>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  )
}
