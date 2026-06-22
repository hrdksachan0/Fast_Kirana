'use client'

import { useEffect, useRef, useState } from 'react'
import { Loader2, Navigation, Search, X } from 'lucide-react'
import { toast } from 'sonner'

// Load Google Maps script globally
let scriptLoadingPromise: Promise<any> | null = null

function loadGoogleMapsScript(apiKey: string): Promise<any> {
  if (typeof window === 'undefined') return Promise.resolve()
  if ((window as any).google?.maps) return Promise.resolve((window as any).google.maps)

  if (scriptLoadingPromise) return scriptLoadingPromise

  scriptLoadingPromise = new Promise((resolve, reject) => {
    const script = document.createElement('script')
    script.src = `https://maps.googleapis.com/maps/api/js?key=${apiKey}&libraries=places`
    script.async = true;
    script.defer = true;
    script.onload = () => {
      resolve((window as any).google.maps)
    }
    script.onerror = (err) => {
      scriptLoadingPromise = null
      reject(err)
    }
    document.head.appendChild(script)
  })

  return scriptLoadingPromise
}

interface LocationData {
  lat: number
  lng: number
  street: string
  city: string
  pincode: string
}

interface MapPickerProps {
  initialLat: number | null
  initialLng: number | null
  storeLat: number
  storeLng: number
  onLocationSelect: (data: LocationData) => void
}

