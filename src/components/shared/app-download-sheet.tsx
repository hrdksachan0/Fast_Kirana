'use client'

import { useEffect, useState, useCallback } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { X } from 'lucide-react'
import { usePathname } from 'next/navigation'
import Image from 'next/image'

const PLAY_STORE_URL =
  'https://play.google.com/store/apps/details?id=com.fastkirana.app'
const DISMISSED_KEY = 'fk_app_sheet_dismissed'
const SHOW_DELAY_MS = 3000

const BLOCKED_PREFIXES = [
  '/admin',
  '/restaurant-kitchen',
  '/cafe-kitchen',
  '/picker',
  '/delivery',
  '/restaurant-login',
  '/superadmin',
  '/auth/mobile-login',
  '/auth/mobile-callback',
]

export function AppDownloadSheet() {
  const pathname = usePathname()
  const [show, setShow] = useState(false)

  useEffect(() => {
    if (typeof window === 'undefined') return

    // Only show on Android — no iOS app exists
    const ua = navigator.userAgent || ''
    if (!/android/i.test(ua)) return

    const isStandalone =
      window.matchMedia('(display-mode: standalone)').matches ||
      document.referrer.includes('android-app://')
    if (isStandalone) return
    if (window.innerWidth > 768) return
    if (pathname && BLOCKED_PREFIXES.some((p) => pathname.startsWith(p))) return
    try {
      const ts = localStorage.getItem(DISMISSED_KEY)
      if (ts && Date.now() - parseInt(ts, 10) < 24 * 60 * 60 * 1000) return
    } catch {}
    const timer = setTimeout(() => setShow(true), SHOW_DELAY_MS)
    return () => clearTimeout(timer)
  }, [pathname])

  const dismiss = useCallback(() => {
    setShow(false)
    try {
      localStorage.setItem(DISMISSED_KEY, Date.now().toString())
    } catch {}
  }, [])

  const openApp = useCallback(() => {
    if (typeof window === 'undefined') return
    // Try to open the installed app, fall back to Play Store
    const intent =
      'intent://open#Intent;scheme=fastkirana;package=com.fastkirana.app;end'
    const start = Date.now()
    window.location.href = intent
    setTimeout(() => {
      if (Date.now() - start < 1800) window.location.href = PLAY_STORE_URL
    }, 800)
  }, [])

  if (pathname && BLOCKED_PREFIXES.some((p) => pathname.startsWith(p))) {
    return null
  }

  return (
    <AnimatePresence>
      {show && (
        <>
          {/* Overlay */}
          <motion.div
            key="dl-overlay"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.3 }}
            className="fixed inset-0 z-[9998] bg-black/50"
            onClick={dismiss}
          />

          {/* Sheet */}
          <motion.div
            key="dl-sheet"
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{ type: 'spring', damping: 30, stiffness: 350 }}
            className="fixed inset-x-0 bottom-0 z-[9999] md:hidden"
          >
            {/* Close */}
            <div className="flex justify-center pb-3">
              <button
                type="button"
                onClick={dismiss}
                aria-label="Close"
                className="h-7 w-7 rounded-full bg-white/90 shadow-md flex items-center
                           justify-center active:scale-90 transition-transform cursor-pointer"
              >
                <X size={14} strokeWidth={2.5} className="text-zinc-600" />
              </button>
            </div>

            <div className="rounded-t-3xl bg-white px-5 pb-8 pt-5 shadow-[0_-4px_30px_rgba(0,0,0,0.15)]">
              {/* Icon + Text */}
              <div className="flex flex-col items-center text-center">
                <div className="h-14 w-14 rounded-2xl overflow-hidden shadow-md border border-zinc-100">
                  <Image
                    src="/brand/fastkirana_app_icon.png"
                    alt="FastKirana"
                    width={56}
                    height={56}
                    className="h-full w-full object-contain"
                  />
                </div>

                <h3 className="mt-3 text-[17px] font-extrabold text-zinc-900">
                  Better experience on the app
                </h3>
                <p className="mt-1 text-[13px] text-zinc-500">
                  Live tracking • Faster checkout • Exclusive deals
                </p>
              </div>

              {/* CTA */}
              <button
                type="button"
                onClick={openApp}
                className="mt-5 w-full rounded-xl bg-[#e20a22] py-3 text-[15px]
                           font-bold text-white shadow-sm active:bg-[#b30013]
                           transition-colors cursor-pointer"
              >
                Open in App
              </button>

              <button
                type="button"
                onClick={dismiss}
                className="mt-2.5 w-full py-1.5 text-[13px] font-medium text-zinc-400
                           cursor-pointer"
              >
                Continue on web
              </button>
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  )
}
