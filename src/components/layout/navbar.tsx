'use client'

import Link from 'next/link'
import { Search, ShoppingBag, MapPin, User, ChevronDown, Sun, Moon } from 'lucide-react'
import { useState, useEffect, useCallback, Suspense, useRef } from 'react'
import { triggerHaptic } from '@/lib/haptic'
import { playCartPop } from '@/lib/audio'
import { useCartStore } from '@/stores/cart-store'
import { useUIStore } from '@/stores/ui-store'
import { usePathname } from 'next/navigation'
import dynamic from 'next/dynamic'

const LocationPicker = dynamic(() => import('@/components/shared/location-picker').then(mod => mod.LocationPicker), {
  ssr: false
})
const SearchOverlay = dynamic(() => import('@/components/shared/search-overlay').then(mod => mod.SearchOverlay), {
  ssr: false
})

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
  const pathname = usePathname()
  const isCategoryPage = pathname?.startsWith('/category/')
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
  const setSettings = useUIStore((s) => s.setSettings)
  const setSelectedLocation = useUIStore((s) => s.setSelectedLocation)
  const setUserCoords = useUIStore((s) => s.setUserCoords)
  const { data: session } = useSession()
  const { theme, toggleTheme } = useTheme()
  const [groceryMartOpen, setGroceryMartOpen] = useState(true)
  const [cafeOpen, setCafeOpen] = useState(true)
  const [restaurantOpen, setRestaurantOpen] = useState(true)
  const [mounted, setMounted] = useState(false)
  const prevGroceryOpenRef = useRef<boolean | null>(null)
  const prevCafeOpenRef = useRef<boolean | null>(null)
  const prevRestaurantOpenRef = useRef<boolean | null>(null)

  const getDashboardLink = useCallback(() => {
    if (!session?.user) return '/account'
    const role = session.user.role
    const email = session.user.email || ''
    switch (role) {
      case 'ADMIN': return '/admin'
      case 'CHEF':
        if (email.toLowerCase().startsWith('restaurant')) return '/restaurant-kitchen'
        return '/cafe-kitchen'
      case 'PICKER': return '/picker'
      case 'DELIVERY': return '/delivery'
      default: return '/account'
    }
  }, [session])

  useEffect(() => {
    setMounted(true)
  }, [])





  useEffect(() => {
    hydrateLocation()

    const fetchStatus = () => {
      fetch('/api/settings', { cache: 'no-store' })
        .then(res => res.json())
        .then(data => {
          const gOpen = data.grocery_mart_open !== 'false'
          const cOpen = data.cafe_open !== 'false'
          const rOpen = data.restaurant_open !== 'false'
          const radius = data.delivery_radius ? parseFloat(data.delivery_radius) : 5.0
          const storeLat = data.store_lat ? parseFloat(data.store_lat) : 26.1534185
          const storeLng = data.store_lng ? parseFloat(data.store_lng) : 80.1714024

          // Parse category statuses
          const categoryStatus: Record<string, boolean> = {}
          Object.keys(data).forEach((key) => {
            if (key.startsWith('category_open_')) {
              const slug = key.replace('category_open_', '')
              categoryStatus[slug] = data[key] === 'true'
            }
          })

          // Trigger alerts on opening transition
          if (prevGroceryOpenRef.current !== null && prevGroceryOpenRef.current === false && gOpen === true) {
            triggerHaptic('success')
            toast.success('🏪 Grocery Mart is now OPEN! Order your fresh groceries now.', {
              duration: 6000,
              id: 'grocery-mart-opened-alert',
            })
            playCartPop()
          }

          if (prevCafeOpenRef.current !== null && prevCafeOpenRef.current === false && cOpen === true) {
            triggerHaptic('success')
            toast.success('☕ FastKirana Cafe is now OPEN! Order fresh sandwiches & coffee now.', {
              duration: 6000,
              id: 'cafe-opened-alert',
            })
            playCartPop()
          }

          if (prevRestaurantOpenRef.current !== null && prevRestaurantOpenRef.current === false && rOpen === true) {
            triggerHaptic('success')
            toast.success('🍳 Wedson Restaurant is now OPEN! Order hot meals & combos now.', {
              duration: 6000,
              id: 'restaurant-opened-alert',
            })
            playCartPop()
          }

          // Trigger alerts on closing transition
          if (prevGroceryOpenRef.current !== null && prevGroceryOpenRef.current === true && gOpen === false) {
            triggerHaptic('warning')
            toast.error('🏪 Grocery Mart has been temporarily closed by admin.', {
              duration: 6000,
              id: 'grocery-mart-closed-alert',
            })
          }

          if (prevCafeOpenRef.current !== null && prevCafeOpenRef.current === true && cOpen === false) {
            triggerHaptic('warning')
            toast.error('☕ FastKirana Cafe has been temporarily closed by admin.', {
              duration: 6000,
              id: 'cafe-closed-alert',
            })
          }

          if (prevRestaurantOpenRef.current !== null && prevRestaurantOpenRef.current === true && rOpen === false) {
            triggerHaptic('warning')
            toast.error('🍳 Wedson Restaurant has been temporarily closed by admin.', {
              duration: 6000,
              id: 'restaurant-closed-alert',
            })
          }

          prevGroceryOpenRef.current = gOpen
          prevCafeOpenRef.current = cOpen
          prevRestaurantOpenRef.current = rOpen
          
          setGroceryMartOpen(gOpen)
          setCafeOpen(cOpen)
          setRestaurantOpen(rOpen)
          setStoreStatus(gOpen, cOpen, rOpen, radius, categoryStatus)
          setSettings(data)

          // Automatically set default location if not set, without intrusive geolocation prompts
          const currentLoc = useUIStore.getState().selectedLocation
          if (!currentLoc || currentLoc === 'Select Location') {
            const fallbackArea = "Ghatampur Market"
            setSelectedLocation(fallbackArea)
            setUserCoords({ lat: storeLat, lng: storeLng })
          }
        })
        .catch(err => console.error('Error loading store status/location in navbar:', err))
    }

    // Initial fetch
    fetchStatus()

    // Background polling (every 60 seconds) only when tab is visible to avoid Vercel resource exhaustion
    const statusInterval = setInterval(() => {
      if (document.visibilityState === 'visible') {
        fetchStatus()
      }
    }, 60000)

    // Re-fetch status immediately when user refocusses or returns to the window tab
    const handleFocus = () => {
      fetchStatus()
    }
    window.addEventListener('focus', handleFocus)

    // Re-fetch status immediately when tab becomes visible
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        fetchStatus()
      }
    }
    document.addEventListener('visibilitychange', handleVisibilityChange)

    return () => {
      clearInterval(statusInterval)
      window.removeEventListener('focus', handleFocus)
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }

  }, [hydrateLocation, setStoreStatus, setSettings, setSelectedLocation, setUserCoords])

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
          "fixed top-0 left-0 right-0 z-50 transition-all duration-300 border-b backdrop-blur-xl",
          isScrolled
            ? "bg-white/70 dark:bg-zinc-950/70 border-zinc-200/45 dark:border-white/[0.05] shadow-md py-1.5"
            : "bg-white/80 dark:bg-zinc-950/80 border-zinc-150/30 dark:border-white/[0.04] shadow-xs py-2.5"
        )}
      >
        <div className="mx-auto max-w-7xl px-4">
          {/* Mobile Header (2 Rows) */}
          <div className="flex flex-col gap-2 md:hidden animate-fade-in">
            <div className="flex items-center justify-between w-full gap-3">
              {/* Left Logo and Location Info combined */}
              <div className="flex items-center gap-2 flex-1 min-w-0">
                <Link href="/" className="flex items-center shrink-0">
                  <Logo simple={true} showText={false} className="h-8.5 w-8.5" />
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
                    <span className="truncate max-w-[185px]">
                      {selectedLocation || "Select Location"}
                    </span>
                    <ChevronDown size={10} className="text-zinc-400 shrink-0" />
                  </span>
                </button>
              </div>

              {/* Top Right Actions: Theme Toggle & Zepto-style Avatar */}
              <div className="flex items-center gap-2 shrink-0">
                <button
                  onClick={() => {
                    toggleTheme()
                    if (typeof window !== 'undefined' && 'vibrate' in navigator) {
                      navigator.vibrate(12)
                    }
                  }}
                  className="h-8.5 w-8.5 rounded-full bg-zinc-100/80 dark:bg-zinc-900/80 border border-zinc-200/50 dark:border-zinc-800/40 flex items-center justify-center hover:bg-zinc-200 dark:hover:bg-zinc-800 transition-colors shrink-0"
                  aria-label="Toggle theme"
                >
                  {theme === 'dark' ? (
                    <Sun size={15} className="text-amber-500" />
                  ) : (
                    <Moon size={15} className="text-indigo-600" />
                  )}
                </button>

              </div>
            </div>

            {/* Bottom Row: Full-width Search Trigger */}
            {!isCategoryPage && (
              <div
                onClick={() => setSearchOpen(true)}
                className="w-full relative cursor-pointer group mt-0.5"
              >
                <Search size={15} className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-400 group-hover:text-primary transition-all duration-300" />
                <input
                  type="text"
                  placeholder={SEARCH_PLACEHOLDERS[placeholderIndex]}
                  readOnly
                  className={cn(
                    "w-full cursor-pointer rounded-full border transition-all duration-300 shadow-xs focus:outline-none placeholder:text-zinc-400/85 text-xs font-bold",
                    isScrolled
                      ? "border-zinc-200/50 dark:border-white/[0.08] bg-white/95 dark:bg-black/60 py-2 pl-10 pr-4"
                      : "border-zinc-150/70 dark:border-white/[0.06] bg-white dark:bg-zinc-900/90 py-2.5 pl-10 pr-4 shadow-[0_2px_8px_rgba(0,0,0,0.02)]"
                  )}
                />
              </div>
            )}
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
              className="flex-1 max-w-xl cursor-pointer group relative"
            >
              <div className="relative flex items-center">
                <Search size={17} className="absolute left-4.5 text-zinc-400 group-hover:text-rose-500 transition-colors duration-300" />
                <input
                  type="text"
                  placeholder={SEARCH_PLACEHOLDERS[placeholderIndex]}
                  readOnly
                  className="w-full cursor-pointer rounded-full border border-zinc-200/60 dark:border-zinc-800/40 bg-zinc-50/40 dark:bg-zinc-900/20 py-2.5 pl-11.5 pr-14 text-xs font-bold placeholder:text-zinc-400/80 focus:outline-none transition-all duration-300 group-hover:border-zinc-300 dark:group-hover:border-zinc-700 group-hover:bg-zinc-100/40 dark:group-hover:bg-zinc-900/45 shadow-[0_2px_8px_rgba(0,0,0,0.01)] group-hover:shadow-[0_4px_12px_rgba(0,0,0,0.03)]"
                />
                <span className="absolute right-4.5 px-2 py-1 rounded-md bg-zinc-200/50 dark:bg-zinc-800/60 text-[9px] font-black text-zinc-500 dark:text-zinc-400 border border-zinc-300/30 dark:border-zinc-700/30 select-none pointer-events-none transition-transform duration-300 group-hover:scale-95">
                  ⌘K
                </span>
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
                className="p-2.5 rounded-full border border-zinc-200/60 dark:border-zinc-800/50 bg-zinc-50/30 dark:bg-zinc-900/20 text-zinc-650 dark:text-zinc-450 hover:bg-zinc-100/50 dark:hover:bg-zinc-900/40 hover:border-zinc-300 dark:hover:border-zinc-700 hover:text-rose-500 transition-all duration-300 shadow-[0_2px_8px_rgba(0,0,0,0.01)]"
                aria-label="Toggle theme"
              >
                {theme === 'dark' ? (
                  <Sun size={17} className="text-amber-500 animate-pulse-gentle" />
                ) : (
                  <Moon size={17} className="text-indigo-600" />
                )}
              </button>
              
              <Link
                href={getDashboardLink()}
                className="flex items-center gap-2 px-4 py-2.5 rounded-full border border-zinc-200/60 dark:border-zinc-800/50 bg-zinc-50/30 dark:bg-zinc-900/20 text-zinc-650 dark:text-zinc-350 hover:bg-zinc-100/50 dark:hover:bg-zinc-900/40 hover:border-zinc-300 dark:hover:border-zinc-700 hover:text-rose-500 transition-all duration-300 cursor-pointer group shadow-[0_2px_8px_rgba(0,0,0,0.01)] hover:shadow-[0_4px_12px_rgba(0,0,0,0.03)]"
              >
                <User size={16} className="group-hover:scale-105 transition-transform stroke-[2.2]" />
                <span className="text-xs font-black tracking-tight">
                  {session ? (session.user.role === 'USER' ? 'Account' : 'Console') : 'Login'}
                </span>
              </Link>

              {!mounted || totalItems === 0 ? (
                <button
                  onClick={toggleCart}
                  className="flex items-center gap-2 px-4.5 py-2.5 rounded-full border border-zinc-200/60 dark:border-zinc-800/50 bg-zinc-50/30 dark:bg-zinc-900/20 text-zinc-650 dark:text-zinc-350 hover:bg-zinc-100/50 dark:hover:bg-zinc-900/40 hover:border-zinc-300 dark:hover:border-zinc-700 hover:text-rose-500 transition-all duration-300 font-black text-xs cursor-pointer group shadow-[0_2px_8px_rgba(0,0,0,0.01)]"
                >
                  <ShoppingBag size={16} className="group-hover:scale-105 transition-transform stroke-[2.2]" />
                  <span>Cart</span>
                </button>
              ) : (
                <button
                  onClick={toggleCart}
                  className={cn(
                    "flex items-center gap-2 px-4.5 py-2.5 rounded-full bg-[#00b140] hover:bg-[#009b35] text-white font-extrabold text-xs transition-all duration-300 shadow-md shadow-emerald-500/10 hover:shadow-emerald-500/20 cursor-pointer relative",
                    isCartBouncing && "scale-105"
                  )}
                  id="navbar-cart-icon"
                >
                  <ShoppingBag size={16} className="stroke-[2.5]" />
                  <span>Cart</span>
                  <span className="bg-white text-[#00b140] text-[10px] font-black h-5 px-1.5 rounded-full flex items-center justify-center min-w-[20px] ml-1">
                    {totalItems}
                  </span>
                </button>
              )}
            </div>
          </div>
        </div>


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
              href={getDashboardLink()} 
              className="flex w-full items-center gap-3 rounded-xl px-3 py-3 md:hover:bg-zinc-100 dark:md:hover:bg-zinc-900 active:bg-zinc-100 dark:active:bg-zinc-900/60 transition-colors" 
              onClick={() => setIsMobileMenuOpen(false)}
            >
              <User size={18} className="text-zinc-500 dark:text-zinc-400" />
              <span className="text-sm font-bold text-zinc-800 dark:text-zinc-200">
                {session && session.user.role !== 'USER' ? 'My Console' : 'My Account'}
              </span>
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
