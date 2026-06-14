'use client'

import { usePushNotification } from '@/hooks/use-push-notification'
import { Sparkles, Bell, ChevronUp } from 'lucide-react'
import { triggerHaptic } from '@/lib/haptic'
import Image from 'next/image'

interface LockscreenAlertMockupProps {
  orderId?: string
}

export function LockscreenAlertMockup({ orderId }: LockscreenAlertMockupProps) {
  const { isSubscribed, permission, subscribe, isSupported } = usePushNotification()

  if (isSubscribed || permission !== 'default' || !isSupported) {
    return null
  }

  const handleSubscribe = () => {
    triggerHaptic('light')
    subscribe()
  }

  const displayId = orderId || 'NCHWB4'

  return (
    <div className="bg-card border border-border p-4 sm:p-5 rounded-2xl shadow-sm space-y-4 animate-fade-in overflow-hidden relative">
      {/* Lockscreen preview environment */}
      <div className="relative rounded-xl overflow-hidden bg-[#0a0a0c] p-5 pb-6 flex flex-col items-center justify-center min-h-[350px] border border-white/10">
        {/* Subtle lockscreen wallpaper gradient */}
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-zinc-900/40 via-[#0a0a0c] to-black pointer-events-none" />
        
        {/* Lockscreen clock */}
        <div className="text-center text-zinc-400 mb-5 select-none relative z-10">
          <span className="text-2xl font-light tracking-tight font-sans text-white">09:41</span>
          <p className="text-[8px] font-bold uppercase tracking-widest mt-0.5 opacity-60">Monday, June 15</p>
        </div>

        {/* === Notification Group (Swiggy / Blinkit style) === */}
        <div className="w-full max-w-[320px] space-y-2 relative z-10 select-none">
          
          {/* Notification 1 — Rider on the way */}
          <div className="bg-[#1c1c1e]/95 backdrop-blur-xl border border-zinc-800/60 rounded-2xl p-3 shadow-2xl">
            {/* App header row with logo */}
            <div className="flex items-center gap-2 mb-2">
              <div className="h-5 w-5 rounded-md overflow-hidden shadow-sm shrink-0 border border-zinc-700/50">
                <Image
                  src="/icons/icon-192.png"
                  alt="FastKirana"
                  width={20}
                  height={20}
                  className="object-cover"
                />
              </div>
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wide">FASTKIRANA</span>
              <span className="text-[10px] text-zinc-500 ml-auto">2m ago</span>
            </div>
            {/* Content row */}
            <div className="flex items-start gap-2.5">
              <div className="flex-1 min-w-0">
                <h5 className="text-[11px] font-extrabold text-white leading-tight">
                  🚴 Rider is on the way!
                </h5>
                <p className="text-[10px] font-semibold text-zinc-400 mt-0.5 leading-snug line-clamp-2">
                  Your order #{displayId} has been picked up and the rider is headed to you. Arriving in ~8 mins.
                </p>
              </div>
              <div className="h-9 w-9 rounded-lg overflow-hidden border border-zinc-700/50 shadow-md shrink-0">
                <Image
                  src="/icons/icon-192.png"
                  alt="FastKirana Logo"
                  width={36}
                  height={36}
                  className="object-cover"
                />
              </div>
            </div>
          </div>

          {/* Notification 2 — Order packed */}
          <div className="bg-[#1c1c1e]/95 backdrop-blur-xl border border-zinc-800/60 rounded-2xl p-3 shadow-2xl">
            {/* App header row with logo */}
            <div className="flex items-center gap-2 mb-2">
              <div className="h-5 w-5 rounded-md overflow-hidden shadow-sm shrink-0 border border-zinc-700/50">
                <Image
                  src="/icons/icon-192.png"
                  alt="FastKirana"
                  width={20}
                  height={20}
                  className="object-cover"
                />
              </div>
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wide">FASTKIRANA</span>
              <span className="text-[10px] text-zinc-500 ml-auto">8m ago</span>
            </div>
            {/* Content row */}
            <div className="flex items-start gap-2.5">
              <div className="flex-1 min-w-0">
                <h5 className="text-[11px] font-extrabold text-white leading-tight">
                  📦 Order Packed & Ready
                </h5>
                <p className="text-[10px] font-semibold text-zinc-400 mt-0.5 leading-snug line-clamp-2">
                  Your order #{displayId} is packed. A rider will pick it up shortly.
                </p>
              </div>
              <div className="h-9 w-9 rounded-lg overflow-hidden border border-zinc-700/50 shadow-md shrink-0">
                <Image
                  src="/icons/icon-192.png"
                  alt="FastKirana Logo"
                  width={36}
                  height={36}
                  className="object-cover"
                />
              </div>
            </div>
          </div>

          {/* Notification 3 — Order confirmed (partially hidden / stacked) */}
          <div className="bg-[#1c1c1e]/80 backdrop-blur-xl border border-zinc-800/40 rounded-2xl p-3 shadow-xl opacity-70 scale-[0.97] origin-top">
            <div className="flex items-center gap-2 mb-1.5">
              <div className="h-5 w-5 rounded-md overflow-hidden shadow-sm shrink-0 border border-zinc-700/50">
                <Image
                  src="/icons/icon-192.png"
                  alt="FastKirana"
                  width={20}
                  height={20}
                  className="object-cover"
                />
              </div>
              <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wide">FASTKIRANA</span>
              <span className="text-[10px] text-zinc-500 ml-auto">12m ago</span>
            </div>
            <div className="flex items-start gap-2.5">
              <div className="flex-1 min-w-0">
                <h5 className="text-[11px] font-extrabold text-white leading-tight">
                  ✅ Order Confirmed!
                </h5>
                <p className="text-[10px] font-semibold text-zinc-400 mt-0.5 line-clamp-1">
                  Your order #{displayId} is confirmed. We're preparing it now...
                </p>
              </div>
              <div className="h-9 w-9 rounded-lg overflow-hidden border border-zinc-700/50 shadow-md shrink-0">
                <Image
                  src="/icons/icon-192.png"
                  alt="FastKirana Logo"
                  width={36}
                  height={36}
                  className="object-cover"
                />
              </div>
            </div>
          </div>

        </div>

        {/* Lock Screen bottom indicator bar */}
        <div className="absolute bottom-2.5 left-1/2 -translate-x-1/2 w-28 h-1 bg-zinc-700 rounded-full" />
      </div>

      {/* Information & Action */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 pt-1">
        <div className="space-y-1 text-center sm:text-left">
          <h3 className="text-xs font-black text-text-primary flex items-center gap-1 justify-center sm:justify-start">
            Enable Lockscreen Live Updates
            <Sparkles className="h-3.5 w-3.5 text-amber-500 fill-amber-500/20" />
          </h3>
          <p className="text-[10px] text-text-secondary leading-relaxed font-semibold">
            Get real-time order status, rider maps, and delivery alerts directly on your lockscreen.
          </p>
        </div>
        <button
          onClick={handleSubscribe}
          className="w-full sm:w-auto h-9 px-5 bg-primary hover:bg-primary/95 text-white font-black text-[10.5px] rounded-xl transition-all shadow-md active:scale-98 cursor-pointer shrink-0 flex items-center justify-center gap-1.5"
        >
          <Bell size={11} className="stroke-[2.5]" />
          Turn On Live Alerts
        </button>
      </div>
    </div>
  )
}
