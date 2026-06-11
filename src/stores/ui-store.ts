import { create } from 'zustand'
import { Product } from '@/types'

interface UserCoords {
  lat: number
  lng: number
}

interface UIState {
  isCartOpen: boolean
  isMobileMenuOpen: boolean
  isSearchOpen: boolean
  isLocationPickerOpen: boolean
  activeVariantProduct: Product | null
  selectedLocation: string
  userCoords: UserCoords | null
  shopName: string
  shopPhone: string
  groceryMartOpen: boolean
  cafeOpen: boolean
  deliveryRadius: number
  setCartOpen: (open: boolean) => void
  toggleCart: () => void
  setMobileMenuOpen: (open: boolean) => void
  setSearchOpen: (open: boolean) => void
  setLocationPickerOpen: (open: boolean) => void
  setActiveVariantProduct: (product: Product | null) => void
  setSelectedLocation: (location: string) => void
  setUserCoords: (coords: UserCoords | null) => void
  setShopDetails: (name: string, phone: string) => void
  setStoreStatus: (groceryOpen: boolean, cafeOpen: boolean, radius: number) => void
  hydrateLocation: () => void
}

export const useUIStore = create<UIState>((set) => ({
  isCartOpen: false,
  isMobileMenuOpen: false,
  isSearchOpen: false,
  isLocationPickerOpen: false,
  activeVariantProduct: null,
  selectedLocation: 'Select Location',
  userCoords: null,
  shopName: '',
  shopPhone: '',
  groceryMartOpen: true,
  cafeOpen: true,
  deliveryRadius: 5,

  setCartOpen: (open) => set({ isCartOpen: open }),
  toggleCart: () => set((state) => ({ isCartOpen: !state.isCartOpen })),
  setMobileMenuOpen: (open) => set({ isMobileMenuOpen: open }),
  setSearchOpen: (open) => set({ isSearchOpen: open }),
  setLocationPickerOpen: (open) => set({ isLocationPickerOpen: open }),
  setActiveVariantProduct: (product) => set({ activeVariantProduct: product }),
  setSelectedLocation: (location) => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('fk-location', location)
    }
    set({ selectedLocation: location })
  },
  setUserCoords: (coords) => {
    if (typeof window !== 'undefined' && coords) {
      localStorage.setItem('fk-coords', JSON.stringify(coords))
    }
    set({ userCoords: coords })
  },
  setShopDetails: (name, phone) => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('fk-shop-name', name)
      localStorage.setItem('fk-shop-phone', phone)
    }
    set({ shopName: name, shopPhone: phone })
  },
  setStoreStatus: (groceryOpen, cafeOpen, radius) => {
    set({ groceryMartOpen: groceryOpen, cafeOpen, deliveryRadius: radius })
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
      if (savedCoords) {
        try { set({ userCoords: JSON.parse(savedCoords) }) } catch {}
      }
    }
  },
}))
