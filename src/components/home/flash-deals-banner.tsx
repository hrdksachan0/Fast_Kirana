'use client'

import { useState, useEffect } from 'react'
import { usePushNotification } from '@/hooks/use-push-notification'
import { Bell, Sparkles, Check, X } from 'lucide-react'
import { triggerHaptic } from '@/lib/haptic'
import { toast } from 'sonner'
import Image from 'next/image'

export function FlashDealsBanner() {
  const { subscribe, isSubscribed } = usePushNotification()
  const [enabled, setEnabled] = useState(false)
  const [isDismissed, setIsDismissed] = useState(false)

  useEffect(() => {
    if (typeof window !== 'undefined') {
      const isAlertActive = localStorage.getItem('flash-deals-alerts-enabled') === 'true'
      const dismissed = localStorage.getItem('flash-deals-banner-dismissed') === 'true'
      
      setTimeout(() => {
        setEnabled(isSubscribed && isAlertActive)
        setIsDismissed(dismissed || (isSubscribed && isAlertActive))
      }, 0)
    }
  }, [isSubscribed])

  const handleToggle = () => {
    triggerHaptic('light')
    
    if (enabled) {
      localStorage.setItem('flash-deals-alerts-enabled', 'false')
      setEnabled(false)
      toast.success('Muted flash sale alerts.')
      return
    }

    subscribe(() => {
      localStorage.setItem('flash-deals-alerts-enabled', 'true')
      setEnabled(true)
      toast.success('⚡ Alerts Active! We will ping you before flash deals end.', {
        id: 'flash-deals-alert-success',
      })
    })

    // Immediately dismiss the banner when they click subscribe/notify to keep layout clean
    localStorage.setItem('flash-deals-banner-dismissed', 'true')
    setIsDismissed(true)
  }

  if (isDismissed) return null

  return (
    <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-red-600 via-rose-600 to-orange-500 p-4 shadow-lg hover:shadow-xl transition-all duration-300 border border-white/10 my-4">
      {/* Close Button */}
      <button
        onClick={() => {
          triggerHaptic('light')
          localStorage.setItem('flash-deals-banner-dismissed', 'true')
          setIsDismissed(true)
        }}
        className="absolute top-2.5 right-2.5 p-1 rounded-full text-white/60 hover:text-white hover:bg-white/10 transition-colors z-20 cursor-pointer"
        aria-label="Dismiss banner"
      >
        <X size={14} className="stroke-[2.5]" />
      </button>

      {/* Decorative background shapes */}
      <div className="absolute top-[-50%] right-[-10%] w-[180px] h-[180px] rounded-full bg-white/10 blur-[30px] pointer-events-none" />
      <div className="absolute bottom-[-30%] left-[-5%] w-[120px] h-[120px] rounded-full bg-orange-400/20 blur-[20px] pointer-events-none" />

      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 relative z-10">
        <div className="flex items-center gap-3">
          {/* App Logo */}
          <div className="h-11 w-11 rounded-xl overflow-hidden shadow-lg border-2 border-white/25 shrink-0">
            <Image
              src="/icons/icon-192.png"
              alt="FastKirana"
              width={44}
              height={44}
              className="object-cover"
            />
          </div>
          <div className="text-center sm:text-left">
            <h4 className="text-white font-extrabold text-sm tracking-tight flex items-center gap-1 justify-center sm:justify-start">
              10-Min Flash Deal Alerts
              <Sparkles className="h-3.5 w-3.5 text-amber-300 fill-amber-300/20" />
            </h4>
            <p className="text-rose-100/90 text-[10.5px] font-semibold mt-0.5 leading-relaxed">
              Get notified the exact second limited-time bargains drop! Don&apos;t miss out on 60% items.
            </p>
          </div>
        </div>

        <button
          onClick={handleToggle}
          className={`w-full sm:w-auto h-9 px-5 font-black text-[10.5px] rounded-xl transition-all shadow-md active:scale-98 cursor-pointer shrink-0 flex items-center justify-center gap-1.5 ${
            enabled
              ? 'bg-white/20 hover:bg-white/25 text-white border border-white/30'
              : 'bg-white hover:bg-white/95 text-rose-600'
          }`}
        >
          {enabled ? (
            <>
              <Check size={11} className="stroke-[3]" />
              Alerts Active
            </>
          ) : (
            <>
              <Bell size={11} className="stroke-[2.5]" />
              Notify Me
            </>
          )}
        </button>
      </div>
    </div>
  )
}
