'use client'

import Link from 'next/link'
import { Search, ShoppingBag, MapPin, User, ChevronDown } from 'lucide-react'
import { useState, useEffect, useCallback } from 'react'
import { useCartStore } from '@/stores/cart-store'
import { useUIStore } from '@/stores/ui-store'
import { usePathname } from 'next/navigation'
import { LocationPicker } from '@/components/shared/location-picker'
import { SearchOverlay } from '@/components/shared/search-overlay'
import { Logo } from '@/components/layout/logo'
import { useSession } from 'next-auth/react'
import { cn } from '@/lib/utils'

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
  const { data: session } = useSession()
  const [groceryMartOpen, setGroceryMartOpen] = useState(true)
  const [cafeOpen, setCafeOpen] = useState(true)

  useEffect(() => {
    hydrateLocation()
    fetch('/api/settings')
      .then(res => res.json())
      .then(data => {
        const gOpen = data.grocery_mart_open !== 'false'
        const cOpen = data.cafe_open !== 'false'
        const radius = data.delivery_radius ? parseFloat(data.delivery_radius) : 5.0
        
        setGroceryMartOpen(gOpen)
        setCafeOpen(cOpen)
        setStoreStatus(gOpen, cOpen, radius)
      })
      .catch(err => console.error('Error loading store status in navbar:', err))
  }, [hydrateLocation, setStoreStatus])

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
          "fixed top-0 left-0 right-0 z-50 transition-all duration-300 border-b",
          isScrolled
            ? "bg-white/80 dark:bg-zinc-950/85 backdrop-blur-md border-zinc-200/50 dark:border-zinc-800/50 shadow-md shadow-zinc-100/40 dark:shadow-none py-1.5"
            : "bg-white/95 dark:bg-zinc-950/95 border-zinc-100 dark:border-zinc-900 shadow-sm py-2.5"
        )}
      >
        <div className="mx-auto max-w-7xl px-4">
          {/* Mobile Header (2 Rows) */}
          <div className="flex flex-col gap-2.5 md:hidden animate-fade-in">
            <div className="flex items-center justify-between w-full">
              <div className="flex items-center gap-2 min-w-0">
                <Link href="/" className="flex items-center shrink-0">
                  <Logo showText={false} />
                </Link>
              </div>

              {/* Location Select (mobile) */}
              <button
                onClick={() => setLocationPickerOpen(true)}
                className="flex items-center gap-1.5 bg-[#fff1ed] dark:bg-rose-950/20 border border-rose-100/30 dark:border-rose-900/20 px-4 py-2 rounded-full transition-all shrink-0 select-none cursor-pointer max-w-[50%] shadow-sm"
              >
                <MapPin size={14} className="text-primary shrink-0 animate-bounce-subtle" />
                <span className="text-xs font-black truncate text-zinc-800 dark:text-zinc-100">
                  {selectedLocation || "Select Location"}
                </span>
                <span className="h-1.5 w-1.5 rounded-full bg-accent shrink-0 relative flex">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-accent opacity-75"></span>
                  <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-accent"></span>
                </span>
              </button>

              {/* Actions (mobile) */}
              <div className="flex items-center gap-4 shrink-0">
                <Link href="/account" className="text-zinc-600 dark:text-zinc-400 hover:text-primary transition-colors">
                  <User size={22} className="stroke-[2]" />
                </Link>
                <button
                  onClick={toggleCart}
                  className={cn(
                    "relative text-zinc-600 dark:text-zinc-400 hover:text-primary transition-all duration-300",
                    isCartBouncing && "scale-110 text-primary"
                  )}
                  id="navbar-cart-icon"
                >
                  <ShoppingBag size={22} className="stroke-[2]" />
                  {totalItems > 0 && (
                    <span className="absolute -top-1.5 -right-1.5 flex h-4.5 w-4.5 items-center justify-center rounded-full bg-primary text-[9px] font-black text-white animate-badge-bounce shadow-sm">
                      {totalItems}
                    </span>
                  )}
                </button>
              </div>
            </div>

            {/* Bottom Row: Full-width Search Trigger */}
            <div
              onClick={() => setSearchOpen(true)}
              className="w-full relative cursor-pointer group"
            >
              <Search size={17} className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-400 group-hover:text-primary transition-colors" />
              <input
                type="text"
                placeholder={SEARCH_PLACEHOLDERS[placeholderIndex]}
                readOnly
                className="w-full cursor-pointer rounded-full border border-zinc-200/80 dark:border-zinc-800/80 bg-zinc-50/70 dark:bg-zinc-900/70 py-3 pl-11 pr-4 text-xs font-semibold placeholder:text-zinc-400/80 focus:outline-none transition-all duration-300 shadow-sm"
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
              <div className="h-8 w-[1px] bg-zinc-200 dark:bg-zinc-800 mx-2" />
              <button
                onClick={() => setLocationPickerOpen(true)}
                className="flex flex-col items-start hover:opacity-85 transition-opacity text-left cursor-pointer group shrink-0"
              >
                <span className="text-[10px] font-extrabold text-primary dark:text-rose-400 uppercase tracking-wider flex items-center gap-1">
                  <MapPin size={10} className="text-primary animate-bounce-subtle" />
                  Deliver to
                </span>
                <span className="text-sm font-black text-zinc-800 dark:text-zinc-100 group-hover:text-primary transition-colors flex items-center gap-1 mt-0.5">
                  {selectedLocation || "Select Location"}
                  <ChevronDown size={14} className="text-zinc-500 shrink-0 group-hover:translate-y-0.5 transition-transform" />
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
                  className="w-full cursor-pointer rounded-full border border-zinc-200/80 dark:border-zinc-800/80 bg-zinc-50/90 dark:bg-zinc-900/90 py-2.5 pl-11 pr-4 text-sm font-semibold placeholder:text-zinc-400/85 focus:outline-none transition-all duration-300 group-hover:border-zinc-300 dark:group-hover:border-zinc-700 group-hover:bg-zinc-100/50 dark:group-hover:bg-zinc-800/50 shadow-sm"
                />
              </div>
            </div>

            <div className="flex items-center gap-6 shrink-0">
              <Link
                href="/account"
                className="flex items-center gap-2 px-3 py-2 rounded-xl text-zinc-600 dark:text-zinc-400 hover:text-primary transition-colors cursor-pointer group"
              >
                <User size={18} className="group-hover:scale-105 transition-transform stroke-[2]" />
                <span className="text-sm font-bold">{session ? 'Account' : 'Login'}</span>
              </Link>

              {totalItems === 0 ? (
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
      </nav>

      {isMobileMenuOpen && (
        <div className="fixed inset-0 z-40 bg-black/30 md:hidden" onClick={() => setIsMobileMenuOpen(false)}>
          <div
            className="absolute left-0 top-0 w-72 h-full bg-white shadow-xl p-4 space-y-2"
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => { setLocationPickerOpen(true); setIsMobileMenuOpen(false) }}
              className="flex w-full items-center gap-3 rounded-xl px-3 py-3 hover:bg-zinc-100 transition-colors"
            >
              <MapPin size={18} className="text-primary" />
              <div className="text-left">
                <p className="text-xs text-zinc-500">Deliver to</p>
                <p className="text-sm font-medium">{selectedLocation}</p>
              </div>
            </button>
            <Link href="/account" className="flex w-full items-center gap-3 rounded-xl px-3 py-3 hover:bg-zinc-100 transition-colors" onClick={() => setIsMobileMenuOpen(false)}>
              <User size={18} className="text-zinc-600" />
              <span className="text-sm font-medium">My Account</span>
            </Link>
            <Link href="/account/orders" className="flex w-full items-center gap-3 rounded-xl px-3 py-3 hover:bg-zinc-100 transition-colors" onClick={() => setIsMobileMenuOpen(false)}>
              <ShoppingBag size={18} className="text-zinc-600" />
              <span className="text-sm font-medium">My Orders</span>
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
