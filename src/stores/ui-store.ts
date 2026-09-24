import { create } from 'zustand'
import { Product } from '@/types'
import type { CartProduct } from '@/stores/cart-store'

interface UserCoords {
  lat: number
  lng: number
}

interface UIState {
  isCartOpen: boolean
  isMobileMenuOpen: boolean
  isSearchOpen: boolean
  isLocationPickerOpen: boolean
  isTabBarVisible: boolean
  activeVariantProduct: Product | null
  pendingConflictProduct: Product | CartProduct | null
  selectedLocation: string
  userCoords: UserCoords | null
  shopName: string
  shopPhone: string
  groceryMartOpen: boolean
  cafeOpen: boolean
  restaurantOpen: boolean
  categoryStatus: Record<string, boolean>
  deliveryRadius: number
  activeStoreId: string | null
  activeCity: string
  availableHubs: any[]
  isLocationServiceable: boolean
  userDistanceKm: number | null
  settings: Record<string, string>
  setCartOpen: (open: boolean) => void
  toggleCart: () => void
  setMobileMenuOpen: (open: boolean) => void
  setSearchOpen: (open: boolean) => void
  setLocationPickerOpen: (open: boolean) => void
  setTabBarVisible: (visible: boolean) => void
  setActiveVariantProduct: (product: Product | null) => void
  setPendingConflictProduct: (product: Product | CartProduct | null) => void
  setSelectedLocation: (location: string) => void
  setActiveCity: (city: string) => void
  setActiveHub: (hub: any) => void
  setUserCoords: (coords: UserCoords | null) => void
  setAvailableHubs: (hubs: any[]) => void
  setIsLocationServiceable: (serviceable: boolean, distanceKm?: number | null) => void
  outletStatus: Record<string, boolean>
  setStoreStatus: (
    groceryOpen: boolean, 
    cafeOpen: boolean, 
    restaurantOpen: boolean, 
    radius: number, 
    categoryStatus: Record<string, boolean>,
    outletStatus?: Record<string, boolean>
  ) => void
  setSettings: (settings: Record<string, string>) => void
  setShopDetails: (name: string, phone: string) => void
  hydrateLocation: () => void
}

export function calculateDistanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371
  const dLat = (lat2 - lat1) * (Math.PI / 180)
  const dLon = (lon2 - lon1) * (Math.PI / 180)
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

