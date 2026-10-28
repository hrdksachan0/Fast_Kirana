'use client'

import { useEffect, useMemo } from 'react'
import { useSearchParams } from 'next/navigation'
import Image from 'next/image'
import { Download, ExternalLink } from 'lucide-react'

const PLAY_STORE_PACKAGE = 'com.fastkirana.app'
const BASE_PLAY_STORE_URL = `https://play.google.com/store/apps/details?id=${PLAY_STORE_PACKAGE}`
const MARKET_URL = `market://details?id=${PLAY_STORE_PACKAGE}`

export function AppRedirectClient() {
  const searchParams = useSearchParams()

  const { fullPlayStoreUrl, marketUrlWithReferrer } = useMemo(() => {
    const paramsString = searchParams.toString()
    const referrer = paramsString || 'utm_source=instagram&utm_medium=bio_link&utm_campaign=profile'
    const encodedReferrer = encodeURIComponent(referrer)

    return {
      fullPlayStoreUrl: `${BASE_PLAY_STORE_URL}&referrer=${encodedReferrer}`,
      marketUrlWithReferrer: `${MARKET_URL}&referrer=${encodedReferrer}`,
    }
  }, [searchParams])

  useEffect(() => {
    if (typeof window === 'undefined') return

    const ua = navigator.userAgent || ''
    const isAndroid = /android/i.test(ua)

    // Immediate 0-second redirection to Google Play Store
    if (isAndroid) {
      // 1. Try native Play Store app protocol
      try {
        window.location.replace(marketUrlWithReferrer)
      } catch (_) {
        window.location.replace(fullPlayStoreUrl)
      }

      // 2. Safety fallback: if market:// doesn't switch immediately, open standard Play Store web URL
      const timer = setTimeout(() => {
        window.location.replace(fullPlayStoreUrl)
      }, 300)

      return () => clearTimeout(timer)
    } else {
      // Desktop / iOS: Direct to Play Store web page
      window.location.replace(fullPlayStoreUrl)
    }
  }, [fullPlayStoreUrl, marketUrlWithReferrer])

  return (
    <div className="min-h-screen bg-neutral-950 text-white flex flex-col items-center justify-center p-4">
      {/* Background Glow */}
      <div className="fixed inset-0 pointer-events-none bg-[radial-gradient(circle_at_center,_var(--tw-gradient-stops))] from-emerald-950/40 via-neutral-950 to-neutral-950" />

      <div className="relative z-10 w-full max-w-sm flex flex-col items-center text-center">
        {/* App Icon */}
        <div className="relative mb-5">
          <div className="w-20 h-20 rounded-2xl bg-gradient-to-b from-neutral-800 to-neutral-900 p-2 shadow-2xl border border-neutral-800 flex items-center justify-center overflow-hidden">
            <Image
              src="/brand/fastkirana_app_icon.png"
              alt="FastMinute App"
              width={72}
              height={72}
              priority
              className="rounded-xl object-cover"
              onError={(e) => {
                const target = e.target as HTMLImageElement
                if (!target.src.includes('fastkirana_app_icon.png')) {
                  target.src = '/fastkirana_app_icon.png'
                }
              }}
            />
          </div>
        </div>

        {/* Title */}
        <h1 className="text-xl font-bold text-white mb-2">Redirecting to Google Play...</h1>
        <p className="text-neutral-400 text-xs mb-6 max-w-xs">
          Taking you directly to FastMinute on Google Play Store.
        </p>

        {/* Spinner */}
        <div className="w-8 h-8 rounded-full border-3 border-emerald-500 border-t-transparent animate-spin mb-6" />

        {/* Direct Manual Button in case browser blocks auto-redirect */}
        <a
          href={fullPlayStoreUrl}
          className="w-full py-3.5 px-4 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-400 hover:to-emerald-500 text-neutral-950 font-bold text-sm shadow-lg shadow-emerald-500/20 active:scale-[0.98] transition flex items-center justify-center gap-2 mb-3"
        >
          <Download className="w-4 h-4 fill-neutral-950" />
          <span>Open in Google Play Store</span>
        </a>

        <a
          href="/"
          className="text-neutral-500 hover:text-neutral-300 text-xs flex items-center gap-1 transition"
        >
          <ExternalLink className="w-3 h-3" />
          <span>Continue to FastMinute Web</span>
        </a>
      </div>
    </div>
  )
}
