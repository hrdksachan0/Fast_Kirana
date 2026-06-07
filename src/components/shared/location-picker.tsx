'use client'

import { useState, useEffect, useCallback, useRef, useMemo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { MapPin, Navigation, Search, X, Loader2, ChevronRight, Clock, CheckCircle2 } from 'lucide-react'
import { useUIStore } from '@/stores/ui-store'
import { toast } from 'sonner'

// Dynamic town areas — will be populated based on detected location
const DEFAULT_AREAS = [
  { name: 'Main Market', subtitle: 'Town Center (0.0 km)', emoji: '🏪', lat: 12.9352, lng: 77.6245 },
  { name: 'Station Road', subtitle: 'Near Railway Station (1.5 km)', emoji: '🚉', lat: 12.9452, lng: 77.6345 },
  { name: 'College Road', subtitle: 'Near University (1.5 km)', emoji: '🎓', lat: 12.9252, lng: 77.6145 },
  { name: 'Hospital Road', subtitle: 'Medical District (3.5 km)', emoji: '🏥', lat: 12.9552, lng: 77.6045 },
  { name: 'Faraway Suburb', subtitle: 'Outskirts of Town (8.2 km)', emoji: '🏡', lat: 12.9352, lng: 77.7000 },
]

function getDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371 // Radius of the earth in km
  const dLat = (lat2 - lat1) * (Math.PI / 180)
  const dLon = (lon2 - lon1) * (Math.PI / 180)
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c // Distance in km
}

interface LocationPickerProps {
  open: boolean
  onClose: () => void
}

