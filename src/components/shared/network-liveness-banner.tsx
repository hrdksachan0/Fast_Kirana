'use client'

import React, { useState, useEffect } from 'react'
import { WifiOff, Wifi } from 'lucide-react'

export function NetworkLivenessBanner() {
  const [isOnline, setIsOnline] = useState(true)
  const [showReconnectedBanner, setShowReconnectedBanner] = useState(false)

  useEffect(() => {
    if (typeof window === 'undefined') return

    // Initial status
    setIsOnline(navigator.onLine)

    const handleOnline = () => {
      setIsOnline(true)
      setShowReconnectedBanner(true)
      const timer = setTimeout(() => {
        setShowReconnectedBanner(false)
      }, 3500)
      return () => clearTimeout(timer)
    }

    const handleOffline = () => {
      setIsOnline(false)
      setShowReconnectedBanner(false)
    }

    window.addEventListener('online', handleOnline)
    window.addEventListener('offline', handleOffline)

    return () => {
      window.removeEventListener('online', handleOnline)
      window.removeEventListener('offline', handleOffline)
    }
  }, [])

  if (isOnline && !showReconnectedBanner) {
    return null
  }

  return (
    <div
      role="status"
      aria-live="polite"
      className="fixed bottom-16 sm:bottom-4 left-1/2 -translate-x-1/2 z-50 w-[92%] max-w-md pointer-events-none transition-all duration-300 animate-in fade-in slide-in-from-bottom-3"
    >
      {!isOnline ? (
        <div className="bg-amber-950/90 dark:bg-amber-950/95 border border-amber-600/50 text-amber-200 px-4 py-2.5 rounded-2xl shadow-xl backdrop-blur-md flex items-center justify-between gap-3 text-xs font-semibold">
          <div className="flex items-center gap-2.5 min-w-0">
            <span className="p-1.5 rounded-xl bg-amber-500/20 text-amber-400 shrink-0">
              <WifiOff className="h-4 w-4 animate-pulse" />
            </span>
            <div className="min-w-0">
              <p className="font-bold text-amber-100">You are currently offline</p>
              <p className="text-[10px] text-amber-300/80 truncate">Cart changes are saved safely on your device.</p>
            </div>
          </div>
          <span className="text-[9px] font-black uppercase tracking-wider bg-amber-500/20 px-2 py-0.5 rounded-md border border-amber-500/30 shrink-0">
            Offline
          </span>
        </div>
      ) : (
        <div className="bg-emerald-950/90 dark:bg-emerald-950/95 border border-emerald-600/50 text-emerald-200 px-4 py-2.5 rounded-2xl shadow-xl backdrop-blur-md flex items-center justify-between gap-3 text-xs font-semibold">
          <div className="flex items-center gap-2.5 min-w-0">
            <span className="p-1.5 rounded-xl bg-emerald-500/20 text-emerald-400 shrink-0">
              <Wifi className="h-4 w-4" />
            </span>
            <div className="min-w-0">
              <p className="font-bold text-emerald-100">Back Online! ⚡</p>
              <p className="text-[10px] text-emerald-300/80 truncate">Cart and live prices synchronized.</p>
            </div>
          </div>
          <span className="text-[9px] font-black uppercase tracking-wider bg-emerald-500/20 px-2 py-0.5 rounded-md border border-emerald-500/30 shrink-0">
            Synced
          </span>
        </div>
      )}
    </div>
  )
}
