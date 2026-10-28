'use client'

import { useEffect, useState, useMemo } from 'react'
import { useSearchParams } from 'next/navigation'
import Image from 'next/image'
import { Zap, Download, ExternalLink, ShoppingBag, ShieldCheck, ArrowRight, Smartphone } from 'lucide-react'

const PLAY_STORE_PACKAGE = 'com.fastkirana.app'
const PLAY_STORE_URL = `https://play.google.com/store/apps/details?id=${PLAY_STORE_PACKAGE}`
const APP_SCHEME = 'fastminute'
const FALLBACK_SCHEME = 'fastkirana'

export function AppRedirectClient() {
  const searchParams = useSearchParams()
  const [deviceType, setDeviceType] = useState<'android' | 'ios' | 'desktop'>('android')
  const [isInstagramBrowser, setIsInstagramBrowser] = useState(false)
  const [redirectAttempted, setRedirectAttempted] = useState(false)
  const [statusMessage, setStatusMessage] = useState('Opening FastMinute App...')

  // Construct target link, query parameters & deep link intent
  const { targetPath, fullReferrer, appIntentUrl, directPlayStoreUrl } = useMemo(() => {
    const rawTarget = searchParams.get('target') || searchParams.get('path') || 'home'
    const cleanTarget = rawTarget.replace(/^\//, '')
    const paramsString = searchParams.toString()

    // Pass UTM referrer to Google Play Store install attribution
    const referrer = paramsString || 'utm_source=instagram&utm_medium=bio_link&utm_campaign=profile'
    const storeLink = `${PLAY_STORE_URL}&referrer=${encodeURIComponent(referrer)}`

    // Standard Android Chrome / Instagram In-App Browser intent:
    // Tries to launch installed FastMinute app; if absent, redirects to Play Store listing.
    const intent = `intent://${cleanTarget}#Intent;scheme=${APP_SCHEME};package=${PLAY_STORE_PACKAGE};S.browser_fallback_url=${encodeURIComponent(
      storeLink
    )};S.market_referrer=${encodeURIComponent(referrer)};end`

    return {
      targetPath: cleanTarget,
      fullReferrer: referrer,
      appIntentUrl: intent,
      directPlayStoreUrl: storeLink,
    }
  }, [searchParams])

  useEffect(() => {
    if (typeof window === 'undefined') return

    const ua = navigator.userAgent || navigator.vendor || (window as any).opera || ''
    const isAndroid = /android/i.test(ua)
    const isIOS = /iPad|iPhone|iPod/.test(ua) && !(window as any).MSStream
    const isIG = /Instagram|FBAN|FBAV/i.test(ua)

    setIsInstagramBrowser(isIG)

    if (isAndroid) {
      setDeviceType('android')
      setStatusMessage('Launching FastMinute App on Android...')

      // Attempt automatic deep-link redirection
      try {
        setRedirectAttempted(true)
        window.location.href = appIntentUrl
      } catch (err) {
        console.warn('Auto intent redirect prevented:', err)
      }

      // Fallback timer: If still on page after 2.5s, update status
      const timer = setTimeout(() => {
        setStatusMessage('App opening or ready to download')
      }, 2500)

      return () => clearTimeout(timer)
    } else if (isIOS) {
      setDeviceType('ios')
      setStatusMessage('FastMinute is currently available on Android & Web')
    } else {
      setDeviceType('desktop')
      setStatusMessage('Welcome to FastMinute')
      // If desktop, give 2 seconds and redirect to web store
      const timer = setTimeout(() => {
        const dest = targetPath && targetPath !== 'home' ? `/${targetPath}` : '/'
        const query = searchParams.toString()
        window.location.href = query ? `${dest}?${query}` : dest
      }, 3000)

      return () => clearTimeout(timer)
    }
  }, [appIntentUrl, searchParams, targetPath])

  const handleManualAppLaunch = () => {
    if (deviceType === 'android') {
      window.location.href = appIntentUrl
    } else {
      window.location.href = '/'
    }
  }

  return (
    <div className="min-h-screen bg-neutral-950 text-white flex flex-col items-center justify-between p-4 selection:bg-emerald-500 selection:text-black">
      {/* Background radial gradient */}
      <div className="fixed inset-0 pointer-events-none bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] from-emerald-950/40 via-neutral-950 to-neutral-950" />

      {/* Top Brand Bar */}
      <header className="relative z-10 w-full max-w-md pt-4 flex items-center justify-center">
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-neutral-900/80 border border-neutral-800 text-xs font-medium text-neutral-300 backdrop-blur-md">
          <Zap className="w-3.5 h-3.5 text-emerald-400 fill-emerald-400" />
          <span>FastMinute Express • 10-Minute Delivery</span>
        </div>
      </header>

      {/* Main Card */}
      <main className="relative z-10 w-full max-w-sm my-auto py-6 flex flex-col items-center text-center">
        {/* App Logo with animated glow */}
        <div className="relative mb-6">
          <div className="absolute -inset-2 bg-gradient-to-r from-emerald-500 to-green-500 rounded-3xl blur-xl opacity-40 animate-pulse" />
          <div className="relative w-24 h-24 rounded-2xl bg-gradient-to-b from-neutral-800 to-neutral-900 p-2 shadow-2xl border border-neutral-700/60 flex items-center justify-center overflow-hidden">
            <Image
              src="/brand/fastkirana_app_icon.png"
              alt="FastMinute App"
              width={80}
              height={80}
              priority
              className="rounded-xl object-cover"
              onError={(e) => {
                // Fallback icon path if brand subfolder has different image
                const target = e.target as HTMLImageElement
                if (!target.src.includes('fastkirana_app_icon.png')) {
                  target.src = '/fastkirana_app_icon.png'
                }
              }}
            />
          </div>
        </div>

        {/* Title */}
        <h1 className="text-2xl font-bold tracking-tight text-white flex items-center justify-center gap-1.5 mb-1">
          FastMinute
          <span className="text-xs px-2 py-0.5 rounded-md bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 font-semibold uppercase tracking-wider">
            App
          </span>
        </h1>
        <p className="text-neutral-400 text-sm max-w-xs mb-6">
          Ghatampur&apos;s 10-Minute Grocery &amp; Hot Food Delivery
        </p>

        {/* Status / Loader Pill */}
        <div className="mb-6 flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-neutral-900 border border-neutral-800/80 text-xs text-neutral-300">
          <span className="relative flex h-2 w-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
            <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
          </span>
          <span className="font-mono">{statusMessage}</span>
        </div>

        {/* Action Buttons */}
        <div className="w-full space-y-3">
          {/* Primary CTA: Open App */}
          <button
            onClick={handleManualAppLaunch}
            className="w-full py-3.5 px-4 rounded-xl bg-gradient-to-r from-emerald-500 to-emerald-600 hover:from-emerald-400 hover:to-emerald-500 text-neutral-950 font-bold text-base shadow-lg shadow-emerald-500/20 active:scale-[0.98] transition flex items-center justify-center gap-2"
          >
            <Zap className="w-5 h-5 fill-neutral-950" />
            <span>Open in FastMinute App</span>
          </button>

          {/* Secondary CTA: Google Play Store */}
          <a
            href={directPlayStoreUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="w-full py-3 px-4 rounded-xl bg-neutral-900 hover:bg-neutral-800 border border-neutral-800 text-white font-medium text-sm active:scale-[0.98] transition flex items-center justify-center gap-2.5"
          >
            <Download className="w-4 h-4 text-emerald-400" />
            <span>Install from Google Play</span>
            <span className="text-[10px] uppercase font-bold px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400 ml-auto">
              FREE
            </span>
          </a>

          {/* Tertiary CTA: Web Store */}
          <a
            href={targetPath && targetPath !== 'home' ? `/${targetPath}` : '/'}
            className="w-full py-2.5 px-4 rounded-xl text-neutral-400 hover:text-white font-medium text-xs flex items-center justify-center gap-1.5 transition"
          >
            <ExternalLink className="w-3.5 h-3.5" />
            <span>Or continue on Web Store (fastminute.in)</span>
          </a>
        </div>

        {/* Feature Highlights */}
        <div className="w-full grid grid-cols-3 gap-2 mt-8 pt-6 border-t border-neutral-900 text-[11px] text-neutral-400">
          <div className="flex flex-col items-center">
            <span className="text-emerald-400 font-bold text-sm">⚡ 10-25m</span>
            <span>Fast Delivery</span>
          </div>
          <div className="flex flex-col items-center border-x border-neutral-900">
            <span className="text-emerald-400 font-bold text-sm">₹0 Fee</span>
            <span>On Orders ₹99+</span>
          </div>
          <div className="flex flex-col items-center">
            <span className="text-emerald-400 font-bold text-sm">⭐ 100%</span>
            <span>Fresh &amp; Packed</span>
          </div>
        </div>
      </main>

      {/* Footer info */}
      <footer className="relative z-10 w-full max-w-sm pb-4 text-center">
        <p className="text-[11px] text-neutral-500 flex items-center justify-center gap-1">
          <ShieldCheck className="w-3 h-3 text-emerald-500" />
          <span>Official FastMinute Quick Commerce Smart Link</span>
        </p>
      </footer>
    </div>
  )
}
