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
  setUserCoords: (coords: UserCoords | null) => void
  setAvailableHubs: (hubs: any[]) => void
  setIsLocationServiceable: (serviceable: boolean, distanceKm?: number | null) => void
  setShopDetails: (name: string, phone: string) => void
  setStoreStatus: (groceryOpen: boolean, cafeOpen: boolean, restaurantOpen: boolean, radius: number, categoryStatus: Record<string, boolean>) => void
  setSettings: (settings: Record<string, string>) => void
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

function evaluateServiceability(
  coords: UserCoords | null,
  hubs: any[],
  settings: Record<string, string>
): { isServiceable: boolean; distanceKm: number | null; matchedHubId: string | null } {
  if (!coords) {
    return { isServiceable: true, distanceKm: null, matchedHubId: null }
  }

  // 1. If we have active hubs loaded, check distance against ALL active hubs
  if (Array.isArray(hubs) && hubs.length > 0) {
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
      return {
        isServiceable: true,
        distanceKm: closestMatchingDist,
        matchedHubId: closestMatchingHub.id
      }
    }

    return {
      isServiceable: false,
      distanceKm: minAnyDist !== Infinity ? minAnyDist : null,
      matchedHubId: closestAnyHub?.id || null
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
    matchedHubId: null
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
  availableHubs: [],
  shopName: '',
  shopPhone: '',
  groceryMartOpen: true,
  cafeOpen: true,
  restaurantOpen: true,
  categoryStatus: {},
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
  setIsLocationServiceable: (serviceable, distanceKm = null) => {
    set({ isLocationServiceable: serviceable, userDistanceKm: distanceKm })
  },
  setAvailableHubs: (hubs) => {
    set({ availableHubs: hubs })
    const state = useUIStore.getState()
    if (state.userCoords) {
      const evalRes = evaluateServiceability(state.userCoords, hubs, state.settings)
      set({
        isLocationServiceable: evalRes.isServiceable,
        userDistanceKm: evalRes.distanceKm,
        activeStoreId: evalRes.matchedHubId
      })
    }
  },
  setUserCoords: (coords) => {
    if (typeof window !== 'undefined' && coords) {
      localStorage.setItem('fk-coords', JSON.stringify(coords))
    }
    if (!coords) {
      set({ userCoords: null, isLocationServiceable: true, userDistanceKm: null, activeStoreId: null })
      return
    }

    const state = useUIStore.getState()
    const evalRes = evaluateServiceability(coords, state.availableHubs, state.settings)

    set({
      userCoords: coords,
      isLocationServiceable: evalRes.isServiceable,
      userDistanceKm: evalRes.distanceKm,
      activeStoreId: evalRes.matchedHubId
    })
  },
  setShopDetails: (name, phone) => {
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
      set({
        isLocationServiceable: evalRes.isServiceable,
        userDistanceKm: evalRes.distanceKm,
        activeStoreId: evalRes.matchedHubId
      })
    }
  },
  hydrateLocation: () => {
    if (typeof window !== 'undefined') {
      const saved = localStorage.getItem('fk-location')
      const savedCoords = localStorage.getItem('fk-coords')
      const savedShopName = localStorage.getItem('fk-shop-name')
      const savedShopPhone = localStorage.getItem('fk-shop-phone')
      if (saved) set({ selectedLocation: saved })
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
            set({
              userCoords: parsed,
              isLocationServiceable: evalRes.isServiceable,
              userDistanceKm: evalRes.distanceKm,
              activeStoreId: evalRes.matchedHubId
            })
          }
        } catch {}
      }
    }
  },
}))
