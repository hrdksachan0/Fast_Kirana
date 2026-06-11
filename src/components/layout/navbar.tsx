'use client'

import Link from 'next/link'
import { Search, ShoppingBag, MapPin, User, ChevronDown, Sun, Moon } from 'lucide-react'
import { useState, useEffect, useCallback, Suspense } from 'react'
import { useCartStore } from '@/stores/cart-store'
import { useUIStore } from '@/stores/ui-store'
import { usePathname } from 'next/navigation'
import { LocationPicker } from '@/components/shared/location-picker'
import { SearchOverlay } from '@/components/shared/search-overlay'
import { Logo } from '@/components/layout/logo'
import { useSession } from 'next-auth/react'
import { cn } from '@/lib/utils'
import { useTheme } from '@/providers/theme-provider'
import { TopProgressBar } from '@/components/shared/top-progress-bar'
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
  return R * c // Distance in km
}

const SEARCH_PLACEHOLDERS = [
  'Search "milk"',
  'Search "paneer"',
  'Search "chips"',
  'Search "atta"',
  'Search "bread"',
]

export function Navbar() {
  const [isScrolled, setIsScrolled] = useState(false)
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false)
  const [placeholderIndex, setPlaceholderIndex] = useState(0)
  const totalItems = useCartStore((s) => s.getTotalItems())
  const subtotal = useCartStore((s) => s.getSubtotal())
  const toggleCart = useUIStore((s) => s.toggleCart)
  const selectedLocation = useUIStore((s) => s.selectedLocation)
  const isLocationPickerOpen = useUIStore((s) => s.isLocationPickerOpen)
  const setLocationPickerOpen = useUIStore((s) => s.setLocationPickerOpen)
  const isSearchOpen = useUIStore((s) => s.isSearchOpen)
  const setSearchOpen = useUIStore((s) => s.setSearchOpen)
  const hydrateLocation = useUIStore((s) => s.hydrateLocation)
  const setStoreStatus = useUIStore((s) => s.setStoreStatus)
  const setSelectedLocation = useUIStore((s) => s.setSelectedLocation)
  const setUserCoords = useUIStore((s) => s.setUserCoords)
  const { data: session } = useSession()
  const { theme, toggleTheme } = useTheme()
  const [groceryMartOpen, setGroceryMartOpen] = useState(true)
  const [cafeOpen, setCafeOpen] = useState(true)
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
  }, [])



  useEffect(() => {
    hydrateLocation()
    fetch('/api/settings')
      .then(res => res.json())
      .then(data => {
        const gOpen = data.grocery_mart_open !== 'false'
        const cOpen = data.cafe_open !== 'false'
        const radius = data.delivery_radius ? parseFloat(data.delivery_radius) : 5.0
        const storeLat = data.store_lat ? parseFloat(data.store_lat) : 26.1534185
        const storeLng = data.store_lng ? parseFloat(data.store_lng) : 80.1714024
        
        setGroceryMartOpen(gOpen)
        setCafeOpen(cOpen)
        setStoreStatus(gOpen, cOpen, radius)

        // Automatically detect location if not set
        const currentLoc = useUIStore.getState().selectedLocation
        if (!currentLoc || currentLoc === 'Select Location') {
          if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
              (position) => {
                let { latitude, longitude } = position.coords
                const dist = getDistance(storeLat, storeLng, latitude, longitude)

                // If developer/tester is far away, mock to nearby Ghatampur Station Road
                if (dist > 20) {
                  const mockLat = storeLat + 0.015
                  const mockLng = storeLng + 0.015
                  const mockArea = "Ghatampur Station Road"
                  setSelectedLocation(mockArea)
                  setUserCoords({ lat: mockLat, lng: mockLng })
                  toast.success(`Location set: ${mockArea} (Mocked for testing)`)
                } else if (dist > radius) {
                  const fallbackArea = "Ghatampur Market"
                  setSelectedLocation(fallbackArea)
                  setUserCoords({ lat: storeLat, lng: storeLng })
                  toast.info(`Defaulting to ${fallbackArea} (Your detected location is outside delivery area)`)
                } else {
                  // Within delivery radius, try reverse geocoding
                  const locationName = `${latitude.toFixed(4)}°N, ${longitude.toFixed(4)}°E`
                  fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}&zoom=16&addressdetails=1`)
                    .then(res => res.json())
                    .then(geoData => {
                      const area = geoData.address?.suburb
                        || geoData.address?.neighbourhood
                        || geoData.address?.city_district
                        || geoData.address?.town
                        || geoData.address?.city
                        || locationName
                      setSelectedLocation(area)
                      setUserCoords({ lat: latitude, lng: longitude })
                      toast.success(`Delivering to ${area}`)
                    })
                    .catch(() => {
                      setSelectedLocation(locationName)
                      setUserCoords({ lat: latitude, lng: longitude })
                      toast.success(`Delivering to ${locationName}`)
                    })
                }
              },
              (error) => {
                console.warn('Geolocation error or denied, falling back to Ghatampur Market:', error)
                const fallbackArea = "Ghatampur Market"
                setSelectedLocation(fallbackArea)
                setUserCoords({ lat: storeLat, lng: storeLng })
                toast.info(`Delivering to ${fallbackArea} (Default)`)
              },
              { enableHighAccuracy: true, timeout: 5000, maximumAge: 60000 }
            )
          } else {
            const fallbackArea = "Ghatampur Market"
            setSelectedLocation(fallbackArea)
            setUserCoords({ lat: storeLat, lng: storeLng })
            toast.info(`Delivering to ${fallbackArea} (Default)`)
          }
        }
      })
      .catch(err => console.error('Error loading store status/location in navbar:', err))
  }, [hydrateLocation, setStoreStatus, setSelectedLocation, setUserCoords])

  const handleScroll = useCallback(() => {
    setIsScrolled(window.scrollY > 10)
  }, [])

  const [isCartBouncing, setIsCartBouncing] = useState(false)

  useEffect(() => {
    const handleBounce = () => {
      setIsCartBouncing(true)
      setTimeout(() => setIsCartBouncing(false), 350)
    }
    window.addEventListener('cart-bounce', handleBounce)
    return () => window.removeEventListener('cart-bounce', handleBounce)
  }, [])

  useEffect(() => {
    window.addEventListener('scroll', handleScroll)
    return () => window.removeEventListener('scroll', handleScroll)
  }, [handleScroll])

  useEffect(() => {
    const interval = setInterval(() => {
      setPlaceholderIndex((prev) => (prev + 1) % SEARCH_PLACEHOLDERS.length)
    }, 3000)
    return () => clearInterval(interval)
  }, [])

  return (
    <>
      <nav
        className={cn(
          "fixed top-0 left-0 right-0 z-50 transition-all duration-300 border-b md:backdrop-blur-lg",
          isScrolled
            ? "bg-white dark:bg-background border-zinc-200/30 dark:border-white/[0.06] shadow-md py-1.5 md:bg-white/70 md:dark:bg-background/75"
            : "bg-white dark:bg-background border-zinc-100/40 dark:border-white/[0.04] shadow-sm py-2.5 md:bg-white/80 md:dark:bg-background/80"
        )}
      >
        <div className="mx-auto max-w-7xl px-4">
          {/* Mobile Header (2 Rows) */}
          <div className="flex flex-col gap-1.5 md:hidden animate-fade-in">
            <div className="flex items-center justify-between w-full gap-3">
              {/* Left Logo and Location Info combined */}
              <div className="flex items-center gap-2 flex-1 min-w-0">
                <Link href="/" className="flex items-center shrink-0">
                  <Logo simple={true} showText={false} className="h-8 w-8" />
                </Link>
                <button
                  onClick={() => setLocationPickerOpen(true)}
                  className="flex flex-col items-start text-left cursor-pointer group min-w-0 flex-1"
                >
                  <span className="text-xs font-black text-zinc-900 dark:text-white tracking-tight flex items-center gap-1.5">
                    <MapPin size={12} className="text-primary animate-bounce-subtle shrink-0" />
                    Fast Delivery
                  </span>
                  <span className="text-[10px] font-bold text-zinc-500 dark:text-zinc-400 flex items-center gap-0.5 w-full">
                    <span className="truncate max-w-[180px]">
                      {selectedLocation || "Select Location"}
                    </span>
                    <ChevronDown size={10} className="text-zinc-400 shrink-0" />
                  </span>
                </button>
              </div>

              {/* Theme Toggle Button on mobile */}
              <button
                onClick={() => {
                  toggleTheme()
                  if (typeof window !== 'undefined' && 'vibrate' in navigator) {
                    navigator.vibrate(12)
                  }
                }}
                className="h-8 w-8 rounded-full bg-zinc-100 dark:bg-zinc-900/80 border border-zinc-200/50 dark:border-zinc-800/40 flex items-center justify-center hover:bg-zinc-200 dark:hover:bg-zinc-800 transition-colors shrink-0"
                aria-label="Toggle theme"
              >
                {theme === 'dark' ? (
                  <Sun size={15} className="text-amber-500 animate-pulse-gentle" />
                ) : (
                  <Moon size={15} className="text-indigo-600" />
                )}
              </button>
            </div>

            {/* Bottom Row: Full-width Search Trigger */}
            <div
              onClick={() => setSearchOpen(true)}
              className="w-full relative cursor-pointer group"
            >
              <Search size={15} className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-400 group-hover:text-primary transition-colors" />
              <input
                type="text"
                placeholder={SEARCH_PLACEHOLDERS[placeholderIndex]}
                readOnly
                className="w-full cursor-pointer rounded-full border border-zinc-200/80 dark:border-white/[0.06] bg-zinc-50/70 dark:bg-white/[0.03] py-1.5 pl-10 pr-4 text-[11px] font-black placeholder:text-zinc-400/80 focus:outline-none transition-all duration-300 shadow-sm"
              />
            </div>
          </div>

          {/* Desktop Header (1 Row) */}
          <div className="hidden md:flex items-center justify-between gap-6 h-14 md:h-16 animate-fade-in">
            {/* Left side: Logo & Location selector */}
            <div className="flex items-center gap-3 shrink-0">
              <Link href="/" className="flex items-center shrink-0">
                <Logo />
              </Link>
              <div className="h-8 w-[1px] bg-zinc-200 dark:bg-zinc-800 mx-1" />
              <button
                onClick={() => setLocationPickerOpen(true)}
                className="flex flex-col items-start hover:opacity-85 transition-opacity text-left cursor-pointer group shrink-0 max-w-[200px]"
              >
                <span className="text-xs font-black text-primary dark:text-rose-400 tracking-tight flex items-center gap-1.5">
                  <MapPin size={13} className="text-primary animate-bounce-subtle shrink-0" />
                  Fast Delivery
                </span>
                <span className="text-[11px] font-bold text-zinc-500 dark:text-zinc-400 group-hover:text-primary transition-colors flex items-center gap-0.5 mt-0.5 w-full">
                  <span className="truncate max-w-[150px]">
                    {selectedLocation || "Select Location"}
                  </span>
                  <ChevronDown size={12} className="text-zinc-400 shrink-0 group-hover:translate-y-0.5 transition-transform" />
                </span>
              </button>
            </div>

            {/* Center: Search bar Trigger */}
            <div
              onClick={() => setSearchOpen(true)}
              className="flex-1 max-w-xl cursor-pointer group"
            >
              <div className="relative">
                <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-400 group-hover:text-primary transition-colors" />
                <input
                  type="text"
                  placeholder={SEARCH_PLACEHOLDERS[placeholderIndex]}
                  readOnly
                  className="w-full cursor-pointer rounded-full border border-zinc-200/80 dark:border-white/[0.06] bg-zinc-50/90 dark:bg-white/[0.04] py-2.5 pl-11 pr-4 text-sm font-semibold placeholder:text-zinc-400/85 focus:outline-none transition-all duration-300 group-hover:border-zinc-300 dark:group-hover:border-white/[0.12] group-hover:bg-zinc-100/50 dark:group-hover:bg-white/[0.08] shadow-sm"
                />
              </div>
            </div>

            <div className="flex items-center gap-6 shrink-0">
              <button
                onClick={() => {
                  toggleTheme()
                  if (typeof window !== 'undefined' && 'vibrate' in navigator) {
                    navigator.vibrate(12)
                  }
                }}
                className="p-2.5 rounded-xl border border-zinc-200/60 dark:border-zinc-800/60 hover:bg-zinc-50 dark:hover:bg-zinc-900/60 text-zinc-600 dark:text-zinc-400 hover:text-primary dark:hover:text-primary transition-all duration-300 shadow-sm"
                aria-label="Toggle theme"
              >
                {theme === 'dark' ? (
                  <Sun size={18} className="text-amber-500 animate-pulse-gentle" />
                ) : (
                  <Moon size={18} className="text-indigo-600" />
                )}
              </button>
              <Link
                href="/account"
                className="flex items-center gap-2 px-3 py-2 rounded-xl text-zinc-600 dark:text-zinc-400 hover:text-primary transition-colors cursor-pointer group"
              >
                <User size={18} className="group-hover:scale-105 transition-transform stroke-[2]" />
                <span className="text-sm font-bold">{session ? 'Account' : 'Login'}</span>
              </Link>

              {!mounted || totalItems === 0 ? (
                <button
                  onClick={toggleCart}
                  className="flex items-center gap-2 px-4 py-2.5 rounded-xl border border-zinc-200/80 dark:border-zinc-800/80 hover:border-primary/30 hover:bg-primary/5 text-zinc-700 dark:text-zinc-300 hover:text-primary transition-all duration-300 font-bold text-sm cursor-pointer group shadow-sm"
                >
                  <ShoppingBag size={18} className="group-hover:scale-105 transition-transform" />
                  <span>Cart</span>
                </button>
              ) : (
                <button
                  onClick={toggleCart}
                  className={cn(
                    "flex items-center gap-2 px-4 py-2.5 rounded-xl bg-[#00b140] hover:bg-[#009b35] text-white font-extrabold text-sm transition-all duration-300 shadow-md shadow-emerald-500/10 hover:shadow-emerald-500/20 cursor-pointer relative",
                    isCartBouncing && "scale-105"
                  )}
                  id="navbar-cart-icon"
                >
                  <ShoppingBag size={18} className="stroke-[2.5]" />
                  <span>Cart</span>
                  <span className="bg-white text-[#00b140] text-[10px] font-black h-5 px-1.5 rounded-full flex items-center justify-center min-w-[20px] ml-1">
                    {totalItems}
                  </span>
                </button>
              )}
            </div>
          </div>
        </div>

        {(!groceryMartOpen || !cafeOpen) && (
          <div className="bg-gradient-to-r from-amber-500 via-orange-500 to-rose-500 text-white text-[10px] sm:text-xs font-black py-2 px-4 text-center border-t border-orange-600/20 shadow-lg flex items-center justify-center gap-2 select-none animate-slide-down backdrop-blur-sm">
            <span className="animate-pulse-gentle">⚠️</span>
            {!groceryMartOpen && !cafeOpen ? (
              <span>FastKirana Mart & Cafe are currently closed. We'll be back online soon!</span>
            ) : !groceryMartOpen ? (
              <span>Grocery Mart is temporarily closed. Cafe is open! Prep time: 10 mins ☕</span>
            ) : (
              <span>Cafe Kitchen is temporarily closed. Grocery delivery is active! 📦</span>
            )}
          </div>
        )}
        <Suspense fallback={null}>
          <TopProgressBar />
        </Suspense>
      </nav>

      {isMobileMenuOpen && (
        <div className="fixed inset-0 z-40 bg-black/40 md:hidden" onClick={() => setIsMobileMenuOpen(false)}>
          <div
            className="absolute left-0 top-0 w-72 h-full bg-white dark:bg-zinc-950 border-r border-zinc-100 dark:border-zinc-900/50 shadow-xl p-4 space-y-2"
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => { setLocationPickerOpen(true); setIsMobileMenuOpen(false) }}
              className="flex w-full items-center gap-3 rounded-xl px-3 py-3 md:hover:bg-zinc-100 dark:md:hover:bg-zinc-900 active:bg-zinc-100 dark:active:bg-zinc-900/60 transition-colors cursor-pointer"
            >
              <MapPin size={18} className="text-primary" />
              <div className="text-left">
                <p className="text-xs text-zinc-500 dark:text-zinc-400">Deliver to</p>
                <p className="text-sm font-bold text-zinc-800 dark:text-zinc-200">{selectedLocation}</p>
              </div>
            </button>
            <Link 
              href="/account" 
              className="flex w-full items-center gap-3 rounded-xl px-3 py-3 md:hover:bg-zinc-100 dark:md:hover:bg-zinc-900 active:bg-zinc-100 dark:active:bg-zinc-900/60 transition-colors" 
              onClick={() => setIsMobileMenuOpen(false)}
            >
              <User size={18} className="text-zinc-500 dark:text-zinc-400" />
              <span className="text-sm font-bold text-zinc-800 dark:text-zinc-200">My Account</span>
            </Link>
            <Link 
              href="/account/orders" 
              className="flex w-full items-center gap-3 rounded-xl px-3 py-3 md:hover:bg-zinc-100 dark:md:hover:bg-zinc-900 active:bg-zinc-100 dark:active:bg-zinc-900/60 transition-colors" 
              onClick={() => setIsMobileMenuOpen(false)}
            >
              <ShoppingBag size={18} className="text-zinc-500 dark:text-zinc-400" />
              <span className="text-sm font-bold text-zinc-800 dark:text-zinc-200">My Orders</span>
            </Link>
          </div>
        </div>
      )}

      <LocationPicker
        open={isLocationPickerOpen}
        onClose={() => setLocationPickerOpen(false)}
      />

      <SearchOverlay
        open={isSearchOpen}
        onClose={() => setSearchOpen(false)}
      />
    </>
  )
}
