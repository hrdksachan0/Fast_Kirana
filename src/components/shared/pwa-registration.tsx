'use client'

import { useEffect, useState } from 'react'
import { Download, X, Share } from 'lucide-react'
import { useCartStore } from '@/stores/cart-store'
import { cn } from '@/lib/utils'

export function PWARegistration() {
  const [deferredPrompt, setDeferredPrompt] = useState<any>(null)
  const [showBanner, setShowBanner] = useState(false)
  const [isIOS, setIsIOS] = useState(false)
  const [showIOSInstructions, setShowIOSInstructions] = useState(false)

  useEffect(() => {
    // 1. Register Service Worker
    if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
      window.addEventListener('load', () => {
        navigator.serviceWorker
          .register('/sw.js')
          .then((reg) => {
            console.log('ServiceWorker registered with scope: ', reg.scope)
          })
          .catch((err) => {
            console.error('ServiceWorker registration failed: ', err)
          })
      })
    }

    // 2. Detect standalone mode (if already installed and opened as PWA, do not show banner)
    const isStandalone = 
      window.matchMedia('(display-mode: standalone)').matches ||
      (window.navigator as any).standalone === true
    if (isStandalone) return

    // 3. Detect iOS
    const userAgent = window.navigator.userAgent
    const ios = /iPad|iPhone|iPod/.test(userAgent) && !(window as any).MSStream
    setIsIOS(ios)

    // Check if dismissed in this session
    const isDismissed = sessionStorage.getItem('pwa-prompt-dismissed')
    if (isDismissed) return

    if (ios) {
      // iOS Safari doesn't support beforeinstallprompt but supports PWA via Add to Home Screen
      // Show the banner so they can click to get instructions
      setShowBanner(true)
    }

    // 4. Capture Chrome/Android beforeinstallprompt
    const handleBeforeInstallPrompt = (e: any) => {
      e.preventDefault()
      setDeferredPrompt(e)
      setShowBanner(true)
    }

    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt)

    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt)
    }
  }, [])

  const handleInstallClick = async () => {
    if (isIOS) {
      setShowIOSInstructions(true)
      return
    }

    if (!deferredPrompt) return

    deferredPrompt.prompt()
    const { outcome } = await deferredPrompt.userChoice
    if (outcome === 'accepted') {
      setShowBanner(false)
    }
    setDeferredPrompt(null)
  }

  const handleDismiss = () => {
    setShowBanner(false)
    setShowIOSInstructions(false)
    sessionStorage.setItem('pwa-prompt-dismissed', 'true')
  }

  const hasCartItems = useCartStore((s) => s.items.length > 0)

  if (!showBanner) return null

  return (
    <div className={cn(
      "fixed left-4 right-4 z-[999] md:hidden animate-slide-in-bottom",
      hasCartItems ? "bottom-[114px]" : "bottom-[72px]"
    )}>
      <div className="bg-card border border-border/80 p-3.5 rounded-2xl shadow-elevated glass flex flex-col gap-2 relative">
        
        {/* Banner content */}
        {!showIOSInstructions ? (
          <div className="flex items-center gap-3">
            {/* App Icon */}
            <div className="h-10 w-10 rounded-xl bg-primary flex items-center justify-center text-white shrink-0 font-black shadow-inner shadow-black/10 text-base">
              FK
            </div>
            
            {/* Text details */}
            <div className="flex-1 min-w-0">
              <h4 className="text-xs font-black text-text-primary tracking-tight">Install FastKirana App</h4>
              <p className="text-[10px] font-bold text-text-secondary truncate mt-0.5">
                Get fast delivery & a smoother app experience.
              </p>
            </div>

            {/* Actions */}
            <div className="flex items-center gap-2">
              <button
                onClick={handleInstallClick}
                className="h-8 px-3 rounded-lg bg-[#00b140] hover:bg-accent-dark text-white font-extrabold text-[10px] flex items-center gap-1 transition-colors shrink-0"
              >
                <Download size={11} className="stroke-[2.5]" />
                Install
              </button>
              
              <button 
                onClick={handleDismiss}
                className="h-7 w-7 rounded-lg border border-border hover:bg-muted flex items-center justify-center text-text-secondary shrink-0"
                aria-label="Dismiss banner"
              >
                <X size={13} />
              </button>
            </div>
          </div>
        ) : (
          /* iOS Instructions UI */
          <div className="flex flex-col gap-1.5 p-1">
            <div className="flex items-center justify-between">
              <h4 className="text-xs font-black text-text-primary">How to install on iOS Safari:</h4>
              <button 
                onClick={handleDismiss}
                className="h-6 w-6 rounded-lg hover:bg-muted flex items-center justify-center text-text-secondary"
                aria-label="Dismiss banner"
              >
                <X size={12} />
              </button>
            </div>
            <div className="text-[10px] font-bold text-text-secondary space-y-1.5 mt-1">
              <div className="flex items-center gap-2">
                <span className="h-4 w-4 rounded-full bg-muted flex items-center justify-center text-[9px] font-black shrink-0">1</span>
                <span>Tap the <span className="inline-flex items-center align-middle text-primary"><Share size={12} className="inline mx-0.5" /> Share</span> icon in your Safari browser.</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="h-4 w-4 rounded-full bg-muted flex items-center justify-center text-[9px] font-black shrink-0">2</span>
                <span>Scroll down and tap <span className="font-extrabold text-text-primary">"Add to Home Screen"</span>.</span>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
