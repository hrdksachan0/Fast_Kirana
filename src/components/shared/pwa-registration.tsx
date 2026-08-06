'use client'

import { useEffect, useState } from 'react'
import { Download, X, Share } from 'lucide-react'

export function PWARegistration() {
  const [deferredPrompt, setDeferredPrompt] = useState<any>(null)
  const [showBanner, setShowBanner] = useState(false)
  const [isIOS, setIsIOS] = useState(false)
  const [showIOSInstructions, setShowIOSInstructions] = useState(false)

  useEffect(() => {
    // 1. Register Service Worker
    if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
      const registerSW = () => {
        navigator.serviceWorker
          .register('/sw.js?v=2')
          .then((reg) => {
            reg.update()
          })
          .catch((err) => {
            console.error('ServiceWorker registration failed: ', err)
          })
      }

      if (document.readyState === 'complete') {
        registerSW()
      } else {
        window.addEventListener('load', registerSW)
      }
    }

    // 2. Detect standalone mode
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

  if (!showBanner) return null

  // iOS instructions modal overlay
  if (showIOSInstructions) {
    return (
      <div className="fixed inset-0 z-[60] flex items-end justify-center md:hidden">
        <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={handleDismiss} />
        <div className="relative w-full max-w-md mx-3 mb-6 bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-2xl p-5 shadow-2xl animate-slide-up">
          <div className="flex items-center justify-between mb-3">
            <h4 className="text-sm font-black text-zinc-900 dark:text-zinc-100">Install on iOS</h4>
            <button 
              onClick={handleDismiss}
              className="h-7 w-7 rounded-full bg-zinc-100 dark:bg-zinc-800 flex items-center justify-center text-zinc-500 hover:text-zinc-700"
              aria-label="Close"
            >
              <X size={14} />
            </button>
          </div>
          <div className="text-xs font-medium text-zinc-600 dark:text-zinc-400 space-y-3">
            <div className="flex items-center gap-3">
              <span className="h-6 w-6 rounded-full bg-[#e20a22]/10 text-[#e20a22] flex items-center justify-center text-[11px] font-black shrink-0">1</span>
              <span>Tap the <span className="inline-flex items-center align-middle text-[#007AFF] font-bold"><Share size={13} className="inline mx-0.5" /> Share</span> button in Safari.</span>
            </div>
            <div className="flex items-center gap-3">
              <span className="h-6 w-6 rounded-full bg-[#e20a22]/10 text-[#e20a22] flex items-center justify-center text-[11px] font-black shrink-0">2</span>
              <span>Scroll down and tap <span className="font-bold text-zinc-900 dark:text-zinc-100">&quot;Add to Home Screen&quot;</span>.</span>
            </div>
          </div>
        </div>
      </div>
    )
  }

  // Slim inline smart app banner — NOT fixed/floating, rendered inside page flow
  return (
    <div className="md:hidden">
      <div className="mx-3 mt-1.5 mb-1 flex items-center gap-2.5 bg-white dark:bg-zinc-900 border border-zinc-200/80 dark:border-zinc-800/80 rounded-xl px-3 py-2 shadow-sm">
        {/* App Icon */}
        <div className="h-8 w-8 rounded-lg overflow-hidden shrink-0 border border-zinc-200 dark:border-zinc-700 shadow-sm">
          <img src="/icons/icon-192.png" alt="FastKirana" className="object-cover h-full w-full" />
        </div>
        
        {/* Text */}
        <div className="flex-1 min-w-0">
          <p className="text-[11px] font-extrabold text-zinc-900 dark:text-zinc-100 leading-tight">Install FastKirana App</p>
          <p className="text-[9px] font-medium text-zinc-500 dark:text-zinc-400 truncate leading-tight mt-px">
            Get fast delivery & a smoother app experience.
          </p>
        </div>

        {/* Install Button */}
        <button
          onClick={handleInstallClick}
          className="h-7 px-3 rounded-lg bg-[#00b140] hover:bg-[#009935] text-white font-bold text-[10px] flex items-center gap-1 transition-colors shrink-0 active:scale-95"
        >
          <Download size={10} className="stroke-[2.5]" />
          Install
        </button>
        
        {/* Dismiss */}
        <button 
          onClick={handleDismiss}
          className="h-6 w-6 rounded-full bg-zinc-100 dark:bg-zinc-800 flex items-center justify-center text-zinc-400 hover:text-zinc-600 shrink-0"
          aria-label="Dismiss"
        >
          <X size={11} />
        </button>
      </div>
    </div>
  )
}