export function LocationPicker({ open, onClose }: LocationPickerProps) {
  const [searchQuery, setSearchQuery] = useState('')
  const [isDetecting, setIsDetecting] = useState(false)
  const [recentLocations, setRecentLocations] = useState<string[]>([])
  const [detectedArea, setDetectedArea] = useState<string | null>(null)
  const [deliveryAvailable, setDeliveryAvailable] = useState<boolean | null>(null)
  const [deliveryRadius, setDeliveryRadius] = useState(5.0)
  const [storeLat, setStoreLat] = useState(26.1534185)
  const [storeLng, setStoreLng] = useState(80.1714024)
  const inputRef = useRef<HTMLInputElement>(null)

  // Fetch delivery radius and store coordinates from settings
  useEffect(() => {
    if (open) {
      fetch('/api/settings')
        .then(res => res.json())
        .then(data => {
          if (data.delivery_radius) {
            setDeliveryRadius(parseFloat(data.delivery_radius))
          }
          if (data.store_lat) {
            setStoreLat(parseFloat(data.store_lat))
          }
          if (data.store_lng) {
            setStoreLng(parseFloat(data.store_lng))
          }
        })
        .catch(err => console.error('Error loading settings in location-picker:', err))
    }
  }, [open])

  const setSelectedLocation = useUIStore((s) => s.setSelectedLocation)
  const setUserCoords = useUIStore((s) => s.setUserCoords)
  const selectedLocation = useUIStore((s) => s.selectedLocation)

  // Dynamically compute areas around the store's lat/lng
  const areas = useMemo(() => [
    { name: 'Ghatampur Market', subtitle: 'Town Center (0.0 km)', emoji: '🏪', lat: storeLat, lng: storeLng },
    { name: 'Ghatampur Station Road', subtitle: 'Near Railway Station (1.5 km)', emoji: '🚉', lat: storeLat + 0.01, lng: storeLng + 0.01 },
    { name: 'Kanpur Road', subtitle: 'Near Highway (1.5 km)', emoji: '🛣️', lat: storeLat - 0.01, lng: storeLng - 0.01 },
    { name: 'Community Health Centre', subtitle: 'Medical District (3.5 km)', emoji: '🏥', lat: storeLat + 0.02, lng: storeLng - 0.02 },
    { name: 'Hamirpur Road Suburb', subtitle: 'Outskirts of Town (8.2 km)', emoji: '🏡', lat: storeLat, lng: storeLng + 0.082 },
  ], [storeLat, storeLng])

  // Load recent locations from localStorage
  useEffect(() => {
    if (open) {
      const saved = localStorage.getItem('fk-recent-locations')
      if (saved) {
        try { setRecentLocations(JSON.parse(saved)) } catch {}
      }
      setDetectedArea(null)
      setDeliveryAvailable(null)
      // Focus search input after animation
      setTimeout(() => inputRef.current?.focus(), 300)
    }
  }, [open])

  const addToRecent = useCallback((location: string) => {
    setRecentLocations((prev) => {
      const updated = [location, ...prev.filter((l) => l !== location)].slice(0, 5)
      localStorage.setItem('fk-recent-locations', JSON.stringify(updated))
      return updated
    })
  }, [])

  const handleSelectLocation = useCallback((name: string) => {
    const matchedArea = areas.find((a: any) => a.name === name)
    const lat = matchedArea ? matchedArea.lat : storeLat
    const lng = matchedArea ? matchedArea.lng : storeLng

    const dist = getDistance(storeLat, storeLng, lat, lng)
    if (dist > deliveryRadius) {
      setDeliveryAvailable(false)
      toast.error(`Location is too far! (${dist.toFixed(1)} km away. Delivery radius is ${deliveryRadius} km.)`, {
        duration: 4000
      })
      return
    }

    setSelectedLocation(name)
    setUserCoords({ lat, lng })
    addToRecent(name)
    setDeliveryAvailable(true)
    
    // Brief confirmation before closing
    setTimeout(() => {
      onClose()
      toast.success(`Delivering to ${name}`, {
        icon: '📍',
        duration: 2000,
      })
    }, 400)
  }, [setSelectedLocation, setUserCoords, addToRecent, onClose, deliveryRadius])

  const handleDetectLocation = useCallback(() => {
    if (!navigator.geolocation) {
      toast.error('Geolocation is not supported by your browser')
      return
    }

    setIsDetecting(true)
    navigator.geolocation.getCurrentPosition(
      (position) => {
        let { latitude, longitude } = position.coords
        
        // Calculate distance from store
        const dist = getDistance(storeLat, storeLng, latitude, longitude)
        
        // If developer testing from far away (> 20 km), automatically mock to nearby (2.5 km away)
        if (dist > 20) {
          toast.warning(`Detected GPS is ${dist.toFixed(0)} km away. Mocking to 2.5 km for local testing!`)
          latitude = storeLat + 0.015 // ~2.2 km away
          longitude = storeLng + 0.015
          setIsDetecting(false)
          setDetectedArea("Ghatampur Station Road")
          setDeliveryAvailable(true)
          handleSelectLocation("Ghatampur Station Road")
          return
        } else if (dist > deliveryRadius) {
          setIsDetecting(false)
          setDeliveryAvailable(false)
          toast.error(`Detected location is too far! (${dist.toFixed(1)} km away. Delivery radius is ${deliveryRadius} km.)`, {
            duration: 4000
          })
          return
        }
        
        setUserCoords({ lat: latitude, lng: longitude })

        // Reverse geocode - use a readable fallback
        const locationName = `${latitude.toFixed(4)}°N, ${longitude.toFixed(4)}°E`
        // Try reverse geocoding with Nominatim (free, no API key)
        fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}&zoom=16&addressdetails=1`)
          .then((res) => res.json())
          .then((data) => {
            const area = data.address?.suburb
              || data.address?.neighbourhood
              || data.address?.city_district
              || data.address?.town
              || data.address?.city
              || locationName
            setIsDetecting(false)
            setDetectedArea(area)
            setDeliveryAvailable(true)
            handleSelectLocation(area)
          })
          .catch(() => {
            setIsDetecting(false)
            setDetectedArea(locationName)
            handleSelectLocation(locationName)
          })
      },
      (error) => {
        setIsDetecting(false)
        switch (error.code) {
          case error.PERMISSION_DENIED:
            toast.error('Location permission denied. Please enable it in your browser settings.')
            break
          case error.POSITION_UNAVAILABLE:
            toast.error('Location unavailable. Please try again.')
            break
          case error.TIMEOUT:
            toast.error('Location request timed out. Please try again.')
            break
          default:
            toast.error('Unable to detect location')
        }
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 }
    )
  }, [setUserCoords, handleSelectLocation, deliveryRadius])

  const filteredAreas = searchQuery.trim()
    ? areas.filter(
        (area: any) =>
          area.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
          area.subtitle.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : areas

  return (
    <AnimatePresence>
      {open && (
        <div className="fixed inset-0 z-[60] flex items-end sm:items-center justify-center">
          {/* Backdrop */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            className="absolute inset-0 bg-black/30 backdrop-blur-md"
            onClick={onClose}
          />

          {/* Modal */}
          <motion.div
            initial={{ opacity: 0, y: 100, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 100, scale: 0.95 }}
            transition={{ type: 'spring', damping: 28, stiffness: 350 }}
            className="relative z-10 w-full sm:max-w-md max-h-[85vh] overflow-hidden rounded-t-3xl sm:rounded-2xl glass shadow-2xl border border-white/30 dark:border-zinc-800/40"
          >
            {/* Drag handle (mobile) */}
            <div className="flex justify-center pt-3 pb-1 sm:hidden">
              <div className="h-1 w-10 rounded-full bg-gray-300" />
            </div>

            {/* Header */}
            <div className="flex items-center justify-between px-5 pt-3 pb-2 sm:pt-5">
              <div>
                <h2 className="text-lg font-bold text-text-primary">Choose your location</h2>
                <p className="text-xs text-text-muted mt-0.5">Select delivery area for fastest delivery</p>
              </div>
              <button
                onClick={onClose}
                className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-hover hover:bg-gray-200 transition-colors"
              >
                <X size={16} className="text-text-secondary" />
              </button>
            </div>

            {/* GPS button */}
            <div className="px-5 pt-3">
              <button
                onClick={handleDetectLocation}
                disabled={isDetecting}
                className="flex w-full items-center gap-3 rounded-2xl border-2 border-dashed border-primary/30 bg-gradient-to-r from-primary/5 to-accent/5 px-4 py-3.5 transition-all hover:border-primary/60 hover:from-primary/10 hover:to-accent/10 active:scale-[0.98] disabled:opacity-70"
              >
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary/10">
                  {isDetecting ? (
                    <Loader2 size={20} className="text-primary animate-spin" />
                  ) : (
                    <Navigation size={20} className="text-primary" />
                  )}
                </div>
                <div className="text-left flex-1">
                  <p className="text-sm font-semibold text-primary">
                    {isDetecting ? 'Detecting location...' : 'Use Current Location'}
                  </p>
                  <p className="text-xs text-text-muted mt-0.5">Via GPS — most accurate & fastest</p>
                </div>
                {!isDetecting && (
                  <div className="flex items-center gap-1 text-[10px] font-bold text-accent bg-accent/10 px-2 py-1 rounded-lg">
                    <span className="relative flex h-1.5 w-1.5">
                      <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-accent opacity-75"></span>
                      <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-accent"></span>
                    </span>
                    RECOMMENDED
                  </div>
                )}
              </button>
            </div>

            {/* Address Preset Chips */}
            <div className="px-5 pt-3 flex flex-wrap gap-2">
              <button
                onClick={() => handleSelectLocation('Ghatampur Market')}
                className="flex items-center gap-1 px-2.5 py-1 rounded-full border border-border bg-white/40 dark:bg-zinc-900/40 hover:bg-primary/5 hover:border-primary/30 text-[10px] sm:text-xs font-bold text-text-primary transition-all cursor-pointer active:scale-95 shadow-sm"
              >
                🏠 Home
              </button>
              <button
                onClick={() => handleSelectLocation('Ghatampur Station Road')}
                className="flex items-center gap-1 px-2.5 py-1 rounded-full border border-border bg-white/40 dark:bg-zinc-900/40 hover:bg-primary/5 hover:border-primary/30 text-[10px] sm:text-xs font-bold text-text-primary transition-all cursor-pointer active:scale-95 shadow-sm"
              >
                💼 Work
              </button>
              <button
                onClick={() => handleSelectLocation('Kanpur Road')}
                className="flex items-center gap-1 px-2.5 py-1 rounded-full border border-border bg-white/40 dark:bg-zinc-900/40 hover:bg-primary/5 hover:border-primary/30 text-[10px] sm:text-xs font-bold text-text-primary transition-all cursor-pointer active:scale-95 shadow-sm"
              >
                🛣️ Highway
              </button>
            </div>

            {/* Mock Map Preview */}
            <div className="mx-5 mt-3.5 relative h-28 rounded-2xl overflow-hidden border border-border/60 dark:border-zinc-800/40 bg-zinc-100/30 dark:bg-zinc-950/30 flex items-center justify-center shadow-inner">
              <div className="absolute inset-0 bg-[linear-gradient(rgba(0,0,0,0.03)_1px,transparent_1px),linear-gradient(90deg,rgba(0,0,0,0.03)_1px,transparent_1px)] dark:bg-[linear-gradient(rgba(255,255,255,0.02)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.02)_1px,transparent_1px)] bg-[size:16px_16px]" />
              
              {/* Mock road lines */}
              <div className="absolute top-1/2 left-0 right-0 h-3 bg-zinc-200/80 dark:bg-zinc-900/80 -translate-y-1/2" />
              <div className="absolute left-1/3 top-0 bottom-0 w-3 bg-zinc-200/80 dark:bg-zinc-900/80" />
              
              {/* Store icon dot */}
              <div className="absolute left-1/3 top-1/2 -translate-x-1.5 -translate-y-1.5 h-3.5 w-3.5 rounded-full bg-primary flex items-center justify-center shadow">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary/80 opacity-75"></span>
                <span className="h-1.5 w-1.5 rounded-full bg-white"></span>
              </div>
              <span className="absolute left-1/3 top-1/2 -translate-x-1/2 -translate-y-6 text-[8px] font-black bg-primary text-white px-1.5 py-0.5 rounded shadow whitespace-nowrap z-10">FastKirana Hub</span>

              {/* Delivery Pin Drop */}
              <motion.div
                key={selectedLocation}
                initial={{ y: -16, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ type: 'spring', stiffness: 200, damping: 12 }}
                className="absolute left-2/3 top-1/2 -translate-x-1/2 -translate-y-4 text-accent text-lg"
              >
                📍
              </motion.div>
              <span className="absolute left-2/3 top-1/2 -translate-x-1/2 translate-y-3.5 text-[8px] font-black bg-accent text-white px-1.5 py-0.5 rounded shadow whitespace-nowrap z-10">
                {selectedLocation && selectedLocation !== 'Select Location' ? selectedLocation : 'Deliver Here'}
              </span>
            </div>

            {/* Delivery confirmation */}
            {detectedArea && deliveryAvailable && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                className="mx-5 mt-3 rounded-xl bg-accent/10 border border-accent/20 p-3 flex items-center gap-2"
              >
                <CheckCircle2 size={18} className="text-accent shrink-0" />
                <div>
                  <p className="text-xs font-bold text-accent">We deliver here! ✅</p>
                  <p className="text-[10px] text-text-secondary mt-0.5">Fast delivery service active to {detectedArea}</p>
                </div>
              </motion.div>
            )}

            {/* Search */}
            <div className="px-5 pt-4">
              <div className="relative">
                <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-text-muted" />
                <input
                  ref={inputRef}
                  type="text"
                  placeholder="Search for area, street name..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full rounded-xl border border-border bg-white py-2.5 pl-10 pr-4 text-sm placeholder:text-text-muted focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all"
                />
                {searchQuery && (
                  <button
                    onClick={() => setSearchQuery('')}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-text-muted hover:text-text-secondary"
                  >
                    <X size={14} />
                  </button>
                )}
              </div>
            </div>

            {/* Scrollable list area */}
            <div className="overflow-y-auto max-h-[calc(85vh-300px)] sm:max-h-[300px] px-5 pt-3 pb-5">
              {/* Current Location */}
              {selectedLocation && selectedLocation !== 'Select Location' && !searchQuery && (
                <div className="mb-4">
                  <p className="text-[11px] font-semibold uppercase tracking-wider text-text-muted mb-2 px-1">
                    Current Location
                  </p>
                  <div className="flex items-center gap-3 rounded-xl px-3 py-2.5 bg-primary/5 border border-primary/10">
                    <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-primary/10">
                      <MapPin size={14} className="text-primary" />
                    </div>
                    <span className="text-sm font-semibold text-primary truncate">{selectedLocation}</span>
                    <CheckCircle2 size={14} className="ml-auto text-accent shrink-0" />
                  </div>
                </div>
              )}

              {/* Recent locations */}
              {!searchQuery && recentLocations.length > 0 && (
                <div className="mb-4">
                  <p className="text-[11px] font-semibold uppercase tracking-wider text-text-muted mb-2 px-1">
                    Recent
                  </p>
                  <div className="space-y-0.5">
                    {recentLocations.map((loc, i) => (
                      <motion.button
                        key={`recent-${loc}`}
                        initial={{ opacity: 0, x: -10 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: i * 0.03 }}
                        onClick={() => handleSelectLocation(loc)}
                        className="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 hover:bg-surface-hover transition-colors group"
                      >
                        <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-accent/10">
                          <Clock size={14} className="text-accent" />
                        </div>
                        <span className="text-sm font-medium text-text-primary text-left truncate">{loc}</span>
                        <ChevronRight size={14} className="ml-auto text-text-muted opacity-0 group-hover:opacity-100 transition-opacity shrink-0" />
                      </motion.button>
                    ))}
                  </div>
                </div>
              )}

              {/* Popular areas */}
              <div>
                <p className="text-[11px] font-semibold uppercase tracking-wider text-text-muted mb-2 px-1">
                  {searchQuery ? 'Search Results' : '📍 Popular Areas in Your Town'}
                </p>
                {filteredAreas.length === 0 ? (
                  <div className="flex flex-col items-center py-8 text-center">
                    <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-surface-hover mb-3">
                      <MapPin size={20} className="text-text-muted" />
                    </div>
                    <p className="text-sm font-medium text-text-secondary">No areas found</p>
                    <p className="text-xs text-text-muted mt-1">Try a different search term</p>
                  </div>
                ) : (
                  <div className="space-y-0.5">
                    {filteredAreas.map((area: any, i: number) => (
                      <motion.button
                        key={area.name}
                        initial={{ opacity: 0, x: -10 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: i * 0.04 }}
                        onClick={() => handleSelectLocation(area.name)}
                        className="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 hover:bg-surface-hover transition-colors group"
                      >
                        <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-base">
                          {area.emoji}
                        </div>
                        <div className="text-left min-w-0">
                          <p className="text-sm font-medium text-text-primary truncate">{area.name}</p>
                          <p className="text-xs text-text-muted truncate">{area.subtitle}</p>
                        </div>
                        <div className="ml-auto flex items-center gap-1 shrink-0">
                          <span className="text-[10px] text-accent font-bold">Fast Delivery</span>
                          <ChevronRight size={14} className="text-text-muted opacity-0 group-hover:opacity-100 transition-opacity" />
                        </div>
                      </motion.button>
                    ))}
                  </div>
                )}
              </div>

              {/* Search submit for manual entry */}
              {searchQuery.trim() && filteredAreas.length === 0 && (
                <motion.button
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  onClick={() => handleSelectLocation(searchQuery.trim())}
                  className="mt-3 flex w-full items-center justify-center gap-2 rounded-2xl bg-primary px-4 py-3 text-sm font-semibold text-white hover:bg-primary/90 transition-colors active:scale-[0.98]"
                >
                  <MapPin size={16} />
                  Use &quot;{searchQuery.trim()}&quot; as location
                </motion.button>
              )}
            </div>

            {/* Bottom delivery info strip */}
            <div className="px-5 pb-4 pt-2 border-t border-border/40">
              <div className="flex items-center justify-center gap-2 text-[10px] text-text-muted">
                <span className="relative flex h-1.5 w-1.5">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-accent opacity-75"></span>
                  <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-accent"></span>
                </span>
                <span className="font-semibold">FastKirana delivers fast across your entire town</span>
              </div>
            </div>
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  )
}
