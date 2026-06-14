'use client'

import { usePushNotification } from '@/hooks/use-push-notification'
import { Sparkles, Bell } from 'lucide-react'
import { triggerHaptic } from '@/lib/haptic'

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

  return (
    <div className="bg-card border border-border p-4 sm:p-5 rounded-2xl shadow-sm space-y-4 animate-fade-in overflow-hidden relative">
      {/* Lockscreen preview environment */}
      <div className="relative rounded-xl overflow-hidden bg-gradient-to-br from-slate-900 via-indigo-950 to-slate-950 p-6 flex flex-col items-center justify-center min-h-[190px] border border-white/10">
        
        {/* Lockscreen clock */}
        <div className="text-center text-white/75 mb-3 select-none">
          <span className="text-2xl font-light tracking-tight font-sans">09:41</span>
          <p className="text-[8px] font-bold uppercase tracking-widest mt-0.5 opacity-70">Monday, June 15</p>
        </div>

        {/* Styled Glassmorphic Notification Card */}
        <div className="w-full max-w-[270px] bg-white/10 dark:bg-black/35 backdrop-blur-md border border-white/20 dark:border-white/10 rounded-2xl p-3 shadow-2xl relative animate-float-slow">
          <div className="flex items-center justify-between mb-1">
            <div className="flex items-center gap-1.5">
              {/* App Icon */}
              <div className="h-4.5 w-4.5 bg-primary rounded-md flex items-center justify-center text-[10px] text-white font-extrabold select-none shadow">
                F
              </div>
              <span className="text-[8px] font-black text-white/90 tracking-wider uppercase">FastKirana</span>
            </div>
            <span className="text-[7.5px] font-bold text-white/60">now</span>
          </div>
          <div>
            <h4 className="text-[10px] font-black text-white">Ramesh is 2 mins away! 🚴</h4>
            <p className="text-[8.5px] font-bold text-white/80 mt-0.5 leading-snug">
              Your delivery executive is approaching your location with fresh groceries.
            </p>
          </div>
        </div>

        {/* Lock Screen bottom indicator bar */}
        <div className="absolute bottom-2 left-1/2 -translate-x-1/2 w-20 h-0.5 bg-white/40 rounded-full" />
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
