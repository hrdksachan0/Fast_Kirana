'use client'

import { Bell, X, ShieldAlert, Sparkles } from 'lucide-react'
import { useSession } from 'next-auth/react'
import { usePushNotification } from '@/hooks/use-push-notification'
import { triggerHaptic } from '@/lib/haptic'
import Image from 'next/image'
import { useCartStore } from '@/stores/cart-store'

export function PushNotificationConsent() {
  const { status } = useSession()
  const {
    isSupported,
    isIOS,
    permission,
    isSubscribed,
    isLoading,
    showPrompt,
    subscribe,
    dismiss,
  } = usePushNotification()

  const handleSubscribe = async () => {
    triggerHaptic('light')
    await subscribe()
  }

  const handleDismiss = () => {
    triggerHaptic('light')
    dismiss()
  }

  const hasCartItems = useCartStore((s) => s.items.length > 0)
  const bottomOffsetClass = hasCartItems ? "bottom-[136px]" : "bottom-[72px]"

  if (status !== 'authenticated') return null

  if (!isSupported) {
    if (isIOS && showPrompt) {
      return (
        <div className={`fixed ${bottomOffsetClass} left-4 right-4 z-40 sm:bottom-6 sm:right-6 sm:left-auto sm:w-[400px] overflow-hidden bg-amber-50 dark:bg-amber-950/20 border border-amber-200 dark:border-amber-900/40 p-4 rounded-2xl shadow-elevated flex items-start justify-between gap-3 animate-slide-up`}>
          <div className="flex gap-3">
            <div className="h-10 w-10 rounded-xl overflow-hidden shadow-sm border border-amber-250 dark:border-amber-900/30 shrink-0">
              <Image src="/icons/icon-192.png" alt="FastKirana" width={40} height={40} className="object-cover" />
            </div>
            <div>
              <h4 className="text-xs font-black text-amber-800 dark:text-amber-400 flex items-center gap-1">
                iPhone Web Push Instructions
                <Sparkles className="h-3.5 w-3.5 text-amber-500 fill-amber-500/20" />
              </h4>
              <p className="text-[10px] font-bold text-amber-700/80 dark:text-amber-500/80 mt-0.5 leading-relaxed">
                To receive live updates on iPhone, open this site in **Safari**, tap the **Share** button, select **"Add to Home Screen"**, and launch the app from your Home Screen.
              </p>
            </div>
          </div>
          <button
            onClick={handleDismiss}
            className="text-amber-600/40 hover:text-amber-600 transition-colors h-7 w-7 rounded-lg hover:bg-amber-500/5 flex items-center justify-center shrink-0 cursor-pointer"
            aria-label="Dismiss banner"
          >
            <X size={14} />
          </button>
        </div>
      )
    }
    return null
  }

  if (!showPrompt || isSubscribed) return null

  // If permission is denied, show an instruction box to enable in settings
  if (permission === 'denied') {
    return (
      <div className={`fixed ${bottomOffsetClass} left-4 right-4 z-40 sm:bottom-6 sm:right-6 sm:left-auto sm:w-[400px] bg-rose-50 dark:bg-rose-950/20 border border-rose-200 dark:border-rose-900/40 p-4 rounded-2xl flex items-start justify-between gap-3 animate-fade-in shadow-elevated`}>
        <div className="flex gap-3">
          <div className="h-10 w-10 rounded-xl overflow-hidden shadow-sm border border-rose-250 dark:border-rose-900/30 shrink-0 relative">
            <Image src="/icons/icon-192.png" alt="FastKirana" width={40} height={40} className="object-cover" />
            <div className="absolute inset-0 bg-rose-500/20 flex items-center justify-center">
              <ShieldAlert className="h-4 w-4 text-rose-600" />
            </div>
          </div>
          <div>
            <h4 className="text-xs font-black text-rose-800 dark:text-rose-400">Notifications Blocked</h4>
            <p className="text-[10px] font-bold text-rose-700/80 dark:text-rose-500/80 mt-0.5 leading-relaxed">
              Please enable notification permissions for this website in your browser settings to receive live order updates.
            </p>
          </div>
        </div>
        <button
          onClick={handleDismiss}
          className="text-rose-600/40 hover:text-rose-600 transition-colors h-7 w-7 rounded-lg hover:bg-rose-500/5 flex items-center justify-center shrink-0 cursor-pointer"
          aria-label="Dismiss banner"
        >
          <X size={14} />
        </button>
      </div>
    )
  }

  return (
    <div className={`fixed ${bottomOffsetClass} left-4 right-4 z-40 sm:bottom-6 sm:right-6 sm:left-auto sm:w-[400px] overflow-hidden bg-zinc-900 dark:bg-zinc-950 border border-zinc-800 p-3.5 rounded-2xl shadow-elevated flex flex-row items-center justify-between gap-3 animate-slide-up`}>
      <div className="flex items-center gap-3 min-w-0">
        {/* App Logo with notification badge */}
        <div className="h-10 w-10 rounded-xl overflow-hidden shadow-sm border border-zinc-800 shrink-0 relative bg-zinc-800/60 flex items-center justify-center">
          <Image src="/icons/icon-192.png" alt="FastKirana" width={40} height={40} className="object-cover" />
          <span className="absolute -top-1 -right-1 flex h-2.5 w-2.5">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-accent opacity-80"></span>
            <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-accent"></span>
          </span>
        </div>

        <div className="min-w-0">
          <h4 className="text-xs font-black text-white tracking-tight flex items-center gap-1">
            Stay Updated in Real-Time
            <Sparkles className="h-3.5 w-3.5 text-amber-400 fill-amber-400/20" />
          </h4>
          <p className="text-[10px] font-bold text-zinc-400 mt-0.5 leading-tight">
            Get instant push notifications when your order is Out for Delivery.
          </p>
        </div>
      </div>

      <div className="flex items-center gap-2 shrink-0">
        <button
          onClick={handleSubscribe}
          disabled={isLoading}
          className="h-8 px-3.5 rounded-xl bg-white hover:bg-zinc-100 text-zinc-900 dark:bg-white dark:hover:bg-zinc-100 dark:text-zinc-950 font-black text-[10px] flex items-center gap-1.5 transition-all shadow-md disabled:opacity-75 disabled:cursor-not-allowed cursor-pointer"
        >
          {isLoading ? (
            <span className="h-3 w-3 border-2 border-zinc-900/30 border-t-zinc-900 rounded-full animate-spin" />
          ) : (
            <Bell size={11} className="stroke-[2.5]" />
          )}
          Enable
        </button>

        <button
          onClick={handleDismiss}
          className="h-8 w-8 rounded-xl border border-zinc-800 bg-transparent hover:bg-zinc-800 flex items-center justify-center text-zinc-400 hover:text-white transition-colors cursor-pointer"
          aria-label="No thanks"
        >
          <X size={13} />
        </button>
      </div>
    </div>
  )
}
