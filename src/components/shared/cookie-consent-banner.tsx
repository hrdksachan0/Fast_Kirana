'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { ShieldCheck, Cookie, X, Settings2, Check } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { triggerHaptic } from '@/lib/haptic'
import { useCartStore } from '@/stores/cart-store'

export interface CookieConsentPreferences {
  necessary: boolean // always true
  analytics: boolean
  marketing: boolean
  timestamp: string
  version: string
}

const CONSENT_STORAGE_KEY = 'fastminute_consent_v1'
const CURRENT_POLICY_VERSION = '2026-11-12'

export function CookieConsentBanner() {
  const [isOpen, setIsOpen] = useState(false)
  const [showPreferences, setShowPreferences] = useState(false)
  const [analyticsEnabled, setAnalyticsEnabled] = useState(false)
  const [marketingEnabled, setMarketingEnabled] = useState(false)

  const hasCartItems = useCartStore((s) => s.items.length > 0)
  const bottomOffsetClass = hasCartItems ? 'bottom-[136px]' : 'bottom-[74px] md:bottom-6'

  useEffect(() => {
    try {
      const stored = localStorage.getItem(CONSENT_STORAGE_KEY)
      if (!stored) {
        // First visit: show consent banner after a short delay for smooth hydration
        const timer = setTimeout(() => setIsOpen(true), 1200)
        return () => clearTimeout(timer)
      } else {
        const parsed: CookieConsentPreferences = JSON.parse(stored)
        setAnalyticsEnabled(Boolean(parsed.analytics))
        setMarketingEnabled(Boolean(parsed.marketing))
      }
    } catch {
      setIsOpen(true)
    }

    // Listen to custom event to reopen preferences from footer
    const handleOpenSettings = () => {
      setShowPreferences(true)
      setIsOpen(true)
    }

    window.addEventListener('open-cookie-settings', handleOpenSettings)
    return () => window.removeEventListener('open-cookie-settings', handleOpenSettings)
  }, [])

  const saveConsent = (analytics: boolean, marketing: boolean) => {
    const prefs: CookieConsentPreferences = {
      necessary: true,
      analytics,
      marketing,
      timestamp: new Date().toISOString(),
      version: CURRENT_POLICY_VERSION,
    }

    try {
      localStorage.setItem(CONSENT_STORAGE_KEY, JSON.stringify(prefs))
      window.dispatchEvent(new CustomEvent('fastminute_consent_changed', { detail: prefs }))
    } catch {}

    triggerHaptic('light')
    setIsOpen(false)
    setShowPreferences(false)
  }

  const handleAcceptAll = () => {
    saveConsent(true, true)
  }

  const handleRejectNonEssential = () => {
    saveConsent(false, false)
  }

  const handleSaveCustom = () => {
    saveConsent(analyticsEnabled, marketingEnabled)
  }

  if (!isOpen) return null

  return (
    <>
      {/* Background overlay when modal preferences are open */}
      {showPreferences && (
        <div
          className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm animate-fade-in"
          onClick={() => setShowPreferences(false)}
        />
      )}

      {/* Main Consent Banner */}
      {!showPreferences ? (
        <div
          role="dialog"
          aria-label="Cookie & Privacy Consent"
          className={`fixed ${bottomOffsetClass} left-4 right-4 z-40 sm:left-auto sm:right-6 sm:max-w-md bg-zinc-950/95 dark:bg-zinc-900/95 border border-zinc-800 text-zinc-100 p-4 rounded-2xl shadow-2xl backdrop-blur-md animate-slide-up select-none`}
        >
          <div className="flex items-start gap-3">
            <div className="h-9 w-9 rounded-xl bg-primary/10 border border-primary/20 flex items-center justify-center shrink-0 mt-0.5 text-primary">
              <Cookie className="h-4.5 w-4.5" />
            </div>

            <div className="space-y-1.5 flex-1 min-w-0">
              <h3 className="text-xs font-black tracking-tight text-white flex items-center gap-1.5">
                Privacy &amp; Cookie Choices
                <span className="text-[10px] font-semibold text-emerald-400 bg-emerald-950/60 border border-emerald-800/40 px-1.5 py-0.2 rounded-full">
                  DPDP Act Compliant
                </span>
              </h3>
              <p className="text-[11px] text-zinc-400 leading-relaxed font-medium">
                We use strictly necessary cookies for authentication and cart checkout. With your consent, we use privacy-masked diagnostics to improve speed. We never sell your personal data.
              </p>
              <div className="pt-0.5">
                <Link
                  href="/privacy-policy"
                  className="text-[10.5px] font-bold text-primary hover:underline inline-flex items-center gap-1"
                >
                  Read our Privacy Policy &rarr;
                </Link>
              </div>
            </div>
          </div>

          <div className="mt-3.5 pt-3 border-t border-zinc-800/80 flex flex-wrap items-center justify-between gap-2">
            <button
              type="button"
              onClick={() => setShowPreferences(true)}
              className="text-[11px] font-bold text-zinc-400 hover:text-white transition-colors flex items-center gap-1 cursor-pointer py-1 px-1.5"
            >
              <Settings2 className="h-3 w-3" />
              Customize
            </button>

            <div className="flex items-center gap-2">
              <Button
                type="button"
                variant="outline"
                onClick={handleRejectNonEssential}
                className="h-8 px-3 rounded-xl border-zinc-700 bg-transparent hover:bg-zinc-800 text-zinc-200 text-xs font-bold transition-all cursor-pointer"
              >
                Reject Non-Essential
              </Button>
              <Button
                type="button"
                onClick={handleAcceptAll}
                className="h-8 px-3.5 rounded-xl bg-primary hover:bg-primary/90 text-white text-xs font-black shadow-md shadow-primary/20 transition-all cursor-pointer"
              >
                Accept All
              </Button>
            </div>
          </div>
        </div>
      ) : (
        /* Detailed Preferences Modal */
        <div
          role="dialog"
          aria-modal="true"
          className="fixed left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 z-50 w-[92vw] max-w-lg bg-zinc-950 border border-zinc-800 text-zinc-100 p-5 rounded-2xl shadow-2xl space-y-4 animate-scale-in"
        >
          <div className="flex items-center justify-between pb-3 border-b border-zinc-800">
            <div className="flex items-center gap-2">
              <ShieldCheck className="h-5 w-5 text-emerald-400" />
              <h3 className="text-sm font-black text-white">Manage Privacy Preferences</h3>
            </div>
            <button
              onClick={() => setShowPreferences(false)}
              className="text-zinc-400 hover:text-white p-1 rounded-lg hover:bg-zinc-800 transition-colors"
              aria-label="Close"
            >
              <X className="h-4 w-4" />
            </button>
          </div>

          <p className="text-xs text-zinc-400 leading-relaxed">
            Configure how FastMinute handles cookies and diagnostics on your device. You can update these settings at any time via the link in our footer.
          </p>

          <div className="space-y-3 pt-1 max-h-[60vh] overflow-y-auto pr-1">
            {/* Strictly Necessary */}
            <div className="p-3.5 rounded-xl bg-zinc-900/80 border border-zinc-800 space-y-1">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-white flex items-center gap-1.5">
                  Strictly Necessary
                  <span className="text-[9px] font-black uppercase tracking-wider text-emerald-400 bg-emerald-950/60 border border-emerald-800/40 px-1.5 py-0.5 rounded">
                    Always Active
                  </span>
                </span>
                <span className="text-xs text-emerald-400 font-bold flex items-center gap-0.5">
                  <Check className="h-3.5 w-3.5" /> Required
                </span>
              </div>
              <p className="text-[11px] text-zinc-400 leading-normal">
                Essential for core store functionality: secure OTP login sessions, maintaining your live grocery basket, and processing payments securely via Cashfree.
              </p>
            </div>

            {/* Performance & Analytics */}
            <div className="p-3.5 rounded-xl bg-zinc-900/80 border border-zinc-800 space-y-2">
              <div className="flex items-center justify-between">
                <div>
                  <span className="text-xs font-bold text-white block">Performance &amp; Diagnostics</span>
                  <span className="text-[10px] text-zinc-500 font-medium">Sentry Error Logging &amp; Speed Metrics</span>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={analyticsEnabled}
                    onChange={(e) => setAnalyticsEnabled(e.target.checked)}
                    className="sr-only peer"
                  />
                  <div className="w-9 h-5 bg-zinc-700 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-zinc-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-primary"></div>
                </label>
              </div>
              <p className="text-[11px] text-zinc-400 leading-normal">
                Helps us identify app crashes, broken checkout flows, and slow network responses. When enabled, all form inputs, passwords, and personal details remain strictly masked and encrypted.
              </p>
            </div>

            {/* Promotional & Marketing */}
            <div className="p-3.5 rounded-xl bg-zinc-900/80 border border-zinc-800 space-y-2">
              <div className="flex items-center justify-between">
                <div>
                  <span className="text-xs font-bold text-white block">Promotional Alerts</span>
                  <span className="text-[10px] text-zinc-500 font-medium">Hyperlocal discount notifications</span>
                </div>
                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={marketingEnabled}
                    onChange={(e) => setMarketingEnabled(e.target.checked)}
                    className="sr-only peer"
                  />
                  <div className="w-9 h-5 bg-zinc-700 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-zinc-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-primary"></div>
                </label>
              </div>
              <p className="text-[11px] text-zinc-400 leading-normal">
                Permits tailored local flash-sale alerts in Ghatampur for daily essentials. We never share your contact details with external ad networks.
              </p>
            </div>
          </div>

          <div className="pt-3 border-t border-zinc-800 flex items-center justify-end gap-2.5">
            <Button
              type="button"
              variant="outline"
              onClick={handleRejectNonEssential}
              className="h-9 px-4 rounded-xl border-zinc-700 bg-transparent hover:bg-zinc-800 text-zinc-300 text-xs font-bold cursor-pointer"
            >
              Reject All Optional
            </Button>
            <Button
              type="button"
              onClick={handleSaveCustom}
              className="h-9 px-5 rounded-xl bg-primary hover:bg-primary/90 text-white text-xs font-black shadow-md shadow-primary/20 cursor-pointer"
            >
              Save Preferences
            </Button>
          </div>
        </div>
      )}
    </>
  )
}