export function isPointInPolygon(point: { lat: number; lng: number }, polygon: any): boolean {
  if (!polygon) return false
  let polyArray = polygon
  if (typeof polygon === 'string') {
    try { polyArray = JSON.parse(polygon) } catch { return false }
  }
  if (!Array.isArray(polyArray) || polyArray.length < 3) return false

  const x = point.lat
  const y = point.lng
  let inside = false
  for (let i = 0, j = polyArray.length - 1; i < polyArray.length; j = i++) {
    const ptI = polyArray[i]
    const ptJ = polyArray[j]
    const xi = typeof ptI?.lat === 'number' ? ptI.lat : (Array.isArray(ptI) ? Number(ptI[0]) : 0)
    const yi = typeof ptI?.lng === 'number' ? ptI.lng : (Array.isArray(ptI) ? Number(ptI[1]) : 0)
    const xj = typeof ptJ?.lat === 'number' ? ptJ.lat : (Array.isArray(ptJ) ? Number(ptJ[0]) : 0)
    const yj = typeof ptJ?.lng === 'number' ? ptJ.lng : (Array.isArray(ptJ) ? Number(ptJ[1]) : 0)

    const intersect = ((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / ((yj - yi) === 0 ? 0.000001 : (yj - yi)) + xi)
    if (intersect) inside = !inside
  }
  return inside
}

function evaluateServiceability(
  coords: UserCoords | null,
  hubs: any[],
  settings: Record<string, string>
): { isServiceable: boolean; distanceKm: number | null; matchedHubId: string | null; matchedCity: string } {
  if (!coords) {
    return { isServiceable: true, distanceKm: null, matchedHubId: null, matchedCity: 'Ghatampur' }
  }

  // 1. If we have active hubs loaded, check distance against ALL active hubs
  if (Array.isArray(hubs) && hubs.length > 0) {
    // 1A. First priority: Exact Polygon Geofence match
    for (const hub of hubs) {
      if (hub.deliveryPolygon && isPointInPolygon(coords, hub.deliveryPolygon)) {
        const dist = (hub.latitude && hub.longitude)
          ? calculateDistanceKm(coords.lat, coords.lng, hub.latitude, hub.longitude)
          : 0.5
        const city = hub.city || hub.name?.replace(/\s+(Hub|Market|Central|Dark\s*Store).*$/i, '').trim() || 'Ghatampur'
        return {
          isServiceable: true,
          distanceKm: dist,
          matchedHubId: hub.id,
          matchedCity: city,
        }
      }
    }

    // 1B. Second priority: Radial distance
    let closestMatchingHub: any = null
    let closestMatchingDist = Infinity

    let closestAnyHub: any = null
    let minAnyDist = Infinity

    for (const hub of hubs) {
      if (!hub.latitude || !hub.longitude) continue
      const dist = calculateDistanceKm(coords.lat, coords.lng, hub.latitude, hub.longitude)
      const allowedRadius = hub.deliveryRadiusKm || 5.0

      if (dist <= allowedRadius && dist < closestMatchingDist) {
        closestMatchingDist = dist
        closestMatchingHub = hub
      }

      if (dist < minAnyDist) {
        minAnyDist = dist
        closestAnyHub = hub
      }
    }

    if (closestMatchingHub) {
      const city = closestMatchingHub.city || closestMatchingHub.name?.replace(/\s+(Hub|Market|Central|Dark\s*Store).*$/i, '').trim() || 'Ghatampur'
      return {
        isServiceable: true,
        distanceKm: closestMatchingDist,
        matchedHubId: closestMatchingHub.id,
        matchedCity: city,
      }
    }

    const fallbackCity = closestAnyHub?.city || closestAnyHub?.name?.replace(/\s+(Hub|Market|Central|Dark\s*Store).*$/i, '').trim() || 'Ghatampur'
    return {
      isServiceable: false,
      distanceKm: minAnyDist !== Infinity ? minAnyDist : null,
      matchedHubId: closestAnyHub?.id || null,
      matchedCity: fallbackCity,
    }
  }

  // 2. Fallback: single hub coordinates from settings
  const hubLat = parseFloat(settings['store_lat'] || '26.1534185')
  const hubLng = parseFloat(settings['store_lng'] || '80.1714024')
  const maxRadius = parseFloat(settings['delivery_radius'] || '5.0')
  const dist = calculateDistanceKm(coords.lat, coords.lng, hubLat, hubLng)

  return {
    isServiceable: dist <= maxRadius,
    distanceKm: dist,
    matchedHubId: null,
    matchedCity: 'Ghatampur',
  }
}

export const useUIStore = create<UIState>((set) => ({
  isCartOpen: false,
  isMobileMenuOpen: false,
  isSearchOpen: false,
  isLocationPickerOpen: false,
  isTabBarVisible: true,
  activeVariantProduct: null,
  pendingConflictProduct: null,
  selectedLocation: 'Select Location',
  userCoords: null,
  activeStoreId: null,
  activeCity: 'Ghatampur',
  availableHubs: [],
  shopName: '',
  shopPhone: '',
  groceryMartOpen: true,
  cafeOpen: true,
  restaurantOpen: true,
  categoryStatus: {},
  outletStatus: {},
  deliveryRadius: 5,
  isLocationServiceable: true,
  userDistanceKm: null,
  settings: {},

  setCartOpen: (open) => set({ isCartOpen: open }),
  toggleCart: () => set((state) => ({ isCartOpen: !state.isCartOpen })),
  setMobileMenuOpen: (open) => set({ isMobileMenuOpen: open }),
  setSearchOpen: (open) => set({ isSearchOpen: open }),
  setLocationPickerOpen: (open) => set({ isLocationPickerOpen: open }),
  setTabBarVisible: (visible) => set({ isTabBarVisible: visible }),
  setActiveVariantProduct: (product) => set({ activeVariantProduct: product }),
  setPendingConflictProduct: (product) => set({ pendingConflictProduct: product }),
  setSelectedLocation: (location) => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('fk-location', location)
    }
    set({ selectedLocation: location })
  },
  setActiveCity: (city) => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('fk-city', city)
    }
    set({ activeCity: city })
  },
  setActiveHub: (hub) => {
    if (!hub) return
    const city = hub.city || hub.name?.replace(/\s+(Hub|Market|Central|Dark\s*Store).*$/i, '').trim() || 'Ghatampur'
    if (typeof window !== 'undefined') {
      localStorage.setItem('fk-city', city)
      if (hub.id) {
        localStorage.setItem('fk-store-id', hub.id)
        document.cookie = `fk_store_id=${encodeURIComponent(hub.id)}; path=/; max-age=2592000; SameSite=Lax`
      }
      if (hub.latitude && hub.longitude) {
        localStorage.setItem('fk-coords', JSON.stringify({ lat: hub.latitude, lng: hub.longitude }))
      }
      localStorage.setItem('fk-location', `${city} Central`)
    }
    set({
      activeStoreId: hub.id,
      activeCity: city,
      selectedLocation: `${city} Central`,
      userCoords: (hub.latitude && hub.longitude) ? { lat: hub.latitude, lng: hub.longitude } : null,
      isLocationServiceable: true,
      userDistanceKm: 0.5,
    })
  },
  setIsLocationServiceable: (serviceable, distanceKm = null) => {
    set({ isLocationServiceable: serviceable, userDistanceKm: distanceKm })
  },
  setAvailableHubs: (hubs) => {
    set({ availableHubs: hubs })
    const state = useUIStore.getState()
    if (state.userCoords) {
      const evalRes = evaluateServiceability(state.userCoords, hubs, state.settings)
      if (typeof window !== 'undefined') {
        if (evalRes.matchedCity) localStorage.setItem('fk-city', evalRes.matchedCity)
        if (evalRes.matchedHubId) {
          localStorage.setItem('fk-store-id', evalRes.matchedHubId)
          document.cookie = `fk_store_id=${encodeURIComponent(evalRes.matchedHubId)}; path=/; max-age=2592000; SameSite=Lax`
        }
      }
      set({
        isLocationServiceable: evalRes.isServiceable,
        userDistanceKm: evalRes.distanceKm,
        activeStoreId: evalRes.matchedHubId,
        activeCity: evalRes.matchedCity || state.activeCity,
      })
    }
  },
  setUserCoords: (coords) => {
    if (typeof window !== 'undefined' && coords) {
      localStorage.setItem('fk-coords', JSON.stringify(coords))
    }
    if (!coords) {
      if (typeof window !== 'undefined') {
        localStorage.removeItem('fk-store-id')
        document.cookie = 'fk_store_id=; path=/; max-age=0'
      }
      set({ userCoords: null, isLocationServiceable: true, userDistanceKm: null, activeStoreId: null })
      return
    }

    const state = useUIStore.getState()
    const evalRes = evaluateServiceability(coords, state.availableHubs, state.settings)

    if (typeof window !== 'undefined') {
      if (evalRes.matchedCity) localStorage.setItem('fk-city', evalRes.matchedCity)
      if (evalRes.matchedHubId) {
        localStorage.setItem('fk-store-id', evalRes.matchedHubId)
        document.cookie = `fk_store_id=${encodeURIComponent(evalRes.matchedHubId)}; path=/; max-age=2592000; SameSite=Lax`
      }
    }

    set({
      userCoords: coords,
      isLocationServiceable: evalRes.isServiceable,
      userDistanceKm: evalRes.distanceKm,
      activeStoreId: evalRes.matchedHubId,
      activeCity: evalRes.matchedCity || state.activeCity,
    })
  },
  setShopDetails: (name: string, phone: string) => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('fk-shop-name', name)
      localStorage.setItem('fk-shop-phone', phone)
    }
    set({ shopName: name, shopPhone: phone })
  },
  setStoreStatus: (groceryOpen, cafeOpen, restaurantOpen, radius, categoryStatus) => {
    set({ groceryMartOpen: groceryOpen, cafeOpen, restaurantOpen, deliveryRadius: radius, categoryStatus })
  },
  setSettings: (settings) => {
    set((state) => ({ settings: { ...state.settings, ...settings } }))
    const state = useUIStore.getState()
    if (state.userCoords) {
      const evalRes = evaluateServiceability(state.userCoords, state.availableHubs, state.settings)
      if (typeof window !== 'undefined' && evalRes.matchedHubId) {
        localStorage.setItem('fk-store-id', evalRes.matchedHubId)
        document.cookie = `fk_store_id=${encodeURIComponent(evalRes.matchedHubId)}; path=/; max-age=2592000; SameSite=Lax`
      }
      set({
        isLocationServiceable: evalRes.isServiceable,
        userDistanceKm: evalRes.distanceKm,
        activeStoreId: evalRes.matchedHubId,
        activeCity: evalRes.matchedCity || state.activeCity,
      })
    }
  },
  hydrateLocation: () => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('fk-location')
      const savedCoords = localStorage.getItem('fk-coords')
      const savedCity = localStorage.getItem('fk-city')
      const savedStoreId = localStorage.getItem('fk-store-id')
      const savedShopName = localStorage.getItem('fk-shop-name')
      const savedShopPhone = localStorage.getItem('fk-shop-phone')
      if (saved) set({ selectedLocation: saved })
      if (savedCity) set({ activeCity: savedCity })
      if (savedStoreId) set({ activeStoreId: savedStoreId })
      if (savedShopName) set({ shopName: savedShopName })
      if (savedShopPhone) set({ shopPhone: savedShopPhone })
      
      // Also fetch hubs list asynchronously for global multi-hub serviceability
      fetch('/api/stores/hubs')
        .then(res => res.json())
        .then(data => {
          if (data?.hubs && Array.isArray(data.hubs)) {
            useUIStore.getState().setAvailableHubs(data.hubs)
          }
        })
        .catch(() => {})

      if (savedCoords) {
        try {
          const parsed = JSON.parse(savedCoords)
          if (parsed && typeof parsed.lat === 'number' && typeof parsed.lng === 'number') {
            const state = useUIStore.getState()
            const evalRes = evaluateServiceability(parsed, state.availableHubs, state.settings)
            if (evalRes.matchedHubId) {
              localStorage.setItem('fk-store-id', evalRes.matchedHubId)
              document.cookie = `fk_store_id=${encodeURIComponent(evalRes.matchedHubId)}; path=/; max-age=2592000; SameSite=Lax`
            }
            set({
              userCoords: parsed,
              isLocationServiceable: evalRes.isServiceable,
              userDistanceKm: evalRes.distanceKm,
              activeStoreId: evalRes.matchedHubId,
              activeCity: evalRes.matchedCity || state.activeCity,
            })
          }
        } catch {}
      } else if (typeof navigator !== 'undefined' && navigator.geolocation) {
        // Silent bootstrap GPS check on first visit
        navigator.geolocation.getCurrentPosition(
          (pos) => {
            useUIStore.getState().setUserCoords({ lat: pos.coords.latitude, lng: pos.coords.longitude })
          },
          () => {},
          { timeout: 6000, maximumAge: 60000 }
        )
      }
    }
  },
}))