export default function MapPicker({
  initialLat,
  initialLng,
  storeLat,
  storeLng,
  onLocationSelect,
}: MapPickerProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const searchInputRef = useRef<HTMLInputElement>(null)
  
  const [apiKey, setApiKey] = useState<string | null>(null)
  const [isLoadingKey, setIsLoadingKey] = useState(true)
  const [isMapLoaded, setIsMapLoaded] = useState(false)
  const [isDragging, setIsDragging] = useState(false)
  const [isResolvingAddress, setIsResolvingAddress] = useState(false)
  const [searchText, setSearchText] = useState('')
  const [currentCoords, setCurrentCoords] = useState<{ lat: number; lng: number } | null>(null)

  const mapRef = useRef<any>(null)
  const autocompleteRef = useRef<any>(null)
  const ignoreNextIdleRef = useRef(false)

  // Fetch API key from server
  useEffect(() => {
    fetch('/api/geocode/key')
      .then((res) => {
        if (!res.ok) throw new Error('Failed to fetch API key')
        return res.json()
      })
      .then((data) => {
        setApiKey(data.apiKey)
      })
      .catch((err) => {
        console.error('Error fetching Google Maps key:', err)
        toast.error('Unable to load map configuration.')
      })
      .finally(() => {
        setIsLoadingKey(false)
      })
  }, [])

  // Load Google Maps SDK
  useEffect(() => {
    if (!apiKey) return

    loadGoogleMapsScript(apiKey)
      .then(() => {
        setIsMapLoaded(true)
      })
      .catch((err) => {
        console.error('Failed to load Google Maps script:', err)
        toast.error('Google Maps failed to load.')
      })
  }, [apiKey])

  // Initialize Map
  useEffect(() => {
    if (!isMapLoaded || !mapContainerRef.current) return

    const google = (window as any).google
    if (!google) return

    // Center logic: use initialLat/Lng if provided, otherwise default to store location
    const defaultCenter = {
      lat: initialLat || storeLat,
      lng: initialLng || storeLng,
    }

    const mapOptions = {
      center: defaultCenter,
      zoom: 17,
      gestureHandling: 'greedy',
      disableDefaultUI: true,
      zoomControl: false,
      styles: [
        {
          featureType: 'poi',
          elementType: 'labels',
          stylers: [{ visibility: 'off' }], // hide points of interest to clean up map
        },
      ],
    }

    const map = new google.maps.Map(mapContainerRef.current, mapOptions)
    mapRef.current = map
    setCurrentCoords(defaultCenter)

    // Setup autocomplete search bar
    if (searchInputRef.current) {
      const autocomplete = new google.maps.places.Autocomplete(searchInputRef.current, {
        componentRestrictions: { country: 'in' },
        fields: ['geometry', 'formatted_address', 'name', 'address_components'],
      })
      autocompleteRef.current = autocomplete

      autocomplete.addListener('place_changed', () => {
        const place = autocomplete.getPlace()
        if (place.geometry && place.geometry.location) {
          const newLat = place.geometry.location.lat()
          const newLng = place.geometry.location.lng()
          
          map.setCenter({ lat: newLat, lng: newLng })
          map.setZoom(17)
          setSearchText(place.name || place.formatted_address || '')
        } else {
          toast.error('No geometry details found for selected place.')
        }
      })
    }

    // Bind dragging events for Swiggy/Zomato Pin animation
    map.addListener('dragstart', () => {
      setIsDragging(true)
    })

    map.addListener('drag', () => {
      const center = map.getCenter()
      if (center) {
        setCurrentCoords({ lat: center.lat(), lng: center.lng() })
      }
    })

    // Bind idle event when map movement stops
    map.addListener('idle', () => {
      setIsDragging(false)
      if (ignoreNextIdleRef.current) {
        ignoreNextIdleRef.current = false
        return
      }

      const center = map.getCenter()
      if (!center) return

      const lat = center.lat()
      const lng = center.lng()
      setCurrentCoords({ lat, lng })
      resolveAddress(lat, lng)
    })

    // If no initial coordinates were provided, attempt auto-detect on start
    if (!initialLat || !initialLng) {
      detectUserLocation(map)
    }

  }, [isMapLoaded])

  // Geolocate user and center map
  const handleLocateMe = () => {
    if (!mapRef.current) return
    detectUserLocation(mapRef.current)
  }

  const detectUserLocation = (mapInstance: any) => {
    if (!navigator.geolocation) {
      toast.error('Geolocation is not supported by your browser.')
      return
    }

    const toastId = toast.loading('Detecting your GPS location...')
    navigator.geolocation.getCurrentPosition(
      (position) => {
        toast.dismiss(toastId)
        let { latitude, longitude } = position.coords

        // Calculate distance from store
        const R = 6371
        const dLat = (latitude - storeLat) * (Math.PI / 180)
        const dLon = (longitude - storeLng) * (Math.PI / 180)
        const a =
          Math.sin(dLat / 2) * Math.sin(dLat / 2) +
          Math.cos(storeLat * (Math.PI / 180)) * Math.cos(latitude * (Math.PI / 180)) *
          Math.sin(dLon / 2) * Math.sin(dLon / 2)
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        const dist = R * c

        // Check if user is way too far (mock for local dev check)
        if (dist > 20) {
          toast.warning(`Detected GPS is ${dist.toFixed(0)} km away. Centering on Ghatampur!`)
          latitude = storeLat + 0.015
          longitude = storeLng + 0.015
        }

        mapInstance.panTo({ lat: latitude, lng: longitude })
        mapInstance.setZoom(17)
        toast.success('Location centered successfully!')
      },
      (error) => {
        toast.dismiss(toastId)
        toast.error('Unable to fetch GPS location. Please check browser permissions.')
      },
      { enableHighAccuracy: true, timeout: 8000 }
    )
  }

  // Reverse Geocode coordinates to auto fill address form
  const resolveAddress = async (lat: number, lng: number) => {
    setIsResolvingAddress(true)
    try {
      const res = await fetch(`/api/geocode?lat=${lat}&lng=${lng}`)
      if (!res.ok) throw new Error('Geocoding api error')
      const resData = await res.json()
      
      const results = resData.data?.results
      if (results && results.length > 0) {
        const firstResult = results[0]
        const addressComponents = firstResult.address_components

        let route = ''
        let sublocality = ''
        let city = 'Ghatampur'
        let postcode = '209206'

        addressComponents.forEach((comp: any) => {
          if (comp.types.includes('route')) {
            route = comp.long_name
          }
          if (
            comp.types.includes('sublocality') ||
            comp.types.includes('sublocality_level_1') ||
            comp.types.includes('sublocality_level_2')
          ) {
            sublocality = comp.long_name
          }
          if (comp.types.includes('locality')) {
            city = comp.long_name
          }
          if (comp.types.includes('postal_code')) {
            postcode = comp.long_name
          }
        })

        const streetParts = [sublocality, route].filter(Boolean)
        const streetName = streetParts.length > 0 ? streetParts.join(', ') : firstResult.formatted_address.split(',')[0]

        // Trigger callback
        onLocationSelect({
          lat,
          lng,
          street: streetName || 'Ghatampur Location',
          city: city || 'Ghatampur',
          pincode: postcode || '209206',
        })
      }
    } catch (err) {
      console.error('Error reverse geocoding center coordinates:', err)
    } finally {
      setIsResolvingAddress(false)
    }
  }

  const handleClearSearch = () => {
    setSearchText('')
    if (searchInputRef.current) {
      searchInputRef.current.value = ''
      searchInputRef.current.focus()
    }
  }

  if (isLoadingKey) {
    return (
      <div className="w-full h-64 rounded-2xl bg-zinc-100 dark:bg-zinc-800/40 flex items-center justify-center border border-border">
        <Loader2 className="h-6 w-6 animate-spin text-primary" />
        <span className="ml-2 text-xs font-bold text-text-secondary">Loading Map Engine...</span>
      </div>
    )
  }

  return (
    <div className="w-full space-y-3">
      {/* Autocomplete Search input */}
      <div className="relative">
        <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
          <Search className="h-4 w-4 text-text-muted" />
        </div>
        <input
          ref={searchInputRef}
          type="text"
          placeholder="Search for local landmark, building, street..."
          value={searchText}
          onChange={(e) => setSearchText(e.target.value)}
          className="block w-full pl-10 pr-10 py-2.5 text-xs font-semibold rounded-xl border border-border bg-background focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary placeholder:text-text-muted/60"
        />
        {searchText && (
          <button
            type="button"
            onClick={handleClearSearch}
            className="absolute inset-y-0 right-0 pr-3 flex items-center hover:text-primary transition-colors"
          >
            <X className="h-4 w-4 text-text-muted" />
          </button>
        )}
      </div>

      {/* Map Container */}
      <div className="relative w-full h-64 sm:h-72 rounded-2xl overflow-hidden border border-border shadow-inner bg-zinc-50 dark:bg-zinc-900/10">
        <div ref={mapContainerRef} className="w-full h-full" />

        {/* Pin overlay - Fixed at center of the map */}
        <div 
          className="absolute left-1/2 top-1/2 pointer-events-none flex flex-col items-center select-none"
          style={{ transform: 'translate(-50%, -100%)' }}
        >
          {/* Swiggy/Zomato Bobbing Pin */}
          <div 
            className={`transition-transform duration-200 ease-out ${
              isDragging ? '-translate-y-4 scale-105' : 'translate-y-0 scale-100'
            }`}
          >
            <svg
              width="40"
              height="40"
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              className="drop-shadow-lg"
            >
              <path
                d="M12 2C8.13 2 5 5.13 5 9C5 14.25 12 22 12 22C12 22 19 14.25 19 9C19 5.13 15.87 2 12 2Z"
                fill="#fb2576" // theme primary
                stroke="#ffffff"
                strokeWidth="1.5"
              />
              <circle cx="12" cy="9" r="3" fill="#ffffff" />
            </svg>
          </div>

          {/* Bobbing Shadow */}
          <div 
            className={`w-3 h-1 bg-black/35 rounded-full blur-[1px] transition-all duration-200 ease-out ${
              isDragging ? 'scale-50 opacity-40 translate-y-3' : 'scale-100 opacity-100 translate-y-0'
            }`}
          />
        </div>

        {/* Floating Controls */}
        <div className="absolute bottom-4 right-4 flex flex-col gap-2">
          {/* Locate Me GPS Button */}
          <button
            type="button"
            onClick={handleLocateMe}
            className="w-10 h-10 rounded-full bg-white dark:bg-zinc-900 shadow-md border border-border flex items-center justify-center text-text-primary hover:text-primary active:scale-95 transition-all hover:shadow-lg"
            title="Locate Me"
          >
            <Navigation className="h-4 w-4 fill-current rotate-45" />
          </button>
        </div>

        {/* Address Resolving Overlay Indicator */}
        {isResolvingAddress && (
          <div className="absolute top-3 left-3 bg-white/95 dark:bg-zinc-900/95 shadow-sm border border-border px-3 py-1.5 rounded-lg flex items-center gap-1.5 animate-pulse">
            <Loader2 className="h-3 w-3 animate-spin text-primary" />
            <span className="text-[10px] font-bold text-text-secondary">Refining address...</span>
          </div>
        )}
      </div>

      {/* Lat/Lng display for debug & confirmation */}
      {currentCoords && (
        <div className="text-[10px] font-mono text-text-muted flex justify-between px-1">
          <span>LAT: {currentCoords.lat.toFixed(6)}</span>
          <span>LNG: {currentCoords.lng.toFixed(6)}</span>
        </div>
      )}
    </div>
  )
}
