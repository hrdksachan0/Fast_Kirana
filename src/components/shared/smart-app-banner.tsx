'use client'

import { useEffect, useState } from 'react'
import { X, Sparkles } from 'lucide-react'
import { usePathname } from 'next/navigation'

const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.fastkirana.app'
const DISMISSED_STORAGE_KEY = 'fastkirana_app_banner_dismissed'

export function SmartAppBanner() {
  const pathname = usePathname()
  const [isVisible, setIsVisible] = useState(false)
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)

    // Only run on client browser
    if (typeof window === 'undefined') return

    // 1. Check if user is already inside a standalone PWA or TWA/App webview
    const isStandalone =
      window.matchMedia('(display-mode: standalone)').matches ||
      (window.navigator as any).standalone === true ||
      document.referrer.includes('android-app://')

    if (isStandalone) {
      return
    }

    // 2. Check if dismissed within last 24 hours
    try {
      const dismissedTimestamp = localStorage.getItem(DISMISSED_STORAGE_KEY)
      if (dismissedTimestamp) {
        const timeDiff = Date.now() - parseInt(dismissedTimestamp, 10)
        // Hide for 24 hours if dismissed
        if (timeDiff < 24 * 60 * 60 * 1000) {
          return
        }
      }
    } catch (_) {}

    // Show banner on mobile browsers
    setIsVisible(true)
  }, [])

  const handleDismiss = (e: React.MouseEvent) => {
    e.stopPropagation()
    setIsVisible(false)
    try {
      localStorage.setItem(DISMISSED_STORAGE_KEY, Date.now().toString())
    } catch (_) {}
  }

  const handleOpenApp = () => {
    if (typeof window === 'undefined') return

    const userAgent = navigator.userAgent || ''
    const isAndroid = /android/i.test(userAgent)
    const isIOS = /iPad|iPhone|iPod/.test(userAgent) && !(window as any).MSStream

    if (isAndroid) {
      // Intent URL attempts to open installed FastKirana Android app, or falls back directly to Play Store listing
      const intentUrl = 'intent://open#Intent;scheme=fastkirana;package=com.fastkirana.app;end'
      const start = Date.now()

      window.location.href = intentUrl

      // If app is not installed, browser stays on page; redirect to Play Store after short timeout
      setTimeout(() => {
        if (Date.now() - start < 1800) {
          window.location.href = PLAY_STORE_URL
        }
      }, 800)
    } else if (isIOS) {
      // For iOS, open App Store or custom scheme if configured
      window.location.href = PLAY_STORE_URL
    } else {
      window.open(PLAY_STORE_URL, '_blank', 'noopener,noreferrer')
    }
  }

  // Do not show on admin, kitchen, or delivery consoles
  if (
    !mounted ||
    !isVisible ||
    !pathname ||
    pathname.startsWith('/admin') ||
    pathname.startsWith('/restaurant-kitchen') ||
    pathname.startsWith('/cafe-kitchen') ||
    pathname.startsWith('/picker') ||
    pathname.startsWith('/delivery')
  ) {
    return null
  }

  return (
    <div
      data-smart-app-banner
      className="relative z-50 w-full bg-gradient-to-r from-zinc-950 via-zinc-900 to-zinc-950 border-b border-white/[0.08] text-white px-3 py-2 shadow-md md:hidden transition-all duration-300 select-none animate-fade-in"
    >
      <div className="mx-auto flex items-center justify-between gap-2 max-w-7xl">
        {/* Left: Dismiss Button */}
        <button
          type="button"
          onClick={handleDismiss}
          className="h-6 w-6 rounded-full bg-white/10 hover:bg-white/20 active:scale-90 flex items-center justify-center text-zinc-400 hover:text-white transition-all shrink-0 cursor-pointer"
          aria-label="Close smart app banner"
        >
          <X size={12} className="stroke-[2.5]" />
        </button>

        {/* Center: App Icon & Compelling Hook */}
        <div
          onClick={handleOpenApp}
          className="flex items-center gap-2.5 min-w-0 flex-1 cursor-pointer active:opacity-90"
        >
          <div className="h-8.5 w-8.5 rounded-xl overflow-hidden shrink-0 border border-white/10 shadow-sm bg-black/40 p-0.5">
            <img
              src="/icons/icon-192.png"
              alt="FastKirana App"
              className="h-full w-full object-cover rounded-[9px]"
            />
          </div>

          <div className="flex flex-col min-w-0">
            <div className="flex items-center gap-1.5 leading-none">
              <span className="text-[11.5px] font-black text-white tracking-tight truncate">
                ⚡ FastKirana
              </span>
              <span className="inline-flex items-center gap-0.5 text-[9px] font-extrabold uppercase px-1.5 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                <Sparkles size={8} /> Fast Delivery
              </span>
            </div>
            <p className="text-[10px] font-medium text-zinc-400 truncate mt-0.5 leading-tight">
              Deliver in Minutes • Track Live on App
            </p>
          </div>
        </div>

        {/* Right: CTA Button */}
        <button
          type="button"
          onClick={handleOpenApp}
          className="h-7.5 px-3 rounded-lg bg-emerald-500 hover:bg-emerald-600 active:scale-95 text-white font-extrabold text-[11px] tracking-wide flex items-center gap-1 shrink-0 shadow-[0_2px_10px_rgba(16,185,129,0.35)] transition-all cursor-pointer"
        >
          <span>USE APP</span>
        </button>
      </div>
    </div>
  )
}
